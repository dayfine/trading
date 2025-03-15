open OUnit2
open Weekly_indicators.Types
open Weekly_indicators.Date

type test_data = {
  date : date;
  value : float;
} [@@deriving show]

let test_create _ =
  let d = create ~year:2024 ~month:3 ~day:15 in
  assert_equal 2024 (year d);
  assert_equal 3 (month d);
  assert_equal 15 (day d)

let test_parse _ =
  let d = parse "2024-03-15" in
  assert_equal 2024 (year d);
  assert_equal 3 (month d);
  assert_equal 15 (day d)

let test_add_days _ =
  let d = create ~year:2024 ~month:3 ~day:15 in
  let d' = add_days d 7 in
  assert_equal 22 (day d');
  assert_equal 3 (month d');
  assert_equal 2024 (year d')

let test_same_week _ =
  let d1 = create ~year:2024 ~month:3 ~day:12 in (* Tuesday *)
  let d2 = create ~year:2024 ~month:3 ~day:15 in (* Friday *)
  let d3 = create ~year:2024 ~month:3 ~day:18 in (* Monday next week *)
  assert_bool "Should be same week" (is_same_week d1 d2);
  assert_bool "Should not be same week" (not (is_same_week d1 d3))

let test_daily_to_weekly _ =
  let create_test_data date value = { date; value } in
  let d1 = create ~year:2024 ~month:3 ~day:12 in
  let d2 = create ~year:2024 ~month:3 ~day:13 in
  let d3 = create ~year:2024 ~month:3 ~day:14 in
  let d4 = create ~year:2024 ~month:3 ~day:15 in
  let d5 = create ~year:2024 ~month:3 ~day:18 in

  let data = [
    create_test_data d1 1.0;
    create_test_data d2 2.0;
    create_test_data d3 3.0;
    create_test_data d4 4.0;
    create_test_data d5 5.0;
  ] in
  let weekly = daily_to_weekly data in
  assert_equal 2 (List.length weekly);
  match weekly with
  | [w1; w2] ->
      assert_equal 4.0 w1.value;  (* last value of first week *)
      assert_equal 5.0 w2.value;  (* first/only value of second week *)
      assert_equal 15 (day w1.date);  (* last day of first week *)
      assert_equal 18 (day w2.date)   (* first day of second week *)
  | _ -> assert_failure "Unexpected weekly data structure"

let suite =
  "Date tests" >::: [
    "test_create" >:: test_create;
    "test_parse" >:: test_parse;
    "test_add_days" >:: test_add_days;
    "test_same_week" >:: test_same_week;
    "test_daily_to_weekly" >:: test_daily_to_weekly;
  ]
