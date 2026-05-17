(** Unit tests for {!Cancel_handler} — the bridge that emits [CancelEntry]
    transitions for fills rejected by the portfolio, so positions don't stay
    stuck in [Entering] forever. Pins the four contracts from
    {!Cancel_handler.mli}: matched-symbol emit, no-match drop, Closed-removal,
    and unknown-id identity. Each contract has one dedicated test below. *)

open OUnit2
open Core
open Matchers
module Cancel_handler = Trading_simulation.Cancel_handler
module Position = Trading_strategy.Position

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d
let _build_date = _date ~y:2024 ~m:Month.Jan ~d:15

(** Build an [Entering] position for [symbol] keyed by [id]. Mirrors the shape
    strategies emit via [CreateEntering] then [Position.create_entering]. *)
let _make_entering_position ~id ~symbol : Position.t =
  {
    id;
    symbol;
    side = Position.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state =
      Position.Entering
        {
          target_quantity = 100.0;
          entry_price = 50.0;
          filled_quantity = 0.0;
          created_date = _date ~y:2024 ~m:Month.Jan ~d:10;
        };
    last_updated = _date ~y:2024 ~m:Month.Jan ~d:10;
    portfolio_lot_ids = [];
  }

let _make_holding_position ~id ~symbol : Position.t =
  {
    id;
    symbol;
    side = Position.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state =
      Position.Holding
        {
          quantity = 100.0;
          entry_price = 50.0;
          entry_date = _date ~y:2024 ~m:Month.Jan ~d:10;
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _date ~y:2024 ~m:Month.Jan ~d:10;
    portfolio_lot_ids = [];
  }

let _make_trade ~symbol : Trading_base.Types.trade =
  {
    id = Printf.sprintf "%s-trade-1" symbol;
    order_id = Printf.sprintf "%s-order-1" symbol;
    symbol;
    side = Trading_base.Types.Buy;
    quantity = 100.0;
    price = 50.0;
    commission = 1.0;
    timestamp = Time_ns_unix.now ();
  }

let _positions_with ~entries : Position.t String.Map.t =
  List.fold entries ~init:String.Map.empty ~f:(fun acc (pos : Position.t) ->
      Map.set acc ~key:pos.id ~data:pos)

(** Contract 1: one [CancelEntry] transition per rejected trade, matched by
    symbol against the [Entering] position. *)
let test_transitions_for_rejected_trades_emits_per_symbol _ =
  let positions =
    _positions_with
      ~entries:
        [
          _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY";
          _make_entering_position ~id:"QQQ-pos-1" ~symbol:"QQQ";
        ]
  in
  let rejected = [ _make_trade ~symbol:"SPY"; _make_trade ~symbol:"QQQ" ] in
  let transitions =
    Cancel_handler.transitions_for_rejected_trades ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that transitions
    (elements_are
       [
         field
           (fun (t : Position.transition) -> t.position_id)
           (equal_to "SPY-pos-1");
         field
           (fun (t : Position.transition) -> t.position_id)
           (equal_to "QQQ-pos-1");
       ])

(** Contract 2: rejected trade whose symbol has no [Entering] match is silently
    dropped (no error). The simulator does not depend on this branch firing
    under normal operation, but the guard exists so a future drift in strategy
    invariants doesn't crash the simulator. *)
let test_transitions_for_rejected_trades_drops_no_match _ =
  let positions =
    _positions_with
      ~entries:[ _make_holding_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let rejected = [ _make_trade ~symbol:"SPY" ] in
  let transitions =
    Cancel_handler.transitions_for_rejected_trades ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that transitions is_empty

(** Contract 3: [apply_to_positions] applies a [CancelEntry] to an [Entering]
    position and removes it from the map (the position reaches the [Closed]
    state, which the simulator drops to keep the positions Map bounded). *)
let test_apply_to_positions_removes_on_closed _ =
  let entering = _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" in
  let positions = _positions_with ~entries:[ entering ] in
  let cancel : Position.transition =
    {
      position_id = "SPY-pos-1";
      date = _build_date;
      kind = Position.CancelEntry { reason = "test rejection" };
    }
  in
  let result = Cancel_handler.apply_to_positions positions cancel in
  assert_that result (is_ok_and_holds (field Map.length (equal_to 0)))

(** Contract 4: [apply_to_positions] returns the input map unchanged when the
    transition's [position_id] has no entry in [positions]. *)
let test_apply_to_positions_unknown_id_is_noop _ =
  let entering = _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" in
  let positions = _positions_with ~entries:[ entering ] in
  let cancel : Position.transition =
    {
      position_id = "MISSING-pos";
      date = _build_date;
      kind = Position.CancelEntry { reason = "unknown id" };
    }
  in
  let result = Cancel_handler.apply_to_positions positions cancel in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field Map.length (equal_to 1);
            field
              (fun m -> Map.find m "SPY-pos-1")
              (is_some_and
                 (field (fun (p : Position.t) -> p.symbol) (equal_to "SPY")));
          ]))

let suite =
  "Cancel_handler"
  >::: [
         "transitions_for_rejected_trades emits one transition per matched \
          symbol" >:: test_transitions_for_rejected_trades_emits_per_symbol;
         "transitions_for_rejected_trades drops rejected trades with no \
          Entering match"
         >:: test_transitions_for_rejected_trades_drops_no_match;
         "apply_to_positions removes the position when it reaches Closed"
         >:: test_apply_to_positions_removes_on_closed;
         "apply_to_positions returns input unchanged for unknown position_id"
         >:: test_apply_to_positions_unknown_id_is_noop;
       ]

let () = run_test_tt_main suite
