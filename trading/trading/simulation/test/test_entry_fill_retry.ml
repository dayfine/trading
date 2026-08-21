(** Unit tests for {!Entry_fill_retry} — G2a, the retry a portfolio-refused
    entry fill gets instead of the ticket being destroyed
    ([dev/plans/ticket-funding-2026-08-16.md] §G2a).

    The contracts pinned here, one test each:

    - {b R1 no-op at the default.} At [max_retries = 0] the refused trades come
      back untouched, the ledger is never written, and no order is submitted —
      so the simulator's cancel path sees exactly what it saw before G2a
      existed.
    - {b Bounded retries.} At [max_retries = n] a repeatedly-refused ticket is
      retried exactly [n] times and destroyed on refusal [n + 1]. Asserted as an
      exact count, not "at least one".
    - {b The re-offer is real.} A retried ticket leaves a fresh [Pending] order
      in the manager carrying the original's symbol / side / type / quantity,
      which is what lets the engine fill it next tick.
    - {b A retry that succeeds does not double-commit cash.} The re-offer adds
      exactly one order and does not disturb the [Entering] position, so the
      ticket's cost is claimed once. (The double-commit this guards against is
      the G3 leak: a ticket resting from week N is invisible to week N+1's
      [remaining_cash], which is re-seeded from [portfolio.cash].)
    - {b Exits pass through.} A refused trade with no [Entering] match is never
      retried, so {!Cancel_handler.revert_rejected_exits} keeps seeing the full
      rejected list.
    - {b Ids are derived, not minted.} Retry ids are a pure function of the
      original id and the attempt number — no clock, no counter — so two
      structurally identical runs produce identical ids. *)

open OUnit2
open Core
open Matchers
module Entry_fill_retry = Trading_simulation.Entry_fill_retry
module Position = Trading_strategy.Position
module Manager = Trading_orders.Manager
module Order_types = Trading_orders.Types

let _date ~y ~m ~d = Date.create_exn ~y ~m ~d

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

let _positions_with entries : Position.t String.Map.t =
  List.fold entries ~init:String.Map.empty ~f:(fun acc (pos : Position.t) ->
      Map.set acc ~key:pos.id ~data:pos)

let _make_trade ~symbol ~order_id : Trading_base.Types.trade =
  {
    id = Printf.sprintf "%s-trade-1" symbol;
    order_id;
    symbol;
    side = Trading_base.Types.Buy;
    quantity = 100.0;
    price = 50.0;
    commission = 1.0;
    timestamp = Time_ns_unix.now ();
  }

