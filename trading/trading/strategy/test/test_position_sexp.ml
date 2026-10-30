open OUnit2
open Core
open Matchers
open Trading_strategy.Position

let _risk =
  {
    stop_loss_price = Some 91.123456789012;
    take_profit_price = None;
    max_hold_days = Some 30;
  }

let _d = Date.create_exn ~y:2024 ~m:Month.Mar ~d:15

let _make state side reasoning exit_reason =
  {
    id = "AAPL-wein-1";
    symbol = "AAPL";
    side;
    entry_reasoning = reasoning;
    exit_reason;
    state;
    last_updated = _d;
    portfolio_lot_ids = [ "lot-1"; "lot-2" ];
  }

let _roundtrip (p : t) = p |> sexp_of_t |> t_of_sexp

let _positions =
  [
    _make
      (Entering
         {
           target_quantity = 100.0;
           entry_price = 123.456789012345;
           filled_quantity = 33.333333333333336;
           created_date = _d;
         })
      Long
      (TechnicalSignal { indicator = "ema"; description = "cross" })
      None;
    _make
      (Holding
         {
           quantity = 100.0;
           entry_price = 0.1 +. 0.2;
           entry_date = _d;
           risk_params = _risk;
         })
      Short (PricePattern "breakout") None;
    _make
      (Exiting
         {
           quantity = 50.0;
           entry_price = 10.0;
           entry_date = _d;
           target_quantity = 50.0;
           exit_price = 9.87654321;
           filled_quantity = 12.5;
           started_date = _d;
           risk_params = _risk;
         })
      Long Rebalancing
      (Some
         (StopLoss
            {
              stop_price = 9.9;
              actual_price = 9.87654321;
              loss_percent = -1.23456789;
            }));
    _make
      (Closed
         {
           quantity = 50.0;
           entry_price = 10.0;
           exit_price = 11.1;
           gross_pnl = Some 55.000000000001;
           entry_date = _d;
           exit_date = _d;
           days_held = 7;
         })
      Long
      (ManualDecision { description = "x" })
      (Some (StrategySignal { label = "stage3"; detail = Some "d" }));
    _make
      (Closed
         {
           quantity = 1.0;
           entry_price = 1.0;
           exit_price = 2.0;
           gross_pnl = None;
           entry_date = _d;
           exit_date = _d;
           days_held = 0;
         })
      Short Rebalancing
      (Some
         (TakeProfit
            { target_price = 2.0; actual_price = 2.0; profit_percent = 100.0 }));
  ]

let test_roundtrip _ =
  assert_that
    (List.map _positions ~f:_roundtrip)
    (equal_to (_positions : t list))

let test_other_exit_reasons _ =
  let rs =
    [
      SignalReversal { description = "r" };
      TimeExpired { days_held = 3; max_days = 5 };
      Underperforming { days_held = 9; current_return = -0.0123456789 };
      PortfolioRebalancing;
    ]
  in
  assert_that
    (List.map rs ~f:(fun r -> r |> sexp_of_exit_reason |> exit_reason_of_sexp))
    (equal_to (rs : exit_reason list))

let suite =
  "position_sexp"
  >::: [
         "roundtrip" >:: test_roundtrip;
         "other_exit_reasons" >:: test_other_exit_reasons;
       ]

let () = run_test_tt_main suite
