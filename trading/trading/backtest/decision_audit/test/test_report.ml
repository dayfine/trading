(** Unit tests for [Decision_audit.Report].

    Covers the funded-vs-near-miss feature statistics (means + counts, [None]s
    dropped) and the markdown roll-up header content, on synthetic
    [Screen_record.t] lists built directly (bypassing the audit projection). *)

open OUnit2
open Core
open Matchers
module TA = Backtest.Trade_audit
module SR = Decision_audit.Screen_record
module Report = Decision_audit.Report
module CF = Decision_audit.Counterfactual

let _date d = Date.of_string d

let _forward ?(symbol = "AAPL") ?(is_funded = true) ?(reason_skipped = None)
    ~return () : CF.candidate_forward =
  {
    symbol;
    side = Trading_base.Types.Long;
    is_funded;
    screen_date = _date "2024-03-01";
    reason_skipped;
    forward_return_pct = return;
    score = 75;
    rs_value = Some 1.0;
    volume_ratio = Some 2.0;
    weeks_advancing = Some 2;
  }

let _funded ~symbol ~score ?(rs_value = Some 1.0) ?(volume_ratio = Some 2.0)
    ?(weeks_advancing = Some 2) () : SR.funded_entry =
  {
    symbol;
    score;
    grade = Weinstein_types.A;
    stage = Weinstein_types.Stage2 { weeks_advancing = 2; late = false };
    weeks_advancing;
    rs_value;
    volume_ratio;
    sector_name = "Tech";
  }

let _near ~symbol ~score ?(rs_value = Some 0.9) ?(volume_ratio = Some 1.2)
    ?(weeks_advancing = Some 5) () : SR.near_miss =
  {
    symbol;
    side = Trading_base.Types.Long;
    score;
    grade = Weinstein_types.B;
    reason_skipped = TA.Insufficient_cash;
    stage = Weinstein_types.Stage2 { weeks_advancing = 5; late = false };
    weeks_advancing;
    rs_value;
    volume_ratio;
    sector_name = "Tech";
  }

let _screen ~funded ~near_misses : SR.t =
  {
    screen_date = _date "2024-03-01";
    funded;
    near_misses;
    summary =
      {
        n_funded = List.length funded;
        n_near_miss = List.length near_misses;
        min_funded_score = None;
        max_nearmiss_score = None;
        inversion = false;
      };
  }

let _find_stat stats name =
  List.find_exn stats ~f:(fun (s : Report.feature_stat) ->
      String.equal s.feature name)

let test_feature_stats_means_and_counts _ =
  let screens =
    [
      _screen
        ~funded:
          [
            _funded ~symbol:"A" ~score:80 ~rs_value:(Some 1.0) ();
            _funded ~symbol:"B" ~score:70 ~rs_value:(Some 1.2) ();
          ]
        ~near_misses:[ _near ~symbol:"C" ~score:60 ~rs_value:(Some 0.8) () ];
    ]
  in
  let stats = Report.feature_stats screens in
  assert_that (_find_stat stats "score")
    (all_of
       [
         field (fun (s : Report.feature_stat) -> s.funded_n) (equal_to 2);
         field
           (fun (s : Report.feature_stat) -> s.funded_mean)
           (is_some_and (float_equal 75.0));
         field (fun (s : Report.feature_stat) -> s.near_miss_n) (equal_to 1);
         field
           (fun (s : Report.feature_stat) -> s.near_miss_mean)
           (is_some_and (float_equal 60.0));
       ])

let test_feature_stats_drops_none_values _ =
  (* One funded rs_value is None → funded_n counts only the present one. *)
  let screens =
    [
      _screen
        ~funded:
          [
            _funded ~symbol:"A" ~score:80 ~rs_value:(Some 1.4) ();
            _funded ~symbol:"B" ~score:70 ~rs_value:None ();
          ]
        ~near_misses:[];
    ]
  in
  let stats = Report.feature_stats screens in
  assert_that
    (_find_stat stats "rs_value")
    (all_of
       [
         field (fun (s : Report.feature_stat) -> s.funded_n) (equal_to 1);
         field
           (fun (s : Report.feature_stat) -> s.funded_mean)
           (is_some_and (float_equal 1.4));
         field (fun (s : Report.feature_stat) -> s.near_miss_n) (equal_to 0);
         field (fun (s : Report.feature_stat) -> s.near_miss_mean) is_none;
       ])

