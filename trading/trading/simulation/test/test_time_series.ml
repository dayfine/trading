open OUnit2
open Core
open Trading_simulation.Time_series

let default_volume = 1000

let make_test_price ~date ~price =
  Types.Daily_price.
    {
      date;
      open_price = price;
      high_price = price;
      low_price = price;
      close_price = price;
      volume = default_volume;
      adjusted_close = price;
    }

(* Cadence type tests *)
let test_cadence_equality _ =
  assert_equal ~printer:show_cadence Daily Daily;
  assert_equal ~printer:show_cadence Weekly Weekly;
  assert_equal ~printer:show_cadence Monthly Monthly;
  assert_bool "Daily <> Weekly" (not (equal_cadence Daily Weekly))

(* is_period_end tests *)
let test_is_period_end_daily _ =
  let monday = Date.create_exn ~y:2024 ~m:Month.Mar ~d:11 in
  let friday = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15 in
  assert_bool "Daily: Monday is period end" (is_period_end ~cadence:Daily monday);
  assert_bool "Daily: Friday is period end" (is_period_end ~cadence:Daily friday)

let test_is_period_end_weekly _ =
  let monday = Date.create_exn ~y:2024 ~m:Month.Mar ~d:11 in
  let wednesday = Date.create_exn ~y:2024 ~m:Month.Mar ~d:13 in
  let friday = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15 in
  assert_bool "Weekly: Monday not period end"
    (not (is_period_end ~cadence:Weekly monday));
  assert_bool "Weekly: Wednesday not period end"
    (not (is_period_end ~cadence:Weekly wednesday));
  assert_bool "Weekly: Friday is period end" (is_period_end ~cadence:Weekly friday)

let test_is_period_end_monthly _ =
  let mid_month = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15 in
  let last_day = Date.create_exn ~y:2024 ~m:Month.Mar ~d:31 in
  let feb_last = Date.create_exn ~y:2024 ~m:Month.Feb ~d:29 in
  (* 2024 is leap year *)
  assert_bool "Monthly: Mid-month not period end"
    (not (is_period_end ~cadence:Monthly mid_month));
  assert_bool "Monthly: Last day of March is period end"
    (is_period_end ~cadence:Monthly last_day);
  assert_bool "Monthly: Feb 29 (leap year) is period end"
    (is_period_end ~cadence:Monthly feb_last)

(* convert_cadence tests *)
let test_convert_cadence_daily _ =
  let prices =
    [
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11) ~price:1.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12) ~price:2.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13) ~price:3.0;
    ]
  in
  let result = convert_cadence prices ~cadence:Daily ~as_of_date:None in
  assert_equal ~printer:Int.to_string 3 (List.length result);
  assert_equal ~printer:Types.Daily_price.show (List.hd_exn prices)
    (List.hd_exn result)

let test_convert_cadence_weekly_complete _ =
  let prices =
    [
      (* Complete week Mon-Fri *)
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11) ~price:1.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12) ~price:2.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15) ~price:5.0;
      (* Friday *)
    ]
  in
  let result = convert_cadence prices ~cadence:Weekly ~as_of_date:None in
  assert_equal ~printer:Int.to_string 1 (List.length result);
  assert_equal ~printer:Date.to_string (Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
    (List.hd_exn result).date;
  assert_equal ~printer:Float.to_string 5.0 (List.hd_exn result).close_price

let test_convert_cadence_weekly_incomplete_excluded _ =
  let prices =
    [
      (* Incomplete week Mon-Wed *)
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11) ~price:1.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13) ~price:3.0;
      (* Wednesday *)
    ]
  in
  (* as_of_date=None means exclude incomplete weeks *)
  let result = convert_cadence prices ~cadence:Weekly ~as_of_date:None in
  assert_equal ~printer:Int.to_string 0 (List.length result)

let test_convert_cadence_weekly_incomplete_provisional _ =
  let prices =
    [
      (* Incomplete week Mon-Wed *)
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11) ~price:1.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13) ~price:3.0;
      (* Wednesday *)
    ]
  in
  (* as_of_date=Some means include provisional *)
  let result =
    convert_cadence prices ~cadence:Weekly
      ~as_of_date:(Some (Date.create_exn ~y:2024 ~m:Month.Mar ~d:13))
  in
  assert_equal ~printer:Int.to_string 1 (List.length result);
  assert_equal ~printer:Date.to_string (Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
    (List.hd_exn result).date;
  assert_equal ~printer:Float.to_string 3.0 (List.hd_exn result).close_price

let test_convert_cadence_weekly_mixed _ =
  let prices =
    [
      (* Week 1: Complete *)
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11) ~price:1.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15) ~price:5.0;
      (* Friday *)
      (* Week 2: Incomplete *)
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:18) ~price:6.0;
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:20) ~price:8.0;
      (* Wednesday *)
    ]
  in
  (* Exclude incomplete: only week 1 *)
  let finalized = convert_cadence prices ~cadence:Weekly ~as_of_date:None in
  assert_equal ~printer:Int.to_string 1 (List.length finalized);
  assert_equal ~printer:Float.to_string 5.0 (List.hd_exn finalized).close_price;
  (* Include provisional: both weeks *)
  let provisional =
    convert_cadence prices ~cadence:Weekly
      ~as_of_date:(Some (Date.create_exn ~y:2024 ~m:Month.Mar ~d:20))
  in
  assert_equal ~printer:Int.to_string 2 (List.length provisional);
  assert_equal ~printer:Float.to_string 8.0
    (List.nth_exn provisional 1).close_price

let test_convert_cadence_monthly_todo _ =
  (* Monthly conversion not yet implemented *)
  let prices =
    [
      make_test_price ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:1) ~price:1.0;
    ]
  in
  let result = convert_cadence prices ~cadence:Monthly ~as_of_date:None in
  (* Currently returns empty - this is a TODO *)
  assert_equal ~printer:Int.to_string 0 (List.length result)

let suite =
  "Time series tests"
  >::: [
         (* Cadence type tests *)
         "test_cadence_equality" >:: test_cadence_equality;
         (* is_period_end tests *)
         "test_is_period_end_daily" >:: test_is_period_end_daily;
         "test_is_period_end_weekly" >:: test_is_period_end_weekly;
         "test_is_period_end_monthly" >:: test_is_period_end_monthly;
         (* convert_cadence tests *)
         "test_convert_cadence_daily" >:: test_convert_cadence_daily;
         "test_convert_cadence_weekly_complete"
         >:: test_convert_cadence_weekly_complete;
         "test_convert_cadence_weekly_incomplete_excluded"
         >:: test_convert_cadence_weekly_incomplete_excluded;
         "test_convert_cadence_weekly_incomplete_provisional"
         >:: test_convert_cadence_weekly_incomplete_provisional;
         "test_convert_cadence_weekly_mixed" >:: test_convert_cadence_weekly_mixed;
         "test_convert_cadence_monthly_todo" >:: test_convert_cadence_monthly_todo;
       ]

let () = run_test_tt_main suite
