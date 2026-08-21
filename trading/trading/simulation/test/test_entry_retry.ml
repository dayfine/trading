(** G2a [entry_fill_reject_retries] — revert-and-retry for entry tickets whose
    fill the {b portfolio} refused ([dev/plans/ticket-funding-2026-08-16.md]).

    {b Unit} tests over {!Trading_simulation.Entry_retry} pin the budget
    arithmetic and the claim guards. {b End-to-end} tests drive a real
    {!Trading_simulation.Simulator.run} over a fixture whose first fill is
    unaffordable and whose later fill is not, so the flag's whole observable
    contract — destroy at [0], fill on a later tick at [2], exhaust-then-destroy
    at [1] — is asserted against the simulator, not against the helper.

    The cap test is the one worth reading twice: its middle bar gaps far past
    the do-not-chase cap while the ticket is mid-retry, and the run still fills
    at the {e trigger} on the last bar — only possible if the reinstated order
    refused the gapped print instead of chasing it. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Entry_retry = Trading_simulation.Entry_retry
module Cancel_handler = Trading_simulation.Cancel_handler
module Position = Trading_strategy.Position
module Order_types = Trading_orders.Types

let _date s = Date.of_string s
let _symbol = "AAPL"
let _position_id = "AAPL-g2a-1"

(* Zero commission: every affordability threshold below is then exactly
   [quantity * price], so the fixture's arithmetic is readable inline. *)
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }

(** {1 Fixtures} *)

let _make_bar ~date ~open_price ~high ~low ~close =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      adjusted_close = close;
      volume = 1_000_000;
      active_through = None;
    }

let _entry_price = 100.0
let _quantity = 100.0

(* Four bars. The strategy writes its ticket on d1; the order is submitted at
   the end of that step and first matched on d2.

   d2 opens at 108 — above the trigger and inside a 10% do-not-chase cap (110),
   so it fills at 108 and asks the book for 10,800.
   d3 gaps to 200, far past the cap.
   d4 opens back at the trigger, asking 10,000.

   Against [_cash = 10,400] that makes d2 unaffordable and d4 affordable, which
   is what separates "destroyed on first rejection" from "re-offered and filled
   later" without any cash appearing from nowhere. *)
let _bars =
  [
    _make_bar ~date:(_date "2024-01-02") ~open_price:96.0 ~high:97.0 ~low:95.0
      ~close:96.0;
    _make_bar ~date:(_date "2024-01-03") ~open_price:108.0 ~high:109.0
      ~low:107.0 ~close:108.0;
    _make_bar ~date:(_date "2024-01-04") ~open_price:200.0 ~high:210.0
      ~low:195.0 ~close:205.0;
    _make_bar ~date:(_date "2024-01-05") ~open_price:100.0 ~high:101.0 ~low:99.0
      ~close:100.0;
  ]

let _cash = 10_400.0

let _config =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-06";
    initial_cash = _cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* One-shot strategy: writes a single [CreateEntering] on its first call with a
   bar, then holds. It never re-emits, so every later fill in a run below comes
   from the ORIGINAL resting order — which is exactly the property the retry
   mechanism is claimed to preserve. *)
let _one_shot_strategy () :
    (module Trading_strategy.Strategy_interface.STRATEGY) =
  let emitted = ref false in
  let module S : Trading_strategy.Strategy_interface.STRATEGY = struct
    let name = "OneShotEntry"

    let _transition ~date : Position.transition =
      {
        position_id = _position_id;
        date;
        kind =
          CreateEntering
            {
              symbol = _symbol;
              side = Position.Long;
              target_quantity = _quantity;
              entry_price = _entry_price;
              reasoning = ManualDecision { description = "g2a fixture" };
            };
      }

    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_ =
      let open Trading_strategy.Strategy_interface in
      match (!emitted, get_price _symbol) with
      | false, Some (bar : Types.Daily_price.t) ->
          emitted := true;
          Ok { transitions = [ _transition ~date:bar.date ] }
      | _ -> Ok { transitions = [] }
  end
  in
  (module S)

