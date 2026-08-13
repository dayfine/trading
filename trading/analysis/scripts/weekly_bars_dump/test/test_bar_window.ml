open Core
open OUnit2
open Matchers
module Bar_window = Weekly_bars_dump_lib.Bar_window

let _bar ~date ~close : Types.Daily_price.t =
  Types.Daily_price.make ~date ~open_price:close ~high_price:(close +. 1.0)
    ~low_price:(close -. 1.0) ~close_price:close ~volume:1000
    ~adjusted_close:close ()

(* 10 weekly bars, one per week starting 2024-01-05 (a Friday), closes
   100.0 .. 109.0 in index order. *)
let _dates =
  List.init 10 ~f:(fun i -> Date.add_days (Date.of_string "2024-01-05") (i * 7))

let _weekly =
  List.mapi _dates ~f:(fun i d -> _bar ~date:d ~close:(100.0 +. Float.of_int i))

let _expected_matchers indices =
  List.map indices ~f:(fun i -> equal_to (List.nth_exn _weekly i))

let test_select_by_index_truncates _ =
  (* decision index 5, weeks_back 3 -> exactly indices 3,4,5. Pins both the
     window slicing AND (by only including 3..5, never 6..9) the lookahead
     invariant: no bar after the decision week is ever emitted. *)
  let result =
    Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_index 5)
      ~weeks_back:3
  in
  assert_that result
    (is_ok_and_holds (elements_are (_expected_matchers [ 3; 4; 5 ])))

let test_select_weeks_back_exceeds_history _ =
  (* decision index 2, weeks_back 100 (more than available) -> clamps to
     indices 0,1,2 -- still never reaching into 3..9. *)
  let result =
    Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_index 2)
      ~weeks_back:100
  in
  assert_that result
    (is_ok_and_holds (elements_are (_expected_matchers [ 0; 1; 2 ])))

let test_select_by_date _ =
  let d = List.nth_exn _dates 6 in
  let result =
    Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_date d)
      ~weeks_back:2
  in
  assert_that result
    (is_ok_and_holds (elements_are (_expected_matchers [ 5; 6 ])))

let test_select_by_date_not_found _ =
  let d = Date.of_string "1999-01-01" in
  assert_that
    (Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_date d)
       ~weeks_back:5)
    is_error

let test_select_by_index_out_of_range _ =
  assert_that
    (Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_index 99)
       ~weeks_back:5)
    is_error

let test_select_weeks_back_nonpositive _ =
  assert_that
    (Bar_window.select ~weekly:_weekly ~through:(Bar_window.By_index 0)
       ~weeks_back:0)
    is_error

let test_trailing_average_close_enough _ =
  let bars =
    List.map (List.range 0 5) ~f:(fun i ->
        _bar ~date:(List.nth_exn _dates i) ~close:(Float.of_int (i + 1)))
  in
  (* closes 1,2,3,4,5; trailing period-3 average = (3+4+5)/3 = 4.0 *)
  assert_that
    (Bar_window.trailing_average_close bars ~period:3)
    (is_some_and (float_equal 4.0))

let test_trailing_average_close_insufficient _ =
  let bars =
    List.map (List.range 0 2) ~f:(fun i ->
        _bar ~date:(List.nth_exn _dates i) ~close:(Float.of_int (i + 1)))
  in
  assert_that (Bar_window.trailing_average_close bars ~period:3) is_none

let suite =
  "Bar_window"
  >::: [
         "select_by_index_truncates" >:: test_select_by_index_truncates;
         "select_weeks_back_exceeds_history"
         >:: test_select_weeks_back_exceeds_history;
         "select_by_date" >:: test_select_by_date;
         "select_by_date_not_found" >:: test_select_by_date_not_found;
         "select_by_index_out_of_range" >:: test_select_by_index_out_of_range;
         "select_weeks_back_nonpositive" >:: test_select_weeks_back_nonpositive;
         "trailing_average_close_enough" >:: test_trailing_average_close_enough;
         "trailing_average_close_insufficient"
         >:: test_trailing_average_close_insufficient;
       ]

let () = run_test_tt_main suite
