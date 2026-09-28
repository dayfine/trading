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
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.ticker) (equal_to "AAPL");
             field (fun o -> o.side) (equal_to Trading_base.Types.Buy);
             field (fun o -> o.shares) (equal_to 100);
           ];
       ])

(* Disarmed default (entry_extension_max_pct = 0.0): the limit collapses onto
   the trigger — the degenerate StopLimit (E, E) the generator emitted before
   #2158, so a default live run is byte-identical. *)
let test_create_entering_long_disarmed_is_zero_width_band _ =
  let t =
    _create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL" ~side:Long
      ~quantity:100.0 ~entry_price:155.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
  assert_that orders
    (elements_are
       [
         field
           (fun o -> o.order_type)
           (equal_to (Trading_base.Types.StopLimit (155.0, 155.0)));
       ])

(* Armed: the limit sits one extension above the trigger for a long — a
   do-not-chase ceiling. 10% above 155.0 = 170.5. *)
let test_create_entering_long_armed_caps_limit_above_trigger _ =
  let t =
    _create_entering_transition ~position_id:"AAPL-1" ~symbol:"AAPL" ~side:Long
      ~quantity:100.0 ~entry_price:155.0
  in
  let orders =
    from_transitions ~entry_extension_max_pct:10.0 ~transitions:[ t ]
      ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         field
           (fun o -> o.order_type)
           (equal_to (Trading_base.Types.StopLimit (155.0, 170.5)));
       ])

let test_create_entering_short_emits_stoplimit_sell _ =
  let t =
    _create_entering_transition ~position_id:"TSLA-1" ~symbol:"TSLA" ~side:Short
      ~quantity:30.0 ~entry_price:200.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.ticker) (equal_to "TSLA");
             field (fun o -> o.side) (equal_to Trading_base.Types.Sell);
             field (fun o -> o.shares) (equal_to 30);
           ];
       ])

(* Armed short: the cap mirrors below the trigger — 10% below 200.0 = 180.0. *)
let test_create_entering_short_armed_caps_limit_below_trigger _ =
  let t =
    _create_entering_transition ~position_id:"TSLA-1" ~symbol:"TSLA" ~side:Short
      ~quantity:30.0 ~entry_price:200.0
  in
  let orders =
    from_transitions ~entry_extension_max_pct:10.0 ~transitions:[ t ]
      ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         field
           (fun o -> o.order_type)
           (equal_to (Trading_base.Types.StopLimit (200.0, 180.0)));
       ])

(* --- TriggerExit → no broker order (GTC stop already at broker) --- *)

let test_trigger_exit_produces_no_order _ =
  (* The Stop order placed by UpdateRiskParams is already working at the
     broker as a GTC order. TriggerExit is internal accounting only — no
     additional order should be sent. *)
  let t = _trigger_exit_transition ~position_id:"AAPL-1" ~exit_price:138.0 in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
  assert_that orders (size_is 0)

(* --- UpdateRiskParams → Stop order --- *)

let test_update_risk_with_stop_emits_stop_order _ =
  let t =
    _update_risk_transition ~position_id:"AAPL-1" ~stop_loss_price:142.0
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
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
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
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
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
  assert_that orders (size_is 0)

let test_exit_complete_is_ignored _ =
  let t =
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2024-01-10";
      kind = Position.ExitComplete;
    }
  in
  let orders = from_transitions ~transitions:[ t ] ~get_position:_lookup () in
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
  let orders =
    from_transitions ~transitions:[ t1; t2 ] ~get_position:_lookup ()
  in
  assert_that orders (size_is 2)

(* --- Empty transitions → empty result --- *)

let test_empty_transitions_returns_empty _ =
  let orders = from_transitions ~transitions:[] ~get_position:_lookup () in
  assert_that orders (size_is 0)

(* --- Stop sync (issue #2984): broker stops sourced from stop-level snapshots
   --- *)

let _entry_complete_transition ~position_id =
  {
    Position.position_id;
    date = Date.of_string "2024-01-05";
    kind =
      Position.EntryComplete
        {
          risk_params =
            {
              Position.stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
  }

(** Level lookup that knows one ticker. *)
let _level_of ~symbol level ticker =
  if String.equal ticker symbol then Some level else None

let _aapl_sync ~before ~after =
  {
    positions = [ _aapl_position ];
    stop_level_before = _level_of ~symbol:"AAPL" before;
    stop_level_after = _level_of ~symbol:"AAPL" after;
  }

(* Entry fill: the stop level was installed when the entry was placed, so it
   does not move this tick — the entry fill alone must put the initial stop at
   the broker. *)
let test_sync_entry_fill_emits_initial_stop _ =
  let orders =
    from_transitions
      ~stop_sync:(_aapl_sync ~before:140.0 ~after:140.0)
      ~transitions:[ _entry_complete_transition ~position_id:"AAPL-1" ]
      ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.ticker) (equal_to "AAPL");
             field (fun o -> o.side) (equal_to Trading_base.Types.Sell);
             field (fun o -> o.shares) (equal_to 50);
             field
               (fun o -> o.order_type)
               (equal_to (Trading_base.Types.Stop 140.0));
           ];
       ])

