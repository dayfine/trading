(** Trade-audit report CLI — render a markdown and/or interactive-HTML audit of
    a single scenario.

    Usage:
    {v
      trade_audit_report --scenario-dir <dir> [--snapshot-dir <dir>]
        [--out <md-path>] [--html <html-path>] [--benchmark-symbol <sym>]
    v}

    [--scenario-dir] points at a directory of the shape produced by
    {!Backtest.Result_writer.write}:

    {v
      <dir>/trades.csv          — round-trip P&L (required)
      <dir>/trade_audit.sexp    — Trade_audit.audit_record list (optional)
      <dir>/summary.sexp        — period + universe size + KPIs (optional)
      <dir>/equity_curve.csv    — NAV series (HTML chart; optional)
      <dir>/open_positions.csv  — end-of-run holdings (HTML; optional)
      <dir>/final_prices.csv    — end-of-run marks (HTML; optional)
    v}

    Reads those files via {!Trade_audit_report.load}, renders to markdown via
    {!Trade_audit_report.to_markdown} (written to [--out], or stdout when
    neither output flag is given), and/or to a self-contained interactive HTML
    file via {!Trade_audit_html.Html_report} (written to [--html]).

    [--snapshot-dir], when supplied, points at the snapshot warehouse the run
    was produced against. It powers three things off the same on-demand bar
    reader: the Weinstein-conformance rule R6 (recent-plunge avoidance)
    pre-entry closes, the HTML NAV-vs-benchmark series ([--benchmark-symbol],
    default [SPY]), and the HTML capital-utilization series. Without it, R6
    reports N/A, and the HTML omits the benchmark line + utilization chart. The
    exe never invokes the backtest runner; it only reformats on-disk artefacts
    and reads bars on demand from the warehouse. *)

open Core
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Html_report = Trade_audit_html.Html_report

(* Daily_panels LRU cache budget for the on-demand bar reads. R6 fetches at most
   one lookback window per entry, and the HTML benchmark/utilization series read
   at most one window per (symbol, weekly date), so a modest cap suffices. *)
let _cache_mb = 512

(* Daily lookback window fed to R6, in trading days. Comfortably spans the
   default 30-calendar-day recent-plunge window; the ratings layer re-filters to
   [config.recent_plunge_lookback_days]. *)
let _daily_lookback_days = 60

(* Lookback for a single as-of mark (HTML benchmark / utilization). Wide enough
   to bridge a short data gap and still land on the last close at/before the
   requested weekly date. *)
let _mark_lookback_days = 15

type _cli_args = {
  scenario_dir : string;
  snapshot_dir : string option;
  out : string option;
  html : string option;
  benchmark_symbol : string;
}

let _usage () =
  eprintf
    "Usage: trade_audit_report --scenario-dir <dir> [--snapshot-dir <dir>] \
     [--out <md-path>] [--html <html-path>] [--benchmark-symbol <sym>]\n";
  Stdlib.exit 1

let _parse_flags args =
  let rec loop args acc =
    match args with
    | [] -> ( match acc.scenario_dir with "" -> _usage () | _ -> acc)
    | "--scenario-dir" :: v :: rest -> loop rest { acc with scenario_dir = v }
    | "--snapshot-dir" :: v :: rest ->
        loop rest { acc with snapshot_dir = Some v }
    | "--out" :: v :: rest -> loop rest { acc with out = Some v }
    | "--html" :: v :: rest -> loop rest { acc with html = Some v }
    | "--benchmark-symbol" :: v :: rest ->
        loop rest { acc with benchmark_symbol = v }
    | _ -> _usage ()
  in
  loop args
    {
      scenario_dir = "";
      snapshot_dir = None;
      out = None;
      html = None;
      benchmark_symbol = "SPY";
    }

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

(* Weekly [(date, close)] bars for the per-trade HTML chart series: up to [n]
   weekly bars ending at/before [as_of], straight off the snapshot weekly view.
   Feeds [Html_report.load ?weekly_series]. *)
let _weekly_series_of_reader reader ~symbol ~n ~as_of =
  let view = Bar_reader.weekly_view_for reader ~symbol ~n ~as_of in
  Array.zip_exn view.Snapshot_bar_views.dates view.Snapshot_bar_views.closes

(* Last adjusted close at/before [as_of] for [symbol], or [None] when the
   warehouse has no bar within the lookback window. Feeds the HTML benchmark and
   utilization series. *)
let _bar_close_of_reader reader ~symbol ~as_of =
  let view =
    Bar_reader.daily_view_for reader ~symbol ~as_of
      ~lookback:_mark_lookback_days
  in
  let closes = view.Snapshot_bar_views.closes in
  if Array.is_empty closes then None else Some closes.(Array.length closes - 1)

let _write ~path s =
  Out_channel.with_file path ~f:(fun oc -> Out_channel.output_string oc s)

let () =
  let { scenario_dir; snapshot_dir; out; html; benchmark_symbol } =
    _parse_args ()
  in
  let reader =
    Option.map snapshot_dir ~f:(fun snapshot_dir ->
        _bar_reader_of_snapshot ~snapshot_dir)
  in
  let closes_lookup = Option.map reader ~f:_closes_lookup_of_reader in
  let report = Trade_audit_report.load ?closes_lookup ~scenario_dir () in
  (* Markdown to [--out] when given; also to stdout when neither output flag was
     supplied (preserving the exe's original default behaviour). *)
  (match (out, html) with
  | None, None -> print_string (Trade_audit_report.to_markdown report)
  | Some path, _ -> _write ~path (Trade_audit_report.to_markdown report)
  | None, Some _ -> ());
  Option.iter html ~f:(fun path ->
      let bar_close =
        Option.map reader ~f:(fun reader -> _bar_close_of_reader reader)
      in
      let weekly_series =
        Option.map reader ~f:(fun reader -> _weekly_series_of_reader reader)
      in
      let data =
        Html_report.load ?bar_close ?weekly_series ~benchmark_symbol ~report
          ~scenario_dir ()
      in
      _write ~path (Html_report.render data))
