open OUnit2
open Matchers
module A = Decision_grading.Aggregate
module G = Decision_grading.Grade

(* A graded_trade with sensible defaults; override only what a test cares about. *)
let trade ?(exit_reason = "stop_loss") ?(realized_pnl_pct = 0.0)
    ?(continuation_pct = 0.0) ?(exit_grade = G.Neutral)
    ?(entry_capture_ratio = None) () =
  {
    A.exit_reason;
    realized_pnl_pct;
    continuation_pct;
    exit_grade;
    entry_capture_ratio;
  }

(* Empty input -> empty output. *)
let test_empty _ = assert_that (A.aggregate_by_exit_reason []) (elements_are [])

(* Distinct reasons -> one group each, sorted ascending by reason. *)
let test_groups_sorted _ =
  let trades =
    [
      trade ~exit_reason:"stop_loss" ();
      trade ~exit_reason:"laggard_rotation" ();
      trade ~exit_reason:"end_of_period" ();
    ]
  in
  assert_that
    (A.aggregate_by_exit_reason trades)
    (elements_are
       [
         field (fun g -> g.A.exit_reason) (equal_to "end_of_period");
         field (fun g -> g.A.exit_reason) (equal_to "laggard_rotation");
         field (fun g -> g.A.exit_reason) (equal_to "stop_loss");
       ])

(* Means, grade fractions, and net value-add over a single group. Two trades,
   one Premature (+0.20 cont) one Good_exit (-0.40 cont): mean cont = -0.10,
   net value-add = +0.10, pct_premature = pct_good_exit = 0.5. *)
let test_group_stats _ =
  let trades =
    [
      trade ~exit_reason:"stop_loss" ~realized_pnl_pct:0.10
        ~continuation_pct:0.20 ~exit_grade:G.Premature
        ~entry_capture_ratio:(Some 0.6) ();
      trade ~exit_reason:"stop_loss" ~realized_pnl_pct:(-0.05)
        ~continuation_pct:(-0.40) ~exit_grade:G.Good_exit
        ~entry_capture_ratio:(Some 0.4) ();
    ]
  in
  assert_that
    (A.aggregate_by_exit_reason trades)
    (elements_are
       [
         all_of
           [
             field (fun g -> g.A.n) (equal_to 2);
             field (fun g -> g.A.mean_realized_pnl_pct) (float_equal 0.025);
             field (fun g -> g.A.mean_continuation_pct) (float_equal (-0.10));
             field (fun g -> g.A.mean_net_value_add_pct) (float_equal 0.10);
             field (fun g -> g.A.pct_premature) (float_equal 0.5);
             field (fun g -> g.A.pct_good_exit) (float_equal 0.5);
             field
               (fun g -> g.A.mean_entry_capture_ratio)
               (is_some_and (float_equal 0.5));
           ];
       ])

(* A group where no trade has a defined capture ratio -> None. *)
let test_capture_ratio_all_none _ =
  let trades =
    [ trade ~entry_capture_ratio:None (); trade ~entry_capture_ratio:None () ]
  in
  assert_that
    (A.aggregate_by_exit_reason trades)
    (elements_are [ field (fun g -> g.A.mean_entry_capture_ratio) is_none ])

(* Capture-ratio mean skips the None trades, averaging only the Some ones. *)
let test_capture_ratio_mixed _ =
  let trades =
    [
      trade ~entry_capture_ratio:(Some 0.8) ();
      trade ~entry_capture_ratio:None ();
      trade ~entry_capture_ratio:(Some 0.2) ();
    ]
  in
  assert_that
    (A.aggregate_by_exit_reason trades)
    (elements_are
       [
         field
           (fun g -> g.A.mean_entry_capture_ratio)
           (is_some_and (float_equal 0.5));
       ])

(* markdown: header + one row per group, in the order given. *)
let test_to_markdown _ =
  let groups =
    A.aggregate_by_exit_reason [ trade ~exit_reason:"stop_loss" () ]
  in
  let md = A.to_markdown groups in
  assert_that md
    (all_of
       [
         contains_substring "| exit_reason | n |";
         contains_substring "| stop_loss | 1 |";
       ])

let suite =
  "aggregate"
  >::: [
         "empty" >:: test_empty;
         "groups_sorted" >:: test_groups_sorted;
         "group_stats" >:: test_group_stats;
         "capture_ratio_all_none" >:: test_capture_ratio_all_none;
         "capture_ratio_mixed" >:: test_capture_ratio_mixed;
         "to_markdown" >:: test_to_markdown;
       ]

let () = run_test_tt_main suite
