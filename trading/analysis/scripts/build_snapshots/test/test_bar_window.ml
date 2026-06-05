open Core
open OUnit2
open Matchers

(* Minimal [Daily_price.t] builder: only [date] is load-bearing for the window
   filter; the OHLCV fields are fixed placeholders. *)
let bar date_str : Types.Daily_price.t =
  {
    date = Date.of_string date_str;
    open_price = 100.0;
    high_price = 101.0;
    low_price = 99.0;
    close_price = 100.5;
    volume = 1_000;
    adjusted_close = 100.5;
    active_through = None;
  }

(* Five consecutive trading days spanning a clear before / window / after split
   so each bound's behaviour is observable. *)
let bars =
  [
    bar "2020-01-02";
    bar "2020-01-03";
    bar "2020-01-06";
    bar "2020-01-07";
    bar "2020-01-08";
  ]

let dates bars = List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.date)

let test_inclusive_window _ =
  (* [start, end] keeps only the three in-range bars; both endpoints inclusive. *)
  let result =
    Bar_window.filter
      ~start:(Date.of_string "2020-01-03")
      ~end_:(Date.of_string "2020-01-07")
      bars
  in
  assert_that (dates result)
    (elements_are
       [
         equal_to (Date.of_string "2020-01-03");
         equal_to (Date.of_string "2020-01-06");
         equal_to (Date.of_string "2020-01-07");
       ])

let test_start_only _ =
  (* start-only filters [date >= start]: drops the first bar, keeps the rest. *)
  let result = Bar_window.filter ~start:(Date.of_string "2020-01-06") bars in
  assert_that (dates result)
    (elements_are
       [
         equal_to (Date.of_string "2020-01-06");
         equal_to (Date.of_string "2020-01-07");
         equal_to (Date.of_string "2020-01-08");
       ])

let test_end_only _ =
  (* end-only filters [date <= end]: keeps the first two, drops the rest. *)
  let result = Bar_window.filter ~end_:(Date.of_string "2020-01-03") bars in
  assert_that (dates result)
    (elements_are
       [
         equal_to (Date.of_string "2020-01-02");
         equal_to (Date.of_string "2020-01-03");
       ])

let test_no_bounds_unchanged _ =
  (* Neither bound → bars returned unchanged (same elements, same order). *)
  assert_that (Bar_window.filter bars)
    (elements_are (List.map bars ~f:(fun b -> equal_to b)))

let suite =
  "bar_window"
  >::: [
         "inclusive_window" >:: test_inclusive_window;
         "start_only" >:: test_start_only;
         "end_only" >:: test_end_only;
         "no_bounds_unchanged" >:: test_no_bounds_unchanged;
       ]

let () = run_test_tt_main suite
