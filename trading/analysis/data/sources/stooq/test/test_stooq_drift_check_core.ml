open Core
open OUnit2
open Matchers
open Stooq_drift_check_core
module Client = Stooq.Stooq_client

let _date y m d = Date.create_exn ~y ~m ~d

(* Builder helpers (kept inline per .claude/rules/test-patterns.md "Test Data
   Builders"). *)

let _stooq ~date ~close : Client.daily_observation =
  { date; open_ = close; high = close; low = close; close; volume = 0 }

(* The drift check pairs Stooq.close against EODHD.adjusted_close (both
   split-adjusted). The [close_price] field is set the same value here for
   record completeness but is unused by the drift pipeline. *)
let _eodhd ~date ~adj_close : Types.Daily_price.t =
  {
    date;
    open_price = adj_close;
    high_price = adj_close;
    low_price = adj_close;
    close_price = adj_close;
    volume = 0;
    adjusted_close = adj_close;
    active_through = None;
  }

(* build_drift_rows: exact-overlap series → row per day, rel_diff = 0. *)
let test_drift_rows_exact_overlap_zero_diff _ =
  let stooq =
    [
      _stooq ~date:(_date 2020 Month.Jan 2) ~close:74.0;
      _stooq ~date:(_date 2020 Month.Jan 3) ~close:75.0;
    ]
  in
  let eodhd =
    [
      _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:74.0;
      _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:75.0;
    ]
  in
  assert_that
    (build_drift_rows ~stooq ~eodhd)
    (elements_are
       [
         equal_to
           ({
              date = _date 2020 Month.Jan 2;
              stooq_close = 74.0;
              eodhd_adj_close = 74.0;
              rel_diff = 0.0;
            }
             : drift_row);
         equal_to
           ({
              date = _date 2020 Month.Jan 3;
              stooq_close = 75.0;
              eodhd_adj_close = 75.0;
              rel_diff = 0.0;
            }
             : drift_row);
       ])

(* Signed rel_diff: eodhd higher than stooq → positive. *)
let test_drift_rows_signed_rel_diff _ =
  let stooq = [ _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0 ] in
  let eodhd = [ _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:101.0 ] in
  assert_that
    (build_drift_rows ~stooq ~eodhd)
    (elements_are
       [
         all_of
           [
             field (fun r -> r.date) (equal_to (_date 2020 Month.Jan 2));
             field (fun r -> r.rel_diff) (float_equal 0.01);
           ];
       ])

let test_drift_rows_negative_when_eodhd_lower _ =
  let stooq = [ _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0 ] in
  let eodhd = [ _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:99.0 ] in
  assert_that
    (build_drift_rows ~stooq ~eodhd)
    (elements_are
       [ field (fun r -> r.rel_diff) (float_equal ~epsilon:1e-9 (-0.01)) ])

(* Dates present only in one source must be dropped (overlap-only join). *)
let test_drift_rows_drops_stooq_only_dates _ =
  let stooq =
    [
      _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0;
      _stooq ~date:(_date 2020 Month.Jan 3) ~close:101.0;
    ]
  in
  let eodhd = [ _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:101.5 ] in
  let rows = build_drift_rows ~stooq ~eodhd in
  assert_that rows
    (elements_are
       [ field (fun r -> r.date) (equal_to (_date 2020 Month.Jan 3)) ])

let test_drift_rows_drops_eodhd_only_dates _ =
  let stooq = [ _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0 ] in
  let eodhd =
    [
      _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:100.5;
      _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:101.0;
    ]
  in
  let rows = build_drift_rows ~stooq ~eodhd in
  assert_that rows
    (elements_are
       [ field (fun r -> r.date) (equal_to (_date 2020 Month.Jan 2)) ])

(* compute_stats: threshold flagging. *)
let test_compute_stats_threshold_flagging _ =
  let rows =
    [
      {
        date = _date 2020 Month.Jan 2;
        stooq_close = 100.0;
        eodhd_adj_close = 100.4;
        rel_diff = 0.004;
      };
      {
        date = _date 2020 Month.Jan 3;
        stooq_close = 100.0;
        eodhd_adj_close = 101.0;
        rel_diff = 0.01;
      };
      {
        date = _date 2020 Month.Jan 6;
        stooq_close = 100.0;
        eodhd_adj_close = 98.0;
        rel_diff = -0.02;
      };
    ]
  in
  (* threshold 0.005 → flagged: days 2 (|0.01|>0.005) and 3 (|0.02|>0.005). *)
  assert_that
    (compute_stats ~threshold:0.005 rows)
    (all_of
       [
         field (fun s -> s.n_compared) (equal_to 3);
         field (fun s -> s.n_flagged) (equal_to 2);
         field (fun s -> s.max_abs_rel_diff) (float_equal ~epsilon:1e-9 0.02);
         field
           (fun s -> s.mean_abs_rel_diff)
           (float_equal ~epsilon:1e-9 ((0.004 +. 0.01 +. 0.02) /. 3.0));
       ])

let test_compute_stats_empty_rows _ =
  assert_that
    (compute_stats ~threshold:0.005 [])
    (equal_to
       ({
          n_compared = 0;
          n_flagged = 0;
          mean_abs_rel_diff = 0.0;
          max_abs_rel_diff = 0.0;
        }
         : stats))

(* build_report: full pipeline, including overlap-bounds + flagged-row
   sort (descending |rel_diff|). *)
let test_build_report_overlap_and_top_flagged _ =
  let stooq =
    [
      _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0;
      _stooq ~date:(_date 2020 Month.Jan 3) ~close:100.0;
      _stooq ~date:(_date 2020 Month.Jan 6) ~close:100.0;
    ]
  in
  let eodhd =
    [
      _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:100.4;
      (* below threshold *)
      _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:101.0;
      (* flagged *)
      _eodhd ~date:(_date 2020 Month.Jan 6) ~adj_close:103.0;
      (* flagged, biggest *)
    ]
  in
  let report = build_report ~symbol:"aapl" ~stooq ~eodhd ~threshold:0.005 in
  assert_that report
    (all_of
       [
         field (fun r -> r.symbol) (equal_to "AAPL");
         field
           (fun r -> r.overlap_first)
           (is_some_and (equal_to (_date 2020 Month.Jan 2)));
         field
           (fun r -> r.overlap_last)
           (is_some_and (equal_to (_date 2020 Month.Jan 6)));
         field (fun r -> r.stats.n_compared) (equal_to 3);
         field (fun r -> r.stats.n_flagged) (equal_to 2);
         field
           (fun r -> r.flagged_rows)
           (elements_are
              [
                field (fun row -> row.date) (equal_to (_date 2020 Month.Jan 6));
                field (fun row -> row.date) (equal_to (_date 2020 Month.Jan 3));
              ]);
       ])

let test_build_report_empty_overlap _ =
  let stooq = [ _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0 ] in
  let eodhd = [ _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:101.0 ] in
  let report = build_report ~symbol:"aapl" ~stooq ~eodhd ~threshold:0.005 in
  assert_that report
    (all_of
       [
         field (fun r -> r.overlap_first) is_none;
         field (fun r -> r.overlap_last) is_none;
         field (fun r -> r.stats.n_compared) (equal_to 0);
         field (fun r -> r.stooq_only_count) (equal_to 1);
         field (fun r -> r.eodhd_only_count) (equal_to 1);
       ])

let test_build_report_counts_unmatched_dates _ =
  let stooq =
    [
      _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0;
      _stooq ~date:(_date 2020 Month.Jan 6) ~close:100.0;
    ]
  in
  let eodhd =
    [
      _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:100.0;
      _eodhd ~date:(_date 2020 Month.Jan 3) ~adj_close:100.0;
      _eodhd ~date:(_date 2020 Month.Jan 7) ~adj_close:100.0;
    ]
  in
  let report = build_report ~symbol:"x" ~stooq ~eodhd ~threshold:0.005 in
  assert_that report
    (all_of
       [
         field (fun r -> r.stats.n_compared) (equal_to 1);
         field (fun r -> r.stooq_only_count) (equal_to 1);
         field (fun r -> r.eodhd_only_count) (equal_to 2);
       ])

let test_format_text_report_contains_summary_lines _ =
  let stooq = [ _stooq ~date:(_date 2020 Month.Jan 2) ~close:100.0 ] in
  let eodhd = [ _eodhd ~date:(_date 2020 Month.Jan 2) ~adj_close:101.0 ] in
  let report = build_report ~symbol:"aapl" ~stooq ~eodhd ~threshold:0.005 in
  let text = format_text_report report in
  assert_that text
    (all_of
       [
         contains_substring "Stooq drift check: AAPL";
         contains_substring "overlap range:";
         contains_substring "days compared: 1";
         contains_substring "days flagged:  1";
       ])

let test_build_report_flagged_rows_capped_at_top_10 _ =
  (* Pins the top-10 cap on flagged_rows (per stooq_drift_check_core.mli). *)
  let n = 15 in
  let stooq =
    List.init n ~f:(fun i ->
        _stooq ~date:(_date 2020 Month.Jan (i + 1)) ~close:100.0)
  in
  let eodhd =
    List.init n ~f:(fun i ->
        _eodhd
          ~date:(_date 2020 Month.Jan (i + 1))
          ~adj_close:(100.0 +. Float.of_int (i + 1)))
  in
  let report = build_report ~symbol:"x" ~stooq ~eodhd ~threshold:0.005 in
  assert_that report
    (all_of
       [
         field (fun r -> r.stats.n_compared) (equal_to n);
         field (fun r -> r.stats.n_flagged) (equal_to n);
         field (fun r -> List.length r.flagged_rows) (equal_to 10);
       ])

let suite =
  "stooq_drift_check_core"
  >::: [
         "test_drift_rows_exact_overlap_zero_diff"
         >:: test_drift_rows_exact_overlap_zero_diff;
         "test_drift_rows_signed_rel_diff" >:: test_drift_rows_signed_rel_diff;
         "test_drift_rows_negative_when_eodhd_lower"
         >:: test_drift_rows_negative_when_eodhd_lower;
         "test_drift_rows_drops_stooq_only_dates"
         >:: test_drift_rows_drops_stooq_only_dates;
         "test_drift_rows_drops_eodhd_only_dates"
         >:: test_drift_rows_drops_eodhd_only_dates;
         "test_compute_stats_threshold_flagging"
         >:: test_compute_stats_threshold_flagging;
         "test_compute_stats_empty_rows" >:: test_compute_stats_empty_rows;
         "test_build_report_overlap_and_top_flagged"
         >:: test_build_report_overlap_and_top_flagged;
         "test_build_report_empty_overlap" >:: test_build_report_empty_overlap;
         "test_build_report_counts_unmatched_dates"
         >:: test_build_report_counts_unmatched_dates;
         "test_format_text_report_contains_summary_lines"
         >:: test_format_text_report_contains_summary_lines;
         "test_build_report_flagged_rows_capped_at_top_10"
         >:: test_build_report_flagged_rows_capped_at_top_10;
       ]

let () = run_test_tt_main suite
