open OUnit2
open Core
open Matchers
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Indicator_panels = Data_panel.Indicator_panels
module Indicator_spec = Data_panel.Indicator_spec
module Get_indicator_adapter = Data_panel.Get_indicator_adapter
module BA2 = Bigarray.Array2

let _make_idx universe =
  match Symbol_index.create ~universe with
  | Ok t -> t
  | Error err -> assert_failure err.Status.message

let _setup ~n_days =
  let idx = _make_idx [ "AAA"; "BBB" ] in
  let ohlcv = Ohlcv_panels.create idx ~n_days in
  let close = Ohlcv_panels.close ohlcv in
  for t = 0 to n_days - 1 do
    BA2.unsafe_set close 0 t (100.0 +. Float.of_int t);
    BA2.unsafe_set close 1 t (200.0 +. Float.of_int t)
  done;
  let panels =
    Indicator_panels.create ~symbol_index:idx ~n_days
      ~specs:[ { name = "SMA"; period = 5; cadence = Daily } ]
  in
  for tick = 0 to n_days - 1 do
    Indicator_panels.advance_all panels ~ohlcv ~t:tick
  done;
  panels

let test_known_symbol_returns_value _ =
  let panels = _setup ~n_days:20 in
  (* SMA-5 of [100..119], window ending at t=10: mean of 106..110 = 108. *)
  let get = Get_indicator_adapter.make panels ~t:10 in
  assert_that (get "AAA" "SMA" 5 Daily) (is_some_and (float_equal 108.0))

let test_unknown_symbol_returns_none _ =
  let panels = _setup ~n_days:20 in
  let get = Get_indicator_adapter.make panels ~t:10 in
  assert_that (get "ZZZ" "SMA" 5 Daily) is_none

let test_unregistered_spec_returns_none _ =
  let panels = _setup ~n_days:20 in
  let get = Get_indicator_adapter.make panels ~t:10 in
  (* EMA was not registered. *)
  assert_that (get "AAA" "EMA" 50 Daily) is_none

let test_warmup_nan_returns_none _ =
  let panels = _setup ~n_days:20 in
  let get = Get_indicator_adapter.make panels ~t:0 in
  (* SMA-5 at t=0 is NaN (warmup region). *)
  assert_that (get "AAA" "SMA" 5 Daily) is_none

let test_cursor_advance _ =
  (* Build the adapter twice with different [t] values; values must differ. *)
  let panels = _setup ~n_days:20 in
  let get_at_t (t : int) = Get_indicator_adapter.make panels ~t in
  let v_5 = (get_at_t 5) "AAA" "SMA" 5 Daily in
  let v_10 = (get_at_t 10) "AAA" "SMA" 5 Daily in
  assert_that (v_5, v_10)
    (pair (is_some_and (float_equal 103.0)) (is_some_and (float_equal 108.0)))

let suite =
  "Get_indicator_adapter tests"
  >::: [
         "test_known_symbol_returns_value" >:: test_known_symbol_returns_value;
         "test_unknown_symbol_returns_none" >:: test_unknown_symbol_returns_none;
         "test_unregistered_spec_returns_none"
         >:: test_unregistered_spec_returns_none;
         "test_warmup_nan_returns_none" >:: test_warmup_nan_returns_none;
         "test_cursor_advance" >:: test_cursor_advance;
       ]

let () = run_test_tt_main suite
