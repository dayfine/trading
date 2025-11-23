open OUnit2
open Core
open Trading_simulation.Simulator

(** Helper to create a daily price *)
let make_daily_price ~date ~open_price ~high ~low ~close ~volume =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume;
      adjusted_close = close;
    }

let date_of_string s = Date.of_string s

(** Test fixtures *)
let sample_price_day1 =
  make_daily_price
    ~date:(date_of_string "2024-01-02")
    ~open_price:150.0 ~high:155.0 ~low:149.0 ~close:154.0 ~volume:1000000

let sample_price_day2 =
  make_daily_price
    ~date:(date_of_string "2024-01-03")
    ~open_price:154.0 ~high:158.0 ~low:153.0 ~close:157.0 ~volume:1200000

(* ==================== symbol_prices tests ==================== *)

let test_symbol_prices_construction _ =
  let prices = [ sample_price_day1; sample_price_day2 ] in
  let sp = { symbol = "AAPL"; prices } in
  assert_equal "AAPL" sp.symbol;
  assert_equal 2 (List.length sp.prices)

let test_symbol_prices_equality _ =
  let sp1 = { symbol = "AAPL"; prices = [ sample_price_day1 ] } in
  let sp2 = { symbol = "AAPL"; prices = [ sample_price_day1 ] } in
  let sp3 = { symbol = "GOOGL"; prices = [ sample_price_day1 ] } in
  assert_bool "Same symbol_prices should be equal" (equal_symbol_prices sp1 sp2);
  assert_bool "Different symbols should not be equal"
    (not (equal_symbol_prices sp1 sp3))

let test_symbol_prices_show _ =
  let sp = { symbol = "AAPL"; prices = [] } in
  let str = show_symbol_prices sp in
  assert_bool "Show should contain symbol"
    (String.is_substring str ~substring:"AAPL")

(* ==================== config tests ==================== *)

let test_config_construction _ =
  let cfg =
    {
      start_date = date_of_string "2024-01-01";
      end_date = date_of_string "2024-12-31";
      initial_cash = 100000.0;
      symbols = [ "AAPL"; "GOOGL" ];
      commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    }
  in
  assert_equal (date_of_string "2024-01-01") cfg.start_date;
  assert_equal (date_of_string "2024-12-31") cfg.end_date;
  assert_equal 100000.0 cfg.initial_cash;
  assert_equal [ "AAPL"; "GOOGL" ] cfg.symbols

let test_config_equality _ =
  let make_config () =
    {
      start_date = date_of_string "2024-01-01";
      end_date = date_of_string "2024-12-31";
      initial_cash = 100000.0;
      symbols = [ "AAPL" ];
      commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    }
  in
  let cfg1 = make_config () in
  let cfg2 = make_config () in
  let cfg3 = { (make_config ()) with initial_cash = 50000.0 } in
  assert_bool "Same configs should be equal" (equal_config cfg1 cfg2);
  assert_bool "Different initial_cash should not be equal"
    (not (equal_config cfg1 cfg3))

let test_config_show _ =
  let cfg =
    {
      start_date = date_of_string "2024-01-01";
      end_date = date_of_string "2024-12-31";
      initial_cash = 100000.0;
      symbols = [ "AAPL" ];
      commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 };
    }
  in
  let str = show_config cfg in
  assert_bool "Show should contain initial_cash"
    (String.is_substring str ~substring:"100000")

(* ==================== Test Suite ==================== *)

let suite =
  "Simulation Types Tests"
  >::: [
         (* symbol_prices *)
         "symbol_prices construction" >:: test_symbol_prices_construction;
         "symbol_prices equality" >:: test_symbol_prices_equality;
         "symbol_prices show" >:: test_symbol_prices_show;
         (* config *)
         "config construction" >:: test_config_construction;
         "config equality" >:: test_config_equality;
         "config show" >:: test_config_show;
       ]

let () = run_test_tt_main suite
