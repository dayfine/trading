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
  ok_or_failwith_status (save storage prices);
  let expected_path = Fpath.(test_dir / "A" / "L" / "AAPL" / "data.csv") in
  assert_equal `Yes (Sys_unix.file_exists (Fpath.to_string expected_path));
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_single_char_symbol _ =
  let symbol = "X" in
  let storage = create ~data_dir:test_dir symbol |> ok_or_failwith_status in
  let prices =
    [
      {
        Types.Daily_price.date = Date.of_string "2024-01-01";
        open_price = 50.0;
        high_price = 55.0;
        low_price = 48.0;
        close_price = 52.0;
        adjusted_close = 52.0;
        volume = 500000;
      };
    ]
  in
  ok_or_failwith_status (save storage prices);
  let expected_path = Fpath.(test_dir / "X" / "X" / "X" / "data.csv") in
  assert_equal `Yes (Sys_unix.file_exists (Fpath.to_string expected_path));
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_create_twice _ =
  let symbol = "MSFT" in
  ignore (create ~data_dir:test_dir symbol |> ok_or_failwith_status);
  ignore (create ~data_dir:test_dir symbol |> ok_or_failwith_status)

let test_invalid_symbol _ =
  let symbol = "" in
  (* Too short for our directory structure *)
  match create ~data_dir:test_dir symbol with
  | Ok _ -> assert_failure "Should have failed with invalid symbol"
  | Error _ -> ()

let test_fail_to_write_if_data_is_not_sorted _ =
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
  match save storage prices with
  | Ok _ -> assert_failure "Expected validation error"
  | Error status ->
      assert_equal ~printer:Status.show status
        (Status.invalid_argument_error
           "Prices must be sorted by date in ascending order and contain no \
            duplicates")

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
  ok_or_failwith_status (save storage prices);
  let start_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let end_date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20 in
  let filtered_prices =
    get storage ~start_date ~end_date () |> ok_or_failwith_status
  in
  assert_equal ~printer:Int.to_string 1 (List.length filtered_prices);
  assert_equal ~printer:Types.Daily_price.show (List.nth_exn prices 1)
    (List.nth_exn filtered_prices 0)

let test_multiple_writes_non_overlapping _ =
  let storage = create ~data_dir:test_dir "META" |> ok_or_failwith_status in
  let prices1 =
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
  let prices2 =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:22;
        open_price = 107.0;
        high_price = 112.0;
        low_price = 106.0;
        close_price = 111.0;
        adjusted_close = 111.0;
        volume = 1400;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:23;
        open_price = 111.0;
        high_price = 115.0;
        low_price = 110.0;
        close_price = 114.0;
        adjusted_close = 114.0;
        volume = 1600;
      };
    ]
  in
  (* Write first batch *)
  ok_or_failwith_status (save storage prices1);
  (* Write second batch *)
  ok_or_failwith_status (save storage prices2);
  (* Get all prices and verify they're in correct order *)
  let all_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    (prices1 @ prices2) all_prices

let test_idempotent_writes _ =
  let storage = create ~data_dir:test_dir "NFLX" |> ok_or_failwith_status in
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
  (* Write the same data multiple times *)
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage prices);
  ok_or_failwith_status (save storage prices);
  (* Get prices and verify they're correct *)
  let retrieved_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    prices retrieved_prices

let test_reject_overlapping_contradictory_data _ =
  let storage = create ~data_dir:test_dir "TSLA" |> ok_or_failwith_status in
  let prices1 =
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
  let prices2 =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 110.0;
        (* Different price for same date *)
        high_price = 115.0;
        low_price = 108.0;
        close_price = 112.0;
        adjusted_close = 112.0;
        volume = 1500;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
        open_price = 112.0;
        high_price = 118.0;
        low_price = 111.0;
        close_price = 116.0;
        adjusted_close = 116.0;
        volume = 1800;
      };
    ]
  in
  (* Write first batch *)
  ok_or_failwith_status (save storage prices1);
  (* Try to write second batch with overlapping date *)
  match save storage prices2 with
  | Ok _ ->
      assert_failure
        "Expected validation error for overlapping dates with different data"
  | Error status ->
      assert_equal ~printer:Status.show status
        (Status.invalid_argument_error
           "Cannot save data with overlapping dates and different values")

let test_allow_overlapping_with_override _ =
  let storage = create ~data_dir:test_dir "AMZN" |> ok_or_failwith_status in
  let prices1 =
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
  let prices2 =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:20;
        open_price = 110.0;
        high_price = 115.0;
        low_price = 108.0;
        close_price = 112.0;
        adjusted_close = 112.0;
        volume = 1500;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Mar ~d:21;
        open_price = 112.0;
        high_price = 118.0;
        low_price = 111.0;
        close_price = 116.0;
        adjusted_close = 116.0;
        volume = 1800;
      };
    ]
  in
  (* Write first batch *)
  ok_or_failwith_status (save storage prices1);
  (* Write second batch with override *)
  ok_or_failwith_status (save storage ~override:true prices2);
  (* Verify final state has the second batch's data for overlapping date *)
  let all_prices = get storage () |> ok_or_failwith_status in
  assert_equal
    ~printer:(fun ps ->
      String.concat ~sep:"\n" (List.map ps ~f:Types.Daily_price.show))
    (* 03/19 price from first batch, all other prices from second batch *)
    ([ List.hd_exn prices1 ] @ prices2)
    all_prices

let suite =
  "CSV Storage tests"
  >::: [
         "test_save_and_get_prices" >:: test_save_and_get_prices;
         "test_single_char_symbol" >:: test_single_char_symbol;
         "test_create_twice" >:: test_create_twice;
         "test_invalid_symbol" >:: test_invalid_symbol;
         "test_fail_to_write_if_data_is_not_sorted"
         >:: test_fail_to_write_if_data_is_not_sorted;
         "test_date_filter" >:: test_date_filter;
         "test_multiple_writes_non_overlapping"
         >:: test_multiple_writes_non_overlapping;
         "test_idempotent_writes" >:: test_idempotent_writes;
         "test_reject_overlapping_contradictory_data"
         >:: test_reject_overlapping_contradictory_data;
         "test_allow_overlapping_with_override"
         >:: test_allow_overlapping_with_override;
       ]

let () =
  setup_test_dir ();
  run_test_tt_main suite;
  teardown_test_dir ()
