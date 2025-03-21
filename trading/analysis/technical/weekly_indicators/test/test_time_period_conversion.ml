open OUnit2
open Core
open Weekly_indicators.Time_period_conversion

(* Week comparison tests *)
let test_same_week _ =
  let test_cases =
    [
      (* Same week *)
      ((2024, 3, 12), (2024, 3, 15), true);  (* Tuesday to Friday *)
      ((2024, 3, 15), (2024, 3, 12), true);  (* Friday to Tuesday *)
      (* Different weeks *)
      ((2024, 3, 12), (2024, 3, 18), false);  (* Tuesday to Monday next week *)
      ((2024, 3, 15), (2024, 3, 19), false);  (* Friday to Tuesday next week *)
      (* Month boundary *)
      ((2024, 3, 31), (2024, 4, 1), false);  (* Sunday to Monday *)
      (* Year boundary *)
      ((2024, 12, 31), (2025, 1, 1), false);  (* Tuesday to Wednesday *)
    ]
  in
  List.iter test_cases ~f:(fun ((y1, m1, d1), (y2, m2, d2), expected) ->
      let d1 = Date.create_exn ~y:y1 ~m:(Month.of_int_exn m1) ~d:d1 in
      let d2 = Date.create_exn ~y:y2 ~m:(Month.of_int_exn m2) ~d:d2 in
      assert_equal expected (is_same_week d1 d2))

(* Daily to weekly conversion tests *)
let test_daily_to_weekly _ =
  let test_cases =
    [
      (* Single week *)
      ( [
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:12;
            open_price = 1.0;
            high_price = 1.0;
            low_price = 1.0;
            close_price = 1.0;
            volume = 1000;
            adjusted_close = 1.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:13;
            open_price = 2.0;
            high_price = 2.0;
            low_price = 2.0;
            close_price = 2.0;
            volume = 1000;
            adjusted_close = 2.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:14;
            open_price = 3.0;
            high_price = 3.0;
            low_price = 3.0;
            close_price = 3.0;
            volume = 1000;
            adjusted_close = 3.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
            open_price = 4.0;
            high_price = 4.0;
            low_price = 4.0;
            close_price = 4.0;
            volume = 1000;
            adjusted_close = 4.0 };
        ],
        4 );  (* Should have 4 entries *)
      (* Multiple weeks *)
      ( [
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:12;
            open_price = 1.0;
            high_price = 1.0;
            low_price = 1.0;
            close_price = 1.0;
            volume = 1000;
            adjusted_close = 1.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:13;
            open_price = 2.0;
            high_price = 2.0;
            low_price = 2.0;
            close_price = 2.0;
            volume = 1000;
            adjusted_close = 2.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:14;
            open_price = 3.0;
            high_price = 3.0;
            low_price = 3.0;
            close_price = 3.0;
            volume = 1000;
            adjusted_close = 3.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
            open_price = 4.0;
            high_price = 4.0;
            low_price = 4.0;
            close_price = 4.0;
            volume = 1000;
            adjusted_close = 4.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:18;
            open_price = 5.0;
            high_price = 5.0;
            low_price = 5.0;
            close_price = 5.0;
            volume = 1000;
            adjusted_close = 5.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
            open_price = 6.0;
            high_price = 6.0;
            low_price = 6.0;
            close_price = 6.0;
            volume = 1000;
            adjusted_close = 6.0 };
          { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
            open_price = 7.0;
            high_price = 7.0;
            low_price = 7.0;
            close_price = 7.0;
            volume = 1000;
            adjusted_close = 7.0 };
        ],
        7 );  (* Should have 7 entries *)
      (* Empty list *)
      ([], 0);
      (* Single entry *)
      ([ { Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:12;
           open_price = 1.0;
           high_price = 1.0;
           low_price = 1.0;
           close_price = 1.0;
           volume = 1000;
           adjusted_close = 1.0 } ], 1);
    ]
  in
  List.iter test_cases ~f:(fun (data, expected_count) ->
      let result = daily_to_weekly data in
      assert_equal expected_count (List.length result))

let suite =
  "Time period conversion tests"
  >::: [
         "test_same_week" >:: test_same_week;
         "test_daily_to_weekly" >:: test_daily_to_weekly;
       ]

let () = run_test_tt_main suite
