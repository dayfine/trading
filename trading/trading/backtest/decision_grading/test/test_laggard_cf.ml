open Core
open OUnit2
open Matchers
module L = Decision_grading.Laggard_cf

let date = Date.of_string

(* build_events pairs each laggard exit with entries strictly after the exit
   date and within the window. Exit on 2020-01-03, window 10d: an entry on
   2020-01-08 (gap 5) is in; 2020-01-03 (gap 0, the exit day) is out;
   2020-01-20 (gap 17) is out. *)
let test_build_events_window _ =
  let events =
    L.build_events ~alloc_window_days:10
      ~laggard_exits:[ ("X", date "2020-01-03", 0.30) ]
      ~entries:
        [
          (date "2020-01-03", 0.99);
          (* same day -> excluded *)
          (date "2020-01-08", 0.10);
          (* in window *)
          (date "2020-01-20", 0.88);
          (* past window -> excluded *)
        ]
  in
  assert_that events
    (elements_are
       [
         all_of
           [
             field (fun e -> e.L.dumped_symbol) (equal_to "X");
             field
               (fun e -> e.L.funded_forward_pcts)
               (elements_are [ float_equal 0.10 ]);
           ];
       ])

(* An event with no entries in the window -> empty funded cohort. *)
let test_build_events_no_redeploy _ =
  let events =
    L.build_events ~alloc_window_days:5
      ~laggard_exits:[ ("Y", date "2020-06-01", 0.05) ]
      ~entries:[ (date "2020-07-01", 0.20) ]
  in
  assert_that events
    (elements_are
       [ field (fun e -> e.L.funded_forward_pcts) (elements_are []) ])

(* summarize: one event, funded cohort {+0.10,+0.20} mean +0.15 vs dumped +0.30
   -> paired diff -0.15 (rotation did NOT pay), pct_paid 0. *)
let test_summarize_did_not_pay _ =
  let events =
    [
      {
        L.dumped_symbol = "X";
        dumped_date = date "2020-01-03";
        dumped_forward_pct = 0.30;
        funded_forward_pcts = [ 0.10; 0.20 ];
      };
    ]
  in
  assert_that (L.summarize events)
    (all_of
       [
         field (fun s -> s.L.n_events) (equal_to 1);
         field (fun s -> s.L.n_with_redeploy) (equal_to 1);
         field (fun s -> s.L.mean_dumped_forward_pct) (float_equal 0.30);
         field (fun s -> s.L.mean_funded_forward_pct) (float_equal 0.15);
         field (fun s -> s.L.mean_paired_diff_pct) (float_equal (-0.15));
         field (fun s -> s.L.pct_rotation_paid) (float_equal 0.0);
       ])

(* Two events, one paid (+) one not (−): pct_rotation_paid 0.5. Event A funded
   +0.40 vs dumped +0.10 -> +0.30 paid; event B funded +0.05 vs dumped +0.25 ->
   -0.20 not paid. mean diff +0.05. *)
let test_summarize_mixed _ =
  let events =
    [
      {
        L.dumped_symbol = "A";
        dumped_date = date "2020-01-03";
        dumped_forward_pct = 0.10;
        funded_forward_pcts = [ 0.40 ];
      };
      {
        L.dumped_symbol = "B";
        dumped_date = date "2020-02-07";
        dumped_forward_pct = 0.25;
        funded_forward_pcts = [ 0.05 ];
      };
    ]
  in
  assert_that (L.summarize events)
    (all_of
       [
         field (fun s -> s.L.pct_rotation_paid) (float_equal 0.5);
         field (fun s -> s.L.mean_paired_diff_pct) (float_equal 0.05);
       ])

(* Events with empty funded cohort are counted in n_events but excluded from the
   stats (n_with_redeploy and the means see only the real one). *)
let test_summarize_skips_no_redeploy _ =
  let events =
    [
      {
        L.dumped_symbol = "A";
        dumped_date = date "2020-01-03";
        dumped_forward_pct = 0.10;
        funded_forward_pcts = [ 0.40 ];
      };
      {
        L.dumped_symbol = "Z";
        dumped_date = date "2020-03-06";
        dumped_forward_pct = 0.50;
        funded_forward_pcts = [];
      };
    ]
  in
  assert_that (L.summarize events)
    (all_of
       [
         field (fun s -> s.L.n_events) (equal_to 2);
         field (fun s -> s.L.n_with_redeploy) (equal_to 1);
         field (fun s -> s.L.mean_dumped_forward_pct) (float_equal 0.10);
         field (fun s -> s.L.mean_paired_diff_pct) (float_equal 0.30);
       ])

(* Empty input -> all-zero summary. *)
let test_summarize_empty _ =
  assert_that (L.summarize [])
    (all_of
       [
         field (fun s -> s.L.n_events) (equal_to 0);
         field (fun s -> s.L.n_with_redeploy) (equal_to 0);
         field (fun s -> s.L.mean_paired_diff_pct) (float_equal 0.0);
         field (fun s -> s.L.pct_rotation_paid) (float_equal 0.0);
       ])

let test_to_markdown _ =
  let s = L.summarize [] in
  assert_that
    (L.to_markdown ~horizon_weeks:13 s)
    (contains_substring "Did laggard-rotation pay?")

let suite =
  "laggard_cf"
  >::: [
         "build_events_window" >:: test_build_events_window;
         "build_events_no_redeploy" >:: test_build_events_no_redeploy;
         "summarize_did_not_pay" >:: test_summarize_did_not_pay;
         "summarize_mixed" >:: test_summarize_mixed;
         "summarize_skips_no_redeploy" >:: test_summarize_skips_no_redeploy;
         "summarize_empty" >:: test_summarize_empty;
         "to_markdown" >:: test_to_markdown;
       ]

let () = run_test_tt_main suite
