open OUnit2
open Weekly_indicators.Ema

let test_parse_date _ =
  let date = parse_date "2024-03-12" in
  assert_equal 2024 date.year;
  assert_equal 3 date.month;
  assert_equal 12 date.day

let test_is_same_week _ =
  let d1 = { year = 2024; month = 3; day = 12 } in
  let d2 = { year = 2024; month = 3; day = 15 } in
  let d3 = { year = 2024; month = 3; day = 18 } in
  assert_bool "Should be same week" (is_same_week d1 d2);
  assert_bool "Should not be same week" (not (is_same_week d1 d3))

let test_daily_to_weekly _ =
  let data = [
    ({ year = 2024; month = 3; day = 12 }, 139.62);
    ({ year = 2024; month = 3; day = 13 }, 140.77);
    ({ year = 2024; month = 3; day = 14 }, 144.34);
    ({ year = 2024; month = 3; day = 15 }, 142.17);
    ({ year = 2024; month = 3; day = 18 }, 148.48);
  ] in
  let weekly = daily_to_weekly data in
  assert_equal 2 (List.length weekly);
  match weekly with
  | [(_d1, p1); (_d2, p2)] ->
      assert_equal 142.17 p1;
      assert_equal 148.48 p2
  | _ -> assert_failure "Unexpected weekly data structure"

let suite =
  "Weekly EMA tests" >::: [
    "test_parse_date" >:: test_parse_date;
    "test_is_same_week" >:: test_is_same_week;
    "test_daily_to_weekly" >:: test_daily_to_weekly;
  ]

let () = run_test_tt_main suite
