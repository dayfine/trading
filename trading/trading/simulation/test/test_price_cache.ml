open OUnit2
open Core
open Trading_simulation.Price_cache
open Matchers

let ok_or_fail_status = function
  | Ok x -> x
  | Error (err : Status.t) -> failwith err.message

let setup_test_data test_name =
  (* Create unique test data directory for each test to avoid parallel execution conflicts *)
  let test_data_dir =
    Fpath.v (Printf.sprintf "test_data/price_cache_%s" test_name)
  in
  let dir_str = Fpath.to_string test_data_dir in
  (match Sys_unix.file_exists dir_str with
  | `Yes -> ignore (Bos.OS.Dir.delete ~recurse:true test_data_dir)
  | _ -> ());
  ignore (Bos.OS.Dir.create ~path:true test_data_dir);

  (* Create sample CSV for AAPL *)
  let aapl_prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
        open_price = 100.0;
        high_price = 102.0;
        low_price = 99.0;
        close_price = 101.0;
        volume = 1000000;
        adjusted_close = 101.0;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:2;
        open_price = 101.0;
        high_price = 103.0;
        low_price = 100.0;
        close_price = 102.0;
        volume = 1100000;
        adjusted_close = 102.0;
      };
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:3;
        open_price = 102.0;
        high_price = 104.0;
        low_price = 101.0;
        close_price = 103.0;
        volume = 1200000;
        adjusted_close = 103.0;
      };
    ]
  in
  let aapl_storage =
    Csv.Csv_storage.create ~data_dir:test_data_dir "AAPL" |> ok_or_fail_status
  in
  ignore (Csv.Csv_storage.save aapl_storage aapl_prices |> ok_or_fail_status);

  (* Create sample CSV for GOOGL *)
  let googl_prices =
    [
      {
        Types.Daily_price.date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:1;
        open_price = 150.0;
        high_price = 152.0;
        low_price = 149.0;
        close_price = 151.0;
        volume = 2000000;
        adjusted_close = 151.0;
      };
    ]
  in
  let googl_storage =
    Csv.Csv_storage.create ~data_dir:test_data_dir "GOOGL" |> ok_or_fail_status
  in
  ignore (Csv.Csv_storage.save googl_storage googl_prices |> ok_or_fail_status);
  test_data_dir

let teardown_test_data test_data_dir =
  let dir_str = Fpath.to_string test_data_dir in
  match Sys_unix.file_exists dir_str with
  | `Yes -> ignore (Bos.OS.Dir.delete ~recurse:true test_data_dir)
  | _ -> ()

let test_create_backend _ =
  let test_data_dir = setup_test_data "create_backend" in
  let backend = create ~data_dir:test_data_dir in
  assert_that (get_cached_symbols backend) (elements_are []);
  teardown_test_data test_data_dir

let test_lazy_loading _ =
  let test_data_dir = setup_test_data "lazy_loading" in
  let backend = create ~data_dir:test_data_dir in

  (* Initially no symbols cached *)
  assert_that (get_cached_symbols backend) (elements_are []);

  (* Load AAPL *)
  let aapl_result = get_prices backend ~symbol:"AAPL" () in
  assert_that aapl_result is_ok;

  (* Now AAPL should be cached *)
  let cached = get_cached_symbols backend in
  assert_that cached (size_is 1);
  assert_bool "AAPL should be cached"
    (List.mem cached "AAPL" ~equal:String.equal);

  teardown_test_data test_data_dir

let test_get_prices_all _ =
  let test_data_dir = setup_test_data "get_prices_all" in
  let backend = create ~data_dir:test_data_dir in

  let result = get_prices backend ~symbol:"AAPL" () in
  assert_that result
    (is_ok_and_holds (fun prices ->
         assert_that prices (size_is 3);
         (* Verify first price *)
         let first : Types.Daily_price.t = List.hd_exn prices in
         assert_that first.close_price (float_equal 101.0)));

  teardown_test_data test_data_dir

let test_get_prices_with_date_filter _ =
  let test_data_dir = setup_test_data "date_filter" in
  let backend = create ~data_dir:test_data_dir in

  (* Get prices from Jan 2 onwards *)
  let result =
    get_prices backend ~symbol:"AAPL"
      ~start_date:(Date.create_exn ~y:2024 ~m:Month.Jan ~d:2)
      ()
  in
  assert_that result
    (is_ok_and_holds (fun prices ->
         assert_that prices (size_is 2);
         let first : Types.Daily_price.t = List.hd_exn prices in
         assert_that first.close_price (float_equal 102.0)));

  (* Get prices up to Jan 2 *)
  let result2 =
    get_prices backend ~symbol:"AAPL"
      ~end_date:(Date.create_exn ~y:2024 ~m:Month.Jan ~d:2)
      ()
  in
  assert_that result2
    (is_ok_and_holds (fun prices -> assert_that prices (size_is 2)));

  (* Get prices for specific date range *)
  let result3 =
    get_prices backend ~symbol:"AAPL"
      ~start_date:(Date.create_exn ~y:2024 ~m:Month.Jan ~d:2)
      ~end_date:(Date.create_exn ~y:2024 ~m:Month.Jan ~d:2)
      ()
  in
  assert_that result3
    (is_ok_and_holds (fun prices ->
         assert_that prices (size_is 1);
         let first : Types.Daily_price.t = List.hd_exn prices in
         assert_that first.close_price (float_equal 102.0)));

  teardown_test_data test_data_dir

let test_caching _ =
  let test_data_dir = setup_test_data "caching" in
  let backend = create ~data_dir:test_data_dir in

  (* Load AAPL first time *)
  let _ = get_prices backend ~symbol:"AAPL" () in

  (* Load AAPL second time (should use cache) *)
  let result = get_prices backend ~symbol:"AAPL" () in
  assert_that result is_ok;

  (* Verify still only one symbol cached *)
  assert_that (get_cached_symbols backend) (size_is 1);

  teardown_test_data test_data_dir

let test_preload_symbols _ =
  let test_data_dir = setup_test_data "preload" in
  let backend = create ~data_dir:test_data_dir in

  (* Preload multiple symbols *)
  let result = preload_symbols backend [ "AAPL"; "GOOGL" ] in
  assert_that result is_ok;

  (* Both should be cached *)
  let cached = get_cached_symbols backend in
  assert_that cached (size_is 2);

  teardown_test_data test_data_dir

let test_clear_cache _ =
  let test_data_dir = setup_test_data "clear_cache" in
  let backend = create ~data_dir:test_data_dir in

  (* Load some data *)
  let _ = get_prices backend ~symbol:"AAPL" () in
  assert_that (get_cached_symbols backend) (size_is 1);

  (* Clear cache *)
  clear_cache backend;
  assert_that (get_cached_symbols backend) (elements_are []);

  teardown_test_data test_data_dir

let test_nonexistent_symbol _ =
  let test_data_dir = setup_test_data "nonexistent" in
  let backend = create ~data_dir:test_data_dir in

  (* Try to load non-existent symbol - should return error, not exception *)
  assert_that
    (get_prices backend ~symbol:"NONEXISTENT" ())
    (is_error_with NotFound ~msg:"not found");

  teardown_test_data test_data_dir

let suite =
  "Price cache tests"
  >::: [
         "test_create_backend" >:: test_create_backend;
         "test_lazy_loading" >:: test_lazy_loading;
         "test_get_prices_all" >:: test_get_prices_all;
         "test_get_prices_with_date_filter" >:: test_get_prices_with_date_filter;
         "test_caching" >:: test_caching;
         "test_preload_symbols" >:: test_preload_symbols;
         "test_clear_cache" >:: test_clear_cache;
         "test_nonexistent_symbol" >:: test_nonexistent_symbol;
       ]

let () = run_test_tt_main suite
