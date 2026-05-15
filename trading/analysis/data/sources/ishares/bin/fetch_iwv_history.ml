(** [fetch_iwv_history.exe] CLI entry point.

    Backfills the on-disk cache of iShares Russell 3000 (IWV) holdings CSVs
    across a date window. Resume-safe and polite: re-runs against a fully-cached
    window issue zero HTTP requests; live requests are spaced by a configurable
    polite sleep (default 2,000 ms).

    See [dev/plans/iwv-scraper-2026-05-16.md] §PR-C and
    [fetch_iwv_history_lib.mli] for the planning / cache-layout contract. *)

open Core
open Async
module Lib = Fetch_iwv_history_lib
module Client = Ishares.Ishares_holdings_client

let _default_cache_dir = "../dev/data/ishares/iwv"
let _default_polite_sleep_ms = 2000

(* HTTP fetcher type. Tests don't exercise this layer (we'd hit
   ishares.com); the executable wires [_default_fetch] in unconditionally. *)
type fetch_fn = Uri.t -> string Status.status_or Deferred.t

let _default_fetch : fetch_fn =
 fun uri ->
  Cohttp_async.Client.get uri >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| fun body_str -> Ok body_str
  | status ->
      let status_str = Cohttp.Code.string_of_status status in
      Cohttp_async.Body.to_string body >>| fun body_str ->
      Status.error_internal
        (Printf.sprintf "HTTP %s for %s\n%s" status_str (Uri.to_string uri)
           body_str)

(* Outcome of fetching a single date. [Error_logged] records the error
   string for the end-of-run summary but does NOT abort the backfill —
   one transient failure should not throw away the entire window. *)
type fetch_outcome = Wrote_csv | Wrote_sentinel | Error_logged of string

let _classify_body body =
  match Client.parse body with
  | Ok Client.No_data_sentinel -> `Sentinel
  | Ok (Client.Parsed _) -> `Data
  | Error err -> `Parse_error (Status.show err)

let _persist_outcome ~cache_dir ~as_of body : fetch_outcome =
  match _classify_body body with
  | `Sentinel -> (
      match Lib.write_sentinel_marker ~cache_dir ~as_of with
      | Ok () -> Wrote_sentinel
      | Error err -> Error_logged (Status.show err))
  | `Data -> (
      match Lib.write_csv_body ~cache_dir ~as_of ~body with
      | Ok () -> Wrote_csv
      | Error err -> Error_logged (Status.show err))
  | `Parse_error msg -> Error_logged ("parse error: " ^ msg)

let _fetch_one ~fetch ~cache_dir as_of : fetch_outcome Deferred.t =
  let uri = Client.build_uri ~as_of in
  fetch uri >>| function
  | Ok body -> _persist_outcome ~cache_dir ~as_of body
  | Error err -> Error_logged (Status.show err)

let _sleep_ms n =
  if n <= 0 then Deferred.unit
  else Clock.after (Time_float.Span.of_ms (Float.of_int n))

(* Per-step running totals so the end-of-run summary is accurate. The
   [skipped_cached] / [skipped_sentinel] counters come from the plan
   classification; the fetch counters tick up as the loop runs. *)
type run_totals = {
  skipped_cached : int;
  skipped_sentinel : int;
  wrote_csv : int;
  wrote_sentinel : int;
  errors : (Date.t * string) list;
}

let _empty_totals =
  {
    skipped_cached = 0;
    skipped_sentinel = 0;
    wrote_csv = 0;
    wrote_sentinel = 0;
    errors = [];
  }

let _tick_action totals = function
  | Lib.Skip_cached ->
      { totals with skipped_cached = totals.skipped_cached + 1 }
  | Lib.Skip_sentinel ->
      { totals with skipped_sentinel = totals.skipped_sentinel + 1 }
  | Lib.Fetch -> totals

let _tick_outcome totals as_of = function
  | Wrote_csv -> { totals with wrote_csv = totals.wrote_csv + 1 }
  | Wrote_sentinel -> { totals with wrote_sentinel = totals.wrote_sentinel + 1 }
  | Error_logged msg -> { totals with errors = (as_of, msg) :: totals.errors }

(* Walk the plan in order; for each [Fetch] step do an HTTP round trip
   followed by the polite sleep, except after the final fetch. *)
