(** Bulk-fetch bars for delisted symbols (P2 of the delisted-aware universe
    agenda — see [dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md]).

    Reads the delisted-symbols roster cached by [fetch_delisted_symbols.exe]
    (P1, #1184), filters to a configurable subset (default: Common Stock on
    NASDAQ + NYSE), and fetches historical bars for each via
    [Eodhd.Http_client.get_historical_price] — reusing
    [Fetch_symbols_lib.fetch_one] for the per-symbol CSV+metadata write.

    Idempotent: if a symbol's CSV already exists under [data_dir], the fetch is
    skipped. Re-running picks up where the prior run left off.

    Resumability + politeness: sequential fetch with configurable inter-request
    sleep (default 600 ms ≈ 100 req/min). For the ~15.8k NASDAQ/NYSE Common
    Stock subset the full run takes ~3-5 hr wall at the default rate, assuming
    the EODHD tier's per-day quota isn't exhausted sooner.

    Typical usage (smoke):
    {v
      fetch_delisted_bars.exe \
        -roster-path data/delisted_symbols.sexp \
        -secrets-path trading/analysis/data/sources/eodhd/secrets \
        -limit 10
    v}

    Full run:
    {v
      fetch_delisted_bars.exe \
        -roster-path data/delisted_symbols.sexp \
        -secrets-path trading/analysis/data/sources/eodhd/secrets \
        -sleep-ms 600
    v} *)

open Core
open Async

