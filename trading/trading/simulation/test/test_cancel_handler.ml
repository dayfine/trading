(** Unit tests for {!Cancel_handler} — the bridge that handles
    portfolio-rejected fills so positions don't stay stuck. Pins the entry-side
    contracts (matched-symbol [CancelEntry] emit, no-match drop, Closed-removal,
    unknown-id identity) and the exit-side [revert_rejected_exits] contracts
    (#1553): unfilled [Exiting] reverts to [Holding] preserving the stop,
    partially-filled [Exiting] is left untouched, a non-[Exiting] match is a
    no-op, and a wrong-side trade on the symbol is a no-op (#2466). Each
    contract has one dedicated test below. Contract 9 additionally pins
    [handle_rejected_trades]'s composed pipeline directly: step 5 (revert) must
    see the FULL [rejected_trades] rather than step 2 (cancel)'s retry-filtered
    remainder (2026-08-25 qc-behavioral finding on PR #2542). *)

open OUnit2
open Core
open Matchers
module Cancel_handler = Trading_simulation.Cancel_handler
module Entry_fill_retry = Trading_simulation.Entry_fill_retry
module Position = Trading_strategy.Position
module Manager = Trading_orders.Manager
module Order_types = Trading_orders.Types

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d
let _build_date = _date ~y:2024 ~m:Month.Jan ~d:15

(** Build an [Entering] position for [symbol] keyed by [id]. Mirrors the shape
    strategies emit via [CreateEntering] then [Position.create_entering]. [side]
    defaults to [Long]; pass [Short] to build a ticket whose entry trade side is
    [Sell] instead of [Buy]. *)
let _make_entering_position ?(side = Position.Long) ~id ~symbol () : Position.t
    =
  {
    id;
    symbol;
    side;
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

(** Build an [Exiting] position for [symbol] keyed by [id]. [filled_quantity]
    defaults to 0.0 (the stuck-exit signature #1553 targets); pass a positive
    value to model a partially-filled exit that must NOT be reverted. [side]
    defaults to [Short] (exit trade side [Buy]); pass [Long] to build one whose
    exit trade side is [Sell] instead. The carried [entry_date]/[risk_params]
    are the fields the revert reconstructs [Holding] from. *)
let _make_exiting_position ?(side = Position.Short) ~id ~symbol
    ?(filled_quantity = 0.0) () : Position.t =
  {
    id;
    symbol;
    side;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason =
      Some
        (Position.StopLoss
           { stop_price = 0.53; actual_price = 0.55; loss_percent = -2.4 });
    state =
      Position.Exiting
        {
          quantity = 1000.0;
          entry_price = 0.72;
          entry_date = _date ~y:2022 ~m:Month.May ~d:27;
          target_quantity = 1000.0;
          exit_price = 0.55;
          filled_quantity;
          started_date = _date ~y:2022 ~m:Month.Nov ~d:10;
          risk_params =
            {
              stop_loss_price = Some 0.53;
              take_profit_price = None;
              max_hold_days = None;
            };
        };
    last_updated = _date ~y:2022 ~m:Month.Nov ~d:10;
    portfolio_lot_ids = [];
  }

(* [side] defaults to [Buy], which {e closes} the [Short] position
   [_make_exiting_position] builds — the shape the exit-revert contracts below
   assume. Pass [Sell] for the wrong-side case (contract 8). *)
let _make_trade ?(side = Trading_base.Types.Buy) ~symbol () :
    Trading_base.Types.trade =
  {
    id = Printf.sprintf "%s-trade-1" symbol;
    order_id = Printf.sprintf "%s-order-1" symbol;
    symbol;
    side;
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
          _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ();
          _make_entering_position ~id:"QQQ-pos-1" ~symbol:"QQQ" ();
        ]
  in
  let rejected =
    [ _make_trade ~symbol:"SPY" (); _make_trade ~symbol:"QQQ" () ]
  in
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
  let rejected = [ _make_trade ~symbol:"SPY" () ] in
  let transitions =
    Cancel_handler.transitions_for_rejected_trades ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that transitions is_empty

(** Contract 3: [apply_to_positions] applies a [CancelEntry] to an [Entering]
    position and removes it from the map (the position reaches the [Closed]
    state, which the simulator drops to keep the positions Map bounded). *)
let test_apply_to_positions_removes_on_closed _ =
  let entering = _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" () in
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
  let entering = _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" () in
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

(** Contract 5 (#1553): [revert_rejected_exits] reverts an unfilled [Exiting]
    position whose exit fill was rejected back to [Holding], preserving the
    pre-exit quantity / entry price / entry date / risk params (so the stop
    keeps tracking on retry). This is the fix for the stuck-[Exiting] zombie. *)
let test_revert_rejected_exits_reverts_unfilled_exiting _ =
  let positions =
    _positions_with
      ~entries:[ _make_exiting_position ~id:"THM-pos-1" ~symbol:"THM" () ]
  in
  let rejected = [ _make_trade ~symbol:"THM" () ] in
  let positions =
    Cancel_handler.revert_rejected_exits ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that
    (Map.find positions "THM-pos-1")
    (is_some_and
       (field
          (fun (p : Position.t) -> p.state)
          (matching ~msg:"Expected Holding after revert"
             (function
               | Position.Holding { quantity; entry_price; risk_params; _ } ->
                   Some (quantity, entry_price, risk_params.stop_loss_price)
               | _ -> None)
             (all_of
                [
                  field (fun (q, _, _) -> q) (float_equal 1000.0);
                  field (fun (_, ep, _) -> ep) (float_equal 0.72);
                  field
                    (fun (_, _, stop) -> stop)
                    (is_some_and (float_equal 0.53));
                ]))))

(** Contract 6 (#1553): a {e partially} filled [Exiting] position is NOT
    reverted — reverting would resurrect a [Holding] at the full pre-exit
    quantity while the portfolio already booked the partial cover. The position
    stays [Exiting]. *)
let test_revert_rejected_exits_skips_partially_filled _ =
  let positions =
    _positions_with
      ~entries:
        [
          _make_exiting_position ~id:"THM-pos-1" ~symbol:"THM"
            ~filled_quantity:300.0 ();
        ]
  in
  let rejected = [ _make_trade ~symbol:"THM" () ] in
  let positions =
    Cancel_handler.revert_rejected_exits ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that
    (Map.find positions "THM-pos-1")
    (is_some_and
       (field
          (fun (p : Position.t) -> p.state)
          (matching ~msg:"Expected position to stay Exiting"
             (function
               | Position.Exiting { filled_quantity; _ } -> Some filled_quantity
               | _ -> None)
             (float_equal 300.0))))

(** Contract 7 (#1553): a rejected trade whose symbol matches only a [Holding]
    (not [Exiting]) position is a no-op — the map is returned unchanged. Guards
    against reverting positions that were never exiting. *)
let test_revert_rejected_exits_ignores_non_exiting _ =
  let positions =
    _positions_with
      ~entries:[ _make_holding_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let rejected = [ _make_trade ~symbol:"SPY" () ] in
  let positions =
    Cancel_handler.revert_rejected_exits ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that
    (Map.find positions "SPY-pos-1")
    (is_some_and
       (field
          (fun (p : Position.t) -> p.state)
          (matching ~msg:"Expected Holding unchanged"
             (function
               | Position.Holding { quantity; _ } -> Some quantity | _ -> None)
             (float_equal 100.0))))

(** Contract 8 (#2466): a rejected trade on the {e wrong side} for the [Exiting]
    position sharing its symbol does not revert it. The fixture position is
    [Short], so its exit fill is a Buy; the [Sell] here is an {e entry} fill (a
    short ticket opening on the same symbol) that the portfolio refused.

    This is the guard, not a regression: [revert_rejected_exits] is handed the
    whole rejected list — entries included ([handle_rejected_trades] passes the
    outer [rejected_trades], not the retry-filtered remainder) — so on
    symbol-and-state matching alone this Sell would cancel a stop-out the
    portfolio never refused. The [Entering]/[Exiting]-on-one-symbol pairing is
    unreachable under the shipped Weinstein strategy, which is why no golden
    moves; the check belongs here because this module is strategy-agnostic and
    {!Fill_router} already applies it to the accepted fills. *)
let test_revert_rejected_exits_ignores_wrong_side_trade _ =
  let positions =
    _positions_with
      ~entries:[ _make_exiting_position ~id:"THM-pos-1" ~symbol:"THM" () ]
  in
  let rejected =
    [ _make_trade ~side:Trading_base.Types.Sell ~symbol:"THM" () ]
  in
  let positions =
    Cancel_handler.revert_rejected_exits ~date:_build_date ~positions
      ~rejected_trades:rejected
  in
  assert_that
    (Map.find positions "THM-pos-1")
    (is_some_and
       (field
          (fun (p : Position.t) -> p.state)
          (matching ~msg:"Expected position to stay Exiting"
             (function
               | Position.Exiting { filled_quantity; _ } -> Some filled_quantity
               | _ -> None)
             (float_equal 0.0))))

(* A restable order for [id]/[symbol]/[side] — enough for
   [Entry_fill_retry._reoffer] to find it via [Manager.get_order] and accept a
   fresh copy. Field values otherwise don't matter to the contract below. *)
let _make_restable_order ~id ~symbol ~side : Order_types.order =
  {
    id;
    symbol;
    side;
    order_type = Trading_base.Types.Market;
    quantity = 100.0;
    time_in_force = Order_types.Day;
    status = Order_types.Pending;
    filled_quantity = 0.0;
    avg_fill_price = None;
    created_at = Time_ns_unix.epoch;
    updated_at = Time_ns_unix.epoch;
  }

(** Contract 9 (BACKLOG-1/M-B, 2026-08-25 qc-behavioral finding on PR #2542):
    [handle_rejected_trades] deliberately feeds step 2 (cancel) the
    retry-filtered remainder but step 5 (revert) the FULL, unfiltered
    [rejected_trades] (see the [.mli]'s ordering note). Swapping step 5's input
    to the filtered list compiles cleanly and was undetected by all 416
    pre-existing tests, because no fixture had a retried entry trade whose
    (symbol, side) also satisfied an unrelated [Exiting] sibling's revert match
    — the one case where the two lists actually disagree.

    This fixture manufactures that overlap directly (bypassing the strategy
    invariant that keeps the pairing unreachable in a real run, exactly as
    contract 8 and the [.mli] both note this module must not rely on): on symbol
    "AAPL", [AAPL-pos-2] is an [Entering] [Short] ticket whose entry trade side
    is [Sell]; [AAPL-pos-3] is an unrelated, unfilled [Exiting] [Long] sibling
    whose exit trade side is also [Sell]. The one rejected Sell trade for "AAPL"
    both (a) gets retried — spending [AAPL-pos-2]'s budget, so it is absent from
    the retry-filtered remainder step 2 uses — and (b) is the trade that must
    revert [AAPL-pos-3] to [Holding], which only happens if step 5 sees the FULL
    list. A third, disjoint ticket ([MSFT-pos-1], whose order is unknown to the
    manager and so is never retried) exercises the ordinary cancel path so the
    fixture is not reducible to the two-position AAPL pair alone. *)
let test_handle_rejected_trades_reverts_off_the_full_list_not_the_filtered_one
    _test_ctxt =
  let positions =
    _positions_with
      ~entries:
        [
          _make_entering_position ~id:"MSFT-pos-1" ~symbol:"MSFT" ();
          _make_entering_position ~id:"AAPL-pos-2" ~symbol:"AAPL"
            ~side:Position.Short ();
          _make_exiting_position ~id:"AAPL-pos-3" ~symbol:"AAPL"
            ~side:Position.Long ();
        ]
  in
  let order_manager = Manager.create () in
  let (_ : Status.status list) =
    Manager.submit_orders order_manager
      [
        _make_restable_order ~id:"AAPL-order-1" ~symbol:"AAPL"
          ~side:Trading_base.Types.Sell;
      ]
  in
  let entry_fill_retry = Entry_fill_retry.create ~max_retries:1 in
  let rejected =
    [
      _make_trade ~symbol:"MSFT" ();
      _make_trade ~symbol:"AAPL" ~side:Trading_base.Types.Sell ();
    ]
  in
  let result =
    Cancel_handler.handle_rejected_trades ~date:_build_date ~positions
      ~rejected_trades:rejected ~order_manager ~entry_fill_retry
      ~on_transitions:None
  in
  assert_that result
    (is_ok_and_holds
       (all_of
          [
            field Map.length (equal_to 2);
            map_includes
              [
                ( "AAPL-pos-2",
                  field
                    (fun (p : Position.t) -> p.state)
                    (matching
                       ~msg:"Expected the retried ticket to stay Entering"
                       (function Position.Entering _ -> Some () | _ -> None)
                       (equal_to ())) );
                ( "AAPL-pos-3",
                  field
                    (fun (p : Position.t) -> p.state)
                    (matching
                       ~msg:
                         "Expected the sibling Exiting position to revert to \
                          Holding off the FULL rejected-trades list, not the \
                          retry-filtered remainder"
                       (function Position.Holding _ -> Some () | _ -> None)
                       (equal_to ())) );
              ];
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
         "revert_rejected_exits reverts an unfilled Exiting position to Holding"
         >:: test_revert_rejected_exits_reverts_unfilled_exiting;
         "revert_rejected_exits skips a partially-filled Exiting position"
         >:: test_revert_rejected_exits_skips_partially_filled;
         "revert_rejected_exits ignores a non-Exiting (Holding) position"
         >:: test_revert_rejected_exits_ignores_non_exiting;
         "revert_rejected_exits ignores a wrong-side trade on the symbol"
         >:: test_revert_rejected_exits_ignores_wrong_side_trade;
         "handle_rejected_trades reverts off the full rejected-trades list, \
          not the retry-filtered remainder"
         >:: test_handle_rejected_trades_reverts_off_the_full_list_not_the_filtered_one;
       ]

let () = run_test_tt_main suite
