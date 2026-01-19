(** Tests for Order Generator module *)

open OUnit2
open Core
open Trading_simulation.Order_generator
open Trading_strategy.Position
open Matchers

let today = Date.of_string "2024-01-15"
let empty_positions = String.Map.empty

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

(* ==================== transition_to_order tests ==================== *)

let test_create_entering_generates_buy_order _ =
  let transition =
    make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
      ~quantity:100.0 ~price:150.0
  in
  let result = transition_to_order ~positions:empty_positions transition in
  assert_that result
    (is_ok_and_holds
       (is_some_and (fun order ->
            assert_that order.Trading_orders.Types.symbol (equal_to "AAPL");
            assert_that order.side (equal_to Trading_base.Types.Buy);
            assert_that order.order_type (equal_to Trading_base.Types.Market);
            assert_that order.quantity (float_equal 100.0);
            assert_that order.time_in_force (equal_to Trading_orders.Types.Day))))

let test_trigger_exit_no_position_returns_none _ =
  (* TriggerExit without a matching position returns None *)
  let transition =
    make_trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:155.0
  in
  let result = transition_to_order ~positions:empty_positions transition in
  assert_that result (is_ok_and_holds is_none)

let test_trigger_exit_with_position_generates_sell_order _ =
  (* Create a position in Holding state *)
  let create_transition =
    make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
      ~quantity:100.0 ~price:150.0
  in
  let position =
    create_entering create_transition |> Result.ok |> Option.value_exn
  in
  (* Apply fills to move to Holding *)
  let fill_transition =
    {
      position_id = "AAPL-1";
      date = today;
      kind = EntryFill { filled_quantity = 100.0; fill_price = 150.0 };
    }
  in
  let position =
    apply_transition position fill_transition |> Result.ok |> Option.value_exn
  in
  let complete_transition =
    {
      position_id = "AAPL-1";
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
  in
  let position =
    apply_transition position complete_transition
    |> Result.ok |> Option.value_exn
  in
  let positions = String.Map.singleton "AAPL-1" position in
  (* Now test TriggerExit *)
  let exit_transition =
    make_trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:155.0
  in
  let result = transition_to_order ~positions exit_transition in
  assert_that result
    (is_ok_and_holds
       (is_some_and (fun order ->
            assert_that order.Trading_orders.Types.symbol (equal_to "AAPL");
            assert_that order.side (equal_to Trading_base.Types.Sell);
            assert_that order.order_type (equal_to Trading_base.Types.Market);
            assert_that order.quantity (float_equal 100.0))))

let test_entry_fill_returns_none _ =
  let transition =
    make_entry_fill_transition ~position_id:"AAPL-1" ~quantity:50.0 ~price:150.5
  in
  let result = transition_to_order ~positions:empty_positions transition in
  assert_that result (is_ok_and_holds is_none)

let test_entry_complete_returns_none _ =
  let transition = make_entry_complete_transition ~position_id:"AAPL-1" in
  let result = transition_to_order ~positions:empty_positions transition in
  assert_that result (is_ok_and_holds is_none)

(* ==================== transitions_to_orders tests ==================== *)

let test_empty_transitions_returns_empty_orders _ =
  let result = transitions_to_orders ~positions:empty_positions [] in
  assert_that result
    (is_ok_and_holds (fun orders ->
         assert_that (List.length orders) (equal_to 0)))

let test_single_create_entering_generates_one_order _ =
  let transitions =
    [
      make_create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL"
        ~quantity:100.0 ~price:150.0;
    ]
  in
  let result = transitions_to_orders ~positions:empty_positions transitions in
  assert_that result
    (is_ok_and_holds (fun orders ->
         assert_that (List.length orders) (equal_to 1);
         let order = List.hd_exn orders in
         assert_that order.Trading_orders.Types.symbol (equal_to "AAPL");
         assert_that order.Trading_orders.Types.quantity (float_equal 100.0)))

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
    (is_ok_and_holds (fun orders ->
         assert_that (List.length orders) (equal_to 2);
         let symbols =
           List.map orders ~f:(fun o -> o.Trading_orders.Types.symbol)
           |> List.sort ~compare:String.compare
         in
         assert_that symbols (equal_to [ "AAPL"; "GOOGL" ])))

let test_mixed_transitions_filters_non_order_generating _ =
  (* Without positions, TriggerExit won't generate orders *)
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
    (is_ok_and_holds (fun orders ->
         (* Only CreateEntering generates an order; TriggerExit needs position *)
         assert_that (List.length orders) (equal_to 1);
         assert_that (List.hd_exn orders).Trading_orders.Types.symbol
           (equal_to "AAPL")))

let suite =
  "Order Generator Tests"
  >::: [
         "test_create_entering_generates_buy_order"
         >:: test_create_entering_generates_buy_order;
         "test_trigger_exit_no_position_returns_none"
         >:: test_trigger_exit_no_position_returns_none;
         "test_trigger_exit_with_position_generates_sell_order"
         >:: test_trigger_exit_with_position_generates_sell_order;
         "test_entry_fill_returns_none" >:: test_entry_fill_returns_none;
         "test_entry_complete_returns_none" >:: test_entry_complete_returns_none;
         "test_empty_transitions_returns_empty_orders"
         >:: test_empty_transitions_returns_empty_orders;
         "test_single_create_entering_generates_one_order"
         >:: test_single_create_entering_generates_one_order;
         "test_multiple_create_entering_generates_multiple_orders"
         >:: test_multiple_create_entering_generates_multiple_orders;
         "test_mixed_transitions_filters_non_order_generating"
         >:: test_mixed_transitions_filters_non_order_generating;
       ]

let () = run_test_tt_main suite
