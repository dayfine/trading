(** End-to-end simulator test for the #2696 fill-time residual: a resting entry
    ticket admitted on a symbol's [active_through] marker day must not fill on a
    later bar.

    {b Why this test and not the unit test alone.} The residual is a composition
    of four behaviours, none of which is visible from
    {!Trading_simulation.Delisted_ticket_cancel} in isolation:
    [Market_state.update] keeps serving a dark symbol's retained last bar;
    [Engine.process_orders] iterates active orders rather than today's bars;
    resting tickets are not re-screened at the default config; and the StopLimit
    entry model is exempt from the next-open fill gate. Only a run through
    {!Trading_simulation.Simulator} exercises all four.

    {b The V17 band.} The fill this pins lands {b 2 days} after the marker,
    inside the 1-6-day window that sits {e under}
    [Backtest_validation.Validator_fallback_check.check_v17]'s
    [stale_entry_days = 7] default. That band is precisely where the residual
    used to hide: a clean V17 after the #2695 admission gate was evidence by
    margin, not by construction, because a fill in this window is not reported.
    The control arm below shows the fill really does land there without the
    cancel, so the treatment arm's empty trade list is the closure, not a
    fixture that never fired.

    Fixture shape (mirrors [test_gtc_entry_persistence.ml], whose first test is
    exactly this bar series without a marker): the ticket is written on Jan 2,
    the symbol's marker is Jan 3, and the first bar to trade through the E = 160
    trigger is Jan 5 — 2 days past the marker, 3 days after the ticket was
    written. Both arms run the identical bar series and strategy; the only
    difference is whether [active_through_for] returns the marker. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let _date s = Date.of_string s
let _symbol = "AAPL"
let _entry_price = 160.0
let _marker = _date "2024-01-03"

let _make_daily_price ~date ~open_price ~high ~low ~close =
  Types.Daily_price.
    {
      date;
      open_price;
      high_price = high;
      low_price = low;
      close_price = close;
      volume = 1_000_000;
      adjusted_close = close;
      active_through = None;
    }

(* Below the E = 160 trigger through Jan 4; the Jan 5 bar trades up through it
   (high = 165) and would fill the resting ticket. Jan 5 is 2 days past the
   Jan 3 marker and 3 days after the Jan 2 admission — inside V17's blind band.
*)
let _prices =
  [
    _make_daily_price ~date:(_date "2024-01-02") ~open_price:150.0 ~high:152.0
      ~low:149.0 ~close:151.0;
    _make_daily_price ~date:(_date "2024-01-03") ~open_price:151.0 ~high:153.0
      ~low:150.0 ~close:152.0;
    _make_daily_price ~date:(_date "2024-01-04") ~open_price:152.0 ~high:154.0
      ~low:151.0 ~close:153.0;
    _make_daily_price ~date:(_date "2024-01-05") ~open_price:153.0 ~high:165.0
      ~low:152.0 ~close:164.0;
    _make_daily_price ~date:(_date "2024-01-08") ~open_price:164.0 ~high:166.0
      ~low:162.0 ~close:165.0;
  ]

let _commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Writes one entry ticket for [_symbol] on the first call and never again —
    the "admitted on / before the marker day, then left resting" shape. Standing
    in for the screener keeps the test about the ticket lifecycle rather than
    about candidate assembly (which #2695's gate owns). *)
module Once_entry_strategy : sig
  include Trading_strategy.Strategy_interface.STRATEGY

  val reset : unit -> unit
end = struct
  let name = "OnceEntry"
  let emitted = ref false
  let reset () = emitted := false

  let _create_entering : Trading_strategy.Position.transition =
    {
      position_id = "AAPL-TICKET";
      date = _date "2024-01-02";
      kind =
        CreateEntering
          {
            symbol = _symbol;
            side = Long;
            target_quantity = 10.0;
            entry_price = _entry_price;
            reasoning = ManualDecision { description = "delisting fixture" };
          };
    }

  let on_market_close ~get_price:_ ~get_indicator:_ ~portfolio:_ =
    if !emitted then Ok { Trading_strategy.Strategy_interface.transitions = [] }
    else begin
      emitted := true;
      Ok
        {
          Trading_strategy.Strategy_interface.transitions = [ _create_entering ];
        }
    end
end

let _config =
  {
    start_date = _date "2024-01-02";
    end_date = _date "2024-01-09";
    initial_cash = 100_000.0;
    commission = _commission;
    strategy_cadence = Types.Cadence.Daily;
  }

(* Both arms differ only in [active_through_for]: [None] is the control (every
   warehouse built before #2691), [Some _marker] the treatment. *)
let _run_exn ~name ?active_through_for () =
  Once_entry_strategy.reset ();
  with_test_data name
    [ (_symbol, _prices) ]
    ~f:(fun data_dir ->
      let deps =
        create_deps ~symbols:[ _symbol ] ~data_dir
          ~strategy:(module Once_entry_strategy)
          ~commission:_commission ~entry_extension_max_pct:15.0
          ?active_through_for ()
      in
      let sim = Test_helpers.create_exn ~config:_config ~deps in
      match run sim with
      | Error err -> failwith ("run failed: " ^ Status.show err)
      | Ok result -> result)

let _all_trades result = List.concat_map result.steps ~f:(fun s -> s.trades)

(** {b Control.} No marker: the resting ticket fills on the Jan-5 cross, 2 days
    past what would have been the marker and 3 days after admission — a fill
    inside V17's 7-day blind band, which is the residual this issue closes.
    Asserted on the trade itself so the treatment arm's silence is meaningful.
*)
let test_without_marker_the_ticket_fills_inside_the_v17_band _ =
  assert_that
    (_all_trades (_run_exn ~name:"delisted_ticket_cancel_control" ()))
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_base.Types.trade) -> t.symbol)
               (equal_to _symbol);
             field
               (fun (t : Trading_base.Types.trade) -> t.side)
               (equal_to (Trading_base.Types.Buy : Trading_base.Types.side));
             field
               (fun (t : Trading_base.Types.trade) -> t.quantity)
               (float_equal 10.0);
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (is_between
                  (module Float_ord)
                  ~low:_entry_price ~high:(_entry_price *. 1.15));
           ];
       ])

