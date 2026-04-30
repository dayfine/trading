(** Runs the Weinstein trailing-stop state machine over every held position on
    each strategy invocation. Emits exit transitions for positions whose stops
    were hit and adjust transitions for positions whose stops were raised.

    Isolates the stops-loop plumbing from the strategy orchestrator so
    [weinstein_strategy.ml] focuses on cadence, screening, and wiring. *)

open Core
open Trading_strategy

(** Cadence at which the trailing-stop state machine advances.

    - [Daily] — call {!Weinstein_stops.update} on every tick. The state machine
      tightens / raises the stop based on every daily bar. This is the
      historical default and preserves all baselines.
    - [Weekly] — only advance the state machine on the week's final trading day
      (Friday). Mid-week (Mon-Thu) ticks still run the trigger check
      ({!Weinstein_stops.check_stop_hit}) and emit a [TriggerExit] when the
      bar's high/low crosses the stop, but do NOT raise/tighten the stop.

    The book authority (Weinstein Ch. 6, "Stop-Loss Rules") describes weekly
    re-evaluation: the trail moves only when a weekly bar confirms a new pivot
    above the prior pivot. Trigger is continuous (intraday); update is weekly.
    [Weekly] mirrors that contract; [Daily] does not. *)
type stop_update_cadence = Daily | Weekly [@@deriving show, eq, sexp]

val update :
  ?ma_cache:Weekly_ma_cache.t ->
  ?stop_update_cadence:stop_update_cadence ->
  stops_config:Weinstein_stops.config ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  stop_states:Weinstein_stops.stop_state Map.M(String).t ref ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  unit ->
  Position.transition list * Position.transition list
(** [update] folds over every held position and advances its stop state. For
    each position it:

    1. Computes the current MA direction from the accumulated bar history
    (reading and updating [prior_stages] so Stage1->Stage2 disambiguation
    works). 2. Calls {!Weinstein_stops.update} with the bar, MA value/direction,
    and current stop state. 3. Writes the new stop state into [stop_states]. 4.
    Emits a [TriggerExit] transition on [Stop_hit] or an [UpdateRiskParams]
    transition on [Stop_raised].

    Returns [(exit_transitions, adjust_transitions)] as separate lists so the
    caller can order them consistently in the final output.

    Stage 4 PR-D: when [ma_cache] is passed, MA values are read from the
    per-symbol cache on Friday-aligned ticks (cache hit). Mid-week ticks miss
    the cache and fall back to inline MA computation — preserving bit-equality
    with the bar-list path on every call.

    [stop_update_cadence] (default [Daily]) controls when the trail advances —
    see {!stop_update_cadence}. Under [Weekly], non-Friday [as_of] dates skip
    the state-machine update and only emit [TriggerExit] when the bar crosses
    the existing stop level. The default of [Daily] preserves bit-equality with
    every existing caller and baseline. *)
