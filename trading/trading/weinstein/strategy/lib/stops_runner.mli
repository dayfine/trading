(** Runs the Weinstein trailing-stop state machine over every held position on
    each strategy invocation. Emits exit transitions for positions whose stops
    were hit and adjust transitions for positions whose stops were raised.

    Isolates the stops-loop plumbing from the strategy orchestrator so
    [weinstein_strategy.ml] focuses on cadence, screening, and wiring. *)

open Core
open Trading_strategy

val update :
  stops_config:Weinstein_stops.config ->
  stage_config:Stage.config ->
  lookback_bars:int ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  stop_states:Weinstein_stops.stop_state Map.M(String).t ref ->
  bar_reader:Bar_reader.t ->
  as_of:Date.t ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
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
    caller can order them consistently in the final output. *)
