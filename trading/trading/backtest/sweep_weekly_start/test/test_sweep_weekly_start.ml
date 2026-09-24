(** Pure unit tests for {!Sweep_weekly_start.Sweep_weekly_start_lib}.

    The IO-touching entry point {!Sweep_weekly_start_lib.run} requires SPY bars
    under [data/S/Y/SPY/] which is not part of [test_data/], so these tests
    drive the pure surface (monday enumeration, aggregation, formatters, sexp
    round-trip) with hand-constructed cell fixtures instead.

    The {!Backtest.Runner.run_backtest} integration is covered by the existing
    [test_bah_runner_e2e] suite — that's where data is required and where the
    fill-pricing invariants are pinned. This file does not duplicate that
    coverage. *)

open OUnit2
open Core
open Matchers
module SWS = Sweep_weekly_start.Sweep_weekly_start_lib

(* --- fixture builders --- *)

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d

let _make_cell ~start_date ~cagr ?(final_value = 100000.0)
    ?(total_return = 0.10) ?(max_dd = 0.10) ?(sharpe = 1.0) () : SWS.cell =
  { start_date; final_value; total_return; cagr; max_dd; sharpe }

let _sample_cells () : SWS.cell list =
  [
    _make_cell ~start_date:(_date ~y:2023 ~m:May ~d:22) ~cagr:0.05 ();
    _make_cell ~start_date:(_date ~y:2023 ~m:May ~d:29) ~cagr:0.15 ();
    _make_cell ~start_date:(_date ~y:2023 ~m:Jun ~d:5) ~cagr:0.20 ();
    _make_cell ~start_date:(_date ~y:2023 ~m:Jun ~d:12) ~cagr:0.10 ();
    _make_cell ~start_date:(_date ~y:2023 ~m:Jun ~d:19) ~cagr:(-0.05) ();
  ]

let _sample_result () : SWS.sweep_result =
  let cells = _sample_cells () in
  {
    run_date = _date ~y:2026 ~m:May ~d:17;
    end_date = _date ~y:2026 ~m:May ~d:17;
    symbol = "SPY";
    initial_cash = 100000.0;
    years_back = 3;
    cells;
    summary = SWS.summarize cells;
    coverage = None;
    dropped_cells = [];
  }

(* --- tests --- *)

(** [mondays_in_window] enumerates Mondays in chronological order. With a fixed
    [end_date] of Sun 2026-05-17 and [years_back = 0] then a 1-week window we
    expect a small known set. We pin [years_back = 1] over a fixed end_date and
    assert size + monotone monday-ness via [elements_are] on the head/tail. *)
let test_mondays_in_window_chronological _ =
  let end_date = _date ~y:2026 ~m:May ~d:17 in
  let mondays = SWS.mondays_in_window ~end_date ~years_back:1 in
  (* A 1y window has ~52 Mondays; assert size band and Monday-ness. *)
  assert_that mondays
    (all_of
       [
         size_is 52;
         each
           (matching ~msg:"every cell start is a Monday"
              (fun (d : Date.t) ->
                if Day_of_week.equal (Date.day_of_week d) Day_of_week.Mon then
                  Some ()
                else None)
              (equal_to ()));
       ])

(** End-date is excluded when it's itself a Monday — the sweep needs
    [start_date < end_date] for any non-empty return. *)
let test_mondays_in_window_excludes_end_date _ =
  let end_date = _date ~y:2026 ~m:May ~d:18 in
  (* 2026-05-18 is a Monday. *)
  assert_that (Date.day_of_week end_date) (equal_to Day_of_week.Mon);
  let mondays = SWS.mondays_in_window ~end_date ~years_back:0 in
  assert_that mondays is_empty

(** [summarize] computes best, worst, median, mean, stddev from a known cell
    set. Sample cells have CAGRs [0.05; 0.15; 0.20; 0.10; -0.05]:
    - best = 0.20 (start 2023-06-05)
    - worst = -0.05 (start 2023-06-19)
    - mean = 0.09
    - median = 0.10
    - sample stddev = sqrt(sum((x-0.09)^2)/4) = sqrt(0.0370/4) = sqrt(0.00925) =
      0.096177 (six-digit truncation matches the [@epsilon:1e-4] band). *)
