open OUnit2
open Core
open Matchers
open Weinstein_order_gen
open Trading_strategy

(** Helper to build a minimal Position.t in Holding state for lookup. *)
let _make_holding_position ~id ~symbol ~side ~quantity ~entry_price =
  {
    Position.id;
    symbol;
    side;
    entry_reasoning =
      Position.TechnicalSignal { indicator = "SMA"; description = "stage 2" };
    exit_reason = None;
    state =
      Position.Holding
        {
          quantity;
          entry_price;
          entry_date = Date.of_string "2024-01-01";
          risk_params =
            {
              Position.stop_loss_price = Some (entry_price *. 0.92);
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = Date.of_string "2024-01-01";
    portfolio_lot_ids = [];
  }

(** Helper to build a CreateEntering transition. *)
let _create_entering_transition ~position_id ~symbol ~side ~quantity
    ~entry_price =
  {
    Position.position_id;
    date = Date.of_string "2024-01-05";
    kind =
      Position.CreateEntering
        {
          symbol;
          side;
          target_quantity = quantity;
          entry_price;
          reasoning =
            Position.TechnicalSignal
              { indicator = "SMA30"; description = "stage 2 breakout" };
        };
  }

(** Helper to build a TriggerExit transition. *)
let _trigger_exit_transition ~position_id ~exit_price =
  {
    Position.position_id;
    date = Date.of_string "2024-01-10";
    kind =
      Position.TriggerExit
        {
          exit_reason =
            Position.StopLoss
              {
                stop_price = exit_price;
                actual_price = exit_price;
                loss_percent = 0.08;
              };
          exit_price;
        };
  }

(** Helper to build an UpdateRiskParams transition. *)
let _update_risk_transition ~position_id ~stop_loss_price =
  {
    Position.position_id;
    date = Date.of_string "2024-01-07";
    kind =
      Position.UpdateRiskParams
        {
          new_risk_params =
            {
              Position.stop_loss_price = Some stop_loss_price;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

(** Lookup that has one known AAPL position. *)
let _aapl_position =
  _make_holding_position ~id:"AAPL-1" ~symbol:"AAPL" ~side:Position.Long
    ~quantity:50.0 ~entry_price:150.0

let _lookup position_id =
  if String.equal position_id "AAPL-1" then Some _aapl_position else None

(* --- CreateEntering → StopLimit buy --- *)

let test_create_entering_long_emits_stoplimit_buy _ =
  let t =
    _create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL" ~side:Long
      ~quantity:100.0 ~entry_price:155.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders
    (elements_are
       [
         (fun o ->
           assert_that o.ticker (equal_to "AAPL");
           assert_that o.side (equal_to Trading_base.Types.Buy);
           assert_that o.shares (equal_to 100));
       ])

let test_create_entering_long_order_type_is_stoplimit _ =
  let t =
    _create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL" ~side:Long
      ~quantity:100.0 ~entry_price:155.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders
    (elements_are
       [
         (fun o ->
           assert_that o.order_type
             (matching ~msg:"Expected StopLimit"
                (function
                  | Trading_base.Types.StopLimit _ -> Some () | _ -> None)
                (equal_to ())));
       ])

let test_create_entering_short_emits_stoplimit_sell _ =
  let t =
    _create_entering_transition ~position_id:"TSLA-1" ~symbol:"TSLA" ~side:Short
      ~quantity:30.0 ~entry_price:200.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders
    (elements_are
       [
         (fun o ->
           assert_that o.ticker (equal_to "TSLA");
           assert_that o.side (equal_to Trading_base.Types.Sell);
           assert_that o.shares (equal_to 30));
       ])

(* --- TriggerExit → no broker order (GTC stop already at broker) --- *)

let test_trigger_exit_produces_no_order _ =
  (* The Stop order placed by UpdateRiskParams is already working at the
     broker as a GTC order. TriggerExit is internal accounting only — no
     additional order should be sent. *)
  let t = _trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:138.0 in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders (size_is 0)

(* --- UpdateRiskParams → Stop order --- *)

let test_update_risk_with_stop_emits_stop_order _ =
  let t =
    _update_risk_transition ~position_id:"AAPL-1" ~stop_loss_price:142.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders
    (elements_are
       [
         (fun o ->
           assert_that o.ticker (equal_to "AAPL");
           assert_that o.side (equal_to Trading_base.Types.Sell);
           assert_that o.shares (equal_to 50));
       ])

let test_update_risk_no_stop_returns_empty _ =
  let t =
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2024-01-07";
      kind =
        Position.UpdateRiskParams
          {
            new_risk_params =
              {
                Position.stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders (size_is 0)

(* --- Simulator-internal transitions → ignored --- *)

let test_entry_fill_is_ignored _ =
  let t =
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2024-01-05";
      kind = Position.EntryFill { filled_quantity = 50.0; fill_price = 155.0 };
    }
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders (size_is 0)

let test_exit_complete_is_ignored _ =
  let t =
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2024-01-10";
      kind = Position.ExitComplete;
    }
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup in
  assert_that orders (size_is 0)

(* --- Multiple transitions in one call --- *)

let test_multiple_transitions_produce_one_order_each _ =
  let t1 =
    _create_entering_transition ~position_id:"AAPL-2" ~symbol:"AAPL" ~side:Long
      ~quantity:20.0 ~entry_price:160.0
  in
  let t2 =
    _update_risk_transition ~position_id:"AAPL-1" ~stop_loss_price:142.0
  in
  let orders = from_transitions ~transitions:[ t1; t2 ] ~get_position:_lookup in
  assert_that orders (size_is 2)

(* --- Empty transitions → empty result --- *)

let test_empty_transitions_returns_empty _ =
  let orders = from_transitions ~transitions:[] ~get_position:_lookup in
  assert_that orders (size_is 0)

let suite =
  "order_gen"
  >::: [
         "create_entering_long_emits_stoplimit_buy"
         >:: test_create_entering_long_emits_stoplimit_buy;
         "create_entering_long_order_type_is_stoplimit"
         >:: test_create_entering_long_order_type_is_stoplimit;
         "create_entering_short_emits_stoplimit_sell"
         >:: test_create_entering_short_emits_stoplimit_sell;
         "trigger_exit_produces_no_order"
         >:: test_trigger_exit_produces_no_order;
         "update_risk_with_stop_emits_stop_order"
         >:: test_update_risk_with_stop_emits_stop_order;
         "update_risk_no_stop_returns_empty"
         >:: test_update_risk_no_stop_returns_empty;
         "entry_fill_is_ignored" >:: test_entry_fill_is_ignored;
         "exit_complete_is_ignored" >:: test_exit_complete_is_ignored;
         "multiple_transitions_produce_one_order_each"
         >:: test_multiple_transitions_produce_one_order_each;
         "empty_transitions_returns_empty"
         >:: test_empty_transitions_returns_empty;
       ]

let () = run_test_tt_main suite
