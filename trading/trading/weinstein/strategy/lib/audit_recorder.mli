(** Decision-trail recorder: a callback bundle the strategy invokes at entry /
    exit decision sites.

    The strategy emits raw events containing the analysis values it has in scope
    at decision time ({!Screener.scored_candidate}, {!Macro.result},
    {!Stage.result}, etc.). The backtest layer wires concrete callbacks that
    construct a {!Backtest.Trade_audit.entry_decision} / [exit_decision] from
    the event and accumulates them into a [Trade_audit.t] collector.

    The strategy library does not depend on [Backtest] — this module exists
    precisely to keep that direction. The {!noop} default lets non-recording
    callers leave the audit unwired with zero overhead. *)

open Core

(** Why a candidate produced by the screener was not entered.

    Tagged at the strategy boundary where [_make_entry_transition] is called.
    The backtest-side recorder maps these into
    {!Backtest.Trade_audit.skip_reason}.

    {b Note}: only the three reasons the strategy can directly observe at the
    sizing/cash gates land here. Screener-internal truncations
    ([Below_min_grade], [Top_n_cutoff], [Sector_concentration]) are not visible
    at this site — the screener already filtered the candidate before the
    strategy saw it. The audit's [alternatives_considered] field therefore
    enumerates only the rivals from the same screen call that the strategy
    actually considered for entry. *)
type skip_reason = Insufficient_cash | Already_held | Sized_to_zero

type alternative_input = {
  candidate : Screener.scored_candidate;
  reason : skip_reason;
}
(** A candidate that scored at the same screen call as the chosen one but was
    not entered. *)

(** Whether the installed initial stop sat on a real support floor (or short:
    resistance ceiling) derived from bar history, or fell back to the
    fixed-buffer proxy. Mirrors {!Backtest.Trade_audit.stop_floor_kind}. *)
type stop_floor_kind = Support_floor | Buffer_fallback

type entry_event = {
  position_id : string;
      (** Position id assigned at entry — matches the [Position.transition] this
          event is recorded alongside, and [Stop_log.stop_info.position_id] /
          [Backtest.Trade_audit.entry_decision.position_id]. *)
  candidate : Screener.scored_candidate;
      (** The chosen candidate. Carries [analysis], [sector], [side], [score],
          [grade], [rationale], [suggested_entry], [suggested_stop], [risk_pct].
      *)
  macro : Macro.result;
      (** Macro snapshot computed by [_run_screen] this Friday. *)
  current_date : Date.t;
  installed_stop : float;
      (** Output of
          [Weinstein_stops.compute_initial_stop_with_floor_with_callbacks]'s
          stop level after the buffer is applied. *)
  stop_floor_kind : stop_floor_kind;
      (** Whether [installed_stop] sat on a real support floor or fell back. *)
  shares : int;
      (** From [Portfolio_risk.compute_position_size] — round-share count
          actually ordered. *)
  initial_position_value : float;
      (** [shares * suggested_entry] — dollar exposure at entry. *)
  initial_risk_dollars : float;
      (** [|suggested_entry - installed_stop| * shares] — dollar risk to stop.
      *)
  alternatives : alternative_input list;
      (** Rivals from the same screen call that were not entered. *)
}
(** Event captured at entry-decision time. *)

type exit_event = {
  position_id : string;
  symbol : string;
  exit_date : Date.t;
  exit_price : float;
  exit_reason : Trading_strategy.Position.exit_reason;
      (** Raw exit reason from the [Position.TriggerExit] kind. The backtest
          layer maps this into a {!Backtest.Stop_log.exit_trigger}. *)
  macro_trend_at_exit : Weinstein_types.market_trend;
  macro_confidence_at_exit : float;
  stage_at_exit : Weinstein_types.stage;
  rs_trend_at_exit : Weinstein_types.rs_trend option;
  distance_from_ma_pct : float;
      (** [(exit_price - ma_value) / ma_value] at exit time. Positive if exit
          was above the MA, negative if below. [0.0] when the MA could not be
          read. *)
}
(** Event captured at exit-decision time. *)

type cascade_event = {
  date : Date.t;
      (** Friday on which the screen ran — same as [current_date] passed into
          [_screen_universe]. *)
  diagnostics : Screener.cascade_diagnostics;
      (** Per-cascade-phase admission counts. Carried through unchanged from
          [Screener.result.cascade_diagnostics]. *)
  entered : int;
      (** How many of the {!Screener.scored_candidate}s the strategy actually
          entered this Friday — the count of {!Position.transition}s emitted by
          {!Weinstein_strategy.entries_from_candidates}. Sits below
          [diagnostics.long_top_n_admitted + diagnostics.short_top_n_admitted]
          because cash limits, sector concentration, and round-share sizing all
          drop further candidates between the screener output and the actual
          entry list. *)
}
(** Event captured at the end of one Friday's cascade. Complements
    [entry_event]: where [entry_event] records a single chosen candidate plus
    its rivals, [cascade_event] records the per-phase activity counts for the
    whole cascade — including phases that filter out every candidate before any
    rival comparison happens. *)

type force_liquidation_event = Portfolio_risk.Force_liquidation.event
(** Event captured every time {!Force_liquidation.check} fires for a position.
    Mirrors [Force_liquidation.event] one-for-one; re-exposed here as part of
    the recorder bundle so the strategy library does not depend on [Backtest.*].
    The backtest-side recorder maps these into a [Force_liquidation_log] for
    [force_liquidations.sexp] persistence and [trades.csv] exit-trigger
    labelling. *)

type t = {
  record_entry : entry_event -> unit;
  record_exit : exit_event -> unit;
  record_cascade_summary : cascade_event -> unit;
  record_force_liquidation : force_liquidation_event -> unit;
}
(** Recorder bundle. All callbacks are invoked unconditionally by the strategy
    at entry / exit / per-Friday sites; the implementation decides whether to
    persist or drop. *)

val noop : t
(** Recorder that drops every event. Default for callers (tests, live mode) that
    do not wire a backtest collector. *)
