(** Strategy-level regression tests for the force-liquidation halt-and-resume
    contract (PR #695, qc-behavioral B1).

    The bug pinned here: [Weinstein_strategy._on_market_close] previously
    short-circuited on [halted = true] before invoking the macro analyser, so
    [prior_macro] was never refreshed once the portfolio-floor halt fired.
    [_maybe_reset_halt] was gated on [not halted] downstream of the
    short-circuit, so the halt latched permanently — contradicting the .mli
    claim that the halt clears when macro flips off [Bearish].

    The fix splits [_run_screen] into a cheap [_run_macro_only] pass and an
    expensive [_run_screen_after_macro] pass; the macro pass and
    [_maybe_reset_halt] now run on every Friday including halted Fridays, so the
    halt-reset fires the moment macro recovers.

    These tests drive [Internal_for_test.on_market_close] directly so the
    halt-and-resume sequencing is observable without going through {!make}'s
    closure. *)

open Core
open OUnit2
open Matchers
open Weinstein_strategy
open Weinstein_types
module FL = Portfolio_risk.Force_liquidation

(* ------------------------------------------------------------------ *)
(* Helpers — minimal panel-backed bar reader on a single index symbol  *)
(* ------------------------------------------------------------------ *)

let _make_daily_bar ~date ~price =
  {
    Types.Daily_price.date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
  }

(** Build [n] consecutive daily bars (one per calendar day) starting at
    [start_date], with prices walking by [step] per day. The strategy reads
    weekly views on top of the daily panel; producing one daily bar per day
    gives the weekly aggregator a clean sequence to bucket. *)
let _make_daily_bars ~start_date ~n ~start_price ~step =
  List.init n ~f:(fun i ->
      let date = Date.add_days start_date i in
      let price = start_price +. (Float.of_int i *. step) in
      _make_daily_bar ~date ~price)

(** Find a Friday close to [start_date] (i.e. the next Friday on or after). *)
let _next_friday d =
  let rec go d =
    if Day_of_week.equal (Date.day_of_week d) Day_of_week.Fri then d
    else go (Date.add_days d 1)
  in
  go d

type _strategy_state = {
  stop_states : Weinstein_stops.stop_state String.Map.t ref;
  last_stop_out_dates : Date.t Hashtbl.M(String).t;
  prior_macro : market_trend ref;
  prior_macro_result : Macro.result option ref;
  peak_tracker : FL.Peak_tracker.t;
  prior_stages : stage Hashtbl.M(String).t;
  sector_prior_stages : stage Hashtbl.M(String).t;
  ticker_sectors : (string, string) Hashtbl.t;
  stage3_streaks : int Hashtbl.M(String).t;
  laggard_streaks : int Hashtbl.M(String).t;
  bar_reader : Bar_reader.t;
}
(** Build a fresh closure-state bundle that mirrors what {!make} constructs
    internally. Returns [(state, get_price)] where [state] holds the mutable
    refs used by {!Internal_for_test.on_market_close}. *)

let _fresh_state ~bar_reader =
  {
    stop_states = ref String.Map.empty;
    last_stop_out_dates = Hashtbl.create (module String);
    prior_macro = ref Neutral;
    prior_macro_result = ref None;
    peak_tracker = FL.Peak_tracker.create ();
    prior_stages = Hashtbl.create (module String);
    sector_prior_stages = Hashtbl.create (module String);
    ticker_sectors = Hashtbl.create (module String);
    stage3_streaks = Hashtbl.create (module String);
    laggard_streaks = Hashtbl.create (module String);
    bar_reader;
  }

(** Wrap [Bar_reader.daily_bars_for state.bar_reader] into the
    [Strategy_interface.get_price_fn] shape expected by [_on_market_close]. *)
let _get_price_of_state state ~current_date symbol =
  match
    Bar_reader.daily_bars_for state.bar_reader ~symbol ~as_of:current_date
  with
  | [] -> None
  | bars -> List.last bars

let _drive_tick state ~config ~current_date ~portfolio =
  Internal_for_test.on_market_close ~config ~ad_bars:[]
    ~stop_states:state.stop_states
    ~last_stop_out_dates:state.last_stop_out_dates
    ~prior_macro:state.prior_macro ~prior_macro_result:state.prior_macro_result
    ~peak_tracker:state.peak_tracker ~bar_reader:state.bar_reader
    ~prior_stages:state.prior_stages
    ~sector_prior_stages:state.sector_prior_stages
    ~ticker_sectors:state.ticker_sectors ~stage3_streaks:state.stage3_streaks
    ~laggard_streaks:state.laggard_streaks ~audit_recorder:Audit_recorder.noop
    ~get_price:(_get_price_of_state state ~current_date)
    ~get_indicator:(fun _ _ _ _ -> None)
    ~portfolio

(* ------------------------------------------------------------------ *)
(* Direct-unit pinning of _maybe_reset_halt                            *)
(* ------------------------------------------------------------------ *)

(** Pins the macro-flip semantics of {!Internal_for_test.maybe_reset_halt}. The
    halt clears when macro is [Bullish] or [Neutral]; stays armed under
    [Bearish]. *)
let test_maybe_reset_halt_clears_on_non_bearish _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Bullish;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active)

