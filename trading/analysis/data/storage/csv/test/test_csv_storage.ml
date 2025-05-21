open OUnit2
open Bos
open Core
open Csv.Csv_storage
open Status

let ok_or_failwith_status = function
  | Stdlib.Result.Ok x -> x
  | Error status -> failwith status.message

let ok_or_failwith_os_error = function
  | Stdlib.Result.Ok x -> x
  | Error (`Msg msg) -> failwith msg

let test_dir = Fpath.v "test_data"

let setup_test_dir () =
  let dir_str = Fpath.to_string test_dir in
  (match Sys_unix.file_exists dir_str with
  | `Yes -> ok_or_failwith_os_error (OS.Dir.delete ~recurse:true test_dir)
  | _ -> ());
  ignore (ok_or_failwith_os_error (OS.Dir.create test_dir))

let teardown_test_dir () =
  let dir_str = Fpath.to_string test_dir in
  match Sys_unix.file_exists dir_str with
  | `Yes -> ok_or_failwith_os_error (OS.Dir.delete ~recurse:true test_dir)
  | _ -> ()

let test_create_directory_structure _ =
  let symbol = "GOOG" in
  let _storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  let expected_path = Fpath.(test_dir / "G" / "O" / symbol / "data.csv") in
  assert_equal `Yes (Sys_unix.file_exists (Fpath.to_string expected_path))

let test_save_and_get_prices _ =
  let symbol = "AAPL" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  let prices =
    [
      {
        Types.Daily_price.date = Date.of_string "2024-01-01";
        open_price = 100.0;
        high_price = 105.0;
        low_price = 95.0;
        close_price = 102.0;
        adjusted_close = 102.0;
        volume = 1000000;
      };
      {
        Types.Daily_price.date = Date.of_string "2024-01-02";
        open_price = 102.0;
        high_price = 107.0;
        low_price = 101.0;
        close_price = 106.0;
        adjusted_close = 106.0;
        volume = 1200000;
      };
    ]
  in
  ok_or_failwith_status (save storage ~override:true prices);
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal (List.length prices) (List.length retrieved_prices);
  List.iter2_exn prices retrieved_prices ~f:(fun expected actual ->
      assert_equal expected.date actual.date;
      assert_equal expected.open_price actual.open_price;
      assert_equal expected.high_price actual.high_price;
      assert_equal expected.low_price actual.low_price;
      assert_equal expected.close_price actual.close_price;
      assert_equal expected.adjusted_close actual.adjusted_close;
      assert_equal expected.volume actual.volume)

let test_invalid_symbol _ =
  let symbol = "A" in
  (* Too short for our directory structure *)
  match create ~data_dir:test_dir symbol with
  | Ok _ -> assert_failure "Should have failed with invalid symbol"
  | Error _ -> ()

let test_date_filter _ =
  let storage = create ~data_dir:test_dir "GOOG" |> ok_or_failwith_status in
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
  ignore (save storage ~override:true prices |> ok_or_failwith_status);
  let start_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let end_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let filtered_prices =
    get storage ~start_date ~end_date () |> ok_or_failwith_status
  in
  assert_equal ~printer:Int.to_string 1 (List.length filtered_prices);
  assert_equal ~printer:Types.Daily_price.show (List.nth_exn prices 1)
    (List.nth_exn filtered_prices 0)

let test_validation_error _ =
  let storage = create ~data_dir:test_dir "GOOG" |> ok_or_failwith_status in
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
         "test_create_directory_structure" >:: test_create_directory_structure;
         "test_save_and_get_prices" >:: test_save_and_get_prices;
         "test_invalid_symbol" >:: test_invalid_symbol;
         "test_date_filter" >:: test_date_filter;
         "test_validation_error" >:: test_validation_error;
       ]

let () =
  setup_test_dir ();
  run_test_tt_main suite;
  teardown_test_dir ()
