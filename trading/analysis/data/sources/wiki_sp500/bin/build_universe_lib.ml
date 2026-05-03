open Core
open Async

type warning = { symbol : string; reason : string } [@@deriving show, eq]

type outcome = {
  universe_sexp : Sexp.t;
  warnings : warning list;
  skipped : warning list;
  fetched_count : int;
}

(* EODHD All-World tier has US history from Jan 2000; 1996 is a
   conservative floor in case we replay further back. *)
let _earliest_fetch_date = Date.create_exn ~y:1996 ~m:Month.Jan ~d:1

let _read_file path =
  try Ok (In_channel.read_all path)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read %s: %s" path msg)

let _csv_path_for ~cache_dir symbol = Filename.concat cache_dir (symbol ^ ".csv")

let _csv_exists ~cache_dir symbol =
  match Sys_unix.file_exists (_csv_path_for ~cache_dir symbol) with
  | `Yes -> true
  | `No | `Unknown -> false

(* Per-symbol CSV cache layout: flat [<cache_dir>/<sym>.csv] (one row per
   bar) — distinct from the sharded {!Csv_storage} layout because this
   path is a write-once cache for survivorship-bias delisted issues. *)
let _write_price_csv ~path (prices : Types.Daily_price.t list) =
  (try Core_unix.mkdir_p (Filename.dirname path) with _ -> ());
  try
    Out_channel.with_file path ~f:(fun oc ->
        Out_channel.output_string oc
          "date,open,high,low,close,adjusted_close,volume\n";
        List.iter prices ~f:(fun p ->
            let open Types.Daily_price in
            Out_channel.output_string oc
              (Printf.sprintf "%s,%g,%g,%g,%g,%g,%d\n" (Date.to_string p.date)
                 p.open_price p.high_price p.low_price p.close_price
                 p.adjusted_close p.volume)));
    Ok ()
  with Sys_error msg ->
    Status.error_internal (Printf.sprintf "failed to write %s: %s" path msg)

let _canonicalize_constituent ~as_of
    (c : Wiki_sp500.Membership_replay.constituent) =
  {
    c with
    symbol = Wiki_sp500.Ticker_aliases.canonicalize ~symbol:c.symbol ~as_of;
  }

let _replay_and_canonicalize ~current_csv ~wiki_html ~as_of =
  let%bind.Result current =
    Wiki_sp500.Membership_replay.parse_current_csv current_csv
  in
  let%bind.Result changes = Wiki_sp500.Changes_parser.parse wiki_html in
  let%bind.Result raw =
    Wiki_sp500.Membership_replay.replay_back ~current ~changes ~as_of
  in
  Ok (List.map raw ~f:(_canonicalize_constituent ~as_of))

let _header_comment ~as_of ~cardinality ~skipped =
  let skip_block =
    if List.is_empty skipped then ""
    else
      ";; Skipped (EODHD has no price history):\n"
      ^ String.concat ~sep:"\n"
          (List.map skipped ~f:(fun (w : warning) ->
               Printf.sprintf ";;   %s — %s" w.symbol w.reason))
      ^ "\n;;\n"
  in
  Printf.sprintf
    ";; Historical S&P 500 universe — build_universe.exe.\n\
     ;; as-of: %s | cardinality: %d\n\
     ;; Source: pinned 2026-05-03 Wikipedia snapshots; replay via\n\
     ;; Membership_replay.replay_back + Ticker_aliases.canonicalize.\n\
     ;; Interim Wiki+EODHD path; see\n\
     ;; dev/plans/wiki-eodhd-historical-universe-2026-05-03.md.\n\
     ;;\n\
     %s\n"
    (Date.to_string as_of) cardinality skip_block

let _cardinality_of_universe_sexp = function
  | Sexp.List [ _; Sexp.List entries ] -> List.length entries
  | _ -> 0

let write_outcome_to_file ~path ~as_of (outcome : outcome) =
  try
    Out_channel.with_file path ~f:(fun oc ->
        Out_channel.output_string oc
          (_header_comment ~as_of
             ~cardinality:(_cardinality_of_universe_sexp outcome.universe_sexp)
             ~skipped:outcome.skipped);
        Sexp.output_hum oc outcome.universe_sexp;
        Out_channel.output_string oc "\n");
    Ok ()
  with Sys_error msg ->
    Status.error_internal (Printf.sprintf "failed to write %s: %s" path msg)

let _missing_csv_warnings ~cache_dir constituents =
  List.filter_map constituents
    ~f:(fun (c : Wiki_sp500.Membership_replay.constituent) ->
      if _csv_exists ~cache_dir c.symbol then None
      else Some { symbol = c.symbol; reason = "no local bars" })

let run_offline ~as_of ~current_csv_path ~wiki_html_path ~cache_dir =
  let%bind.Result current_csv = _read_file current_csv_path in
  let%bind.Result wiki_html = _read_file wiki_html_path in
  let%bind.Result constituents =
    _replay_and_canonicalize ~current_csv ~wiki_html ~as_of
  in
  let warnings = _missing_csv_warnings ~cache_dir constituents in
  List.iter warnings ~f:(fun w ->
      Out_channel.eprintf "[warn] no local bars for %s — included anyway\n"
        w.symbol);
  let universe_sexp =
    Wiki_sp500.Membership_replay.to_universe_sexp constituents
  in
  Ok { universe_sexp; warnings; skipped = []; fetched_count = 0 }

(* EODHD wraps non-200 responses in [internal_error "Error: <code> ..."].
   404 means "symbol unknown / no history" — soft skip; other errors
   propagate. *)
let _is_not_found_error (s : Status.t) =
  let msg = Status.show s in
  String.is_substring msg ~substring:"Not Found"
  || String.is_substring msg ~substring:"404"

let _fetch_one ~token ~fetch ~as_of ~cache_dir symbol :
    [ `Fetched | `Skipped of string | `Error of Status.t ] Deferred.t =
  let params : Eodhd.Http_client.historical_price_params =
    {
      symbol;
      start_date = Some _earliest_fetch_date;
      end_date = Some as_of;
      period = Types.Cadence.Daily;
    }
  in
  Eodhd.Http_client.get_historical_price ~token ~params ~fetch () >>| function
  | Ok prices -> (
      match _write_price_csv ~path:(_csv_path_for ~cache_dir symbol) prices with
      | Ok () -> `Fetched
      | Error e -> `Error e)
  | Error e when _is_not_found_error e ->
      `Skipped "EODHD returned 404 (no history)"
  | Error e -> `Error e

