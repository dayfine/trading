open Core
open OUnit2
open Matchers
module Core_ = Shiller_validator_core
module Client = Shiller.Shiller_client

let _date y m d = Date.create_exn ~y ~m ~d

let _make_bar ~date ~adjusted_close : Types.Daily_price.t =
  {
    date;
    open_price = adjusted_close;
    high_price = adjusted_close;
    low_price = adjusted_close;
    close_price = adjusted_close;
    adjusted_close;
    volume = 0;
    active_through = None;
  }

let _make_obs ~period ~sp_price : Client.monthly_observation =
  {
    period;
    sp_price;
    dividend = None;
    earnings = None;
    cpi = None;
    long_rate = None;
  }

(* Resample picks the last bar in each calendar month, anchored to the
   first-of-month for join-keying. Multi-day Feb stream must collapse to a
   single Feb-anchor row using the Feb-28 bar. *)
let test_resample_picks_last_bar_per_month _ =
  let bars =
    [
      _make_bar ~date:(_date 2000 Jan 3) ~adjusted_close:1400.0;
      _make_bar ~date:(_date 2000 Jan 31) ~adjusted_close:1425.0;
      _make_bar ~date:(_date 2000 Feb 1) ~adjusted_close:1430.0;
      _make_bar ~date:(_date 2000 Feb 28) ~adjusted_close:1450.0;
    ]
  in
  assert_that
    (Core_.resample_daily_to_monthly bars)
    (elements_are
       [
         equal_to ((_date 2000 Jan 1, 1425.0) : Date.t * float);
         equal_to ((_date 2000 Feb 1, 1450.0) : Date.t * float);
       ])

let test_resample_empty_input_yields_empty _ =
  assert_that (Core_.resample_daily_to_monthly []) is_empty

(* Drift computation with controlled inputs: Shiller=100, EODHD=101.5 →
   +1.5%. Sign convention: positive when EODHD reads higher than Shiller. *)
let test_drift_row_uses_signed_relative_diff _ =
  let shiller = [ _make_obs ~period:(_date 2010 Jun 1) ~sp_price:100.0 ] in
  let eodhd_monthly = [ (_date 2010 Jun 1, 101.5) ] in
  assert_that
    (Core_.build_drift_rows ~shiller ~eodhd_monthly)
    (elements_are
       [
         all_of
           [
             field (fun r -> r.Core_.period) (equal_to (_date 2010 Jun 1));
             field (fun r -> r.Core_.shiller_sp_price) (float_equal 100.0);
             field
               (fun r -> r.Core_.eodhd_monthly_adj_close)
               (float_equal 101.5);
             field (fun r -> r.Core_.rel_diff) (float_equal 0.015);
           ];
       ])

(* Only months present in BOTH series make it into the rows — that's the
   overlap window. A Shiller-only month and an EODHD-only month both drop
   out. *)
let test_build_drift_rows_keeps_only_overlap _ =
  let shiller =
    [
      _make_obs ~period:(_date 1995 Jan 1) ~sp_price:470.0;
      _make_obs ~period:(_date 2010 Jun 1) ~sp_price:1100.0;
      _make_obs ~period:(_date 2025 Dec 1) ~sp_price:5500.0;
    ]
  in
  let eodhd_monthly =
    [ (_date 2010 Jun 1, 1110.0); (_date 2026 Jan 1, 5700.0) ]
  in
  assert_that
    (Core_.build_drift_rows ~shiller ~eodhd_monthly)
    (elements_are
       [
         all_of
           [
             field (fun r -> r.Core_.period) (equal_to (_date 2010 Jun 1));
             field (fun r -> r.Core_.shiller_sp_price) (float_equal 1100.0);
           ];
       ])

(* compute_stats: rows = [+1%, -2%, +0.4%] with threshold 0.5% →
   abs = [0.01, 0.02, 0.004], n_flagged = 2 (the 1% and 2% rows). *)
let test_compute_stats_counts_flags_above_threshold _ =
  let rows : Core_.drift_row list =
    [
      {
        period = _date 2010 Jan 1;
        shiller_sp_price = 100.0;
        eodhd_monthly_adj_close = 101.0;
        rel_diff = 0.01;
      };
      {
        period = _date 2010 Feb 1;
        shiller_sp_price = 100.0;
        eodhd_monthly_adj_close = 98.0;
        rel_diff = -0.02;
      };
      {
        period = _date 2010 Mar 1;
        shiller_sp_price = 100.0;
        eodhd_monthly_adj_close = 100.4;
        rel_diff = 0.004;
      };
    ]
  in
  assert_that
    (Core_.compute_stats ~threshold:0.005 rows)
    (all_of
       [
         field (fun s -> s.Core_.n_compared) (equal_to 3);
         field (fun s -> s.Core_.n_flagged) (equal_to 2);
         field
           (fun s -> s.Core_.max_abs_rel_diff)
           (float_equal ~epsilon:1e-9 0.02);
         field
           (fun s -> s.Core_.mean_abs_rel_diff)
           (float_equal ~epsilon:1e-9 ((0.01 +. 0.02 +. 0.004) /. 3.0));
       ])