(** {1 Delisted roster sexp shape — must match the P1 binary's output.} *)

type roster_entry = {
  code : string;
  name : string;
  exchange : string;
  asset_type : Eodhd.Asset_type.t;
}
[@@deriving sexp]

type roster = {
  generated_at : Date.t;
  source_endpoint : string;
  symbols : roster_entry list;
}
[@@deriving sexp]

(** {1 Filtering} *)

(** Filter to symbols a Weinstein backtest would actually want: Common Stock on
    the primary US equity exchanges. Drops Funds, ETFs (their delistings aren't
    load-bearing for an equity strategy), and pink-sheet / OTC venues
    (low-volume long tail, bar coverage is sparse). *)
let _is_in_scope (e : roster_entry) : bool =
  Eodhd.Asset_type.equal e.asset_type Eodhd.Asset_type.Common_stock
  && (String.equal e.exchange "NASDAQ" || String.equal e.exchange "NYSE")

(** {1 Idempotent skip} *)

(** A symbol counts as "already cached" iff [data_dir/<X>/<Y>/<SYM>/data.csv]
    exists. We do NOT re-validate row counts or coverage — that's a downstream
    audit's job (see #1181). *)
let _is_cached ~data_dir symbol =
  let csv =
    Csv.Csv_storage.symbol_data_dir ~data_dir:(Fpath.v data_dir) symbol
    |> fun p -> Fpath.(p / "data.csv")
  in
  Stdlib.Sys.file_exists (Fpath.to_string csv)

(** {1 Token loading} *)

let _read_token ~secrets_path =
  try Ok (In_channel.read_all secrets_path |> String.rstrip)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read secrets %s: %s" secrets_path msg)

(** {1 Roster loading} *)

let _load_roster ~roster_path =
  try Ok (Sexp.load_sexp roster_path |> roster_of_sexp)
  with Sys_error msg | Failure msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to load roster %s: %s" roster_path msg)

(** {1 Fetch driver} *)

let _sleep_if_polite ms =
  if ms > 0 then Clock.after (Time_float.Span.of_ms (float_of_int ms))
  else return ()

(** Fetch + cache one target. Returns the updated triple [(ok, err, skipped)].
    Refactored out of [_fetch_all]'s closure to keep nesting within linter
    limits. *)
let _step_one ~token ~data_dir_path ~total ~sleep_ms idx (ok, err, skipped)
    (entry : roster_entry) =
  if _is_cached ~data_dir:(Fpath.to_string data_dir_path) entry.code then (
    printf "[%d/%d] SKIP %s (already cached)\n%!" (idx + 1) total entry.code;
    return (ok, err, skipped + 1))
  else (
    printf "[%d/%d] FETCH %s (%s, %s)\n%!" (idx + 1) total entry.code
      entry.exchange entry.name;
    let%bind result =
      Fetch_symbols_lib.fetch_one ~token ~data_dir:data_dir_path entry.code
    in
    let%bind () = _sleep_if_polite sleep_ms in
    match result with
    | Ok _ -> return (ok + 1, err, skipped)
    | Error _ -> return (ok, err + 1, skipped))

(** Sequential fetch with polite sleep between requests. Returns
    [(ok_count, err_count, skipped_count)]. *)
let _fetch_all ~token ~data_dir ~sleep_ms ~targets =
  let data_dir_path = Fpath.v data_dir in
  let total = List.length targets in
  Deferred.List.foldi targets ~init:(0, 0, 0)
    ~f:(_step_one ~token ~data_dir_path ~total ~sleep_ms)

let _print_summary ~targets ~ok ~err ~skipped =
  printf "\n%!";
  printf "Delisted-bar fetch summary:\n";
  printf "  Targets        : %d\n" (List.length targets);
  printf "  Fetched OK     : %d\n" ok;
  printf "  Fetch errors   : %d\n" err;
  printf "  Already cached : %d\n" skipped

(** {1 Run + report} *)

let _run ~roster_path ~secrets_path ~data_dir ~sleep_ms ~limit =
  let open Deferred.Result.Let_syntax in
  let%bind token = _read_token ~secrets_path |> Deferred.return in
  let%bind roster = _load_roster ~roster_path |> Deferred.return in
  printf "Loaded roster: %d entries (generated_at %s, source %s)\n%!"
    (List.length roster.symbols)
    (Date.to_string roster.generated_at)
    roster.source_endpoint;
  let in_scope = List.filter roster.symbols ~f:_is_in_scope in
  printf "In-scope (Common Stock NASDAQ/NYSE): %d\n%!" (List.length in_scope);
  let targets =
    match limit with None -> in_scope | Some n -> List.take in_scope n
  in
  printf "Fetching %d symbols (sleep %d ms between fetches)\n%!"
    (List.length targets) sleep_ms;
  let%bind ok, err, skipped =
    _fetch_all ~token ~data_dir ~sleep_ms ~targets
    |> Deferred.map ~f:Result.return
  in
  _print_summary ~targets ~ok ~err ~skipped;
  Deferred.Result.return ()

let _main ~roster_path ~secrets_path ~data_dir ~sleep_ms ~limit () =
  _run ~roster_path ~secrets_path ~data_dir ~sleep_ms ~limit >>= function
  | Ok () -> return ()
  | Error e ->
      eprintf "Error: %s\n" (Status.show e);
      exit 1

let _default_secrets_path = "trading/analysis/data/sources/eodhd/secrets"
let _default_data_dir () = Data_path.default_data_dir () |> Fpath.to_string
let _default_sleep_ms = 600

let command =
  Command.async
    ~summary:
      "Bulk-fetch bars for delisted symbols (P2 of the delisted-aware universe \
       agenda — see dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md)"
    (let%map_open.Command roster_path =
       flag "roster-path" (required string)
         ~doc:"PATH Path to delisted_symbols.sexp (output of P1)"
     and secrets_path =
       flag "secrets-path"
         (optional_with_default _default_secrets_path string)
         ~doc:"PATH EODHD API token file (default: repo-local secrets)"
     and data_dir =
       flag "data-dir"
         (optional_with_default (_default_data_dir ()) string)
         ~doc:"PATH Directory to write cached data"
     and sleep_ms =
       flag "sleep-ms"
         (optional_with_default _default_sleep_ms int)
         ~doc:"MS Polite sleep between HTTP fetches (default 600 ms)"
     and limit =
       flag "limit" (optional int)
         ~doc:
           "N Smoke-test cap on the number of symbols to fetch (default: all)"
     in
     _main ~roster_path ~secrets_path ~data_dir ~sleep_ms ~limit)

let () = Command_unix.run command
