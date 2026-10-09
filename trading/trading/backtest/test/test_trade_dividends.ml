(** Unit tests for {!Backtest.Trade_dividends} and the [dividends_received]
    column of [trades.csv] (issue #3175).

    Specimen shape: an AD-like $23 special held through its ex-date, so the
    price-only [pnl_dollars] is a loss while the dividend is a large credit. *)

open Core
open OUnit2
open Matchers
module Trade_dividends = Backtest.Trade_dividends
module Trades_stream = Backtest.Trades_stream
module Metrics = Trading_simulation.Metrics

let _date = Date.of_string

let _div ?amount ex : Corporate_actions.dividend =
  { ex_date = _date ex; unadjusted_amount = amount; adjusted_amount = 0.0 }

let _trip ~symbol ~side ~quantity ~entry ~exit_ : Metrics.trade_metrics =
  {
    symbol;
    side;
    entry_date = _date entry;
    exit_date = _date exit_;
    days_held = 10;
    entry_price = 100.0;
    exit_price = 90.0;
    quantity;
    pnl_dollars = -100.0;
    pnl_percent = -10.0;
    position_id = None;
  }

let _source ?(start = "2020-01-01") divs =
  Trade_dividends.create
    ~load:(fun sym ->
      if String.equal sym "AD" then Ok divs
      else Error (Status.not_found_error "no file"))
    ~start_date:(_date start)

let _long ?(symbol = "AD") ~entry ~exit_ () =
  _trip ~symbol ~side:Trading_base.Types.Buy ~quantity:100.0 ~entry ~exit_

let test_held_through_ex_date_earns_amount_times_quantity _ =
  let src = _source [ _div ~amount:23.0 "2025-08-20" ] in
  assert_that
    (Trade_dividends.received src
       (_long ~entry:"2025-08-01" ~exit_:"2025-08-20" ()))
    (float_equal 2300.0)

let test_buy_filling_on_ex_date_earns_nothing _ =
  let src = _source [ _div ~amount:23.0 "2025-08-20" ] in
  assert_that
    (Trade_dividends.received src
       (_long ~entry:"2025-08-20" ~exit_:"2025-09-01" ()))
    (float_equal 0.0)

let test_ex_date_outside_hold_and_before_window_earn_nothing _ =
  let src =
    _source ~start:"2025-08-10"
      [ _div ~amount:1.0 "2025-08-05"; _div ~amount:2.0 "2025-09-30" ]
  in
  assert_that
    (Trade_dividends.received src
       (_long ~entry:"2025-08-01" ~exit_:"2025-09-01" ()))
    (float_equal 0.0)

let test_short_pays_the_dividend _ =
  let src = _source [ _div ~amount:6.0 "2021-12-17" ] in
  assert_that
    (Trade_dividends.received src
       (_trip ~symbol:"AD" ~side:Trading_base.Types.Sell ~quantity:50.0
          ~entry:"2021-12-01" ~exit_:"2021-12-30"))
    (float_equal (-300.0))

let test_missing_amount_missing_file_and_multiple_rows _ =
  let src =
    _source
      [
        _div "2025-08-10";
        _div ~amount:1.0 "2025-08-12";
        _div ~amount:0.5 "2025-08-15";
      ]
  in
  assert_that
    ( Trade_dividends.received src
        (_long ~entry:"2025-08-01" ~exit_:"2025-08-20" ()),
      Trade_dividends.received src
        (_long ~symbol:"NOFILE" ~entry:"2025-08-01" ~exit_:"2025-08-20" ()) )
    (equal_to (150.0, 0.0))

let _csv_with ?dividends round_trips =
  let dir = Filename_unix.temp_dir "trade_dividends_test" "" in
  Trades_stream.write_all ~output_dir:dir ?dividends
    { round_trips; stop_infos = []; audit = [] };
  let lines = In_channel.read_lines (dir ^ "/trades.csv") in
  List.iter [ "trades.csv" ] ~f:(fun f -> Core_unix.remove (dir ^ "/" ^ f));
  Core_unix.rmdir dir;
  lines

let _last_cell line = String.split ~on:',' line |> List.last_exn

let test_csv_column_is_last_and_carries_the_dividend _ =
  let trip = _long ~entry:"2025-08-01" ~exit_:"2025-08-20" () in
  let armed =
    _csv_with ~dividends:(_source [ _div ~amount:23.0 "2025-08-20" ]) [ trip ]
  in
  let off = _csv_with [ trip ] in
  assert_that
    ( _last_cell (List.nth_exn armed 0),
      _last_cell (List.nth_exn armed 1),
      _last_cell (List.nth_exn off 1) )
    (equal_to ("dividends_received", "2300.00", "0.00"))

(* Crediting armed (the default since the rebaseline-v12 flip), a short with
   no dividend in its hold prints ["0.00"], not ["-0.00"]. *)
let test_short_without_dividend_prints_plain_zero _ =
  let short =
    _trip ~symbol:"NOFILE" ~side:Trading_base.Types.Sell ~quantity:50.0
      ~entry:"2021-12-01" ~exit_:"2021-12-30"
  in
  let armed = _csv_with ~dividends:(_source []) [ short ] in
  assert_that (_last_cell (List.nth_exn armed 1)) (equal_to "0.00")

let suite =
  "trade_dividends"
  >::: [
         "held through ex-date earns amount x quantity"
         >:: test_held_through_ex_date_earns_amount_times_quantity;
         "buy filling on the ex-date earns nothing"
         >:: test_buy_filling_on_ex_date_earns_nothing;
         "ex-dates outside the hold or before the window earn nothing"
         >:: test_ex_date_outside_hold_and_before_window_earn_nothing;
         "a short pays the dividend" >:: test_short_pays_the_dividend;
         "missing amount, missing file, several rows"
         >:: test_missing_amount_missing_file_and_multiple_rows;
         "trades.csv column is last and carries the dividend"
         >:: test_csv_column_is_last_and_carries_the_dividend;
         "a short without a dividend prints plain zero"
         >:: test_short_without_dividend_prints_plain_zero;
       ]

let () = run_test_tt_main suite