let test_markdown_header_reports_totals _ =
  let screens =
    [
      _screen
        ~funded:[ _funded ~symbol:"A" ~score:80 () ]
        ~near_misses:
          [ _near ~symbol:"C" ~score:60 (); _near ~symbol:"D" ~score:55 () ];
    ]
  in
  let md = Report.to_markdown screens in
  assert_that md (contains_substring "Screens: 1 | funded: 1 | near-misses: 2")

let test_markdown_empty_input _ =
  assert_that (Report.to_markdown [])
    (contains_substring "No entry decisions in audit")

(* Phase-2 counterfactual rendering ------------------------------------- *)

let test_forward_stat_mean_median_and_drops_none _ =
  (* Returns 0.10, 0.20, 0.30 present + one None: n=3, mean=0.20, median=0.20. *)
  let cs =
    [
      _forward ~symbol:"A" ~return:(Some 0.10) ();
      _forward ~symbol:"B" ~return:(Some 0.20) ();
      _forward ~symbol:"C" ~return:(Some 0.30) ();
      _forward ~symbol:"D" ~return:None ();
    ]
  in
  assert_that (Report.forward_stat cs)
    (all_of
       [
         field (fun (s : Report.forward_stat) -> s.n) (equal_to 3);
         field
           (fun (s : Report.forward_stat) -> s.mean)
           (is_some_and (float_equal 0.20));
         field
           (fun (s : Report.forward_stat) -> s.median)
           (is_some_and (float_equal 0.20));
       ])

let test_forward_stat_even_length_median _ =
  (* Even length {0.0, 0.10} → median = mean of the two = 0.05. *)
  let cs =
    [
      _forward ~symbol:"A" ~return:(Some 0.0) ();
      _forward ~symbol:"B" ~return:(Some 0.10) ();
    ]
  in
  assert_that (Report.forward_stat cs)
    (field
       (fun (s : Report.forward_stat) -> s.median)
       (is_some_and (float_equal 0.05)))

let test_counterfactual_markdown_rows _ =
  (* One funded (0.10) + two near-miss Insufficient_cash (0.20, 0.40): the
     funded row shows mean/median 0.10 n=1; the all-near-miss row 0.30/0.30 n=2;
     a broken-out near-miss row keyed by the skip reason. *)
  let cs =
    [
      _forward ~symbol:"F" ~is_funded:true ~return:(Some 0.10) ();
      _forward ~symbol:"N1" ~is_funded:false
        ~reason_skipped:(Some TA.Insufficient_cash) ~return:(Some 0.20) ();
      _forward ~symbol:"N2" ~is_funded:false
        ~reason_skipped:(Some TA.Insufficient_cash) ~return:(Some 0.40) ();
    ]
  in
  let md = Report.counterfactual_to_markdown cs in
  assert_that md
    (all_of
       [
         contains_substring "| funded | 0.10 | 0.10 | 1 |";
         contains_substring "| near-miss (all) | 0.30 | 0.30 | 2 |";
         contains_substring "near-miss / Insufficient_cash";
       ])

let test_counterfactual_markdown_empty _ =
  assert_that
    (Report.counterfactual_to_markdown [])
    (contains_substring "No candidates in audit")

let suite =
  "Decision_audit.Report"
  >::: [
         "feature_stats means + counts" >:: test_feature_stats_means_and_counts;
         "feature_stats drops None values"
         >:: test_feature_stats_drops_none_values;
         "markdown header reports totals"
         >:: test_markdown_header_reports_totals;
         "markdown empty input" >:: test_markdown_empty_input;
         "forward_stat mean/median + drops None"
         >:: test_forward_stat_mean_median_and_drops_none;
         "forward_stat even-length median"
         >:: test_forward_stat_even_length_median;
         "counterfactual markdown rows" >:: test_counterfactual_markdown_rows;
         "counterfactual markdown empty" >:: test_counterfactual_markdown_empty;
       ]

let () = run_test_tt_main suite