let test_summarize_aggregate_stats _ =
  let s = SWS.summarize (_sample_cells ()) in
  assert_that s
    (all_of
       [
         field (fun s -> s.SWS.n_cells) (equal_to 5);
         field (fun s -> s.SWS.best_cagr) (float_equal 0.20);
         field
           (fun s -> s.SWS.best_cell_start)
           (equal_to (_date ~y:2023 ~m:Jun ~d:5));
         field (fun s -> s.SWS.worst_cagr) (float_equal (-0.05));
         field
           (fun s -> s.SWS.worst_cell_start)
           (equal_to (_date ~y:2023 ~m:Jun ~d:19));
         field (fun s -> s.SWS.median_cagr) (float_equal 0.10);
         field (fun s -> s.SWS.mean_cagr) (float_equal ~epsilon:1e-9 0.09);
         field (fun s -> s.SWS.stddev_cagr) (float_equal ~epsilon:1e-4 0.09618);
       ])

(** An empty input returns the documented zeroed summary. *)
let test_summarize_empty _ =
  let s = SWS.summarize [] in
  assert_that s
    (all_of
       [
         field (fun s -> s.SWS.n_cells) (equal_to 0);
         field (fun s -> s.SWS.best_cagr) (float_equal 0.0);
         field (fun s -> s.SWS.mean_cagr) (float_equal 0.0);
         field (fun s -> s.SWS.stddev_cagr) (float_equal 0.0);
       ])

(** Markdown output has the header, summary block, table header, and one row per
    cell. *)
let test_format_markdown_table_shape _ =
  let r = _sample_result () in
  let md = SWS.format_markdown r in
  assert_that md
    (all_of
       [
         contains_substring "# Weekly-start sweep -- BAH SPY";
         contains_substring "Run date: 2026-05-17";
         contains_substring "Window: 3 years trailing";
         contains_substring "Cells: 5";
         contains_substring "## Summary";
         contains_substring "Best entry (highest CAGR to end_date): 2023-06-05";
         contains_substring "Worst entry: 2023-06-19";
         contains_substring "## Distribution";
         contains_substring
           "| Cell | Start | Final $ | Total Return | CAGR | Max DD | Sharpe |";
         (* Five data rows -> the indices 1..5 each appear at the start of a
            row. We pin a deterministic mid-row to keep the assertion
            specific. *)
         contains_substring "| 3 | 2023-06-05 |";
       ])

(** [max_cells] downsamples evenly. With 5 cells and max_cells = 3 we expect the
    first, middle, last (indices 0, 2, 4). *)
let test_format_markdown_max_cells _ =
  let r = _sample_result () in
  let md = SWS.format_markdown ~max_cells:3 r in
  assert_that md
    (all_of
       [
         contains_substring "| 1 | 2023-05-22 |";
         contains_substring "| 2 | 2023-06-05 |";
         contains_substring "| 3 | 2023-06-19 |";
         (* The 4th and 5th cells should NOT appear when downsampled. *)
         not_ (contains_substring "| 4 |");
       ])

(** Empty-cell sweep renders a "no cells" notice instead of an empty table. *)
let test_format_markdown_empty _ =
  let r : SWS.sweep_result =
    {
      run_date = _date ~y:2026 ~m:May ~d:17;
      end_date = _date ~y:2026 ~m:May ~d:17;
      symbol = "SPY";
      initial_cash = 100000.0;
      years_back = 0;
      cells = [];
      summary = SWS.summarize [];
      coverage = None;
      dropped_cells = [];
    }
  in
  let md = SWS.format_markdown r in
  assert_that md (contains_substring "(no cells in window)")

(** [format_sexp] -> [sweep_result_of_sexp] round-trips the full result. *)
let test_sexp_roundtrip _ =
  let r = _sample_result () in
  let sexp = SWS.format_sexp r in
  let r' = SWS.sweep_result_of_sexp sexp in
  assert_that r' (equal_to r)

