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

let _date d = Date.of_string d

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

let suite =
  "Decision_audit.Report"
  >::: [
         "feature_stats means + counts" >:: test_feature_stats_means_and_counts;
         "feature_stats drops None values"
         >:: test_feature_stats_drops_none_values;
         "markdown header reports totals"
         >:: test_markdown_header_reports_totals;
         "markdown empty input" >:: test_markdown_empty_input;
       ]

let () = run_test_tt_main suite