(* Empty overlap → an empty stats record with all-zeros. The Markdown
   writer still needs to render something sensible from this. *)
let test_compute_stats_on_empty_rows _ =
  assert_that
    (Core_.compute_stats ~threshold:0.005 [])
    (equal_to
       ({
          n_compared = 0;
          n_flagged = 0;
          mean_abs_rel_diff = 0.0;
          stdev_abs_rel_diff = 0.0;
          max_abs_rel_diff = 0.0;
        }
         : Core_.stats))

(* build_report wires resample + align + stats + top-N together. With a
   single overlap month we should see a 1-row report, overlap_first =
   overlap_last, and top_drift = rows. *)
let test_build_report_pipeline _ =
  let shiller = [ _make_obs ~period:(_date 2020 Mar 1) ~sp_price:2650.0 ] in
  let eodhd_monthly = [ (_date 2020 Mar 1, 2680.0) ] in
  let report =
    Core_.build_report ~shiller ~eodhd_monthly ~threshold:0.005 ~top_n:5
  in
  assert_that report
    (all_of
       [
         field
           (fun r -> r.Core_.overlap_first)
           (is_some_and (equal_to (_date 2020 Mar 1)));
         field
           (fun r -> r.Core_.overlap_last)
           (is_some_and (equal_to (_date 2020 Mar 1)));
         field (fun r -> r.Core_.stats.n_compared) (equal_to 1);
         field (fun r -> r.Core_.stats.n_flagged) (equal_to 1);
         field (fun r -> r.Core_.rows) (size_is 1);
         field (fun r -> r.Core_.top_drift) (size_is 1);
       ])

(* Empty-overlap report from build_report: empty Shiller against any EODHD
   yields a no-overlap report with [None] dates and zero stats. *)
let test_build_report_empty_overlap _ =
  let report =
    Core_.build_report ~shiller:[]
      ~eodhd_monthly:[ (_date 2010 Jun 1, 1100.0) ]
      ~threshold:0.005 ~top_n:5
  in
  assert_that report
    (all_of
       [
         field (fun r -> r.Core_.overlap_first) is_none;
         field (fun r -> r.Core_.overlap_last) is_none;
         field (fun r -> r.Core_.stats.n_compared) (equal_to 0);
         field (fun r -> r.Core_.rows) is_empty;
         field (fun r -> r.Core_.top_drift) is_empty;
       ])

(* top_drift sorts by |rel_diff| descending and caps at top_n. We feed five
   rows with monotonically increasing absolute drift and check the top-3
   come out in the right order. *)
let test_build_report_top_n_orders_by_abs_drift _ =
  let shiller =
    List.init 5 ~f:(fun i ->
        _make_obs
          ~period:(_date 2010 (Month.of_int_exn (i + 1)) 1)
          ~sp_price:100.0)
  in
  let eodhd_monthly =
    [
      (_date 2010 Jan 1, 100.1);
      (* +0.1% *)
      (_date 2010 Feb 1, 100.5);
      (* +0.5% *)
      (_date 2010 Mar 1, 101.0);
      (* +1.0% *)
      (_date 2010 Apr 1, 98.0);
      (* -2.0% *)
      (_date 2010 May 1, 103.0);
      (* +3.0% *)
    ]
  in
  let report =
    Core_.build_report ~shiller ~eodhd_monthly ~threshold:0.005 ~top_n:3
  in
  assert_that report.top_drift
    (elements_are
       [
         field (fun r -> r.Core_.period) (equal_to (_date 2010 May 1));
         field (fun r -> r.Core_.period) (equal_to (_date 2010 Apr 1));
         field (fun r -> r.Core_.period) (equal_to (_date 2010 Mar 1));
       ])

(* Markdown renderer: smoke-test the structural anchors so a structural
   change to the report is caught. We don't pin every byte — that's brittle
   and adds noise. *)
