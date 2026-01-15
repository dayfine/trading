open OUnit2
open Core
open Trading_simulation
open Matchers

let ok_or_fail_status = function
  | Ok x -> x
  | Error (err : Status.t) -> failwith err.message

(** Generate daily prices for a date range with incrementing closes *)
let generate_prices ~start_date ~num_days ~base_price =
  List.init num_days ~f:(fun i ->
      let date = Date.add_days start_date i in
      let close = base_price +. Float.of_int i in
      {
        Types.Daily_price.date;
        open_price = close -. 1.0;
        high_price = close +. 1.0;
        low_price = close -. 2.0;
        close_price = close;
        volume = 1000000;
        adjusted_close = close;
      })

let setup_test_data test_name =
  let test_data_dir =
    Fpath.v (Printf.sprintf "test_data/market_data_adapter_%s" test_name)
  in
  let dir_str = Fpath.to_string test_data_dir in
  (match Sys_unix.file_exists dir_str with
  | `Yes -> ignore (Bos.OS.Dir.delete ~recurse:true test_data_dir)
  | _ -> ());
  ignore (Bos.OS.Dir.create ~path:true test_data_dir);

  (* Generate 30 days of AAPL prices starting from Dec 1, 2023 *)
  let aapl_prices =
    generate_prices
      ~start_date:(Date.create_exn ~y:2023 ~m:Month.Dec ~d:1)
      ~num_days:30 ~base_price:100.0
  in
  let aapl_storage =
    Csv.Csv_storage.create ~data_dir:test_data_dir "AAPL" |> ok_or_fail_status
  in
  ignore (Csv.Csv_storage.save aapl_storage aapl_prices |> ok_or_fail_status);

  (* Generate 30 days of GOOGL prices *)
  let googl_prices =
    generate_prices
      ~start_date:(Date.create_exn ~y:2023 ~m:Month.Dec ~d:1)
      ~num_days:30 ~base_price:150.0
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

(** Test: create adapter *)
let test_create_adapter _ =
  let test_data_dir = setup_test_data "create" in
  let _adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  (* Just verify creation doesn't fail *)
  teardown_test_data test_data_dir

(** Test: get price for existing symbol *)
let test_get_price _ =
  let test_data_dir = setup_test_data "get_price" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in
  let price = Market_data_adapter.get_price adapter ~symbol:"AAPL" ~date in
  (* Dec 10 is day index 9, close = 100.0 + 9 = 109.0 *)
  assert_that price
    (is_some_and
       (field
          (fun (p : Types.Daily_price.t) -> p.close_price)
          (float_equal 109.0)));
  teardown_test_data test_data_dir

(** Test: get price for non-existent date returns None *)
let test_get_price_no_data _ =
  let test_data_dir = setup_test_data "no_data" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  (* Date outside data range *)
  let date = Date.create_exn ~y:2024 ~m:Month.Jan ~d:15 in
  let price = Market_data_adapter.get_price adapter ~symbol:"AAPL" ~date in
  assert_that price is_none;
  teardown_test_data test_data_dir

(** Test: get indicator with daily cadence *)
let test_get_indicator_daily _ =
  let test_data_dir = setup_test_data "indicator_daily" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in
  let ema =
    Market_data_adapter.get_indicator adapter ~symbol:"AAPL"
      ~indicator_name:"EMA" ~period:3 ~cadence:Daily ~date
  in
  (* Same as test_indicator_manager: Dec 10 with period 3 = 108.0 *)
  assert_that ema (is_some_and (float_equal 108.0));
  teardown_test_data test_data_dir

(** Test: get indicator with weekly cadence *)
let test_get_indicator_weekly _ =
  let test_data_dir = setup_test_data "indicator_weekly" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  (* Dec 15, 2023 is a Friday *)
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in
  let ema =
    Market_data_adapter.get_indicator adapter ~symbol:"AAPL"
      ~indicator_name:"EMA" ~period:2 ~cadence:Weekly ~date
  in
  (* Same as test_indicator_manager: Friday Dec 15 weekly period 2 ≈ 111.17 *)
  assert_that ema (is_some_and (float_equal ~epsilon:0.1 111.17));
  teardown_test_data test_data_dir

(** Test: unknown indicator returns None *)
let test_unknown_indicator _ =
  let test_data_dir = setup_test_data "unknown_ind" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in
  let ind =
    Market_data_adapter.get_indicator adapter ~symbol:"AAPL"
      ~indicator_name:"RSI" ~period:14 ~cadence:Daily ~date
  in
  assert_that ind is_none;
  teardown_test_data test_data_dir

(** Test: multiple symbols *)
let test_multiple_symbols _ =
  let test_data_dir = setup_test_data "multi_symbols" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in
  let aapl_price = Market_data_adapter.get_price adapter ~symbol:"AAPL" ~date in
  let googl_price =
    Market_data_adapter.get_price adapter ~symbol:"GOOGL" ~date
  in
  (* AAPL: 109.0, GOOGL: 159.0 *)
  assert_that aapl_price
    (is_some_and
       (field
          (fun (p : Types.Daily_price.t) -> p.close_price)
          (float_equal 109.0)));
  assert_that googl_price
    (is_some_and
       (field
          (fun (p : Types.Daily_price.t) -> p.close_price)
          (float_equal 159.0)));
  teardown_test_data test_data_dir

(** Test: multiple cadences for same symbol *)
let test_multiple_cadences _ =
  let test_data_dir = setup_test_data "multi_cadence" in
  let adapter = Market_data_adapter.create ~data_dir:test_data_dir in
  (* Dec 15, 2023 is a Friday - works for both daily and weekly *)
  let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in
  let ema_daily =
    Market_data_adapter.get_indicator adapter ~symbol:"AAPL"
      ~indicator_name:"EMA" ~period:3 ~cadence:Daily ~date
  in
  let ema_weekly =
    Market_data_adapter.get_indicator adapter ~symbol:"AAPL"
      ~indicator_name:"EMA" ~period:2 ~cadence:Weekly ~date
  in
  (* Daily period 3: 113.0, Weekly period 2: ≈111.17 *)
  assert_that ema_daily (is_some_and (float_equal 113.0));
  assert_that ema_weekly (is_some_and (float_equal ~epsilon:0.1 111.17));
  teardown_test_data test_data_dir

let suite =
  "Market data adapter tests"
  >::: [
         "test_create_adapter" >:: test_create_adapter;
         "test_get_price" >:: test_get_price;
         "test_get_price_no_data" >:: test_get_price_no_data;
         "test_get_indicator_daily" >:: test_get_indicator_daily;
         "test_get_indicator_weekly" >:: test_get_indicator_weekly;
         "test_unknown_indicator" >:: test_unknown_indicator;
         "test_multiple_symbols" >:: test_multiple_symbols;
         "test_multiple_cadences" >:: test_multiple_cadences;
       ]

let () = run_test_tt_main suite
