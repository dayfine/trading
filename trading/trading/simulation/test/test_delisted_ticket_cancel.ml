(** Unit tests for {!Trading_simulation.Delisted_ticket_cancel} — the fill-time
    third of the delisting trio (#2696), which retires a resting entry ticket
    once its symbol's [active_through] marker has passed.

    The selection policy and the order retirement are the whole module, so these
    tests pin both:

    - marker passed → the [Entering] position is closed AND its resting order is
      cancelled in the manager (a "cancelled" ticket whose order still fills is
      worse than no cancel at all);
    - the emitted transition is a [CancelEntry] tagged ["delisted"], the same
      token the exit side stamps, so one audit group covers both halves;
    - marker [None] → nothing happens at all (the R1 no-op that keeps every
      golden bit-identical on every warehouse built before #2691);
    - marker today or in the future → nothing happens, the strict boundary
      {!Trading_simulation.Delisted_exit_runner} and [Delisted_entry_gate] also
      use, so the marker day itself is tradeable on all three sides;
    - a {e partially filled} entry is left alone — its shares are booked, and
      the core [CancelEntry] validator rejects such a transition anyway;
    - a [Holding] position is untouched: that is the exit runner's job, not this
      module's;
    - an unrelated live symbol's ticket and order survive.

    The end-to-end consequence — no fill lands 1-6 days past the marker, the
    band under V17's 7-day default where the residual used to hide — is pinned
    one layer up in [test_delisted_ticket_cancel_sim.ml].

    Authority: [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle:
    fallbacks are quality flags, not mechanisms". *)

open OUnit2
open Core
open Matchers
module Delisted_ticket_cancel = Trading_simulation.Delisted_ticket_cancel
module Position = Trading_strategy.Position
module Orders = Trading_orders

let _date s = Date.of_string s
let _symbol = "DEAD"
let _live = "KEEP"
let _entry_price = 100.0
let _quantity = 10.0
let _position_id = "DEAD-1"
let _live_position_id = "KEEP-1"
let _marker = _date "2024-01-10"
let _today = _date "2024-01-15"

let _risk_params : Position.risk_params =
  { stop_loss_price = None; take_profit_price = None; max_hold_days = None }

let _position ~id ~symbol ~state : Position.t =
  {
    id;
    symbol;
    side = Position.Long;
    entry_reasoning = Position.ManualDecision { description = "test fixture" };
    exit_reason = None;
    state;
    last_updated = _date "2024-01-08";
    portfolio_lot_ids = [];
  }

let _entering ?(filled_quantity = 0.0) () : Position.position_state =
  Entering
    {
      target_quantity = _quantity;
      entry_price = _entry_price;
      filled_quantity;
      created_date = _date "2024-01-08";
    }

let _holding : Position.position_state =
  Holding
    {
      quantity = _quantity;
      entry_price = _entry_price;
      entry_date = _date "2024-01-08";
      risk_params = _risk_params;
    }

(* One resting ticket on the delisted symbol; a second, live one on [_live] so
   every test also shows the module leaving unrelated tickets alone. *)
let _positions ?(state = _entering ()) () =
  String.Map.of_alist_exn
    [
      (_position_id, _position ~id:_position_id ~symbol:_symbol ~state);
      ( _live_position_id,
        _position ~id:_live_position_id ~symbol:_live ~state:(_entering ()) );
    ]

(* A manager holding the Buy entry order behind each ticket. Both rest unfilled,
   which is what [cancel_resting_entry_orders] matches on. *)
let _order_manager () =
  let manager = Orders.Manager.create () in
  let order symbol : Orders.Create_order.order_params =
    {
      symbol;
      side = Trading_base.Types.Buy;
      order_type = Trading_base.Types.Market;
      quantity = _quantity;
      time_in_force = Orders.Types.Day;
    }
  in
  let make id symbol =
    match Orders.Create_order.create_order ~id (order symbol) with
    | Ok o -> o
    | Error e -> assert_failure ("order setup failed: " ^ Status.show e)
  in
  let (_ : Status.status list) =
    Orders.Manager.submit_orders manager
      [ make "dead-order" _symbol; make "live-order" _live ]
  in
  manager

(* [_symbol] carries [marker]; [_live] never does, so every test also shows the
   module leaving an unrelated live ticket and its order alone. *)
let _marked_dead marker symbol =
  if String.equal symbol _symbol then marker else None

let _no_marker : string -> Date.t option = fun _ -> None

(* Run the module and return everything a test can assert on: the post-cancel
   positions, the emitted transitions, and the ids of the orders still active in
   the manager afterwards. *)
let _run ?positions ?(active_through_for = _marked_dead (Some _marker))
    ?(date = _today) () =
  let positions = Option.value positions ~default:(_positions ()) in
  let order_manager = _order_manager () in
  let positions, transitions =
    Delisted_ticket_cancel.tick ~order_manager ~active_through_for ~date
      ~positions ()
  in
  let active_order_ids =
    Orders.Manager.list_orders ~filter:ActiveOnly order_manager
    |> List.map ~f:(fun (o : Orders.Types.order) -> o.id)
    |> List.sort ~compare:String.compare
  in
  (positions, transitions, active_order_ids)

let _positions_of (p, _, _) = p
let _transitions_of (_, t, _) = t
let _active_order_ids_of (_, _, ids) = ids

(** Marker passed: the dead symbol's ticket is closed and dropped from the map,
    and the live symbol's is untouched. *)
let test_passed_marker_drops_the_resting_ticket _ =
  assert_that
    (Map.keys (_positions_of (_run ())))
    (elements_are [ equal_to _live_position_id ])

(** ...and its resting ORDER is retired in the manager. This is the half that
    makes the cancel real: a closed position with a live order would still fill
    on a later bar, and {!Trading_simulation.Fill_router}'s (symbol, side)
    fallback would still route the fill. *)
let test_passed_marker_retires_the_resting_order _ =
  assert_that
    (_active_order_ids_of (_run ()))
    (elements_are [ equal_to "live-order" ])

(** The transition is a [CancelEntry] naming the dead ticket, tagged with the
    module's own reason token — the value a [trade_audit.sexp] reader groups
    ticket deaths by, and deliberately the same ["delisted"] the exit side
    stamps. *)
let test_cancel_transition_carries_the_delisted_reason _ =
  assert_that
    (_transitions_of (_run ()))
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Position.transition) -> t.position_id)
               (equal_to _position_id);
             field (fun (t : Position.transition) -> t.date) (equal_to _today);
             field
               (fun (t : Position.transition) -> t.kind)
               (equal_to
                  (Position.CancelEntry
                     { reason = Delisted_ticket_cancel.cancel_reason }));
           ];
       ])