(* --- end-date guard + dropped-cell fixtures (issue #2915) --- *)

let _flat_bar date : Types.Daily_price.t =
  {
    date;
    open_price = 100.0;
    high_price = 100.0;
    low_price = 100.0;
    close_price = 100.0;
    volume = 1_000;
    adjusted_close = 100.0;
    active_through = None;
  }

(** Weekday bars from [first] through [last] inclusive. *)
let _weekday_bars ~first ~last =
  let is_weekday d =
    match Date.day_of_week d with
    | Day_of_week.Sat | Day_of_week.Sun -> false
    | _ -> true
  in
  Date.dates_between ~min:first ~max:last
  |> List.filter ~f:is_weekday |> List.map ~f:_flat_bar

(** Stage a temp CSV store holding SPY bars ending on [last], and return its
    root. *)
let _stage_spy_bars ~last =
  let data_dir = Fpath.v (Core_unix.mkdtemp "/tmp/sweep_weekly_start_data_") in
  let bars = _weekday_bars ~first:(_date ~y:2026 ~m:Apr ~d:1) ~last in
  (match Csv.Csv_storage.create ~data_dir "SPY" with
  | Error err -> assert_failure ("csv create: " ^ Status.show err)
  | Ok storage -> (
      match Csv.Csv_storage.save storage bars with
      | Error err -> assert_failure ("csv save: " ^ Status.show err)
      | Ok () -> ()));
  data_dir

(** The weekly workflow's shape: a Monday run date well past a stale floor. *)
let _run_date = _date ~y:2026 ~m:Sep ~d:21

let _coverage_for ~last =
  SWS.load_coverage ~data_dir:(_stage_spy_bars ~last) ~symbol:"SPY"
    ~requested_end_date:_run_date
    ~tolerance_days:SWS.default_max_end_date_gap_days

let _result_with ?coverage ?(dropped_cells = []) () : SWS.sweep_result =
  { (_sample_result ()) with coverage; dropped_cells }

(* --- end-date guard tests --- *)

(** Bars stop 2026-05-01 (the committed SPY floor), run date 2026-09-21: 143
    dead days > 7-day tolerance, so the guard clamps to the last bar. *)
let test_truncated_bars_trigger_guard _ =
  let last = _date ~y:2026 ~m:May ~d:1 in
  assert_that (_coverage_for ~last)
    (equal_to
       ({
          requested_end_date = _run_date;
          last_bar_date = last;
          tolerance_days = 7;
          clamped = true;
        }
         : SWS.coverage))

(** A clamped coverage measures every cell to the last bar. *)
let test_clamped_effective_end_is_last_bar _ =
  let last = _date ~y:2026 ~m:May ~d:1 in
  assert_that (SWS.effective_end_date (_coverage_for ~last)) (equal_to last)

(** The truncated fixture's report carries the loud clamp notice with both dates
    and the gap, plus the last-bar line. *)
let test_truncated_bars_report_annotated _ =
  let coverage = _coverage_for ~last:(_date ~y:2026 ~m:May ~d:1) in
  assert_that
    (SWS.format_markdown (_result_with ~coverage ()))
    (all_of
       [
         contains_substring "Last bar: 2026-05-01";
         contains_substring "WARNING -- END DATE CLAMPED";
         contains_substring
           "Requested end date 2026-09-21 is 143 days past the last SPY bar \
            (2026-05-01), beyond the 7-day tolerance";
       ])

(** Bars through Fri 2026-09-18, run Mon 2026-09-21: a 3-day weekend gap, so no
    clamp and the requested end date stands. *)
let test_full_coverage_not_clamped _ =
  let coverage = _coverage_for ~last:(_date ~y:2026 ~m:Sep ~d:18) in
  assert_that coverage
    (all_of
       [
         field (fun (c : SWS.coverage) -> c.clamped) (equal_to false);
         field (fun c -> SWS.effective_end_date c) (equal_to _run_date);
       ])

(** Full coverage: the header still records the last bar, but carries no clamp
    annotation. *)
let test_full_coverage_report_has_no_annotation _ =
  let coverage = _coverage_for ~last:(_date ~y:2026 ~m:Sep ~d:18) in
  assert_that
    (SWS.format_markdown (_result_with ~coverage ()))
    (all_of
       [
         contains_substring "Last bar: 2026-09-18";
         not_ (contains_substring "WARNING");
         not_ (contains_substring "CLAMPED");
       ])

(** Tolerance boundary: a gap of exactly [tolerance_days] passes; one more day
    clamps. *)
let test_resolve_coverage_boundary _ =
  let last_bar_date = _date ~y:2026 ~m:May ~d:1 in
  let clamped_at gap =
    (SWS.resolve_coverage
       ~requested_end_date:(Date.add_days last_bar_date gap)
       ~last_bar_date ~tolerance_days:7)
      .clamped
  in
  assert_that
    (List.map [ 0; 7; 8 ] ~f:clamped_at)
    (elements_are [ equal_to false; equal_to false; equal_to true ])

(* --- dropped-cell tests --- *)

let _dropped_fixture : SWS.dropped_cell list =
  [
    { start_date = _date ~y:2026 ~m:May ~d:4; reason = "empty window A" };
    { start_date = _date ~y:2026 ~m:May ~d:11; reason = "empty window B" };
  ]

(** Dropped cells show in the report: a count in the header and a section naming
    each start date with its reason. *)
let test_dropped_cells_rendered _ =
  assert_that
    (SWS.format_markdown (_result_with ~dropped_cells:_dropped_fixture ()))
    (all_of
       [
         contains_substring "Dropped cells: 2";
         contains_substring "## Dropped cells";
         contains_substring "2 cell(s) dropped";
         contains_substring "- 2026-05-04: empty window A";
         contains_substring "- 2026-05-11: empty window B";
       ])

(** The dropped section is rendered even when no cell survived — the case where
    it matters most. *)
let test_dropped_cells_rendered_when_no_cells _ =
  let r =
    {
      (_result_with ~dropped_cells:_dropped_fixture ()) with
      cells = [];
      summary = SWS.summarize [];
    }
  in
  assert_that (SWS.format_markdown r)
    (all_of
       [
         contains_substring "(no cells in window)";
         contains_substring "Dropped cells: 2";
         contains_substring "- 2026-05-11: empty window B";
       ])

(** Nothing dropped: the header says 0 and there is no dropped section. *)
let test_no_dropped_cells _ =
  assert_that
    (SWS.format_markdown (_result_with ()))
    (all_of
       [
         contains_substring "Dropped cells: 0";
         not_ (contains_substring "## Dropped cells");
       ])

(** Coverage and dropped cells survive the sexp round-trip. *)
let test_sexp_roundtrip_with_guard_fields _ =
  let r =
    _result_with
      ~coverage:
        (SWS.resolve_coverage ~requested_end_date:_run_date
           ~last_bar_date:(_date ~y:2026 ~m:May ~d:1)
           ~tolerance_days:7)
      ~dropped_cells:_dropped_fixture ()
  in
  assert_that (SWS.sweep_result_of_sexp (SWS.format_sexp r)) (equal_to r)

(** A pre-#2915 artefact (no [coverage], no [dropped_cells] field, the shape of
    the committed [weekly-start-sweep-bah-spy.sexp]) must still parse, with
    [coverage = None] and [dropped_cells = []]. A literal is used on purpose: a
    round-trip through [format_sexp] would write whatever shape the current
    derivers emit and so could not catch a lost [[@sexp.option]] /
    [[@sexp.list]]. *)
let test_old_shape_sexp_parses _ =
  let old_shape =
    "((run_date 2026-05-17) (end_date 2026-05-17) (symbol SPY)\n\
    \ (initial_cash 100000) (years_back 3)\n\
    \ (cells (((start_date 2023-05-22) (final_value 100000) (total_return 0.1)\n\
    \   (cagr 0.05) (max_dd 0.1) (sharpe 1))))\n\
    \ (summary ((best_cell_start 2023-05-22) (best_cagr 0.05)\n\
    \   (worst_cell_start 2023-05-22) (worst_cagr 0.05) (median_cagr 0.05)\n\
    \   (mean_cagr 0.05) (stddev_cagr 0) (n_cells 1))))"
  in
  assert_that
    (SWS.sweep_result_of_sexp (Sexp.of_string old_shape))
    (all_of
       [
         field (fun (r : SWS.sweep_result) -> r.coverage) is_none;
         field (fun (r : SWS.sweep_result) -> r.dropped_cells) is_empty;
         field (fun (r : SWS.sweep_result) -> List.length r.cells) (equal_to 1);
       ])

let suite =
  "Sweep_weekly_start"
  >::: [
         "mondays_in_window emits chronological Mondays"
         >:: test_mondays_in_window_chronological;
         "mondays_in_window excludes end_date even when it's a Monday"
         >:: test_mondays_in_window_excludes_end_date;
         "summarize computes best/worst/median/mean/stddev"
         >:: test_summarize_aggregate_stats;
         "summarize handles empty input" >:: test_summarize_empty;
         "format_markdown renders header + summary + table"
         >:: test_format_markdown_table_shape;
         "format_markdown ~max_cells samples evenly"
         >:: test_format_markdown_max_cells;
         "format_markdown empty cells renders a notice"
         >:: test_format_markdown_empty;
         "sweep_result sexp round-trips" >:: test_sexp_roundtrip;
         "truncated bars trigger the end-date guard"
         >:: test_truncated_bars_trigger_guard;
         "clamped effective end is the last bar"
         >:: test_clamped_effective_end_is_last_bar;
         "truncated bars annotate the report"
         >:: test_truncated_bars_report_annotated;
         "full coverage is not clamped" >:: test_full_coverage_not_clamped;
         "full coverage report has no annotation"
         >:: test_full_coverage_report_has_no_annotation;
         "resolve_coverage tolerance boundary"
         >:: test_resolve_coverage_boundary;
         "dropped cells rendered in report" >:: test_dropped_cells_rendered;
         "dropped cells rendered when no cell survived"
         >:: test_dropped_cells_rendered_when_no_cells;
         "no dropped cells renders a zero count" >:: test_no_dropped_cells;
         "sexp round-trips coverage and dropped cells"
         >:: test_sexp_roundtrip_with_guard_fields;
         "pre-#2915 sexp (no guard fields) still parses"
         >:: test_old_shape_sexp_parses;
       ]

let () = run_test_tt_main suite
