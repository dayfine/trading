open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date price =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = price;
    high_price = price *. 1.02;
    low_price = price *. 0.98;
    close_price = price;
    adjusted_close = price;
    volume = 1000;
  }

let get_price_of prices symbol =
  List.find_map prices ~f:(fun (sym, bar) ->
      if String.equal sym symbol then Some bar else None)

let empty_get_indicator _symbol _name _period _cadence = None
let empty_positions = String.Map.empty
let cfg = default_config ~universe:[ "AAPL"; "GSPCX" ] ~index_symbol:"GSPCX"

(* ------------------------------------------------------------------ *)
(* make: produces a STRATEGY module                                     *)
(* ------------------------------------------------------------------ *)

let test_make_produces_strategy _ =
  let (module S) = make cfg in
  assert_that S.name (equal_to "Weinstein")

(* ------------------------------------------------------------------ *)
(* on_market_close: empty universe returns empty transitions           *)
(* ------------------------------------------------------------------ *)

let test_empty_universe_no_transitions _ =
  let cfg = default_config ~universe:[] ~index_symbol:"GSPCX" in
  let (module S) = make cfg in
  let result =
    S.on_market_close ~get_price:(get_price_of [])
      ~get_indicator:empty_get_indicator ~positions:empty_positions
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          is_empty))

(* ------------------------------------------------------------------ *)
(* on_market_close: no price data returns empty transitions            *)
(* ------------------------------------------------------------------ *)

let test_no_price_data_no_transitions _ =
  let (module S) = make cfg in
  let result =
    S.on_market_close ~get_price:(get_price_of [])
      ~get_indicator:empty_get_indicator ~positions:empty_positions
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          is_empty))

(* ------------------------------------------------------------------ *)
(* on_market_close: called multiple times stays consistent             *)
(* ------------------------------------------------------------------ *)

let test_multiple_calls_consistent _ =
  let (module S) = make cfg in
  let prices =
    [
      ("GSPCX", make_bar "2024-01-05" 4500.0);
      ("AAPL", make_bar "2024-01-05" 180.0);
    ]
  in
  let get_price = get_price_of prices in
  let result1 =
    S.on_market_close ~get_price ~get_indicator:empty_get_indicator
      ~positions:empty_positions
  in
  let result2 =
    S.on_market_close ~get_price ~get_indicator:empty_get_indicator
      ~positions:empty_positions
  in
  assert_that result1 is_ok;
  assert_that result2 is_ok

(* ------------------------------------------------------------------ *)
(* name: is "Weinstein"                                                 *)
(* ------------------------------------------------------------------ *)

let test_strategy_name _ =
  let (module S) = make cfg in
  assert_that S.name (equal_to "Weinstein")

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("weinstein_strategy"
    >::: [
           "make produces strategy" >:: test_make_produces_strategy;
           "empty universe no transitions"
           >:: test_empty_universe_no_transitions;
           "no price data no transitions" >:: test_no_price_data_no_transitions;
           "multiple calls consistent" >:: test_multiple_calls_consistent;
           "strategy name" >:: test_strategy_name;
         ])
