(** universe_filter — apply a sexp-driven rule-set to [data/sectors.csv].

    Reads the input sectors CSV, joins it against [data/universe.sexp] to enrich
    each row with instrument [name] + primary [exchange], applies rules from
    [dev/config/universe_filter/<name>.sexp], writes the kept rows to an output
    CSV (separate from input by default so a human can diff and promote). Prints
    a summary of rows in/out, per-rule drop counts, and before/after sector
    breakdown. [-dry-run] prints only.

    If [-universe] is empty or missing, rows are loaded without enrichment —
    useful for rule-sets that only need [symbol] + [sector]. *)

open Core
module U = Universe_filter_lib

let _default_input = "data/sectors.csv"
let _default_output = "data/sectors.filtered.csv"
let _default_universe = "data/universe.sexp"
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

let _load_rows ~input ~universe =
  if String.is_empty universe then U.read_csv input
  else U.load_rows_with_universe ~sectors_csv:input ~universe_sexp:universe

let _run ~input ~output ~config_path ~universe ~dry_run =
  let cfg =
    match U.load_config config_path with Ok c -> c | Error e -> _die e
  in
  let rows =
    match _load_rows ~input ~universe with Ok r -> r | Error e -> _die e
  in
  let result = U.filter cfg rows in
  printf "Input:  %s (%d rows)\n" input (List.length rows);
  printf "Universe: %s\n"
    (if String.is_empty universe then "(none)" else universe);
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
     and universe =
       flag "universe"
         (optional_with_default _default_universe string)
         ~doc:
           (Printf.sprintf
              "PATH universe.sexp for name/exchange join (default: %s; pass \
               empty string to disable)"
              _default_universe)
     and dry_run =
       flag "dry-run" no_arg ~doc:" Print stats only; do not write output"
     in
     fun () -> _run ~input ~output ~config_path ~universe ~dry_run)

let () = Command_unix.run command