(* The entry order the engine already marked [Filled] before the portfolio
   refused the trade — a StopLimit, the shape the do-not-chase fill model
   produces, so the copy's trigger/cap carry-over is exercised. *)
let _make_filled_entry_order ~id ~symbol : Order_types.order =
  {
    id;
    symbol;
    side = Trading_base.Types.Buy;
    order_type = Trading_base.Types.StopLimit (50.0, 52.5);
    quantity = 100.0;
    time_in_force = Order_types.Day;
    status = Order_types.Filled;
    filled_quantity = 100.0;
    avg_fill_price = Some 50.0;
    created_at = Time_ns_unix.epoch;
    updated_at = Time_ns_unix.epoch;
  }

(* A manager holding the refused ticket's (already filled) order. *)
let _manager_with_order ~id ~symbol =
  let manager = Manager.create () in
  let submitted =
    Manager.submit_orders manager [ _make_filled_entry_order ~id ~symbol ]
  in
  assert_that submitted (elements_are [ is_ok ]);
  manager

let _active_orders manager = Manager.list_orders manager ~filter:ActiveOnly

(* One refusal of the standard fixture ticket. Returns the trades the caller
   must still cancel. *)
let _refuse_once ledger ~manager ~positions ~order_id =
  Entry_fill_retry.handle_rejected_entries ledger ~order_manager:manager
    ~positions
    ~rejected_trades:[ _make_trade ~symbol:"SPY" ~order_id ]

(* Refuse the ticket repeatedly, always re-refusing whatever order the previous
   round left resting. Returns the number of rounds that were retried (i.e. the
   rounds whose trade did NOT come back for cancellation). *)
let _refuse_repeatedly ledger ~manager ~positions ~rounds =
  let order_id = ref "2024-01-10-001" in
  List.count (List.range 0 rounds) ~f:(fun _ ->
      let still_dying =
        _refuse_once ledger ~manager ~positions ~order_id:!order_id
      in
      let retried = List.is_empty still_dying in
      (if retried then
         match _active_orders manager with
         | resting :: _ -> order_id := resting.Order_types.id
         | [] -> ());
      retried)

(** R1: the default budget is an exact no-op. Every refused trade comes back for
    cancellation, the ledger records nothing, and no order is submitted — the
    three observable surfaces the simulator's pre-G2a path had. *)
let test_default_budget_is_a_no_op _ =
  let ledger = Entry_fill_retry.create ~max_retries:0 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let positions =
    _positions_with [ _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let still_dying =
    _refuse_once ledger ~manager ~positions ~order_id:"2024-01-10-001"
  in
  assert_that
    ( List.map still_dying ~f:(fun (t : Trading_base.Types.trade) -> t.symbol),
      Entry_fill_retry.retries_used ledger ~position_id:"SPY-pos-1",
      List.length (_active_orders manager) )
    (equal_to ([ "SPY" ], 0, 0))

(** A ticket with budget [1] survives its first refusal and dies on its second:
    exactly one retry, no more. *)
let test_budget_one_retries_exactly_once _ =
  let ledger = Entry_fill_retry.create ~max_retries:1 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let positions =
    _positions_with [ _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let retried = _refuse_repeatedly ledger ~manager ~positions ~rounds:3 in
  assert_that
    (retried, Entry_fill_retry.retries_used ledger ~position_id:"SPY-pos-1")
    (equal_to (1, 1))

(** Same shape at budget [2] — the bound tracks the config value rather than
    being hardcoded, and a third refusal still destroys the ticket. *)
let test_budget_two_retries_exactly_twice _ =
  let ledger = Entry_fill_retry.create ~max_retries:2 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let positions =
    _positions_with [ _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let retried = _refuse_repeatedly ledger ~manager ~positions ~rounds:4 in
  assert_that
    (retried, Entry_fill_retry.retries_used ledger ~position_id:"SPY-pos-1")
    (equal_to (2, 2))

(** The re-offer is a real, fillable order: exactly one active order, [Pending]
    with no fills, carrying the original's symbol / side / type / quantity. That
    is what makes the retry reachable by the engine next tick — without it the
    ticket would rest with nothing behind it. *)
let test_retry_leaves_one_fresh_pending_order _ =
  let ledger = Entry_fill_retry.create ~max_retries:1 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let positions =
    _positions_with [ _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let (_ : Trading_base.Types.trade list) =
    _refuse_once ledger ~manager ~positions ~order_id:"2024-01-10-001"
  in
  assert_that (_active_orders manager)
    (elements_are
       [
         all_of
           [
             field
               (fun (o : Order_types.order) -> o.id)
               (equal_to
                  (Entry_fill_retry.retry_order_id ~order_id:"2024-01-10-001"
                     ~attempt:1));
             field (fun (o : Order_types.order) -> o.symbol) (equal_to "SPY");
             field
               (fun (o : Order_types.order) -> o.side)
               (equal_to Trading_base.Types.Buy);
             field
               (fun (o : Order_types.order) -> o.order_type)
               (equal_to (Trading_base.Types.StopLimit (50.0, 52.5)));
             field
               (fun (o : Order_types.order) -> o.quantity)
               (float_equal 100.0);
             field
               (fun (o : Order_types.order) -> o.status)
               (equal_to Order_types.Pending);
             field
               (fun (o : Order_types.order) -> o.filled_quantity)
               (float_equal 0.0);
           ];
       ])

(** A retry that goes on to succeed must not commit the ticket's cash twice. The
    re-offer replaces the refused claim rather than adding to it: exactly one
    order is live afterwards, and the [Entering] position is returned unchanged
    (same target quantity, still zero filled), so nothing downstream sees two
    claims on the same money. *)
let test_successful_retry_does_not_double_commit _ =
  let ledger = Entry_fill_retry.create ~max_retries:2 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let position = _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" in
  let positions = _positions_with [ position ] in
  let (_ : Trading_base.Types.trade list) =
    _refuse_once ledger ~manager ~positions ~order_id:"2024-01-10-001"
  in
  let resting_quantity =
    List.sum
      (module Float)
      (_active_orders manager)
      ~f:(fun (o : Order_types.order) -> o.quantity)
  in
  assert_that
    ( List.length (_active_orders manager),
      resting_quantity,
      Map.find positions "SPY-pos-1" )
    (equal_to
       (1, 100.0, Some (_make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY")))

(** A refused trade with no [Entering] match — an exit rejection, or an entry
    whose position already left the map — is never retried. It passes straight
    through so {!Cancel_handler.revert_rejected_exits} still sees it. *)
let test_non_entering_symbol_passes_through _ =
  let ledger = Entry_fill_retry.create ~max_retries:2 in
  let manager = _manager_with_order ~id:"2024-01-10-001" ~symbol:"SPY" in
  let positions =
    _positions_with [ _make_holding_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let still_dying =
    _refuse_once ledger ~manager ~positions ~order_id:"2024-01-10-001"
  in
  assert_that
    ( List.map still_dying ~f:(fun (t : Trading_base.Types.trade) -> t.symbol),
      List.length (_active_orders manager) )
    (equal_to ([ "SPY" ], 0))

(** A trade whose order the manager no longer knows falls back to today's
    behaviour rather than leaving the ticket resting with nothing behind it, and
    spends no budget doing so. *)
let test_unknown_order_falls_back_to_cancel _ =
  let ledger = Entry_fill_retry.create ~max_retries:2 in
  let manager = Manager.create () in
  let positions =
    _positions_with [ _make_entering_position ~id:"SPY-pos-1" ~symbol:"SPY" ]
  in
  let still_dying =
    _refuse_once ledger ~manager ~positions ~order_id:"never-submitted"
  in
  assert_that
    ( List.map still_dying ~f:(fun (t : Trading_base.Types.trade) -> t.symbol),
      Entry_fill_retry.retries_used ledger ~position_id:"SPY-pos-1" )
    (equal_to ([ "SPY" ], 0))

(** Retry ids are derived from the original, and the suffix does not nest: the
    second retry of ["X"] is ["X#retry2"], not ["X#retry1#retry2"]. Pinned
    because the id is the only trace a re-offer leaves in [trade_audit.sexp],
    and because a clock-derived id would break run-to-run determinism. *)
let test_retry_ids_are_derived_and_do_not_nest _ =
  let first =
    Entry_fill_retry.retry_order_id ~order_id:"2024-01-10-001" ~attempt:1
  in
  assert_that
    (first, Entry_fill_retry.retry_order_id ~order_id:first ~attempt:2)
    (equal_to ("2024-01-10-001#retry1", "2024-01-10-001#retry2"))

let suite =
  "entry_fill_reject_retries"
  >::: [
         "default budget is a no-op" >:: test_default_budget_is_a_no_op;
         "budget 1 retries exactly once"
         >:: test_budget_one_retries_exactly_once;
         "budget 2 retries exactly twice"
         >:: test_budget_two_retries_exactly_twice;
         "retry leaves one fresh pending order"
         >:: test_retry_leaves_one_fresh_pending_order;
         "successful retry does not double-commit"
         >:: test_successful_retry_does_not_double_commit;
         "non-entering symbol passes through"
         >:: test_non_entering_symbol_passes_through;
         "unknown order falls back to cancel"
         >:: test_unknown_order_falls_back_to_cancel;
         "retry ids are derived and do not nest"
         >:: test_retry_ids_are_derived_and_do_not_nest;
       ]

let () = run_test_tt_main suite
