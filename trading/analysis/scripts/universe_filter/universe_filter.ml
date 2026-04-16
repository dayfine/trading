(** universe_filter — apply a sexp-driven rule-set to [data/sectors.csv].

    Reads an input CSV, applies rules from
    [dev/config/universe_filter/<name>.sexp], writes the kept rows to an output
    CSV (separate from input by default so a human can diff and promote). Prints
    a summary of rows in/out, per-rule drop counts, and before/after sector
    breakdown. [-dry-run] prints only.

    Example: universe_filter -input data/sectors.csv \ -output
    data/sectors.filtered.csv \ -config dev/config/universe_filter/default.sexp
    \ -dry-run *)

open Core
module U = Universe_filter_lib

let _default_input = "data/sectors.csv"
let _default_output = "data/sectors.filtered.csv"
let _default_config = "dev/config/universe_filter/default.sexp"

let _print_breakdown label rows =
  printf "\n%s sector breakdown (%d rows):\n" label (List.length rows);
  List.iter (U.sector_breakdown rows) ~f:(fun (sector, count) ->
      let sector_disp = if String.is_empty sector then "(empty)" else sector in
      printf "  %5d  %s\n" count sector_disp)

let _print_rule_stats (result : U.filter_result) =
  printf "\nPer-rule drop counts (raw matches, pre-allowlist rescue):\n";
  if List.is_empty result.rule_stats then printf "  (no rules)\n"
  else
    List.iter result.rule_stats ~f:(fun { rule_name; drop_count } ->
        printf "  %5d  %s\n" drop_count rule_name);
  printf "Rescued by allow-list: %d\n" result.rescued_by_allowlist

let _die msg =
  eprintf "ERROR: %s\n%!" msg;
  Stdlib.exit 1

let _run ~input ~output ~config_path ~dry_run =
  let cfg =
    match U.load_config config_path with Ok c -> c | Error e -> _die e
  in
  let rows = match U.read_csv input with Ok r -> r | Error e -> _die e in
  let result = U.filter cfg rows in
  printf "Input:  %s (%d rows)\n" input (List.length rows);
  printf "Config: %s\n" config_path;
  _print_breakdown "BEFORE" rows;
  _print_rule_stats result;
  _print_breakdown "AFTER" result.kept;
  printf "\nTotals: kept=%d dropped=%d (input=%d)\n" (List.length result.kept)
    (List.length result.dropped)
    (List.length rows);
  if dry_run then printf "\n[dry-run] Not writing output.\n"
  else
    match U.write_csv output result.kept with
    | Ok () -> printf "\nWrote %s (%d rows)\n" output (List.length result.kept)
    | Error e -> _die (Printf.sprintf "write failed: %s" e)

let command =
  Command.basic ~summary:"Apply universe cleanup rules to data/sectors.csv"
    (let%map_open.Command input =
       flag "input"
         (optional_with_default _default_input string)
         ~doc:(Printf.sprintf "PATH Input CSV (default: %s)" _default_input)
     and output =
       flag "output"
         (optional_with_default _default_output string)
         ~doc:(Printf.sprintf "PATH Output CSV (default: %s)" _default_output)
     and config_path =
       flag "config"
         (optional_with_default _default_config string)
         ~doc:
           (Printf.sprintf "PATH Rule-set sexp (default: %s)" _default_config)
     and dry_run =
       flag "dry-run" no_arg ~doc:" Print stats only; do not write output"
     in
     fun () -> _run ~input ~output ~config_path ~dry_run)

let () = Command_unix.run command
