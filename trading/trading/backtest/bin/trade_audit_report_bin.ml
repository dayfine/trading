(** Trade-audit report CLI — render a markdown audit of a single scenario.

    Usage:
    {v
      trade_audit_report --scenario-dir <dir> [--snapshot-dir <dir>] [--out <path>]
    v}

    [--scenario-dir] points at a directory of the shape produced by
    {!Backtest.Result_writer.write}:

    {v
      <dir>/trades.csv          — round-trip P&L (required)
      <dir>/trade_audit.sexp    — Trade_audit.audit_record list (optional)
      <dir>/summary.sexp        — period + universe size (optional)
    v}

    Reads those files via {!Trade_audit_report.load}, renders to markdown via
    {!Trade_audit_report.to_markdown}, and writes to [--out] (when given) or
    prints to stdout (when omitted).

    [--snapshot-dir], when supplied, points at the snapshot warehouse the run
    was produced against. It lets the Weinstein-conformance rule R6
    (recent-plunge avoidance) evaluate on each entry's pre-entry daily closes —
    the audit record itself carries no pre-entry bars, so without a snapshot dir
    R6 reports N/A for every trade. The exe never invokes the backtest runner;
    it only reformats on-disk artefacts and reads bars on demand from the
    warehouse. *)

open Core
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* Daily_panels LRU cache budget for the pre-entry bar reads. R6 fetches at most
   one lookback window per entry, so a modest cap suffices. *)
let _cache_mb = 512

(* Daily lookback window fed to R6, in trading days. Comfortably spans the
   default 30-calendar-day recent-plunge window; the ratings layer re-filters to
   [config.recent_plunge_lookback_days]. *)
let _daily_lookback_days = 60

type _cli_args = {
  scenario_dir : string;
  snapshot_dir : string option;
  out : string option;
}

let _usage () =
  eprintf
    "Usage: trade_audit_report --scenario-dir <dir> [--snapshot-dir <dir>] \
     [--out <path>]\n";
  Stdlib.exit 1

let _parse_flags args =
  let rec loop args scenario_dir snapshot_dir out =
    match args with
    | [] ->
        let scenario_dir =
          match scenario_dir with Some v -> v | None -> _usage ()
        in
        { scenario_dir; snapshot_dir; out }
    | "--scenario-dir" :: v :: rest -> loop rest (Some v) snapshot_dir out
    | "--snapshot-dir" :: v :: rest -> loop rest scenario_dir (Some v) out
    | "--out" :: v :: rest -> loop rest scenario_dir snapshot_dir (Some v)
    | _ -> _usage ()
  in
  loop args None None None

let _parse_args () =
  let argv = Sys.get_argv () in
  _parse_flags (List.tl_exn (Array.to_list argv))

(* Build a snapshot-backed [Bar_reader.t] over [snapshot_dir]. Exits the process
   on a missing/corrupt manifest or panel-open failure (the "warehouse not
   built" failure mode surfaces immediately). Mirrors [decision_grading_bin]. *)
let _bar_reader_of_snapshot ~snapshot_dir =
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err ->
        eprintf "trade_audit_report: cannot read %s: %s\n" manifest_path
          (Status.show err);
        Stdlib.exit 1
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:_cache_mb
    with
    | Ok p -> p
    | Error err ->
        eprintf "trade_audit_report: Daily_panels.create failed: %s\n"
          (Status.show err);
        Stdlib.exit 1
  in
  Bar_reader.of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(* Resolve each entry's pre-entry daily closes from the snapshot warehouse via
   the float-array daily view (adjusted closes), zipped with their dates. R6
   filters to its own lookback window and ignores the entry-day bar. *)
let _closes_lookup_of_reader reader :
    Trade_audit_report.Trade_audit_ratings.closes_lookup =
 fun ~symbol ~as_of ->
  let view =
    Bar_reader.daily_view_for reader ~symbol ~as_of
      ~lookback:_daily_lookback_days
  in
  Array.to_list
    (Array.zip_exn view.Snapshot_bar_views.dates view.Snapshot_bar_views.closes)

let _emit ~out md =
  match out with
  | None -> print_string md
  | Some path ->
      Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc md)

let () =
  let { scenario_dir; snapshot_dir; out } = _parse_args () in
  let closes_lookup =
    Option.map snapshot_dir ~f:(fun snapshot_dir ->
        _closes_lookup_of_reader (_bar_reader_of_snapshot ~snapshot_dir))
  in
  let report = Trade_audit_report.load ?closes_lookup ~scenario_dir () in
  let md = Trade_audit_report.to_markdown report in
  _emit ~out md
