(** Tests for {!Trade_autopsy_lib.Trade_autopsy} exit-reason derivation: the
    final-bar force-close vs. non-final Stage 2→3 paths. *)

open Core
open OUnit2
open Matchers
module Autopsy = Trade_autopsy_lib.Trade_autopsy
module Config = Trade_autopsy_lib.Trade_autopsy_config
open Test_helpers

let test_final_bar_trade_classified_as_end_of_period _ =
  let closes = [ 100.0; 110.0; 120.0; 130.0 ] in
  let bars = mk_series ~start_date ~closes in
  let final_date = Date.add_days start_date (7 * 3) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date:final_date ~entry_price:100.0
        ~exit_price:130.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [
         field (fun a -> a.Autopsy.exit_reason) (equal_to Autopsy.End_of_period);
       ])

let test_non_final_long_trade_classified_as_stage3_exit _ =
  (* Trade ends on week 2; series extends through week 5. *)
  let closes = [ 100.0; 110.0; 120.0; 115.0; 105.0; 100.0 ] in
  let bars = mk_series ~start_date ~closes in
  let exit_date = Date.add_days start_date (7 * 2) in
  let trades =
    [
      long_trade ~entry_date:start_date ~exit_date ~entry_price:100.0
        ~exit_price:120.0;
    ]
  in
  let result =
    Autopsy.classify_trades ~config:Config.default ~symbol:"FOO"
      ~weekly_bars:bars ~trades
  in
  assert_that result
    (elements_are
       [ field (fun a -> a.Autopsy.exit_reason) (equal_to Autopsy.Stage3_exit) ])

let suite =
  "exit_reason"
  >::: [
         "final-bar trade is end_of_period"
         >:: test_final_bar_trade_classified_as_end_of_period;
         "non-final long trade is stage3_exit"
         >:: test_non_final_long_trade_classified_as_stage3_exit;
       ]

let () = run_test_tt_main suite
