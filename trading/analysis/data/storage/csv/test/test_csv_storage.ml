open OUnit2
open Core
open Csv.Csv_storage
open Status

let ok_or_failwith_status = function
  | Result.Ok x -> x
  | Error status -> failwith status.message

let test_save_and_read _ =
  let storage = create "TEST" |> ok_or_failwith_status in
  let prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
        open_price = 100.0;
        high_price = 105.0;
        low_price = 98.0;
        close_price = 103.0;
        adjusted_close = 103.0;
        volume = 1000;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 103.0;
        high_price = 108.0;
        low_price = 102.0;
        close_price = 107.0;
        adjusted_close = 107.0;
        volume = 1200;
      };
    ]
  in
  (* Save prices *)
  save storage ~override:true prices |> ok_or_failwith_status;
  (* Read back and verify *)
  let read_prices = get_prices storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices read_prices

let test_date_filter _ =
  let storage = create "TEST" |> ok_or_failwith_status in
  let prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
        open_price = 100.0;
        high_price = 105.0;
        low_price = 98.0;
        close_price = 103.0;
        adjusted_close = 103.0;
        volume = 1000;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 103.0;
        high_price = 108.0;
        low_price = 102.0;
        close_price = 107.0;
        adjusted_close = 107.0;
        volume = 1200;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
        open_price = 107.0;
        high_price = 112.0;
        low_price = 106.0;
        close_price = 111.0;
        adjusted_close = 111.0;
        volume = 1400;
      };
    ]
  in
  save storage ~override:true prices |> ok_or_failwith_status;
  let start_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let end_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let filtered_prices =
    get_prices storage ~start_date ~end_date () |> ok_or_failwith_status
  in
  assert_equal ~printer:Int.to_string 1 (List.length filtered_prices);
  assert_equal ~printer:Types.Daily_price.show (List.nth_exn prices 1)
    (List.nth_exn filtered_prices 0)

let test_validation_error _ =
  let storage = create "TEST" |> ok_or_failwith_status in
  let prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 103.0;
        high_price = 108.0;
        low_price = 102.0;
        close_price = 107.0;
        adjusted_close = 107.0;
        volume = 1200;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:19;
        open_price = 100.0;
        high_price = 105.0;
        low_price = 98.0;
        close_price = 103.0;
        adjusted_close = 103.0;
        volume = 1000;
      };
    ]
  in
  match save storage ~override:true prices with
  | Ok _ -> assert_failure "Expected validation error"
  | Error status ->
      assert_equal ~printer:Status.show_code Status.Invalid_argument status.code;
      assert_equal ~printer:String.to_string
        "Prices must be sorted by date in ascending order and contain no \
         duplicates"
        status.message

let suite =
  "CSV Storage tests"
  >::: [
         "test_save_and_read" >:: test_save_and_read;
         "test_date_filter" >:: test_date_filter;
         "test_validation_error" >:: test_validation_error;
       ]

let () = run_test_tt_main suite