let _fetch_missing ~token ~fetch ~as_of ~cache_dir constituents =
  let to_fetch =
    List.filter constituents
      ~f:(fun (c : Wiki_sp500.Membership_replay.constituent) ->
        not (_csv_exists ~cache_dir c.symbol))
  in
  Deferred.List.fold to_fetch
    ~init:(Ok ([], 0))
    ~f:(fun acc (c : Wiki_sp500.Membership_replay.constituent) ->
      match acc with
      | Error _ as e -> Deferred.return e
      | Ok (skipped, fetched_count) -> (
          _fetch_one ~token ~fetch ~as_of ~cache_dir c.symbol >>| function
          | `Fetched ->
              Out_channel.eprintf "[fetch] %s\n" c.symbol;
              Ok (skipped, fetched_count + 1)
          | `Skipped reason ->
              Out_channel.eprintf "[skip] %s — %s\n" c.symbol reason;
              Ok ({ symbol = c.symbol; reason } :: skipped, fetched_count)
          | `Error e -> Error e))

let _drop_skipped constituents skipped =
  let skip_set = String.Set.of_list (List.map skipped ~f:(fun w -> w.symbol)) in
  List.filter constituents
    ~f:(fun (c : Wiki_sp500.Membership_replay.constituent) ->
      not (Set.mem skip_set c.symbol))

let run_with_fetch ~as_of ~current_csv_path ~wiki_html_path ~cache_dir ~token
    ?(fetch = Eodhd.Http_client.default_fetch) () =
  let%bind.Deferred.Result current_csv =
    Deferred.return (_read_file current_csv_path)
  in
  let%bind.Deferred.Result wiki_html =
    Deferred.return (_read_file wiki_html_path)
  in
  let%bind.Deferred.Result constituents =
    Deferred.return (_replay_and_canonicalize ~current_csv ~wiki_html ~as_of)
  in
  let%bind.Deferred.Result skipped, fetched_count =
    _fetch_missing ~token ~fetch ~as_of ~cache_dir constituents
  in
  let kept = _drop_skipped constituents skipped in
  let universe_sexp = Wiki_sp500.Membership_replay.to_universe_sexp kept in
  Deferred.return (Ok { universe_sexp; warnings = []; skipped; fetched_count })

(* --- Change-log mode (PR-D) ------------------------------------------- *)

type change_log_outcome = {
  jsonl : string;
  initial_size : int;
  event_count : int;
}

(* Count newlines in [jsonl] minus the seed-state lines to recover
   [event_count] without re-exposing [Membership_replay.timeline]'s internals.
   We avoid that here by computing [initial_size] from the replayed-back set
   and [event_count] = (total_lines - initial_size). *)
let _count_lines s = String.count s ~f:(fun c -> Char.equal c '\n')

let run_change_log ~from ~until ~current_csv_path ~wiki_html_path =
  let%bind.Result current_csv = _read_file current_csv_path in
  let%bind.Result wiki_html = _read_file wiki_html_path in
  let%bind.Result current =
    Wiki_sp500.Membership_replay.parse_current_csv current_csv
  in
  let%bind.Result changes = Wiki_sp500.Changes_parser.parse wiki_html in
  let%bind.Result timeline =
    Wiki_sp500.Membership_replay.build_timeline ~current ~changes ~from ~until
  in
  let%bind.Result initial =
    Wiki_sp500.Membership_replay.replay_back ~current ~changes ~as_of:from
  in
  let initial_size = List.length initial in
  let jsonl = Wiki_sp500.Membership_replay.timeline_to_jsonl timeline in
  let total_lines = _count_lines jsonl in
  let event_count = total_lines - initial_size in
  Ok { jsonl; initial_size; event_count }

let write_change_log_to_file ~path (outcome : change_log_outcome) =
  try
    Out_channel.with_file path ~f:(fun oc ->
        Out_channel.output_string oc outcome.jsonl);
    Ok ()
  with Sys_error msg ->
    Status.error_internal (Printf.sprintf "failed to write %s: %s" path msg)