(** ...and it lands on the Jan-5 step specifically — 3 calendar days after the
    Jan-2 admission and 2 after the Jan-3 marker, i.e. squarely in the 1-6-day
    band V17 does not report. *)
let test_control_fill_lands_on_the_cross_day _ =
  assert_that
    (List.map (_run_exn ~name:"delisted_ticket_cancel_control_day" ()).steps
       ~f:(fun s -> List.length s.trades))
    (equal_to [ 0; 0; 0; 1; 0; 0; 0 ])

(** {b Treatment.} With the marker present the identical series produces NO
    trade: the ticket is cancelled and its order retired on Jan 4, the first
    step past the marker, before the Jan-5 bar can fill it. Closure by
    construction rather than by V17's margin. *)
let test_with_marker_the_ticket_never_fills _ =
  assert_that
    (_all_trades
       (_run_exn ~name:"delisted_ticket_cancel_treatment"
          ~active_through_for:(fun _ -> Some _marker)
          ()))
    is_empty

(** The order was submitted in both arms — so the treatment arm's empty trade
    list is the cancel working, not the ticket never having been written. *)
let test_treatment_still_submits_the_order_before_cancelling_it _ =
  assert_that
    (List.map
       (_run_exn ~name:"delisted_ticket_cancel_submitted"
          ~active_through_for:(fun _ -> Some _marker)
          ())
         .steps ~f:(fun s -> List.length s.orders_submitted))
    (equal_to [ 1; 0; 0; 0; 0; 0; 0 ])

let suite =
  "delisted ticket cancel (simulation)"
  >::: [
         "without a marker the ticket fills inside the V17 band"
         >:: test_without_marker_the_ticket_fills_inside_the_v17_band;
         "the control fill lands on the cross day"
         >:: test_control_fill_lands_on_the_cross_day;
         "with a marker the ticket never fills"
         >:: test_with_marker_the_ticket_never_fills;
         "the treatment still submits the order before cancelling it"
         >:: test_treatment_still_submits_the_order_before_cancelling_it;
       ]

let () = run_test_tt_main suite