let test_maybe_reset_halt_clears_on_neutral _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Neutral;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Active)

let test_maybe_reset_halt_persists_under_bearish _ =
  let pt = FL.Peak_tracker.create () in
  FL.Peak_tracker.mark_halted pt;
  Internal_for_test.maybe_reset_halt ~peak_tracker:pt ~macro_trend:Bearish;
  assert_that (FL.Peak_tracker.halt_state pt) (equal_to FL.Halted)

(* ------------------------------------------------------------------ *)
(* End-to-end halt-resume regression                                    *)
(* ------------------------------------------------------------------ *)

let _index_symbol = "GSPCX"

(** Build a panel-backed bar reader with a steadily-rising index series of
    [n_days] bars ending on or before [end_date]. The trend is strongly upward
    (1% daily gain); over 30+ weeks of weekly aggregation this drives the macro
    analyser away from [Bearish] under empty AD bars + empty globals. *)
let _rising_index_reader ~end_date =
  let n_days = 260 in
  (* ~52 weeks of trading days *)
  let start_date = Date.add_days end_date (-(n_days - 1)) in
  let bars =
    _make_daily_bars ~start_date ~n:n_days ~start_price:100.0 ~step:1.0
  in
  Bar_reader.of_in_memory_bars [ (_index_symbol, bars) ]

(** B1 regression: the halt-reset fires on Friday even when the peak tracker
    enters the tick already in [Halted]. Pre-fix [_on_market_close] returned
    [entry_transitions = []] AND skipped [_maybe_reset_halt] entirely (gated on
    [not halted]); the halt latched permanently. Post-fix the macro pass runs
    unconditionally on Friday and [_maybe_reset_halt] consults the fresh trend,
    flipping the halt back to [Active] when macro is no longer [Bearish]. *)
let test_halt_resets_after_macro_flip _ =
  let current_date = _next_friday (Date.of_string "2024-04-26") in
  let bar_reader = _rising_index_reader ~end_date:current_date in
  let state = _fresh_state ~bar_reader in
  (* Prime the pump: halt is active before the tick. *)
  FL.Peak_tracker.mark_halted state.peak_tracker;
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Halted);
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  (* Tick must succeed cleanly even with the halt active. *)
  assert_that result is_ok;
  (* The rising-index series produces a non-Bearish macro trend; the halt
     therefore clears. Pre-fix, macro was never refreshed and the halt
     remained Halted. *)
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Active);
  (* prior_macro must reflect the just-computed trend (not the initial
     Neutral default). The rising series hits Bullish under the panel-
     callbacks macro pipeline. *)
  assert_that !(state.prior_macro)
    (matching ~msg:"Expected non-Bearish macro after rising index"
       (function Bearish -> None | t -> Some t)
       (equal_to Bullish))

