open OUnit2
open Core
open Trading_simulation
open Matchers
open Test_helpers

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

(** Standard test prices for indicator tests *)
let indicator_test_prices =
  let aapl_prices =
    generate_prices
      ~start_date:(Date.create_exn ~y:2023 ~m:Month.Dec ~d:1)
      ~num_days:30 ~base_price:100.0
  in
  let googl_prices =
    generate_prices
      ~start_date:(Date.create_exn ~y:2023 ~m:Month.Dec ~d:1)
      ~num_days:30 ~base_price:150.0
  in
  [ ("AAPL", aapl_prices); ("GOOGL", googl_prices) ]

let with_indicator_test_data test_name ~f =
  with_test_data ("indicator_manager_" ^ test_name) indicator_test_prices ~f

let make_spec ?(name = "EMA") ?(period = 3) ?(cadence = Types.Cadence.Daily) ()
    =
  Indicator_manager.{ name; period; cadence }

(** Test: basic indicator retrieval *)
let test_get_indicator_basic _ =
  with_indicator_test_data "basic" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      (* Dec 10 is day index 9, close = 109.0
       EMA period 3, multiplier = 0.5:
       Day 3: SMA = (100+101+102)/3 = 101.0
       Days 4-10: each adds 1.0 to EMA → Dec 10 EMA = 108.0 *)
      let spec = make_spec ~period:3 () in
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in
      let result =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in

      assert_that result (is_ok_and_holds (is_some_and (float_equal 108.0))))

(** Test: cache hit on second access *)
let test_cache_hit _ =
  with_indicator_test_data "cache_hit" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      let spec = make_spec ~period:3 () in
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in

      (* First access *)
      let _ =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in

      (* Check cache has 1 entry *)
      let total, _ = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 1);

      (* Second access - should use cache, same value *)
      let result2 =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in
      assert_that result2 (is_ok_and_holds (is_some_and (float_equal 108.0)));

      (* Cache count unchanged *)
      let total2, _ = Indicator_manager.cache_stats manager in
      assert_that total2 (equal_to 1))

(** Test: mid-week access produces provisional value *)
let test_provisional_value_mid_week _ =
  with_indicator_test_data "provisional" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      (* Dec 13, 2023 is a Wednesday *)
      let wed_date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:13 in
      let spec = make_spec ~cadence:Types.Cadence.Weekly ~period:2 () in

      let result =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec
          ~date:wed_date
      in
      (* Weekly period 2 EMA on Wed Dec 13 ≈ 109.83 *)
      assert_that result
        (is_ok_and_holds (is_some_and (float_equal ~epsilon:0.1 109.83)));

      (* Should be marked as provisional *)
      let _, provisional = Indicator_manager.cache_stats manager in
      assert_that provisional (equal_to 1))

(** Test: Friday access produces finalized value *)
let test_finalized_value_friday _ =
  with_indicator_test_data "finalized" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      (* Dec 15, 2023 is a Friday *)
      let fri_date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in
      let spec = make_spec ~cadence:Types.Cadence.Weekly ~period:2 () in

      let result =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec
          ~date:fri_date
      in
      (* Weekly period 2 EMA on Fri Dec 15 ≈ 111.17 *)
      assert_that result
        (is_ok_and_holds (is_some_and (float_equal ~epsilon:0.1 111.17)));

      (* Should be finalized (not provisional) *)
      let total, provisional = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 1);
      assert_that provisional (equal_to 0))

(** Test: finalize_period clears provisional caches *)
let test_finalize_period _ =
  with_indicator_test_data "finalize_period" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      (* Add a provisional entry (Wednesday) *)
      let wed_date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:13 in
      let spec = make_spec ~cadence:Types.Cadence.Weekly ~period:2 () in
      let _ =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec
          ~date:wed_date
      in

      (* Verify provisional entry exists *)
      let _, provisional_before = Indicator_manager.cache_stats manager in
      assert_that provisional_before (equal_to 1);

      (* Finalize the period *)
      let fri_date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in
      Indicator_manager.finalize_period manager ~cadence:Types.Cadence.Weekly
        ~end_date:fri_date;

      (* Provisional entry should be cleared *)
      let total, provisional_after = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 0);
      assert_that provisional_after (equal_to 0))