let test_format_markdown_report_has_expected_anchors _ =
  let report =
    Core_.build_report
      ~shiller:[ _make_obs ~period:(_date 2020 Mar 1) ~sp_price:2650.0 ]
      ~eodhd_monthly:[ (_date 2020 Mar 1, 2680.0) ]
      ~threshold:0.005 ~top_n:5
  in
  assert_that
    (Core_.format_markdown_report report)
    (all_of
       [
         contains_substring "# Shiller → EODHD adjusted-close cross-validation";
         contains_substring "## Summary";
         contains_substring "Overlap window";
         contains_substring "Months compared: **1**";
         contains_substring "Months flagged";
         contains_substring "## Top 1 drift months";
         contains_substring "2020-03-01";
       ])

(* The empty-overlap Markdown should still render cleanly (no exceptions,
   sensible "no overlap" surface). *)
let test_format_markdown_report_empty_overlap _ =
  let report =
    Core_.build_report ~shiller:[] ~eodhd_monthly:[] ~threshold:0.005 ~top_n:5
  in
  assert_that
    (Core_.format_markdown_report report)
    (all_of
       [
         contains_substring "Months compared: **0**";
         contains_substring "Overlap window: **n/a**";
         contains_substring "no overlap";
       ])

(* The derived-CSV parser consumes fetch_shiller_history.exe output.
   Empty fields in the four optional columns must map to [None]. *)
let test_parse_derived_csv_handles_empty_optionals _ =
  let body =
    "period,sp_price,dividend,earnings,cpi,long_rate\n\
     2026-03-01,6654.42,,,,\n\
     2020-03-01,2652.39,58.51,135.18,258.115,0.87\n"
  in
  assert_that
    (Core_.parse_shiller_derived_csv body)
    (is_ok_and_holds
       (elements_are
          [
            all_of
              [
                field (fun o -> o.Client.period) (equal_to (_date 2026 Mar 1));
                field (fun o -> o.Client.sp_price) (float_equal 6654.42);
                field (fun o -> o.Client.dividend) is_none;
                field (fun o -> o.Client.cpi) is_none;
              ];
            all_of
              [
                field (fun o -> o.Client.period) (equal_to (_date 2020 Mar 1));
                field (fun o -> o.Client.sp_price) (float_equal 2652.39);
                field
                  (fun o -> o.Client.dividend)
                  (is_some_and (float_equal 58.51));
                field
                  (fun o -> o.Client.long_rate)
                  (is_some_and (float_equal 0.87));
              ];
          ]))

let test_parse_derived_csv_header_drift_is_error _ =
  let body =
    "period,WRONG,dividend,earnings,cpi,long_rate\n\
     2020-03-01,2652.39,58.51,135.18,258.115,0.87\n"
  in
  assert_that
    (Core_.parse_shiller_derived_csv body)
    (is_error_with Status.Invalid_argument)

let test_parse_derived_csv_empty_body_is_error _ =
  assert_that
    (Core_.parse_shiller_derived_csv "")
    (is_error_with Status.Invalid_argument)

let suite =
  "shiller_validator"
  >::: [
         "test_resample_picks_last_bar_per_month"
         >:: test_resample_picks_last_bar_per_month;
         "test_resample_empty_input_yields_empty"
         >:: test_resample_empty_input_yields_empty;
         "test_drift_row_uses_signed_relative_diff"
         >:: test_drift_row_uses_signed_relative_diff;
         "test_build_drift_rows_keeps_only_overlap"
         >:: test_build_drift_rows_keeps_only_overlap;
         "test_compute_stats_counts_flags_above_threshold"
         >:: test_compute_stats_counts_flags_above_threshold;
         "test_compute_stats_on_empty_rows" >:: test_compute_stats_on_empty_rows;
         "test_build_report_pipeline" >:: test_build_report_pipeline;
         "test_build_report_empty_overlap" >:: test_build_report_empty_overlap;
         "test_build_report_top_n_orders_by_abs_drift"
         >:: test_build_report_top_n_orders_by_abs_drift;
         "test_format_markdown_report_has_expected_anchors"
         >:: test_format_markdown_report_has_expected_anchors;
         "test_format_markdown_report_empty_overlap"
         >:: test_format_markdown_report_empty_overlap;
         "test_parse_derived_csv_handles_empty_optionals"
         >:: test_parse_derived_csv_handles_empty_optionals;
         "test_parse_derived_csv_header_drift_is_error"
         >:: test_parse_derived_csv_header_drift_is_error;
         "test_parse_derived_csv_empty_body_is_error"
         >:: test_parse_derived_csv_empty_body_is_error;
       ]

let () = run_test_tt_main suite