(* A partial entry fill protects only the shares filled so far. *)
let test_sync_partial_entry_fill_sizes_to_filled _ =
  let entering =
    {
      _aapl_position with
      state =
        Position.Entering
          {
            target_quantity = 100.0;
            entry_price = 150.0;
            filled_quantity = 20.0;
            created_date = Date.of_string "2024-01-04";
          };
    }
  in
  let fill =
    {
      Position.position_id = "AAPL-1";
      date = Date.of_string "2024-01-05";
      kind = Position.EntryFill { filled_quantity = 20.0; fill_price = 150.0 };
    }
  in
  let orders =
    from_transitions
      ~stop_sync:
        {
          (_aapl_sync ~before:140.0 ~after:140.0) with
          positions = [ entering ];
        }
      ~transitions:[ fill ] ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.shares) (equal_to 20);
             field
               (fun o -> o.order_type)
               (equal_to (Trading_base.Types.Stop 140.0));
           ];
       ])

(* A tightening (or split rescale) moves the installed level with no
   transition: the sync must still send the stop modify. *)
let test_sync_level_move_without_transition_emits_stop _ =
  let orders =
    from_transitions
      ~stop_sync:(_aapl_sync ~before:140.0 ~after:145.0)
      ~transitions:[] ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.side) (equal_to Trading_base.Types.Sell);
             field (fun o -> o.shares) (equal_to 50);
             field
               (fun o -> o.order_type)
               (equal_to (Trading_base.Types.Stop 145.0));
           ];
       ])

let test_sync_unchanged_level_emits_nothing _ =
  let orders =
    from_transitions
      ~stop_sync:(_aapl_sync ~before:140.0 ~after:140.0)
      ~transitions:[] ~get_position:_lookup ()
  in
  assert_that orders (size_is 0)

(* The same move reported both by UpdateRiskParams and by the level diff yields
   one Stop order, not two. *)
let test_sync_no_duplicate_with_update_risk_params _ =
  let orders =
    from_transitions
      ~stop_sync:(_aapl_sync ~before:140.0 ~after:145.0)
      ~transitions:
        [ _update_risk_transition ~position_id:"AAPL-1" ~stop_loss_price:145.0 ]
      ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         field
           (fun o -> o.order_type)
           (equal_to (Trading_base.Types.Stop 145.0));
       ])

(* Short mirror: the protective stop is a Buy stop above the short entry. *)
let test_sync_short_entry_fill_emits_buy_stop _ =
  let short_pos =
    _make_holding_position ~id:"TSLA-1" ~symbol:"TSLA" ~side:Position.Short
      ~quantity:30.0 ~entry_price:200.0
  in
  let orders =
    from_transitions
      ~stop_sync:
        {
          positions = [ short_pos ];
          stop_level_before = _level_of ~symbol:"TSLA" 216.0;
          stop_level_after = _level_of ~symbol:"TSLA" 216.0;
        }
      ~transitions:[ _entry_complete_transition ~position_id:"TSLA-1" ]
      ~get_position:_lookup ()
  in
  assert_that orders
    (elements_are
       [
         all_of
           [
             field (fun o -> o.ticker) (equal_to "TSLA");
             field (fun o -> o.side) (equal_to Trading_base.Types.Buy);
             field (fun o -> o.shares) (equal_to 30);
             field
               (fun o -> o.order_type)
               (equal_to (Trading_base.Types.Stop 216.0));
           ];
       ])

(* Opt-in: without [~stop_sync] an entry fill still produces no order
   (pre-#2984 behaviour for existing callers). *)
let test_no_sync_entry_complete_is_ignored _ =
  let orders =
    from_transitions
      ~transitions:[ _entry_complete_transition ~position_id:"AAPL-1" ]
      ~get_position:_lookup ()
  in
  assert_that orders (size_is 0)

let suite =
  "order_gen"
  >::: [
         "create_entering_long_emits_stoplimit_buy"
         >:: test_create_entering_long_emits_stoplimit_buy;
         "create_entering_long_disarmed_is_zero_width_band"
         >:: test_create_entering_long_disarmed_is_zero_width_band;
         "create_entering_long_armed_caps_limit_above_trigger"
         >:: test_create_entering_long_armed_caps_limit_above_trigger;
         "create_entering_short_emits_stoplimit_sell"
         >:: test_create_entering_short_emits_stoplimit_sell;
         "create_entering_short_armed_caps_limit_below_trigger"
         >:: test_create_entering_short_armed_caps_limit_below_trigger;
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
         "sync_entry_fill_emits_initial_stop"
         >:: test_sync_entry_fill_emits_initial_stop;
         "sync_partial_entry_fill_sizes_to_filled"
         >:: test_sync_partial_entry_fill_sizes_to_filled;
         "sync_level_move_without_transition_emits_stop"
         >:: test_sync_level_move_without_transition_emits_stop;
         "sync_unchanged_level_emits_nothing"
         >:: test_sync_unchanged_level_emits_nothing;
         "sync_no_duplicate_with_update_risk_params"
         >:: test_sync_no_duplicate_with_update_risk_params;
         "sync_short_entry_fill_emits_buy_stop"
         >:: test_sync_short_entry_fill_emits_buy_stop;
         "no_sync_entry_complete_is_ignored"
         >:: test_no_sync_entry_complete_is_ignored;
       ]

let () = run_test_tt_main suite
