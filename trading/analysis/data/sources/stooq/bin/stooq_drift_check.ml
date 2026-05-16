(** CLI: single-symbol Stooq-vs-EODHD drift detection.

    Usage:
    {v
      dune exec analysis/data/sources/stooq/bin/stooq_drift_check.exe -- \
        -symbol AAPL \
        -eodhd-cache-dir ../data \
        [-apikey KEY | env STOOQ_APIKEY=KEY] \
        [-threshold 0.005] \
        [-stooq-csv PATH]
    v}

    Behaviour:
    - Loads EODHD bars from the local CSV cache via {!Csv_storage}.
    - Fetches Stooq daily CSV via curl, OR reads a pre-fetched CSV if
      [-stooq-csv] is supplied (useful for offline runs / re-analysis).
    - Aligns by date, computes signed [rel_diff] on close prices, prints summary
      \+ top flagged days.

    Failure modes:
    - EODHD symbol missing from cache → exit 1 with stderr.
    - Stooq apikey not provided (and live fetch attempted) → exit 1 with a hint
      pointing at https://stooq.com/q/d/?s=<symbol>.us&get_apikey.
    - Stooq returns the apikey-error sentinel → exit 1 with same hint.
    - Stooq fetch fails (network / HTTP) → exit 1 with the curl error.
    - Symbol has no Stooq coverage (e.g. delisted, non-US) → exit 0 with "no
      Stooq coverage" notice; this is graceful per the task spec.

    Implementation note: this CLI is [Command.basic], not [Command.async], and
    only spins up the Async scheduler via [Thread_safe.block_on_async_exn] for
    the actual curl fetch. The synchronous-path (EODHD load, fixture-CSV mode)
    keeps [Stdlib.exit] semantics simple — stderr flushes correctly on
    synchronous error paths, which is harder to guarantee inside a
    [Command.async] callback. *)

open! Core
module Client = Stooq.Stooq_client
module Core_ = Stooq_drift_check_core

let _default_threshold = 0.005
let _apikey_env_var = "STOOQ_APIKEY"

let _eprint_apikey_hint symbol =
  Printf.eprintf
    "stooq_drift_check: Stooq's CSV endpoint requires an apikey.\n\
     Get one (free, captcha-gated) at:\n\
    \  https://stooq.com/q/d/?s=%s.us&get_apikey\n\
     Then re-run with -apikey <KEY> or env %s=<KEY>.\n"
    (String.lowercase symbol) _apikey_env_var

let _exit_with_eprint fmt =
  Printf.ksprintf
    (fun msg ->
      Printf.eprintf "stooq_drift_check: %s\n" msg;
      Stdlib.exit 1)
    fmt

let _load_eodhd_or_exit ~data_dir ~symbol : Types.Daily_price.t list =
  match Csv.Csv_storage.create ~data_dir symbol with
  | Error err ->
      _exit_with_eprint "failed to open EODHD cache for %s: %s" symbol
        (Status.show err)
  | Ok store -> (
      match Csv.Csv_storage.get store () with
      | Ok bars -> bars
      | Error err ->
          _exit_with_eprint "failed to read EODHD cache for %s: %s" symbol
            (Status.show err))

let _read_stooq_file ~path =
  match Sys_unix.file_exists path with
  | `No | `Unknown -> _exit_with_eprint "-stooq-csv not found: %s" path
  | `Yes -> In_channel.read_all path

let _resolve_apikey ~apikey_flag =
  match apikey_flag with
  | Some _ -> apikey_flag
  | None -> Sys.getenv _apikey_env_var

let _fetch_stooq_body_blocking ~apikey ~symbol : string =
  let uri = Client.build_uri ?apikey ~symbol () in
  match
    Async.Thread_safe.block_on_async_exn (fun () -> Stooq_curl_fetch.fetch uri)
  with
  | Ok body -> body
  | Error err ->
      _exit_with_eprint "Stooq fetch failed for %s: %s" symbol
        (Error.to_string_hum err)

let _classify_stooq_body ~symbol ~body : Client.series =
  if Client.is_apikey_error_body body then (
    _eprint_apikey_hint symbol;
    Stdlib.exit 1);
  (* The Stooq apikey-error path is the most common failure mode. Beyond
     that, an empty body or a no-rows-after-header body indicates no
     coverage for the symbol (e.g. delisted). We treat both as graceful
     no-coverage exits (exit 0). *)
  match Client.parse body with
  | Ok series when List.is_empty series.observations ->
      Printf.printf
        "stooq_drift_check: %s — no Stooq coverage (empty series).\n" symbol;
      Stdlib.exit 0
  | Ok series -> series
  | Error err ->
      _exit_with_eprint "failed to parse Stooq body for %s: %s" symbol
        (Status.show err)

let _obtain_stooq_series ~apikey ~symbol ~stooq_csv : Client.series =
  let body =
    match stooq_csv with
    | Some path -> _read_stooq_file ~path
    | None -> _fetch_stooq_body_blocking ~apikey ~symbol
  in
  _classify_stooq_body ~symbol ~body

let _run ~symbol ~eodhd_cache_dir ~apikey_flag ~threshold ~stooq_csv =
  let apikey = _resolve_apikey ~apikey_flag in
  let data_dir = Fpath.v eodhd_cache_dir in
  let eodhd = _load_eodhd_or_exit ~data_dir ~symbol in
  let stooq_series = _obtain_stooq_series ~apikey ~symbol ~stooq_csv in
  let report =
    Core_.build_report ~symbol ~stooq:stooq_series.observations ~eodhd
      ~threshold
  in
  print_string (Core_.format_text_report report)

let command =
  Command.basic
    ~summary:
      "Single-symbol Stooq-vs-EODHD drift check: fetches Stooq daily CSV, \
       compares against the EODHD CSV cache, prints summary + flagged days."
    (let%map_open.Command symbol =
       flag "-symbol" (required string) ~doc:"SYM bare ticker (e.g. AAPL)"
     and eodhd_cache_dir =
       flag "-eodhd-cache-dir" (required string)
         ~doc:"DIR root of the EODHD CSV cache (e.g. ./data)"
     and apikey_flag =
       flag "-apikey" (optional string)
         ~doc:
           (Printf.sprintf "KEY Stooq apikey (overrides env %s)" _apikey_env_var)
     and threshold =
       flag "-threshold"
         (optional_with_default _default_threshold float)
         ~doc:
           (Printf.sprintf "FLOAT |rel_diff| flag cutoff (default %.4f = 0.5%%)"
              _default_threshold)
     and stooq_csv =
       flag "-stooq-csv" (optional string)
         ~doc:
           "PATH read Stooq CSV from a local file instead of fetching live \
            (skips the apikey requirement)"
     in
     fun () -> _run ~symbol ~eodhd_cache_dir ~apikey_flag ~threshold ~stooq_csv)

let () = Command_unix.run command
