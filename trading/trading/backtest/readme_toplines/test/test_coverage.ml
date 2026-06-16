open Core
open OUnit2
open Matchers
module Coverage = Readme_toplines.Coverage

let d = Date.of_string

let make_cov ~symbol ~first ~last : Coverage.coverage =
  { symbol; first_bar = d first; last_bar = d last }

(* The pinned period is [latest first_bar, earliest last_bar]: SPY starts
   earliest but the sector ETFs start latest, so 1998-12-22 binds the start;
   they all share the same last bar, so it binds the end. *)
let test_intersection_staggered_starts _ =
  let coverages =
    [
      make_cov ~symbol:"SPY" ~first:"1993-01-29" ~last:"2026-06-12";
      make_cov ~symbol:"BRK-B" ~first:"1996-05-09" ~last:"2026-06-12";
      make_cov ~symbol:"XLK" ~first:"1998-12-22" ~last:"2026-06-12";
    ]
  in
  assert_that
    (Coverage.period_intersection coverages)
    (is_some_and
       (equal_to ((d "1998-12-22", d "2026-06-12") : Date.t * Date.t)))

(* Earliest last_bar binds the end when symbols end on different days. *)
let test_intersection_staggered_ends _ =
  let coverages =
    [
      make_cov ~symbol:"A" ~first:"2000-01-01" ~last:"2026-06-12";
      make_cov ~symbol:"B" ~first:"1999-01-01" ~last:"2025-01-31";
    ]
  in
  assert_that
    (Coverage.period_intersection coverages)
    (is_some_and
       (equal_to ((d "2000-01-01", d "2025-01-31") : Date.t * Date.t)))

let test_intersection_empty_list _ =
  assert_that (Coverage.period_intersection []) is_none

(* No common day: the latest start is after the earliest end. *)
let test_intersection_disjoint _ =
  let coverages =
    [
      make_cov ~symbol:"A" ~first:"2020-01-01" ~last:"2026-01-01";
      make_cov ~symbol:"B" ~first:"1998-01-01" ~last:"2010-01-01";
    ]
  in
  assert_that (Coverage.period_intersection coverages) is_none

let test_total_return_positive _ =
  assert_that
    (Coverage.total_return_pct ~initial:100.0 ~final:250.0)
    (float_equal 150.0)

let test_total_return_negative _ =
  assert_that
    (Coverage.total_return_pct ~initial:100.0 ~final:80.0)
    (float_equal (-20.0))

let test_total_return_nonpositive_base _ =
  assert_that
    (Float.is_nan (Coverage.total_return_pct ~initial:0.0 ~final:100.0))
    (equal_to true)

let test_bah_uses_first_and_last_in_window _ =
  let close_series =
    [
      (d "1998-01-01", 10.0);
      (* before window: ignored *)
      (d "1999-01-04", 20.0);
      (* entry: first >= start *)
      (d "2000-06-01", 35.0);
      (d "2001-12-31", 40.0);
      (* exit: last <= end *)
      (d "2002-06-01", 99.0);
      (* after window: ignored *)
    ]
  in
  (* (40 - 20) / 20 * 100 = 100% *)
  assert_that
    (Coverage.bah_total_return_pct ~start_date:(d "1999-01-01")
       ~end_date:(d "2002-01-01") ~close_series)
    (float_equal 100.0)

(* Empty window: every bar is outside [start_date, end_date], so neither entry
   nor exit can be selected -> nan. *)
let test_bah_empty_window _ =
  assert_that
    (Float.is_nan
       (Coverage.bah_total_return_pct ~start_date:(d "2030-01-01")
          ~end_date:(d "2031-01-01")
          ~close_series:[ (d "1999-01-04", 20.0) ]))
    (equal_to true)

(* Single bar inside the window: entry and exit coincide (entry_date =
   exit_date), so the holding span is zero and the window is unpriceable -> nan,
   not a misleading 0.0. *)
let test_bah_single_bar_window _ =
  assert_that
    (Float.is_nan
       (Coverage.bah_total_return_pct ~start_date:(d "1999-01-01")
          ~end_date:(d "1999-12-31")
          ~close_series:[ (d "1999-06-15", 20.0) ]))
    (equal_to true)

let test_inclusive_days _ =
  assert_that
    (Coverage.inclusive_days ~start_date:(d "2020-01-01")
       ~end_date:(d "2020-01-01"))
    (equal_to 1)

let test_inclusive_days_span _ =
  assert_that
    (Coverage.inclusive_days ~start_date:(d "2020-01-01")
       ~end_date:(d "2020-01-31"))
    (equal_to 31)

(* end_date strictly before start_date -> 0 (degenerate, non-negative span). *)
let test_inclusive_days_end_before_start _ =
  assert_that
    (Coverage.inclusive_days ~start_date:(d "2020-01-31")
       ~end_date:(d "2020-01-01"))
    (equal_to 0)

let suite =
  "coverage"
  >::: [
         "intersection_staggered_starts" >:: test_intersection_staggered_starts;
         "intersection_staggered_ends" >:: test_intersection_staggered_ends;
         "intersection_empty_list" >:: test_intersection_empty_list;
         "intersection_disjoint" >:: test_intersection_disjoint;
         "total_return_positive" >:: test_total_return_positive;
         "total_return_negative" >:: test_total_return_negative;
         "total_return_nonpositive_base" >:: test_total_return_nonpositive_base;
         "bah_uses_first_and_last_in_window"
         >:: test_bah_uses_first_and_last_in_window;
         "bah_empty_window" >:: test_bah_empty_window;
         "bah_single_bar_window" >:: test_bah_single_bar_window;
         "inclusive_days" >:: test_inclusive_days;
         "inclusive_days_span" >:: test_inclusive_days_span;
         "inclusive_days_end_before_start"
         >:: test_inclusive_days_end_before_start;
       ]

let () = run_test_tt_main suite
