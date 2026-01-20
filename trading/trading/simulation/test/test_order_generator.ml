(** Tests for Order Generator module *)

open OUnit2
open Core
open Trading_simulation.Order_generator
open Trading_strategy.Position
open Matchers

let today = Date.of_string "2024-01-15"
let empty_positions = String.Map.empty

type order_essentials = {
  symbol : string;
  side : Trading_base.Types.side;
  order_type : Trading_base.Types.order_type;
  quantity : float;
  time_in_force : Trading_orders.Types.time_in_force;
}
[@@deriving show, eq] [@@warning "-69"]
(** Essential order fields for comparison (ignoring id, timestamps) *)

let order_essentials (o : Trading_orders.Types.order) : order_essentials =
  {
    symbol = o.symbol;
    side = o.side;
    order_type = o.order_type;
    quantity = o.quantity;
    time_in_force = o.time_in_force;
  }

let make_create_entering_transition ~position_id ~symbol ~quantity ~price =
  {
    position_id;
    date = today;
    kind =
      CreateEntering
        {
          symbol;
          target_quantity = quantity;
          entry_price = price;
          reasoning =
            TechnicalSignal { indicator = "EMA"; description = "test" };
        };
  }

let make_trigger_exit_transition ~position_id ~exit_price =
  {
    position_id;
    date = today;
    kind =
      TriggerExit
        {
          exit_reason = SignalReversal { description = "EMA crossover down" };
          exit_price;
        };
  }

let make_entry_fill_transition ~position_id ~quantity ~price =
  {
    position_id;
    date = today;
    kind = EntryFill { filled_quantity = quantity; fill_price = price };
  }

let make_entry_complete_transition ~position_id =
  {
    position_id;
    date = today;
    kind =
      EntryComplete
        {
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

(** Helper to create a position in Holding state *)
let make_holding_position ~position_id ~symbol ~quantity ~price =
  let create_trans =
    make_create_entering_transition ~position_id ~symbol ~quantity ~price
  in
  let pos = create_entering create_trans |> Result.ok |> Option.value_exn in
  let fill_trans = make_entry_fill_transition ~position_id ~quantity ~price in
  let pos = apply_transition pos fill_trans |> Result.ok |> Option.value_exn in
  let complete_trans = make_entry_complete_transition ~position_id in
  apply_transition pos complete_trans |> Result.ok |> Option.value_exn

(** Helper to create a position in Exiting state (for TriggerExit order tests).
    In the actual simulator, the TriggerExit transition is applied before
    order_generator is called, so the position is in Exiting state. *)
let make_exiting_position ~position_id ~symbol ~quantity ~price ~exit_price =
  let holding_pos =
    make_holding_position ~position_id ~symbol ~quantity ~price
  in
  let exit_trans = make_trigger_exit_transition ~position_id ~exit_price in
  apply_transition holding_pos exit_trans |> Result.ok |> Option.value_exn

(* ==================== transitions_to_orders tests ==================== *)

let test_empty_transitions_returns_empty_orders _ =
  let result = transitions_to_orders ~positions:empty_positions [] in
  assert_that result (is_ok_and_holds (elements_are []))

let test_create_entering_generates_buy_order _ =
  let transitions =
    [
      make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
        ~quantity:100.0 ~price:150.0;
    ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            (fun o ->
              assert_that (order_essentials o)
                (equal_to
                   ({
                      symbol = "AAPL";
                      side = Buy;
                      order_type = Market;
                      quantity = 100.0;
                      time_in_force = Day;
                    }
                     : order_essentials)));
          ]))

let test_trigger_exit_no_position_returns_empty _ =
  let transitions =
    [ make_trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:155.0 ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result (is_ok_and_holds (elements_are []))

let test_trigger_exit_with_position_generates_sell_order _ =
  (* In the simulator, TriggerExit transition is applied before order_generator
     is called, so the position is in Exiting state when we generate orders. *)
  let position =
    make_exiting_position ~position_id:"AAPL-1" ~symbol:"AAPL" ~quantity:100.0
      ~price:150.0 ~exit_price:155.0
  in
  let positions = String.Map.singleton "AAPL-1" position in
  let transitions =
    [ make_trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:155.0 ]
  in
  let result = transitions_to_orders ~positions transitions in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            (fun o ->
              assert_that (order_essentials o)
                (equal_to
                   ({
                      symbol = "AAPL";
                      side = Sell;
                      order_type = Market;
                      quantity = 100.0;
                      time_in_force = Day;
                    }
                     : order_essentials)));
          ]))

let test_entry_fill_returns_no_orders _ =
  let transitions =
    [
      make_entry_fill_transition ~position_id:"AAPL-1" ~quantity:50.0
        ~price:150.5;
    ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result (is_ok_and_holds (elements_are []))

let test_entry_complete_returns_no_orders _ =
  let transitions = [ make_entry_complete_transition ~position_id:"AAPL-1" ] in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result (is_ok_and_holds (elements_are []))

let test_multiple_create_entering_generates_multiple_orders _ =
  let transitions =
    [
      make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
        ~quantity:100.0 ~price:150.0;
      make_create_entering_transition ~position_id:"GOOGL-1" ~symbol:"GOOGL"
        ~quantity:50.0 ~price:140.0;
    ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            (fun o ->
              assert_that (order_essentials o)
                (equal_to
                   ({
                      symbol = "AAPL";
                      side = Buy;
                      order_type = Market;
                      quantity = 100.0;
                      time_in_force = Day;
                    }
                     : order_essentials)));
            (fun o ->
              assert_that (order_essentials o)
                (equal_to
                   ({
                      symbol = "GOOGL";
                      side = Buy;
                      order_type = Market;
                      quantity = 50.0;
                      time_in_force = Day;
                    }
                     : order_essentials)));
          ]))

let test_mixed_transitions_filters_non_order_generating _ =
  (* Without positions, only CreateEntering generates orders *)
  let transitions =
    [
      make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
        ~quantity:100.0 ~price:150.0;
      make_entry_fill_transition ~position_id:"AAPL-1" ~quantity:100.0
        ~price:150.25;
      make_entry_complete_transition ~position_id:"AAPL-1";
      make_trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:155.0;
    ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result
    (is_ok_and_holds
       (elements_are
          [
            (fun o ->
              assert_that (order_essentials o)
                (equal_to
                   ({
                      symbol = "AAPL";
                      side = Buy;
                      order_type = Market;
                      quantity = 100.0;
                      time_in_force = Day;
                    }
                     : order_essentials)));
          ]))

let suite =
  "Order Generator Tests"
  >::: [
         "test_empty_transitions_returns_empty_orders"
         >:: test_empty_transitions_returns_empty_orders;
         "test_create_entering_generates_buy_order"
         >:: test_create_entering_generates_buy_order;
         "test_trigger_exit_no_position_returns_empty"
         >:: test_trigger_exit_no_position_returns_empty;
         "test_trigger_exit_with_position_generates_sell_order"
         >:: test_trigger_exit_with_position_generates_sell_order;
         "test_entry_fill_returns_no_orders"
         >:: test_entry_fill_returns_no_orders;
         "test_entry_complete_returns_no_orders"
         >:: test_entry_complete_returns_no_orders;
         "test_multiple_create_entering_generates_multiple_orders"
         >:: test_multiple_create_entering_generates_multiple_orders;
         "test_mixed_transitions_filters_non_order_generating"
         >:: test_mixed_transitions_filters_non_order_generating;
       ]

let () = run_test_tt_main suite
