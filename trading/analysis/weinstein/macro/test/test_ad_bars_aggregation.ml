open OUnit2
open Core
open Matchers

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let d y m day : Date.t = Date.create_exn ~y ~m ~d:day

let bar date ~advancing ~declining : Macro.ad_bar =
  { Macro.date; advancing; declining }

(* ------------------------------------------------------------------ *)
(* Empty and single-week inputs                                         *)
(* ------------------------------------------------------------------ *)

let test_empty_returns_empty _ =
  assert_that (Ad_bars_aggregation.daily_to_weekly []) (size_is 0)

let test_single_bar_single_week _ =
  let input = [ bar (d 2024 Month.Mar 13) ~advancing:1500 ~declining:900 ] in
  assert_that
    (Ad_bars_aggregation.daily_to_weekly input)
    (elements_are
       [
         equal_to
           ({ date = d 2024 Month.Mar 13; advancing = 1500; declining = 900 }
             : Macro.ad_bar);
       ])

(* ------------------------------------------------------------------ *)
(* Full 5-day week aggregates advancing and declining by sum           *)
(* ------------------------------------------------------------------ *)

let test_five_day_week_sums _ =
  (* Mon-Fri of the same ISO week, ascending. *)
  let input =
    [
      bar (d 2024 Month.Mar 11) ~advancing:1000 ~declining:500;
      bar (d 2024 Month.Mar 12) ~advancing:1100 ~declining:600;
      bar (d 2024 Month.Mar 13) ~advancing:1200 ~declining:700;
      bar (d 2024 Month.Mar 14) ~advancing:1300 ~declining:800;
      bar (d 2024 Month.Mar 15) ~advancing:1400 ~declining:900;
    ]
  in
  assert_that
    (Ad_bars_aggregation.daily_to_weekly input)
    (elements_are
       [
         equal_to
           ({
              date = d 2024 Month.Mar 15;
              advancing = 1000 + 1100 + 1200 + 1300 + 1400;
              declining = 500 + 600 + 700 + 800 + 900;
            }
             : Macro.ad_bar);
       ])

(* ------------------------------------------------------------------ *)
(* Multiple weeks produce one bar per week, preserving order           *)
(* ------------------------------------------------------------------ *)

let test_multi_week_preserves_order _ =
  (* Two full Mon-Fri weeks back-to-back. *)
  let input =
    [
      bar (d 2024 Month.Mar 11) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 12) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 13) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 14) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 15) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 18) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 19) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 20) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 21) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 22) ~advancing:200 ~declining:75;
    ]
  in
  assert_that
    (Ad_bars_aggregation.daily_to_weekly input)
    (elements_are
       [
         equal_to
           ({ date = d 2024 Month.Mar 15; advancing = 500; declining = 250 }
             : Macro.ad_bar);
         equal_to
           ({ date = d 2024 Month.Mar 22; advancing = 1000; declining = 375 }
             : Macro.ad_bar);
       ])

(* ------------------------------------------------------------------ *)
(* Partial week at the tail still produces a provisional weekly bar    *)
(* ------------------------------------------------------------------ *)

let test_partial_tail_week_included _ =
  (* A full Mon-Fri week followed by Mon-Wed of the next week. The tail
     partial week should still be emitted, dated on the last observation. *)
  let input =
    [
      bar (d 2024 Month.Mar 11) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 12) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 13) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 14) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 15) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 18) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 19) ~advancing:200 ~declining:75;
      bar (d 2024 Month.Mar 20) ~advancing:200 ~declining:75;
    ]
  in
  assert_that
    (Ad_bars_aggregation.daily_to_weekly input)
    (elements_are
       [
         equal_to
           ({ date = d 2024 Month.Mar 15; advancing = 500; declining = 250 }
             : Macro.ad_bar);
         equal_to
           ({ date = d 2024 Month.Mar 20; advancing = 600; declining = 225 }
             : Macro.ad_bar);
       ])

