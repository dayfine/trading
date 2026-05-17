(** CLI: bulk-emit the composition-side custom-universe snapshots.

    Reads cached EODHD bars, [symbol_types.sexp], [sectors.csv], and
    [inventory.sexp]; iterates over [(year, top_n)] for [year] in
    [[start_year..end_year]] and [top_n] in the supplied list; calls
    {!Universe.Build_from_individuals.build} once per pair; and writes each
    successful snapshot to [{out_dir}/top-{top_n}-{year}.sexp]. Errors from the
    builder are logged + counted but never crash the run.

    Usage:
    {v
      dune exec analysis/data/universe/bin/build_composition_universes_runner.exe -- \
        --bars-root /workspaces/trading-1/data \
        --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
        --sectors-csv /workspaces/trading-1/data/sectors.csv \
        --inventory /workspaces/trading-1/data/inventory.sexp \
        --out-dir trading/test_data/goldens-custom-universe/composition/ \
        --start-year 1998 --end-year 2026 \
        --top-n 500,1000,3000
    v} *)

open! Core

let _exit_with_error msg =
  Stdlib.Printf.fprintf Stdlib.stderr "build_composition_universes_runner: %s\n"
    msg;
  Stdlib.flush Stdlib.stderr;
  Stdlib.exit 1

let _parse_top_n_list raw : int list =
  let parts = String.split raw ~on:',' |> List.map ~f:String.strip in
  let parsed =
    List.map parts ~f:(fun s ->
        match Int.of_string s with
        | n when n > 0 -> Ok n
        | _ -> Error s
        | exception _ -> Error s)
  in
  match List.find parsed ~f:(function Ok _ -> false | Error _ -> true) with
  | Some (Error bad) ->
      _exit_with_error (Printf.sprintf "invalid --top-n %S" bad)
  | _ -> List.map parsed ~f:(function Ok n -> n | Error _ -> assert false)

let _print_summary (result : Build_composition_universes_runner_lib.result) =
  Stdlib.Printf.printf
    "build_composition_universes_runner: written=%d skipped=%d\n" result.written
    result.skipped;
  if result.skipped > 0 then
    List.iter (List.rev result.skip_reasons) ~f:(fun (year, top_n, reason) ->
        Stdlib.Printf.printf "  skip year=%d top_n=%d: %s\n" year top_n reason)

let _run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
    ~out_dir ~start_year ~end_year ~top_ns =
  let result =
    Build_composition_universes_runner_lib.run ~bars_root ~symbol_types_path
      ~sectors_csv_path ~inventory_path ~out_dir ~start_year ~end_year ~top_ns
  in
  _print_summary result

let _default_out_dir = "trading/test_data/goldens-custom-universe/composition/"
let _default_top_n_raw = "500,1000,3000"
let _default_start_year = 1998
let _default_end_year = 2026

let command =
  Command.basic
    ~summary:
      "Bulk-emit composition-side dollar-volume-ranked universe snapshots from \
       cached EODHD bars + symbol_types + sectors + inventory."
    (let%map_open.Command bars_root =
       flag "--bars-root" (required string)
         ~doc:"PATH root of cached bars (e.g. /workspaces/trading-1/data)"
     and symbol_types_path =
       flag "--symbol-types" (required string)
         ~doc:"PATH symbol_types.sexp from asset_type_enrichment"
     and sectors_csv_path =
       flag "--sectors-csv" (required string)
         ~doc:"PATH sectors.csv (header: symbol,sector)"
     and inventory_path =
       flag "--inventory" (required string)
         ~doc:"PATH inventory.sexp from weinstein.data_source"
     and out_dir =
       flag "--out-dir"
         (optional_with_default _default_out_dir string)
         ~doc:
           (Printf.sprintf "PATH output directory (default: %s)"
              _default_out_dir)
     and start_year =
       flag "--start-year"
         (optional_with_default _default_start_year int)
         ~doc:
           (Printf.sprintf "YEAR first reconstitution year (default: %d)"
              _default_start_year)
     and end_year =
       flag "--end-year"
         (optional_with_default _default_end_year int)
         ~doc:
           (Printf.sprintf "YEAR last reconstitution year (default: %d)"
              _default_end_year)
     and top_n_raw =
       flag "--top-n"
         (optional_with_default _default_top_n_raw string)
         ~doc:
           (Printf.sprintf "LIST comma-separated top-N sizes (default: %s)"
              _default_top_n_raw)
     in
     fun () ->
       let top_ns = _parse_top_n_list top_n_raw in
       _run ~bars_root ~symbol_types_path ~sectors_csv_path ~inventory_path
         ~out_dir ~start_year ~end_year ~top_ns)

let () = Command_unix.run command
