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
(* Helpers for position construction                                    *)
(* ------------------------------------------------------------------ *)

let make_holding_pos ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(* ------------------------------------------------------------------ *)
(* initial_stop_states: stop hit emits TriggerExit                     *)
(* ------------------------------------------------------------------ *)

let test_stop_hit_emits_trigger_exit _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  (* Seed a stop at 90.0 so a bar with low=85 crosses it *)
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  (* Bar with low below stop level — should trigger exit *)
  let bar =
    { (make_bar "2024-01-12" 95.0) with Types.Daily_price.low_price = 85.0 }
  in
  let result =
    S.on_market_close
      ~get_price:
        (get_price_of
           [ (ticker, bar); ("GSPCX", make_bar "2024-01-12" 4500.0) ])
      ~get_indicator:empty_get_indicator ~positions
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          (elements_are
             [
               (fun tr ->
                 assert_that tr.Trading_strategy.Position.position_id
                   (equal_to ticker);
                 assert_that tr.Trading_strategy.Position.kind
                   (matching
                      (function
                        | Trading_strategy.Position.TriggerExit _ -> Some ()
                        | _ -> None)
                      (equal_to ())));
             ])))

(* ------------------------------------------------------------------ *)
(* stop hit on non-Friday: stops fire daily, not just on Fridays        *)
(* ------------------------------------------------------------------ *)

let test_stop_fires_on_non_friday _ =
  let ticker = "AAPL" in
  let date = Date.of_string "2024-01-05" in
  let stop_state =
    Weinstein_stops.Initial { stop_level = 90.0; reference_level = 95.0 }
  in
  let initial_stop_states = String.Map.singleton ticker stop_state in
  let (module S) = make ~initial_stop_states cfg in
  let pos = make_holding_pos ticker 100.0 date in
  let positions = String.Map.singleton ticker pos in
  (* 2024-01-09 is a Tuesday — stops should still fire *)
  let bar =
    { (make_bar "2024-01-09" 95.0) with Types.Daily_price.low_price = 85.0 }
  in
  let result =
    S.on_market_close
      ~get_price:
        (get_price_of
           [ (ticker, bar); ("GSPCX", make_bar "2024-01-09" 4500.0) ])
      ~get_indicator:empty_get_indicator ~positions
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun o -> o.Trading_strategy.Strategy_interface.transitions)
          (elements_are
             [
               (fun tr ->
                 assert_that tr.Trading_strategy.Position.position_id
                   (equal_to ticker);
                 assert_that tr.Trading_strategy.Position.kind
                   (matching
                      (function
                        | Trading_strategy.Position.TriggerExit _ -> Some ()
                        | _ -> None)
                      (equal_to ())));
             ])))

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
           "stop hit emits trigger exit" >:: test_stop_hit_emits_trigger_exit;
           "stop fires on non-Friday" >:: test_stop_fires_on_non_friday;
         ])