(** Symmetric: the halt persists when macro stays [Bearish]. Pinned via a
    declining index series — the macro analyser returns [Bearish] under a
    monotonically falling 30-week MA. The halt does NOT clear, even though the
    macro pass ran. *)
let test_halt_persists_when_macro_stays_bearish _ =
  let current_date = _next_friday (Date.of_string "2024-04-26") in
  let n_days = 260 in
  let start_date = Date.add_days current_date (-(n_days - 1)) in
  let bars =
    _make_daily_bars ~start_date ~n:n_days ~start_price:200.0 ~step:(-0.5)
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ (_index_symbol, bars) ] in
  let state = _fresh_state ~bar_reader in
  FL.Peak_tracker.mark_halted state.peak_tracker;
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  assert_that result is_ok;
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Halted);
  assert_that !(state.prior_macro) (equal_to Bearish)

(* ------------------------------------------------------------------ *)
(* G13 — non-trading-day short-circuit                                 *)
(* ------------------------------------------------------------------ *)

(** Regression: the strategy must short-circuit on non-trading days (no bar for
    the primary index). Pre-fix, [_on_market_close] fell back to [Date.today]
    and ran the full pipeline — including [Force_liquidation_runner.update] —
    with cash that contained accumulated short proceeds but
    [_holding_market_value] returning 0.0 for every position (no [get_price]
    this tick). [Portfolio_view.portfolio_value] degenerated to bare [cash],
    well above the true mtm-aware value; [Peak_tracker.observe] phantom-spiked
    the peak. On the next real trading day, [Portfolio_floor] fired for every
    Holding position.

    Empirically (sp500-2019-2023 post-G12, pre-G13): peak permanently set to
    $2.74M from weekend phantom observations; floor at 0.4×peak = $1.096M;
    cascade fired every Monday for 449 spurious force-liqs.

    Post-fix, the strategy returns empty transitions and skips every side-effect
    (stops, FL, splits, macro, screener) when no primary-index bar is available.
    The load-bearing assertion is that [Peak_tracker] stays at its pre-call peak
    — no observation contaminates it. *)
let test_no_primary_index_bar_short_circuits _ =
  let current_date =
    Date.of_string "2019-01-13"
    (* a Sunday *)
  in
  (* Bar reader with no bars for the primary index (or any other symbol) —
     exactly the non-trading-day shape the simulator hits on weekends and
     holidays in panel mode. *)
  let bar_reader = Bar_reader.empty () in
  let state = _fresh_state ~bar_reader in
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 1_500_000.0; positions = String.Map.empty }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  (* Tick succeeds with zero transitions. *)
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Trading_strategy.Strategy_interface.output) ->
            o.transitions)
          is_empty));
  (* The load-bearing assertion: peak_tracker is untouched. Pre-fix this
     would equal [portfolio.cash = 1_500_000.0] (the phantom observation)
     even though no real market state existed this tick. *)
  assert_that (FL.Peak_tracker.peak state.peak_tracker) (float_equal 0.0);
  (* Halt state stays Active too (no breach can fire when no observation
     happens). *)
  assert_that
    (FL.Peak_tracker.halt_state state.peak_tracker)
    (equal_to FL.Active)