(** The reason token itself is ["delisted"] — pinned as a literal so the shared
    audit grouping with {!Trading_simulation.Delisted_exit_runner}'s exit label
    cannot drift silently. *)
let test_cancel_reason_is_delisted _ =
  assert_that Delisted_ticket_cancel.cancel_reason (equal_to "delisted")

(** {b The R1 no-op.} No marker → byte-identical to a run without this module:
    no transition, both tickets intact, both orders still resting. This is EVERY
    run against EVERY warehouse built before #2691. *)
let test_absent_marker_is_a_no_op _ =
  let positions, transitions, active_order_ids =
    _run ~active_through_for:_no_marker ()
  in
  assert_that
    (Map.keys positions, List.length transitions, active_order_ids)
    (equal_to
       ([ _position_id; _live_position_id ], 0, [ "dead-order"; "live-order" ]))

(** A marker dated TODAY does not fire: the comparison is strict, so a ticket
    admitted on the marker day is still allowed to fill that day. This is the
    boundary the admission gate deliberately leaves open and this module closes
    on the NEXT step. *)
let test_marker_dated_today_does_not_cancel _ =
  assert_that
    (_transitions_of (_run ~active_through_for:(_marked_dead (Some _today)) ()))
    (size_is 0)

(** One day past the marker DOES fire — the other side of the same boundary. *)
let test_one_day_past_the_marker_cancels _ =
  assert_that
    (_transitions_of
       (_run
          ~active_through_for:(_marked_dead (Some _marker))
          ~date:(Date.add_days _marker 1) ()))
    (size_is 1)

(** A marker in the future does not fire either — the series is still live. *)
let test_future_marker_does_not_cancel _ =
  assert_that
    (_transitions_of
       (_run ~active_through_for:(_marked_dead (Some (_date "2024-02-01"))) ()))
    (size_is 0)

(** A PARTIALLY filled entry is left alone: its shares are already booked with
    the portfolio, and the core [CancelEntry] validator rejects a transition on
    a filled [Entering] anyway. It is left for the exit runner once it
    completes. *)
let test_partially_filled_entry_is_not_cancelled _ =
  let positions, transitions, active_order_ids =
    _run
      ~positions:(_positions ~state:(_entering ~filled_quantity:4.0 ()) ())
      ()
  in
  assert_that
    (Map.keys positions, List.length transitions, active_order_ids)
    (equal_to
       ([ _position_id; _live_position_id ], 0, [ "dead-order"; "live-order" ]))

(** A [Holding] position on the marked symbol is untouched — closing it is
    {!Trading_simulation.Delisted_exit_runner}'s job, and doing it here too
    would double-exit. *)
let test_holding_position_is_left_to_the_exit_runner _ =
  assert_that
    (_transitions_of (_run ~positions:(_positions ~state:_holding ()) ()))
    (size_is 0)

let suite =
  "delisted_ticket_cancel"
  >::: [
         "passed marker drops the resting ticket"
         >:: test_passed_marker_drops_the_resting_ticket;
         "passed marker retires the resting order"
         >:: test_passed_marker_retires_the_resting_order;
         "cancel transition carries the delisted reason"
         >:: test_cancel_transition_carries_the_delisted_reason;
         "cancel reason is delisted" >:: test_cancel_reason_is_delisted;
         "absent marker is a no-op" >:: test_absent_marker_is_a_no_op;
         "marker dated today does not cancel"
         >:: test_marker_dated_today_does_not_cancel;
         "one day past the marker cancels"
         >:: test_one_day_past_the_marker_cancels;
         "future marker does not cancel" >:: test_future_marker_does_not_cancel;
         "partially filled entry is not cancelled"
         >:: test_partially_filled_entry_is_not_cancelled;
         "holding position is left to the exit runner"
         >:: test_holding_position_is_left_to_the_exit_runner;
       ]

let () = run_test_tt_main suite