let _step_one ~fetch ~cache_dir ~polite_sleep_ms ~total_fetches
    ~remaining_fetches totals step =
  match step.Lib.action with
  | Lib.Skip_cached | Lib.Skip_sentinel ->
      return (_tick_action totals step.Lib.action, remaining_fetches)
  | Lib.Fetch ->
      _fetch_one ~fetch ~cache_dir step.Lib.as_of >>= fun outcome ->
      let totals' = _tick_outcome totals step.Lib.as_of outcome in
      let remaining' = remaining_fetches - 1 in
      let sleep_after = remaining' > 0 && total_fetches > 1 in
      let after =
        if sleep_after then _sleep_ms polite_sleep_ms else Deferred.unit
      in
      after >>| fun () -> (totals', remaining')

let _execute_plan ~fetch ~cache_dir ~polite_sleep_ms steps =
  let total_fetches =
    List.count steps ~f:(fun s ->
        match s.Lib.action with Lib.Fetch -> true | _ -> false)
  in
  Deferred.List.fold steps ~init:(_empty_totals, total_fetches)
    ~f:(fun (totals, remaining) step ->
      _step_one ~fetch ~cache_dir ~polite_sleep_ms ~total_fetches
        ~remaining_fetches:remaining totals step)
  >>| fst

let _print_totals (t : run_totals) =
  printf
    "Backfill complete: %d csv, %d sentinel, %d cached (skipped), %d sentinel \
     (skipped), %d errors.\n"
    t.wrote_csv t.wrote_sentinel t.skipped_cached t.skipped_sentinel
    (List.length t.errors);
  List.iter (List.rev t.errors) ~f:(fun (d, msg) ->
      eprintf "  ERROR %s — %s\n" (Date.to_string d) msg)

let _run ~fetch ~from_str ~until_str ~cache_dir ~cadence_str ~polite_sleep_ms
    ~resume ~dry_run =
  let from = Date.of_string from_str in
  let until = Date.of_string until_str in
  match Lib.cadence_of_string cadence_str with
  | Error err ->
      eprintf "Error: %s\n" (Status.show err);
      return (Stdlib.exit 1)
  | Ok cadence -> (
      let dates = Lib.enumerate_dates ~from ~until cadence in
      match Lib.ensure_cache_dir cache_dir with
      | Error err ->
          eprintf "Error: %s\n" (Status.show err);
          return (Stdlib.exit 1)
      | Ok () ->
          let steps = Lib.plan ~cache_dir ~resume dates in
          if dry_run then (
            printf "%s\n" (Lib.format_plan_summary steps);
            return ())
          else
            _execute_plan ~fetch ~cache_dir ~polite_sleep_ms steps
            >>| _print_totals)

let command =
  Command.async
    ~summary:
      "Backfill the iShares IWV holdings CSV cache across a date window \
       (resume-safe, polite)."
    ~readme:(fun () ->
      "Per asOfDate D in [--from..--until] at the chosen cadence:\n\
      \  * If <cache>/D.csv exists and is non-empty, skip.\n\
      \  * If <cache>/D.sentinel exists, skip.\n\
      \  * Otherwise GET the iShares URL, parse the body. On sentinel\n\
      \    response write D.sentinel; on data response write D.csv.\n\
      \  * Sleep --sleep-ms between fetches.\n\n\
       --dry-run prints the planned actions without HTTP. See\n\
       dev/plans/iwv-scraper-2026-05-16.md §PR-C.")
    (let%map_open.Command from_str =
       flag "from" (required string) ~doc:"YYYY-MM-DD inclusive start date"
     and until_str =
       flag "until" (required string) ~doc:"YYYY-MM-DD inclusive end date"
     and cache_dir =
       flag "cache-dir"
         (optional_with_default _default_cache_dir string)
         ~doc:"PATH local CSV cache directory"
     and cadence_str =
       flag "cadence"
         (optional_with_default "auto" string)
         ~doc:"POLICY auto|daily|monthly|quarterly (default: auto)"
     and polite_sleep_ms =
       flag "sleep-ms"
         (optional_with_default _default_polite_sleep_ms int)
         ~doc:"MS sleep between fetches (default: 2000)"
     and no_resume =
       flag "no-resume" no_arg
         ~doc:" re-fetch every date in the window (default: resume from cache)"
     and dry_run =
       flag "dry-run" no_arg ~doc:" print plan without HTTP / disk writes"
     in
     fun () ->
       let resume = not no_resume in
       _run ~fetch:_default_fetch ~from_str ~until_str ~cache_dir ~cadence_str
         ~polite_sleep_ms ~resume ~dry_run)

let () = Command_unix.run command