(* Result of one run: every fill trade in step order, plus every [CancelEntry]
   reason the simulator announced. The second is how a destroyed ticket is
   observed — it is the same [on_transitions] hook production composes
   [Trade_audit.record_transitions] onto, so asserting the reason here pins the
   input the artifact's [cancel_reason] is written from. *)
type run_observation = {
  fill_dates : Date.t list;
      (** The step date of each fill, so "which tick did it fill on" is asserted
          directly rather than as a position in a step-count vector. *)
  fill_prices : float list;
  cancel_reasons : string list;
}

let _cancel_reason_of (t : Position.transition) =
  match t.kind with Position.CancelEntry { reason } -> Some reason | _ -> None

let _observe_run ~test_name ?entry_extension_max_pct ~entry_fill_reject_retries
    () =
  let cancels = ref [] in
  let on_transitions ts =
    cancels := !cancels @ List.filter_map ts ~f:_cancel_reason_of
  in
  let result =
    with_test_data test_name
      [ (_symbol, _bars) ]
      ~f:(fun data_dir ->
        let deps =
          create_deps ~symbols:[ _symbol ] ~data_dir
            ~strategy:(_one_shot_strategy ()) ~commission:_commission
            ~on_transitions ?entry_extension_max_pct ~entry_fill_reject_retries
            ()
        in
        let sim = Test_helpers.create_exn ~config:_config ~deps in
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("run failed: " ^ Status.show err))
  in
  let dated_trades =
    List.concat_map result.steps ~f:(fun s ->
        List.map s.trades ~f:(fun t -> (s.date, t)))
  in
  {
    fill_dates = List.map dated_trades ~f:fst;
    fill_prices =
      List.map dated_trades ~f:(fun (_, (t : Trading_base.Types.trade)) ->
          t.price);
    cancel_reasons = !cancels;
  }

(** {1 Unit tests — budget arithmetic and order reinstatement} *)

let _entering_position ?(filled_quantity = 0.0) ?(side = Position.Long) () =
  Position.
    {
      id = _position_id;
      symbol = _symbol;
      side;
      entry_reasoning = ManualDecision { description = "g2a unit" };
      exit_reason = None;
      state =
        Entering
          {
            target_quantity = _quantity;
            filled_quantity;
            entry_price = _entry_price;
            created_date = _date "2024-01-02";
          };
      last_updated = _date "2024-01-02";
      portfolio_lot_ids = [];
    }

let _positions_with pos = String.Map.singleton pos.Position.id pos
let _entering_positions = _positions_with (_entering_position ())

let _trade ?(side = Trading_base.Types.Buy) ?(order_id = "ord-1") () =
  Trading_base.Types.
    {
      id = "trade-1";
      order_id;
      symbol = _symbol;
      side;
      quantity = _quantity;
      price = _entry_price;
      commission = 0.0;
      timestamp = Time_ns_unix.epoch;
    }

let _stoplimit_params =
  Trading_orders.Create_order.
    {
      symbol = _symbol;
      side = Trading_base.Types.Buy;
      order_type = Trading_base.Types.StopLimit (_entry_price, 110.0);
      quantity = _quantity;
      time_in_force = Order_types.Day;
    }

(* Stamp "ord-1" [Filled] with no shares booked — what
   [Engine._process_order_with_execution] does the instant it matches an order,
   before the portfolio is consulted. Called once per simulated tick below,
   because that is how often the engine does it. *)
let _stamp_provisionally_filled mgr =
  match Trading_orders.Manager.get_order mgr "ord-1" with
  | Error err -> assert_failure ("get_order failed: " ^ Status.show err)
  | Ok order ->
      let (_ : Status.status) =
        Trading_orders.Manager.update_order mgr
          (Order_types.update_status order Order_types.Filled)
      in
      ()

(* An order manager holding one StopLimit entry order the engine has just
   provisionally stamped [Filled]. *)
let _manager_with_provisionally_filled_order () =
  let mgr = Trading_orders.Manager.create () in
  let order =
    match
      Trading_orders.Create_order.create_order ~id:"ord-1" _stoplimit_params
    with
    | Ok o -> o
    | Error err -> assert_failure ("create_order failed: " ^ Status.show err)
  in
  let (_ : Status.status list) =
    Trading_orders.Manager.submit_orders mgr [ order ]
  in
  _stamp_provisionally_filled mgr;
  mgr

(* A ledger over a manager holding one provisionally-filled entry order, plus
   that manager. *)
let _ledger_and_manager ~max_retries =
  let mgr = _manager_with_provisionally_filled_order () in
  (Entry_retry.create ~max_retries ~order_manager:mgr, mgr)

let _ledger ~max_retries = fst (_ledger_and_manager ~max_retries)

(* Reject the same ticket on [n] successive simulated ticks and report, oldest
   first, whether each rejection was claimed for retry (i.e. withheld from the
   returned give-up list). The engine re-stamps the order [Filled] each tick, so
   the fixture must too — a claim reinstates the order to [Pending], and
   without the re-stamp the next offer would find nothing to re-offer.

   Built with an explicit fold rather than [List.init], whose [f] runs in
   descending index order and would reverse a side-effecting sequence. *)
let _retry_sequence ~max_retries ~n =
  let ledger, mgr = _ledger_and_manager ~max_retries in
  let step acc _ =
    let unclaimed =
      Entry_retry.withhold_retryable ledger ~positions:_entering_positions
        ~rejected_trades:[ _trade () ]
    in
    _stamp_provisionally_filled mgr;
    List.is_empty unclaimed :: acc
  in
  List.rev (List.fold (List.range 0 n) ~init:[] ~f:step)

(** {b The default, R1.} At [0] this is the identity on its input and the order
    is left exactly as the engine stamped it, so the caller's cancel path sees
    the list it always saw and no order can fill again. *)
let test_zero_budget_is_the_identity _ =
  let ledger = _ledger ~max_retries:0 in
  let trade = _trade () in
  assert_that
    (Entry_retry.withhold_retryable ledger ~positions:_entering_positions
       ~rejected_trades:[ trade ])
    (elements_are [ equal_to trade ])

(** [N] means N: the first [N] rejections are claimed and the next one is not.
*)
let test_budget_is_exhausted_after_n_retries _ =
  assert_that
    (_retry_sequence ~max_retries:2 ~n:4)
    (equal_to [ true; true; false; false ])

(** The ledger counts what it spent, per ticket. Two rejections on successive
    ticks against a budget of three leaves one unspent. *)
let test_retries_used_tracks_spend _ =
  let ledger, mgr = _ledger_and_manager ~max_retries:3 in
  let reject () =
    let (_ : Trading_base.Types.trade list) =
      Entry_retry.withhold_retryable ledger ~positions:_entering_positions
        ~rejected_trades:[ _trade () ]
    in
    _stamp_provisionally_filled mgr
  in
  reject ();
  reject ();
  assert_that
    (Entry_retry.retries_used ledger ~position_id:_position_id)
    (equal_to 2)

(** {b The load-bearing reinstatement claim.} A claimed trade's order comes back
    [Pending] with its {b order type unchanged} — same trigger, same limit. The
    limit leg is where [entry_extension_max_pct] lives, so this identity is what
    makes the do-not-chase cap bind on a retry rather than be bypassed by it. *)
let test_claimed_order_returns_to_pending_with_its_type _ =
  let mgr = _manager_with_provisionally_filled_order () in
  let ledger = Entry_retry.create ~max_retries:1 ~order_manager:mgr in
  let (_ : Trading_base.Types.trade list) =
    Entry_retry.withhold_retryable ledger ~positions:_entering_positions
      ~rejected_trades:[ _trade () ]
  in
  assert_that
    (Trading_orders.Manager.get_order mgr "ord-1")
    (is_ok_and_holds
       (all_of
          [
            field
              (fun (o : Order_types.order) -> o.status)
              (equal_to (Order_types.Pending : Order_types.order_status));
            field
              (fun (o : Order_types.order) -> o.order_type)
              (equal_to
                 (Trading_base.Types.StopLimit (_entry_price, 110.0)
                   : Trading_base.Types.order_type));
            field
              (fun (o : Order_types.order) -> o.quantity)
              (float_equal _quantity);
          ]))

(** A rejected {i exit} whose symbol happens to carry an entering sibling is not
    a retry candidate: the side that opens a long is [Buy], and a [Sell] belongs
    to {!Cancel_handler.revert_rejected_exits}. Without the side guard this
    trade would silently spend the entry ticket's budget. *)
let test_wrong_side_is_not_claimed _ =
  let ledger = _ledger ~max_retries:2 in
  assert_that
    (Entry_retry.withhold_retryable ledger ~positions:_entering_positions
       ~rejected_trades:[ _trade ~side:Trading_base.Types.Sell () ])
    (size_is 1)

(** A partially-filled ticket keeps today's behaviour: re-offering its order
    would re-request the full quantity on top of shares already booked — the
    entry-side reading of the guard that keeps
    {!Cancel_handler.revert_rejected_exits} off a partially-filled [Exiting]. *)
let test_partially_filled_ticket_is_not_claimed _ =
  let ledger = _ledger ~max_retries:2 in
  assert_that
    (Entry_retry.withhold_retryable ledger
       ~positions:
         (_positions_with (_entering_position ~filled_quantity:40.0 ()))
       ~rejected_trades:[ _trade () ])
    (size_is 1)

(** A trade naming no order in the manager is not claimed and costs no budget —
    there is nothing to re-offer, so it must follow the normal cancel path
    rather than vanish. *)
let test_trade_with_no_order_is_not_claimed _ =
  let ledger = _ledger ~max_retries:2 in
  assert_that
    ( Entry_retry.withhold_retryable ledger ~positions:_entering_positions
        ~rejected_trades:[ _trade ~order_id:"ord-missing" () ],
      Entry_retry.retries_used ledger ~position_id:_position_id )
    (all_of [ field fst (size_is 1); field snd (equal_to 0) ])

(** {1 End-to-end tests} *)

(** {b Default, R1.} At [0] the d2 rejection destroys the ticket outright, with
    the unchanged [CancelEntry] reason. The d4 bar is affordable and the ticket
    is gone anyway — no fill at all. This is the pre-G2a behaviour, and it is
    the control every arm below is read against. *)
let test_zero_retries_destroys_the_ticket _ =
  assert_that
    (_observe_run ~test_name:"g2a_zero" ~entry_fill_reject_retries:0 ())
    (all_of
       [
         field (fun o -> o.fill_dates) (size_is 0);
         field
           (fun o -> o.cancel_reasons)
           (elements_are [ equal_to Cancel_handler.portfolio_rejection_reason ]);
       ])

(** {b The mechanism.} With budget the d2 rejection keeps the ticket, and the
    original resting order — the strategy emits exactly one [CreateEntering] —
    fills on the affordable d4 bar. No cancel is announced. *)
let test_retry_fills_on_a_later_tick _ =
  assert_that
    (_observe_run ~test_name:"g2a_retry_fills" ~entry_fill_reject_retries:2 ())
    (all_of
       [
         field
           (fun o -> o.fill_dates)
           (elements_are [ equal_to (_date "2024-01-05") ]);
         field (fun o -> o.fill_prices) (elements_are [ float_equal 100.0 ]);
         field (fun o -> o.cancel_reasons) (size_is 0);
       ])

(** {b Exhaustion.} At [1] the d2 rejection spends the only retry and the d3
    rejection destroys the ticket — with the same [cancel_reason] the default
    arm records, one tick later. The affordable d4 bar then finds no order.

    The d3 rejection needs a fill to reject, so this arm runs without the
    do-not-chase cap: as a Market order the reinstated ticket fills at d3's open
    of 200 and asks for 20,000 the book does not have. *)
let test_exhausted_budget_destroys_with_the_same_reason _ =
  assert_that
    (_observe_run ~test_name:"g2a_exhausted" ~entry_fill_reject_retries:1 ())
    (all_of
       [
         field (fun o -> o.fill_dates) (size_is 0);
         field
           (fun o -> o.cancel_reasons)
           (elements_are [ equal_to Cancel_handler.portfolio_rejection_reason ]);
       ])

(** {b The do-not-chase cap still binds on a retry.} Same fixture, same budget,
    but the entry rests as [StopLimit (100, 110)]. d3 gaps to 200 — the stop
    triggers and the limit refuses, so the retried ticket does {e not} fill
    there. It survives to d4 and fills at 100.

    Read the two assertions together: the fill exists (so the retry did happen)
    and it is at 100 on the {e last} step (so the cap, not luck, kept the
    reinstated order off d3's 200 print). Contrast
    {!test_exhausted_budget_destroys_with_the_same_reason}, which is the same
    bars without the cap and whose retry is consumed by exactly that print. *)
let test_extension_cap_refuses_a_too_far_retry_fill _ =
  assert_that
    (_observe_run ~test_name:"g2a_cap" ~entry_extension_max_pct:10.0
       ~entry_fill_reject_retries:2 ())
    (all_of
       [
         field
           (fun o -> o.fill_dates)
           (elements_are [ equal_to (_date "2024-01-05") ]);
         field (fun o -> o.fill_prices) (elements_are [ float_equal 100.0 ]);
         field (fun o -> o.cancel_reasons) (size_is 0);
       ])

let suite =
  "entry_fill_reject_retries (G2a)"
  >::: [
         "a zero budget is the identity" >:: test_zero_budget_is_the_identity;
         "the budget is exhausted after N retries"
         >:: test_budget_is_exhausted_after_n_retries;
         "retries_used tracks what was spent" >:: test_retries_used_tracks_spend;
         "a claimed order returns to Pending with its order type"
         >:: test_claimed_order_returns_to_pending_with_its_type;
         "a wrong-side (exit) trade is not claimed"
         >:: test_wrong_side_is_not_claimed;
         "a partially-filled ticket is not claimed"
         >:: test_partially_filled_ticket_is_not_claimed;
         "a trade whose order is gone is not claimed"
         >:: test_trade_with_no_order_is_not_claimed;
         "0 retries destroys the ticket on the first rejection"
         >:: test_zero_retries_destroys_the_ticket;
         "a retried ticket fills on a later tick"
         >:: test_retry_fills_on_a_later_tick;
         "an exhausted budget destroys with the same cancel reason"
         >:: test_exhausted_budget_destroys_with_the_same_reason;
         "the do-not-chase cap refuses a too-far retry fill"
         >:: test_extension_cap_refuses_a_too_far_retry_fill;
       ]

let () = run_test_tt_main suite
