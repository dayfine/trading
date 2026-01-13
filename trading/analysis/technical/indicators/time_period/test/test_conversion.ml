open OUnit2
open Core
open Types.Daily_price
open Time_period.Conversion

let default_volume = 1000

let make_test_data ~date ~price =
  {
    date;
    open_price = price;
    high_price = price;
    low_price = price;
    close_price = price;
    volume = default_volume;
    adjusted_close = price;
  }

(* Daily to weekly conversion tests *)
let test_single_week _ =
  let data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
        ~price:2.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:14)
        ~price:3.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
    ]
  in
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 4.0;
        low_price = 1.0;
        close_price = 4.0;
        volume = default_volume * 4;
        adjusted_close = 4.0;
      };
    ]

let test_multiple_weeks _ =
  let data =
    [
      (* Week 1: Mar 12-15 *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
        ~price:2.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:14)
        ~price:3.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
      (* Week 2: Mar 18-20 *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:18)
        ~price:5.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:19)
        ~price:6.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:20)
        ~price:7.0;
    ]
  in
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 4.0;
        low_price = 1.0;
        close_price = 4.0;
        volume = default_volume * 4;
        adjusted_close = 4.0;
      };
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 5.0;
        high_price = 7.0;
        low_price = 5.0;
        close_price = 7.0;
        volume = default_volume * 3;
        adjusted_close = 7.0;
      };
    ]

let test_empty_list _ =
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly []) []

let test_single_entry _ =
  let data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
    ]
  in
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly data)
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
    ]

let test_weekdays_only _ =
  let data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
        ~price:2.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:14)
        ~price:3.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
      (* Friday *)
    ]
  in
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly ~weekdays_only:true data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 4.0;
        low_price = 1.0;
        close_price = 4.0;
        volume = default_volume * 4;
        adjusted_close = 4.0;
      };
    ]

let test_unsorted_data_raises_invalid_argument _ =
  let unsorted_data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:1.0;
    ]
  in
  assert_raises
    (Invalid_argument
       "Data must be sorted chronologically by date with no duplicates")
    (fun () -> daily_to_weekly unsorted_data)

let test_weekend_data_with_weekdays_only_raises_invalid_argument _ =
  let weekend_data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
      (* Friday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:16)
        ~price:5.0;
      (* Saturday *)
    ]
  in
  (* Should pass when weekdays_only is false (default) *)
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly weekend_data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:16;
        open_price = 4.0;
        high_price = 5.0;
        low_price = 4.0;
        close_price = 5.0;
        volume = default_volume * 2;
        adjusted_close = 5.0;
      };
    ];
  (* Should fail when weekdays_only is true *)
  assert_raises
    (Invalid_argument "Weekend dates not allowed when weekdays_only is true")
    (fun () -> daily_to_weekly ~weekdays_only:true weekend_data)

let test_duplicate_dates_raises_invalid_argument _ =
  let duplicate_data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:4.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:5.0;
    ]
  in
  assert_raises
    (Invalid_argument
       "Data must be sorted chronologically by date with no duplicates")
    (fun () -> daily_to_weekly duplicate_data)

(* Tests for include_partial_week parameter *)
let test_partial_week_included_by_default _ =
  (* Incomplete week (Mon-Wed) *)
  let data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11)
        ~price:1.0;
      (* Monday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:2.0;
      (* Tuesday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
        ~price:3.0;
      (* Wednesday *)
    ]
  in
  (* Default behavior: include partial week *)
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:13;
        open_price = 1.0;
        high_price = 3.0;
        low_price = 1.0;
        close_price = 3.0;
        volume = default_volume * 3;
        adjusted_close = 3.0;
      };
    ]

let test_partial_week_excluded _ =
  (* Incomplete week (Mon-Wed) *)
  let data =
    [
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11)
        ~price:1.0;
      (* Monday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:12)
        ~price:2.0;
      (* Tuesday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:13)
        ~price:3.0;
      (* Wednesday *)
    ]
  in
  (* Exclude partial week: should return empty *)
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly ~include_partial_week:false data)
    []

let test_complete_and_partial_weeks _ =
  let data =
    [
      (* Week 1: Complete (Mon-Fri) *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11)
        ~price:1.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:5.0;
      (* Friday *)
      (* Week 2: Incomplete (Mon-Wed) *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:18)
        ~price:6.0;
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:20)
        ~price:8.0;
      (* Wednesday *)
    ]
  in
  (* Include partial: both weeks *)
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly ~include_partial_week:true data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 5.0;
        low_price = 1.0;
        close_price = 5.0;
        volume = default_volume * 2;
        adjusted_close = 5.0;
      };
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 6.0;
        high_price = 8.0;
        low_price = 6.0;
        close_price = 8.0;
        volume = default_volume * 2;
        adjusted_close = 8.0;
      };
    ];
  (* Exclude partial: only complete week *)
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    (daily_to_weekly ~include_partial_week:false data)
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 5.0;
        low_price = 1.0;
        close_price = 5.0;
        volume = default_volume * 2;
        adjusted_close = 5.0;
      };
    ]

let test_all_complete_weeks_unaffected _ =
  let data =
    [
      (* Week 1: Complete week with multiple days *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:11)
        ~price:1.0;
      (* Monday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:15)
        ~price:5.0;
      (* Friday *)
      (* Week 2: Complete week with multiple days *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:18)
        ~price:6.0;
      (* Monday *)
      make_test_data
        ~date:(Date.create_exn ~y:2024 ~m:Month.Mar ~d:22)
        ~price:10.0;
      (* Friday *)
    ]
  in
  (* Both settings should give same result for complete weeks *)
  let expected =
    [
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15;
        open_price = 1.0;
        high_price = 5.0;
        low_price = 1.0;
        close_price = 5.0;
        volume = default_volume * 2;
        adjusted_close = 5.0;
      };
      {
        date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:22;
        open_price = 6.0;
        high_price = 10.0;
        low_price = 6.0;
        close_price = 10.0;
        volume = default_volume * 2;
        adjusted_close = 10.0;
      };
    ]
  in
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    expected
    (daily_to_weekly ~include_partial_week:true data);
  assert_equal
    ~printer:(fun l ->
      List.map ~f:Types.Daily_price.show l |> String.concat ~sep:"; ")
    expected
    (daily_to_weekly ~include_partial_week:false data)

let suite =
  "Time period conversion tests"
  >::: [
         "test_single_week" >:: test_single_week;
         "test_multiple_weeks" >:: test_multiple_weeks;
         "test_empty_list" >:: test_empty_list;
         "test_single_entry" >:: test_single_entry;
         "test_weekdays_only" >:: test_weekdays_only;
         "test_unsorted_data_raises_invalid_argument"
         >:: test_unsorted_data_raises_invalid_argument;
         "test_weekend_data_with_weekdays_only_raises_invalid_argument"
         >:: test_weekend_data_with_weekdays_only_raises_invalid_argument;
         "test_duplicate_dates_raises_invalid_argument"
         >:: test_duplicate_dates_raises_invalid_argument;
         (* Tests for include_partial_week parameter *)
         "test_partial_week_included_by_default"
         >:: test_partial_week_included_by_default;
         "test_partial_week_excluded" >:: test_partial_week_excluded;
         "test_complete_and_partial_weeks" >:: test_complete_and_partial_weeks;
         "test_all_complete_weeks_unaffected"
         >:: test_all_complete_weeks_unaffected;
       ]

let () = run_test_tt_main suite