(* ------------------------------------------------------------------ *)
(* Adjust-vs-exit dedup invariant (PR #911 follow-up)                  *)
(* ------------------------------------------------------------------ *)

(** Build a [Holding] long position via the canonical entry chain so the result
    is bit-equal to what the simulator would have produced. Reused by the dedup
    test below. *)
let _make_holding_long ~symbol ~position_id ~entry_date ~quantity ~entry_price =
  let unwrap = function
    | Ok p -> p
    | Error err -> assert_failure ("position setup failed: " ^ Status.show err)
  in
  let trans kind =
    { Trading_strategy.Position.position_id; date = entry_date; kind }
  in
  let p =
    Trading_strategy.Position.create_entering
      (trans
         (Trading_strategy.Position.CreateEntering
            {
              symbol;
              side = Trading_base.Types.Long;
              target_quantity = quantity;
              entry_price;
              reasoning =
                Trading_strategy.Position.TechnicalSignal
                  { indicator = "test"; description = "dedup test entry" };
            }))
    |> unwrap
  in
  let p =
    Trading_strategy.Position.apply_transition p
      (trans
         (Trading_strategy.Position.EntryFill
            { filled_quantity = quantity; fill_price = entry_price }))
    |> unwrap
  in
  Trading_strategy.Position.apply_transition p
    (trans
       (Trading_strategy.Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = Some 50.0;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(** Regression for the (Exiting, UpdateRiskParams) collision pinned by the dedup
    pass at [weinstein_strategy.ml] lines 746–783.

    The strategy's transition assembly previously concatenated
    [adjust_transitions] (UpdateRiskParams from {!Stops_runner}) AFTER the exit
    channels. When the same [position_id] appeared in both — a [Stop_raised]
    event from {!Weinstein_stops} producing an adjust, AND a
    {!Force_liquidation_runner} fire producing a [TriggerExit] on the same bar —
    the simulator applied transitions in declaration order: exits first, then
    adjusts. The trailing UpdateRiskParams hit a position whose state had just
    been advanced to [Exiting], which
    {!Trading_strategy.Position.apply_transition} rejects as
    [Invalid transition UpdateRiskParams for current state]. The resulting
    [Error] propagated out of [Simulator.step], surfaced as a [failwith] at
    [Backtest.Panel_runner._step_failed], and aborted the scenario_runner child
    without an [actual.sexp].

    The dedup invariant pinned here: a [position_id] present in any exit-channel
    id-set (stops [Stop_hit], Stage-3 force-exit, laggard rotation, or
    force-liquidation) must NOT appear in the post-filter [adjust_transitions]
    returned by {!Internal_for_test.on_market_close}.

    Test construction:
    - Long AAPL position, entry $100 × 100, [stop_state = Tightened] seeded with
      [stop_level = 50.0, last_correction_extreme = 90.0].
    - Tick bar at close = $70: bar.low = 70 < last_correction_extreme = 90, so
      [Weinstein_stops._ratchet_tightened] computes a tighter candidate stop and
      emits [Stop_raised] → [Stops_runner] turns this into an [UpdateRiskParams]
      adjust transition for position_id "AAPL-1".
    - The same tick: entry $100 → current $70 = 30% loss (above the 25%
      [max_long_unrealized_loss_fraction] default), so
      {!Force_liquidation_runner.update} emits a per-position [TriggerExit] for
      "AAPL-1".
    - bar.low = 70 > stop_level = 50, so [check_stop_hit] returns false — stops
      do NOT also emit a trigger; the only exit channel firing is
      force-liquidation.
    - The output transition list must contain the force-liq [TriggerExit] for
      "AAPL-1" and zero [UpdateRiskParams] entries for "AAPL-1".

    Pre-dedup the test would observe both transitions; post-dedup only the
    [TriggerExit] survives. *)
let test_adjust_dedup_against_force_liq_exit _ =
  let symbol = "AAPL" in
  let position_id = "AAPL-1" in
  let entry_date = Date.of_string "2024-01-02" in
  let current_date = Date.of_string "2024-04-29" in
  let pos =
    _make_holding_long ~symbol ~position_id ~entry_date ~quantity:100.0
      ~entry_price:100.0
  in
  let positions = String.Map.singleton symbol pos in
  (* Single-bar reader: AAPL drops to $70 (30% loss → fires per-position
     force-liq); the primary index sits at $100 so the Friday macro pass
     and the [_compute_ma_and_stage] warmup default both stay quiet. *)
  let aapl_bar =
    {
      (_make_daily_bar ~date:current_date ~price:70.0) with
      Types.Daily_price.low_price = 70.0;
      close_price = 70.0;
    }
  in
  let index_bar = _make_daily_bar ~date:current_date ~price:100.0 in
  let bar_reader =
    Bar_reader.of_in_memory_bars
      [ (symbol, [ aapl_bar ]); (_index_symbol, [ index_bar ]) ]
  in
  let state = _fresh_state ~bar_reader in
  (* Seed the Tightened stop_state. Bar low = 70 stays above stop_level = 50
     (no trigger), but 70 < last_correction_extreme = 90, so the ratchet
     fires Stop_raised with a candidate stop above the current 50.0. *)
  state.stop_states :=
    Map.set !(state.stop_states) ~key:symbol
      ~data:
        (Weinstein_stops.Tightened
           {
             stop_level = 50.0;
             last_correction_extreme = 90.0;
             reason = "test setup — primed for ratchet";
           });
  let config =
    Weinstein_strategy.default_config ~universe:[] ~index_symbol:_index_symbol
  in
  let portfolio : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions }
  in
  let result = _drive_tick state ~config ~current_date ~portfolio in
  (* Assertion: the position's TriggerExit (from force-liq) is in the
     transition list, and no UpdateRiskParams transition for the same
     position_id appears. Pre-dedup, both would be present and the
     simulator would error on the second.

     Counts are extracted via [field] composition (one [assert_that] per
     value) per .claude/rules/test-patterns.md — the [all_of] tree pins
     both [TriggerExit = 1] and [UpdateRiskParams = 0] for the
     position_id under test. *)
  let count_for transitions ~is_kind =
    List.count transitions ~f:(fun (t : Trading_strategy.Position.transition) ->
        String.equal t.position_id position_id && is_kind t.kind)
  in
  let is_trigger_exit = function
    | Trading_strategy.Position.TriggerExit _ -> true
    | _ -> false
  in
  let is_update_risk_params = function
    | Trading_strategy.Position.UpdateRiskParams _ -> true
    | _ -> false
  in
  assert_that result
    (is_ok_and_holds
       (field
          (fun (o : Trading_strategy.Strategy_interface.output) ->
            o.transitions)
          (all_of
             [
               (* Exactly one TriggerExit for the position — the force-liq
                  one. Pre-fix this would also be 1 (force-liq still fires);
                  this assertion just pins that the exit is preserved. *)
               field
                 (fun ts -> count_for ts ~is_kind:is_trigger_exit)
                 (equal_to 1);
               (* Zero UpdateRiskParams for the position. Pre-dedup this
                  would be 1 (the Stop_raised adjust). The dedup filter
                  strips it because the position is in [force_liq_exited_ids].
                  This is the load-bearing assertion. *)
               field
                 (fun ts -> count_for ts ~is_kind:is_update_risk_params)
                 (equal_to 0);
             ])))

(* ------------------------------------------------------------------ *)
(* Suite                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "force_liquidation_strategy"
  >::: [
         "maybe_reset_halt clears on Bullish"
         >:: test_maybe_reset_halt_clears_on_non_bearish;
         "maybe_reset_halt clears on Neutral"
         >:: test_maybe_reset_halt_clears_on_neutral;
         "maybe_reset_halt persists under Bearish"
         >:: test_maybe_reset_halt_persists_under_bearish;
         "halt resets after macro flip on Friday tick"
         >:: test_halt_resets_after_macro_flip;
         "halt persists when macro stays Bearish"
         >:: test_halt_persists_when_macro_stays_bearish;
         "G13 — no primary index bar short-circuits without observing peak"
         >:: test_no_primary_index_bar_short_circuits;
         "PR #911 dedup — adjust transitions stripped when force-liq exits"
         >:: test_adjust_dedup_against_force_liq_exit;
       ]

let () = run_test_tt_main suite
