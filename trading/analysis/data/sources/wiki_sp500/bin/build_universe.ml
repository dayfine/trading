(** [build_universe.exe] CLI entry point. See [build_universe_lib.mli] and
    [dev/plans/wiki-eodhd-historical-universe-2026-05-03.md] §PR-C. *)

open Core
open Async

(* Defaults assume invocation from [trading/]. *)
let _default_wiki_html =
  "analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html"

let _default_current_csv =
  "analysis/data/sources/wiki_sp500/test/data/current_constituents_2026-05-03.csv"

let _default_cache_dir = "../dev/data/wiki_sp500"

let _read_token_file path =
  try Ok (String.strip (In_channel.read_all path))
  with Sys_error msg ->
    Error (Printf.sprintf "failed to read token file %s: %s" path msg)

let _finish_outcome ~as_of ~output (outcome : Build_universe_lib.outcome) : unit
    =
  match
    Build_universe_lib.write_outcome_to_file ~path:output ~as_of outcome
  with
  | Error e ->
      eprintf "Error writing output: %s\n" (Status.show e);
      Stdlib.exit 1
  | Ok () ->
      let cardinality =
        match outcome.universe_sexp with
        | Sexp.List [ _; Sexp.List es ] -> List.length es
        | _ -> 0
      in
      printf "Wrote %d constituents (%d skipped, %d fetched, %d warnings).\n"
        cardinality
        (List.length outcome.skipped)
        outcome.fetched_count
        (List.length outcome.warnings)

let _run_offline ~as_of ~current_csv_path ~wiki_html_path ~cache_dir ~output =
  match
    Build_universe_lib.run_offline ~as_of ~current_csv_path ~wiki_html_path
      ~cache_dir
  with
  | Error e ->
      eprintf "Error: %s\n" (Status.show e);
      Stdlib.exit 1
  | Ok outcome -> _finish_outcome ~as_of ~output outcome

let _run_with_fetch ~as_of ~current_csv_path ~wiki_html_path ~cache_dir ~output
    ~token_file =
  match _read_token_file token_file with
  | Error msg ->
      eprintf "Error: %s\n" msg;
      return (Stdlib.exit 1)
  | Ok token -> (
      Build_universe_lib.run_with_fetch ~as_of ~current_csv_path ~wiki_html_path
        ~cache_dir ~token ()
      >>| fun result ->
      match result with
      | Error e ->
          eprintf "Error: %s\n" (Status.show e);
          Stdlib.exit 1
      | Ok outcome -> _finish_outcome ~as_of ~output outcome)

let command =
  Command.async
    ~summary:
      "Reconstruct historical S&P 500 universe and emit a (Pinned …) sexp."
    ~readme:(fun () ->
      "Replays pinned Wikipedia changes-table back from today's constituents \
       to a target [--as-of] date. With [--fetch-prices], also auto-fetches \
       any per-symbol CSV missing from [--cache-dir] via EODHD; 404s are \
       skipped + omitted. See \
       dev/plans/wiki-eodhd-historical-universe-2026-05-03.md §PR-C.")
    (let%map_open.Command as_of_str =
       flag "as-of" (required string)
         ~doc:"YYYY-MM-DD historical date to reconstruct membership for"
     and wiki_html_path =
       flag "wiki-html"
         (optional_with_default _default_wiki_html string)
         ~doc:"PATH pinned Wikipedia changes-table HTML"
     and current_csv_path =
       flag "current-csv"
         (optional_with_default _default_current_csv string)
         ~doc:"PATH pinned Wikipedia current-constituents CSV"
     and output =
       flag "output" (required string) ~doc:"PATH where to write universe sexp"
     and fetch_prices =
       flag "fetch-prices" no_arg
         ~doc:" auto-fetch missing per-symbol price CSVs via EODHD"
     and token_file =
       flag "token-file" (optional string)
         ~doc:"PATH EODHD API token file (required iff --fetch-prices)"
     and cache_dir =
       flag "cache-dir"
         (optional_with_default _default_cache_dir string)
         ~doc:"PATH local CSV cache directory"
     in
     fun () ->
       let as_of = Date.of_string as_of_str in
       if fetch_prices then
         match token_file with
         | None ->
             eprintf "Error: --fetch-prices requires --token-file\n";
             return (Stdlib.exit 1)
         | Some token_file ->
             _run_with_fetch ~as_of ~current_csv_path ~wiki_html_path ~cache_dir
               ~output ~token_file
       else (
         _run_offline ~as_of ~current_csv_path ~wiki_html_path ~cache_dir
           ~output;
         return ()))

let () = Command_unix.run command
