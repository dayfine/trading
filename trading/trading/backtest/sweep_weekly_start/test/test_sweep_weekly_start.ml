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
       ]

let () = run_test_tt_main suite