(* ------------------------------------------------------------------ *)
(* Partial week at the head (starts mid-week) is honoured              *)
(* ------------------------------------------------------------------ *)

let test_partial_head_week _ =
  (* Starts on Wed of one week, runs through the following Mon-Fri. *)
  let input =
    [
      bar (d 2024 Month.Mar 13) ~advancing:300 ~declining:100;
      bar (d 2024 Month.Mar 14) ~advancing:300 ~declining:100;
      bar (d 2024 Month.Mar 15) ~advancing:300 ~declining:100;
      bar (d 2024 Month.Mar 18) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 19) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 20) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 21) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 22) ~advancing:100 ~declining:50;
    ]
  in
  assert_that
    (Ad_bars_aggregation.daily_to_weekly input)
    (elements_are
       [
         equal_to
           ({ date = d 2024 Month.Mar 15; advancing = 900; declining = 300 }
             : Macro.ad_bar);
         equal_to
           ({ date = d 2024 Month.Mar 22; advancing = 500; declining = 250 }
             : Macro.ad_bar);
       ])

(* ------------------------------------------------------------------ *)
(* Output length equals the number of distinct ISO weeks               *)
(* ------------------------------------------------------------------ *)

let test_week_count_matches_distinct_weeks _ =
  (* 4 weeks of daily data, 5 bars each. *)
  let make_week ~start ~offset =
    List.init 5 ~f:(fun i ->
        bar (Date.add_days start i) ~advancing:(100 + offset)
          ~declining:(50 + offset))
  in
  let input =
    List.concat
      [
        make_week ~start:(d 2024 Month.Jan 1) ~offset:0;
        make_week ~start:(d 2024 Month.Jan 8) ~offset:10;
        make_week ~start:(d 2024 Month.Jan 15) ~offset:20;
        make_week ~start:(d 2024 Month.Jan 22) ~offset:30;
      ]
  in
  assert_that (Ad_bars_aggregation.daily_to_weekly input) (size_is 4)

(* ------------------------------------------------------------------ *)
(* Ordering validation: unsorted input raises                          *)
(* ------------------------------------------------------------------ *)

(* Shared message raised by [Time_period.Week_bucketing.bucket_weekly], to which
   [Ad_bars_aggregation.daily_to_weekly] now delegates. *)
let _invalid_ordering_msg =
  "Data must be sorted chronologically by date with no duplicates"

let test_unsorted_input_raises _ =
  let input =
    [
      bar (d 2024 Month.Mar 13) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 12) ~advancing:100 ~declining:50;
    ]
  in
  assert_raises (Invalid_argument _invalid_ordering_msg) (fun () ->
      Ad_bars_aggregation.daily_to_weekly input)

let test_duplicate_date_raises _ =
  let input =
    [
      bar (d 2024 Month.Mar 13) ~advancing:100 ~declining:50;
      bar (d 2024 Month.Mar 13) ~advancing:100 ~declining:50;
    ]
  in
  assert_raises (Invalid_argument _invalid_ordering_msg) (fun () ->
      Ad_bars_aggregation.daily_to_weekly input)

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "ad_bars_aggregation"
  >::: [
         "test_empty_returns_empty" >:: test_empty_returns_empty;
         "test_single_bar_single_week" >:: test_single_bar_single_week;
         "test_five_day_week_sums" >:: test_five_day_week_sums;
         "test_multi_week_preserves_order" >:: test_multi_week_preserves_order;
         "test_partial_tail_week_included" >:: test_partial_tail_week_included;
         "test_partial_head_week" >:: test_partial_head_week;
         "test_week_count_matches_distinct_weeks"
         >:: test_week_count_matches_distinct_weeks;
         "test_unsorted_input_raises" >:: test_unsorted_input_raises;
         "test_duplicate_date_raises" >:: test_duplicate_date_raises;
       ]

let () = run_test_tt_main suite
