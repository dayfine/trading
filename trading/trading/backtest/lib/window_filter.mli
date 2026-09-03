(** Carve the {b measurement window} out of the simulator's warmup-inclusive
    outputs.

    Every Weinstein-family backtest runs the simulator from
    [warmup_start = start_date - warmup_days] so the stage MA / RS analyzers are
    warm on day one of the measurement window. Everything the run records —
    steps, round-trips, stop infos, audit records, cascade summaries,
    force-liquidations, stale holds — therefore spans [warmup_start..end_date],
    while the published result must describe [start_date..end_date] only.

    This module owns that restriction. Each function drops the warmup-window
    prefix of one recorder's output; {!of_steps} does it for the step series and
    additionally computes the run's final mark-to-market portfolio value. The
    functions are pure: same input → same output, no IO.

    Extracted from [runner.ml] (which was at the 500-line declared-large hard
    limit) so the window-restriction family lives in one module with one
    responsibility. [Backtest.Runner] re-exports the members that were already
    part of its public surface, so existing callers are unaffected. *)

open Core
module Sim_types = Trading_simulation_types.Simulator_types

exception
  Empty_measurement_window of {
    start_date : Date.t;
    end_date : Date.t;
    n_sim_steps : int;
    n_steps_in_range : int;
  }
(** Raised by {!of_steps} when the requested measurement window contains no
    trading day at all — i.e. after filtering the simulator's steps to
    [date >= start_date] and then to {!is_trading_day}, nothing is left.

    There is no meaningful final portfolio value, CAGR, drawdown or Sharpe for
    such a window, so the alternative to raising would be to fabricate one
    (typically "flat at [initial_cash]") and let it flow into a report as though
    it were a measurement. The raise is deliberate: a degenerate window is a
    caller-level condition the caller must decide about, not a silent zero.

    In practice this means the requested [start_date] is past the last bar in
    the loaded data — the exact shape that broke the weekly-start sweep (issue
    #2632), whose [end_date] floats with the run date while the committed SPY
    bars stop at a fixed floor. Previously this surfaced as a raw stdlib
    [Invalid_argument "List.last"] with no indication of which window was at
    fault; the payload names the window and both step counts so the caller can
    log it or skip the cell. A [Printexc] printer is registered for it, so an
    uncaught instance prints the same diagnostic.

    [n_sim_steps] is the length of the full warmup-inclusive step series and
    [n_steps_in_range] the length after the [date >= start_date] filter; the
    pair discriminates "start_date is past every step" ([n_steps_in_range = 0])
    from "the window exists but saw no market bars" ([n_steps_in_range > 0]). *)

type window = {
  steps_in_range : Sim_types.step_result list;
      (** Every step at or after [start_date], including non-trading days.
          Round-trip extraction and the in-window metric overlay read this: a
          trade fill is recorded independently of whether the simulator saw a
          market bar that day, so filtering on {!is_trading_day} first would
          silently drop trades. *)
  steps : Sim_types.step_result list;
      (** [steps_in_range] restricted to real trading days ({!is_trading_day}).
          Mark-to-market consumers (equity curve, final portfolio value) read
          this: the simulator reports [portfolio_value = cash] on weekends and
          holidays even while positions are open, so an unfiltered series has
          spurious cliffs. Guaranteed non-empty — {!of_steps} raises
          {!Empty_measurement_window} rather than return an empty [steps]. *)
  final_portfolio_value : float;
      (** [portfolio_value] of the last element of [steps] — the run's
          end-of-window mark-to-market equity. *)
}
(** The two step views of one measurement window, plus the final equity derived
    from them. *)

val is_trading_day : Sim_types.step_result -> bool
(** True if [step] represents a real trading day — i.e. the simulator saw at
    least one bar for any symbol on [step.date]. Reads the authoritative
    [step_result.had_market_bars] flag set in {!Trading_simulation.Simulator}
    from the per-tick [today_bars] list.

    Replaces the prior portfolio-value-vs-cash heuristic, which falsely
    classified post-corporate-action days (held symbol with no further bars →
    [Calculations.portfolio_value] errors → caller silently substitutes [cash])
    as non-trading and silently truncated [equity_curve.csv] /
    [summary.final_portfolio_value] at the day before the gap.

    Must NOT be applied before {!Trading_simulation.Metrics.extract_round_trips}
    — round-trips derive from position-state transitions recorded independently
    of bar presence; filtering on [had_market_bars = false] silently drops every
    trade whose entry {i and} exit landed on bar-less days. *)

val of_steps :
  Sim_types.step_result list -> start_date:Date.t -> end_date:Date.t -> window
(** [of_steps all_steps ~start_date ~end_date] splits the simulator's full
    warmup-inclusive step series into the two views of {!window} and computes
    the final mark-to-market portfolio value.

    [end_date] is used only to describe the window in
    {!Empty_measurement_window}; it does not filter (the simulator never steps
    past its own [end_date]).

    @raise Empty_measurement_window
      when no step in [start_date..end_date] is a trading day. See that
      exception for why this raises instead of returning a degenerate window. *)

val round_trips_in_window :
  ?order_links:string String.Map.t ->
  Sim_types.step_result list ->
  start_date:Date.t ->
  Trading_simulation.Metrics.trade_metrics list
(** Extract round-trips from the full (warmup-inclusive) step series, then keep
    only those whose entry landed in-window ([entry_date >= start_date]).

    [order_links] is the run's
    [Simulator_types.run_result.order_position_links]; it only stamps
    [position_id] on each round-trip (see
    {!Trading_simulation.Metrics.extract_round_trips}) and never changes which
    round-trips are produced or kept.

    Pairing must see the warmup steps: a position opened in the warmup window
    has its opening fill on a step before [start_date]. Extracting over the
    [start_date]-truncated step list drops that opening fill, orphaning the
    in-window closing [Sell], which
    {!Trading_simulation.Metrics.extract_round_trips} then reads as a short-open
    (correct for a genuine short, wrong for a warmup-opened long) — producing a
    spurious SHORT round-trip with inverted P&L even in an
    [enable_short_side = false] backtest. Pairing over the full series keeps the
    warmup long a correct LONG, which this filter then drops as out-of-window.
    Symbols with no warmup position are unaffected. *)

val filter_stop_infos_in_window :
  Stop_log.stop_info list -> start_date:Date.t -> Stop_log.stop_info list
(** Drop [stop_info]s whose [entry_date] is before [start_date] — i.e. positions
    opened during the warmup window. Used at runner teardown to keep
    warmup-window stop events from corrupting [trades.csv] columns (the
    symbol-first fallback in [Trade_context._stop_info_for] would otherwise
    attach a warmup-window stop_info to an in-window round-trip when the same
    symbol re-trades across the boundary).

    Stop_infos with [entry_date = None] are kept (test fixtures that don't drive
    {!Stop_log.set_current_date}). *)

val filter_force_liquidations_in_window :
  Portfolio_risk.Force_liquidation.event list ->
  start_date:Date.t ->
  Portfolio_risk.Force_liquidation.event list
(** Drop force-liquidation events whose [date] is before [start_date] — i.e.
    events that fired during the warmup window. The simulator runs from
    [warmup_start] so [Force_liquidation_log] observes events from days before
    [start_date]; without this filter, warmup-window force-liqs leak into
    [force_liquidations.sexp] and inflate the visible event count. *)

val filter_audit_records_in_window :
  Trade_audit.audit_record list ->
  start_date:Date.t ->
  Trade_audit.audit_record list
(** Drop audit records whose entry-decision date is before [start_date]. The
    strategy's audit recorder fires from [warmup_start], so without this filter
    [trade_audit.sexp] picks up entries whose round-trips were never reported to
    [trades.csv]. *)

val filter_cascade_summaries_in_window :
  Trade_audit.cascade_summary list ->
  start_date:Date.t ->
  Trade_audit.cascade_summary list
(** Drop cascade-summary rows whose Friday [date] is before [start_date] —
    cascade evaluations that ran during the warmup window. The strategy records
    summaries every Friday from [warmup_start], so without this filter
    [trade_audit.sexp] reports activity counts that include warmup-window screen
    calls. *)

val filter_stale_holds_in_window :
  Trading_simulation.Stale_hold.event list ->
  start_date:Date.t ->
  Trading_simulation.Stale_hold.event list
(** Drop stale-hold events whose [date] is before [start_date] — staleness
    observed during the warmup window, which describes bars the measurement
    window never depended on. *)
