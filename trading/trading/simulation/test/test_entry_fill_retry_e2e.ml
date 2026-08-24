(** End-to-end tests for [entry_fill_reject_retries] (G2a) against a real
    {!Trading_simulation.Simulator.run}, complementing the unit tests in
    [test_entry_fill_retry.ml].

    {!Trading_simulation.Entry_fill_retry} re-offers a refused entry as a fresh
    [Pending] {e copy} of the original order, and its [.mli] claims the copy
    "carries the original's symbol, side, order type (including a [StopLimit]'s
    trigger and cap)". The unit suite pins that the copy's [order_type] field is
    equal to the original's. That is a weaker statement than the one the claim
    is made {e for}: that the do-not-chase cap still {b binds} on a retry fill,
    so a ticket whose price ran away while it was mid-retry is not chased.

    The fixture here separates those. Its third bar gaps to double the trigger
    while the ticket is mid-retry:

    - {b With the cap} the reinstated order refuses that print and fills on the
      last bar, back at the trigger.
    - {b Without it} — same bars, same mechanism — the retry is consumed by
      exactly that gapped print.

    The two arms are each other's control: read alone, the capped arm's fill
    could be a ticket that simply never got a chance at the gap. Read together,
    the uncapped arm proves the gap was fillable and the cap is what refused it.
    (Issue #2466: ported from the closed duplicate PR #2465, whose fixture had
    no equivalent on main.) *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers
module Position = Trading_strategy.Position

let _date s = Date.of_string s
let _symbol = "AAPL"
let _position_id = "AAPL-g2a-e2e"

(* Zero commission and zero slippage, so every affordability threshold below is
   exactly [quantity * price] and the assertions read off the bars. *)
let _commission = { Trading_engine.Types.per_share = 0.0; minimum = 0.0 }
let _trigger_price = 100.0
let _quantity = 100.0

(* The do-not-chase band, as a percent past the trigger. At [_trigger_price] the
   limit leg is 110 — above d2's 108 (fillable) and far below d3's 200. *)
let _extension_max_pct = 10.0

(* The book. d2 needs 10,800 and is refused; d4 needs 10,000 and is not. The
   gap between them is what separates "destroyed on the first refusal" from
   "re-offered and filled later" without cash appearing from nowhere. *)
let _cash = 10_400.0

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

(* Four bars. The strategy writes its ticket on d1; the order is submitted at
   the end of that step and first matched on d2.

   d2 opens 108 — past the trigger, inside the 110 cap, so it fills there and
   asks the book for 10,800 it does not have.
   d3 gaps to 200, far past the cap. This is the bar the two arms disagree on.
   d4 opens back at the trigger, asking an affordable 10,000. *)
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

let _config =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-06";
    initial_cash = _cash;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* One-shot strategy: a single [CreateEntering] on its first call with a bar,
   then silence. Because it never re-emits, every fill observed below comes from
   the original resting order or a retry copy of it — never from a fresh ticket,
   which is what makes "the retry happened" readable off a fill date. *)
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
              entry_price = _trigger_price;
              reasoning = ManualDecision { description = "g2a e2e fixture" };
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

type run_observation = {
  fills : (Date.t * float) list;
      (** Step date and price of each accepted fill, so "which tick, at what
          price" is asserted directly rather than as a position in a
          step-indexed vector. *)
  cancel_reasons : string list;
      (** Every [CancelEntry] reason the simulator announced — the same
          [on_transitions] hook production composes [Trade_audit] onto, so a
          destroyed ticket is observed here exactly as the artifact records it.
      *)
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
        let sim = create_exn ~config:_config ~deps in
        match run sim with
        | Ok r -> r
        | Error err -> assert_failure ("run failed: " ^ Status.show err))
  in
  {
    fills =
      List.concat_map result.steps ~f:(fun s ->
          List.map s.trades ~f:(fun (t : Trading_base.Types.trade) ->
              (s.date, t.price)));
    cancel_reasons = !cancels;
  }

(** {b The R1 control.} At budget [0] the d2 refusal destroys the ticket
    outright with the unchanged reason token, and the affordable d4 bar finds no
    order left. This is the pre-G2a behaviour both arms below are read against.
*)
let test_zero_budget_destroys_the_ticket _ =
  assert_that
    (_observe_run ~test_name:"g2a_e2e_zero" ~entry_fill_reject_retries:0 ())
    (all_of
       [
         field (fun o -> o.fills) is_empty;
         field
           (fun o -> o.cancel_reasons)
           (elements_are
              [
                equal_to
                  Trading_simulation.Cancel_handler.portfolio_rejection_reason;
              ]);
       ])

(** {b The uncapped control — the retry is consumed by the gap.} Same bars, one
    retry, no do-not-chase cap: the ticket rests as a Market order, so the
    reinstated copy fills at d3's open of 200 and asks for 20,000 the book does
    not have. That second refusal finds the budget spent and destroys the
    ticket, so d4's affordable bar again finds nothing.

    This arm exists to prove d3 is {e fillable}. Without it, the capped arm's d4
    fill would be consistent with a mechanism that simply never offered at the
    gap. *)
let test_uncapped_retry_is_consumed_by_the_gapped_print _ =
  assert_that
    (_observe_run ~test_name:"g2a_e2e_uncapped" ~entry_fill_reject_retries:1 ())
    (all_of
       [
         field (fun o -> o.fills) is_empty;
         field
           (fun o -> o.cancel_reasons)
           (elements_are
              [
                equal_to
                  Trading_simulation.Cancel_handler.portfolio_rejection_reason;
              ]);
       ])

(** {b The discriminator — the cap binds on a retry fill.} Same bars and
    mechanism, but the ticket rests as [StopLimit (100, 110)]. d3's 200 print
    triggers the stop and the limit refuses it, so the reinstated order does
    {e not} fill there; it survives to d4 and fills at the trigger.

    Both halves are load-bearing. A fill exists, so the retry did happen; and it
    is at 100 on the {e last} step, so the cap — not luck, and not a ticket that
    was never offered (see the uncapped control) — is what kept the reinstated
    order off the gapped print. No cancel is announced: the ticket never died.
*)
let test_extension_cap_refuses_a_gapped_retry_fill _ =
  assert_that
    (_observe_run ~test_name:"g2a_e2e_capped"
       ~entry_extension_max_pct:_extension_max_pct ~entry_fill_reject_retries:2
       ())
    (all_of
       [
         field
           (fun o -> o.fills)
           (elements_are [ equal_to (_date "2024-01-05", 100.0) ]);
         field (fun o -> o.cancel_reasons) is_empty;
       ])

let suite =
  "entry_fill_reject_retries (G2a) end-to-end"
  >::: [
         "a zero budget destroys the ticket on the first refusal"
         >:: test_zero_budget_destroys_the_ticket;
         "without the cap, the retry is consumed by the gapped print"
         >:: test_uncapped_retry_is_consumed_by_the_gapped_print;
         "with the cap, the reinstated order refuses the gapped print and \
          fills at the trigger"
         >:: test_extension_cap_refuses_a_gapped_retry_fill;
       ]

let () = run_test_tt_main suite
