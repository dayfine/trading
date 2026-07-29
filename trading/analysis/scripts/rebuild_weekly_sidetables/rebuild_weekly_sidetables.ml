(* CLI wrapper over {!Sidetable_migrator.migrate}: clone a snapshot warehouse
   with its sketch-v5 [SYMBOL.weekly] side-tables rebuilt on the
   split/dividend-adjusted basis (#2133). The source warehouse is never
   mutated. *)
open Core

let _print_summary (s : Sidetable_migrator.summary) =
  printf
    "migrated %d symbols: rebuilt=%d fallback_no_csv=%d \
     fallback_unstable_basis=%d date_parity_failures=%d\n\
     %!"
    s.total s.rebuilt s.fallback_no_csv s.fallback_unstable_basis
    s.date_parity_failures

let _rebuilt = function Sidetable_migrator.Rebuilt _ -> true | _ -> false

let _flagged (r : Sidetable_migrator.symbol_report) =
  (not r.date_parity) || not (_rebuilt r.outcome)

let _print_flag (r : Sidetable_migrator.symbol_report) =
  printf "  FLAG %s: %s date_parity=%b\n%!" r.symbol
    (Sexp.to_string (Sidetable_migrator.sexp_of_outcome r.outcome))
    r.date_parity

let _print_flagged (s : Sidetable_migrator.summary) =
  List.iter s.reports ~f:(fun r -> if _flagged r then _print_flag r)

let _run ~warehouse_dir ~csv_data_dir ~output_dir ~sketch_deep_days () =
  match
    Sidetable_migrator.migrate ~warehouse_dir ~csv_data_dir ~output_dir
      ~sketch_deep_days ()
  with
  | Error e ->
      eprintf "migration failed: %s\n%!" (Status.show e);
      exit 1
  | Ok summary ->
      _print_summary summary;
      _print_flagged summary

let command =
  Command.basic ~summary:"Rebuild a warehouse's weekly side-tables split-safe"
    ~readme:(fun () ->
      "Clones <warehouse-dir> into <output-dir> with adjusted-basis \
       SYMBOL.weekly side-tables (#2133): .snap files are hard-linked, \
       side-tables are rebuilt from the snap's own daily columns plus \
       CSV-store deep history re-pinned to the warehouse's adjusted basis, and \
       the cloned manifest stamps the adjusted-basis format hash. Outcomes \
       land in <output-dir>/migration_report.sexp.")
    (let%map_open.Command warehouse_dir =
       flag "-warehouse-dir" (required string)
         ~doc:"DIR source snapshot warehouse (never mutated)"
     and csv_data_dir =
       flag "-csv-data-dir" (required string)
         ~doc:"DIR CSV data store for deep history (e.g. data)"
     and output_dir =
       flag "-output-dir" (required string) ~doc:"DIR clone destination"
     and sketch_deep_days =
       flag "-sketch-deep-days"
         (optional_with_default Sidetable_migrator.default_sketch_deep_days int)
         ~doc:
           (Printf.sprintf
              "DAYS calendar days of deep history before the window start \
               (default %d)"
              Sidetable_migrator.default_sketch_deep_days)
     in
     _run ~warehouse_dir ~csv_data_dir ~output_dir ~sketch_deep_days)

let () = Command_unix.run command