(** Test: multiple symbols cached independently *)
let test_multiple_symbols _ =
  with_indicator_test_data "multi_symbols" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      let spec = make_spec ~period:3 () in
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in

      (* Get indicator for both symbols *)
      let result_aapl =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in
      let result_googl =
        Indicator_manager.get_indicator manager ~symbol:"GOOGL" ~spec ~date
      in

      (* AAPL base=100 → EMA=108.0, GOOGL base=150 → EMA=158.0 *)
      assert_that result_aapl
        (is_ok_and_holds (is_some_and (float_equal 108.0)));
      assert_that result_googl
        (is_ok_and_holds (is_some_and (float_equal 158.0)));

      (* Both should be cached *)
      let total, _ = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 2))

(** Test: different periods cached separately *)
let test_different_periods _ =
  with_indicator_test_data "diff_periods" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in

      let spec_3 = make_spec ~period:3 () in
      let spec_5 = make_spec ~period:5 () in

      let result_3 =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec:spec_3
          ~date
      in
      let result_5 =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec:spec_5
          ~date
      in

      (* Dec 15 is day index 14, close = 114.0
       Period 3 (mult=0.5): EMA = 113.0
       Period 5 (mult=1/3): EMA = 112.0 *)
      assert_that result_3 (is_ok_and_holds (is_some_and (float_equal 113.0)));
      assert_that result_5 (is_ok_and_holds (is_some_and (float_equal 112.0)));

      (* Both should be cached separately *)
      let total, _ = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 2))

(** Test: different cadences cached separately *)
let test_different_cadences _ =
  with_indicator_test_data "diff_cadences" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      (* Dec 15, 2023 is a Friday - works for both daily and weekly *)
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:15 in

      let spec_daily = make_spec ~cadence:Types.Cadence.Daily ~period:3 () in
      let spec_weekly = make_spec ~cadence:Types.Cadence.Weekly ~period:2 () in

      let result_daily =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec:spec_daily
          ~date
      in
      let result_weekly =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec:spec_weekly
          ~date
      in

      (* Daily period 3: EMA = 113.0
       Weekly period 2: EMA ≈ 111.17 (same as test_finalized_value_friday) *)
      assert_that result_daily
        (is_ok_and_holds (is_some_and (float_equal 113.0)));
      assert_that result_weekly
        (is_ok_and_holds (is_some_and (float_equal ~epsilon:0.1 111.17)));

      (* Both should be cached separately *)
      let total, _ = Indicator_manager.cache_stats manager in
      assert_that total (equal_to 2))

(** Test: clear_cache removes all entries *)
let test_clear_cache _ =
  with_indicator_test_data "clear_cache" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      let spec = make_spec ~period:3 () in
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in

      (* Add some entries *)
      let _ =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in
      let _ =
        Indicator_manager.get_indicator manager ~symbol:"GOOGL" ~spec ~date
      in

      let total_before, _ = Indicator_manager.cache_stats manager in
      assert_that total_before (equal_to 2);

      (* Clear cache *)
      Indicator_manager.clear_cache manager;

      let total_after, _ = Indicator_manager.cache_stats manager in
      assert_that total_after (equal_to 0))

(** Test: unknown indicator returns error *)
let test_unknown_indicator _ =
  with_indicator_test_data "unknown" ~f:(fun test_data_dir ->
      let price_cache = Price_cache.create ~data_dir:test_data_dir in
      let manager = Indicator_manager.create ~price_cache in

      let spec = make_spec ~name:"UNKNOWN" ~period:3 () in
      let date = Date.create_exn ~y:2023 ~m:Month.Dec ~d:10 in

      let result =
        Indicator_manager.get_indicator manager ~symbol:"AAPL" ~spec ~date
      in
      assert_that result is_error)

let suite =
  "Indicator manager tests"
  >::: [
         "test_get_indicator_basic" >:: test_get_indicator_basic;
         "test_cache_hit" >:: test_cache_hit;
         "test_provisional_value_mid_week" >:: test_provisional_value_mid_week;
         "test_finalized_value_friday" >:: test_finalized_value_friday;
         "test_finalize_period" >:: test_finalize_period;
         "test_multiple_symbols" >:: test_multiple_symbols;
         "test_different_periods" >:: test_different_periods;
         "test_different_cadences" >:: test_different_cadences;
         "test_clear_cache" >:: test_clear_cache;
         "test_unknown_indicator" >:: test_unknown_indicator;
       ]

let () = run_test_tt_main suite
