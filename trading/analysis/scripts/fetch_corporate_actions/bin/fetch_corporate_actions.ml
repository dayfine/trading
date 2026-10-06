(** Bulk-fetch EODHD dividends and splits into the per-symbol data store.

    For each symbol, writes [dividends.csv] and [splits.csv] next to its
    [data.csv] (format: [Corporate_actions]). Symbols whose two files already
    exist are skipped unless [-refresh]; re-running picks up where a prior run
    stopped. Ends with a coverage summary (ok / empty / error / skipped).

    Symbols come from [-symbols-file] (one per line, [#] comments) or, by
    default, every symbol directory under [-data-dir] that holds a [data.csv].

    The API key comes from [-api-key], else the [EODHD_API_KEY] environment
    variable.

    Smoke:
    {v   fetch_corporate_actions.exe -api-key <key> -limit 3 v}

    Full run:
    {v   fetch_corporate_actions.exe -api-key <key> -parallel 4 -sleep-ms 300 v}
*)

open Core
open Async
module Lib = Fetch_corporate_actions_lib

let _resolve_token = function
  | Some key -> Ok key
  | None -> (
      match Sys.getenv "EODHD_API_KEY" with
      | Some key -> Ok key
      | None -> Error "No API key: pass -api-key or set EODHD_API_KEY.")

let _resolve_symbols ~data_dir ~symbols_file ~limit =
  let all =
    match symbols_file with
    | Some path -> Lib.parse_symbols (In_channel.read_all path)
    | None -> Lib.symbols_in_data_dir data_dir
  in
  match limit with None -> all | Some n -> List.take all n

let _main ~api_key ~data_dir ~symbols_file ~limit ~refresh ~sleep_ms ~parallel
    () =
  match _resolve_token api_key with
  | Error msg ->
      eprintf "%s\n%!" msg;
      exit 1
  | Ok token ->
      let data_dir = Fpath.v data_dir in
      let symbols = _resolve_symbols ~data_dir ~symbols_file ~limit in
      printf "Fetching corporate actions for %d symbols (parallel=%d)\n%!"
        (List.length symbols) parallel;
      let config : Lib.config = { data_dir; refresh; sleep_ms; parallel } in
      let%map summary = Lib.run ~token config symbols in
      printf "\n%s\n%!" (Lib.render_summary summary)

let _default_data_dir () = Data_path.default_data_dir () |> Fpath.to_string
let _default_sleep_ms = 600
let _default_parallel = 1

let command =
  Command.async
    ~summary:"Bulk-fetch EODHD dividends + splits into the per-symbol store"
    (let%map_open.Command api_key =
       flag "api-key" (optional string)
         ~doc:"KEY EODHD API key (default: $EODHD_API_KEY)"
     and data_dir =
       flag "data-dir"
         (optional_with_default (_default_data_dir ()) string)
         ~doc:"PATH Data store root"
     and symbols_file =
       flag "symbols-file" (optional string)
         ~doc:"PATH One symbol per line (default: every symbol in -data-dir)"
     and limit =
       flag "limit" (optional int) ~doc:"N Fetch only the first N symbols"
     and refresh =
       flag "refresh" no_arg ~doc:" Re-fetch symbols already fetched"
     and sleep_ms =
       flag "sleep-ms"
         (optional_with_default _default_sleep_ms int)
         ~doc:"MS Pause after each symbol (default 600)"
     and parallel =
       flag "parallel"
         (optional_with_default _default_parallel int)
         ~doc:"N Symbols in flight (default 1)"
     in
     _main ~api_key ~data_dir ~symbols_file ~limit ~refresh ~sleep_ms ~parallel)

let () = Command_unix.run command
