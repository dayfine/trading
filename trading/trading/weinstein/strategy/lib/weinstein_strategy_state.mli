open Core

(** Per-run mutable state bootstrap for {!Weinstein_strategy.make}.

    Factored out of [Weinstein_strategy] to keep that coordinator file within
    the declared-large file-length limit. The single function below builds the
    closure-scoped refs/hashtables the [on_market_close] hot path threads
    through every tick, plus the weekly A-D bar list (aggregated once per run).
    Not intended for external callers. *)

type t =
  Weinstein_stops.stop_state String.Map.t ref
  * Date.t Hashtbl.M(String).t
  * Weinstein_types.market_trend ref
  * Portfolio_risk.Force_liquidation.Peak_tracker.t
  * Macro.result option ref
  * Decline_character.t ref
  * Weinstein_types.stage Hashtbl.M(String).t
  * float Hashtbl.M(String).t
  * Weinstein_types.stage Hashtbl.M(String).t
  * int Hashtbl.M(String).t
  * int Hashtbl.M(String).t
  * Macro.ad_bar list
(** The bundle of per-run mutable state returned by {!init}, in the field order
    consumed by [Weinstein_strategy.make]:
    [(stop_states, last_stop_out_dates, prior_macro, peak_tracker,
     prior_macro_result, prior_decline_character, prior_stages,
     prior_stage_ma_values, sector_prior_stages, stage3_streaks,
     laggard_streaks, weekly_ad_bars)]. *)

val init :
  initial_stop_states:Weinstein_stops.stop_state String.Map.t ->
  ad_bars:Macro.ad_bar list ->
  t
(** [init ~initial_stop_states ~ad_bars] allocates a fresh per-run state bundle:
    each ref/hashtable starts empty (or at its neutral seed value), and
    [ad_bars] is aggregated to the run-fixed weekly A-D bar list. Pure
    allocation — no I/O, no shared state. *)
