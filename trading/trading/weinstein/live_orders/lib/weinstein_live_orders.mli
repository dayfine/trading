(** Live order path: one live tick's broker orders, with the protective stop
    sourced from the strategy's stop state (issue #2984).

    {!Weinstein_order_gen.from_transitions} maps transitions to broker orders.
    On its own it emits a protective [Stop] only for an [UpdateRiskParams]
    transition, so a freshly filled position has no broker stop until its first
    trailing raise, and a tightening (which emits no transition) never reaches
    the broker. Its [?stop_sync] argument closes that gap, but only if a caller
    snapshots the strategy's [stop_states] around the tick and passes the
    post-transition positions. This module is that caller. A live runner calls
    {!run_tick} once per tick; it never calls [from_transitions] without
    [~stop_sync].

    The enforced stop lives in [stop_states] ([Weinstein_stops.get_stop_level]
    of each ticker's state), not in [risk_params], so the before / after levels
    are read from the two [stop_states] snapshots. *)

open Core
open Trading_strategy

type tick = {
  transitions : Position.transition list;
      (** Everything that happened to positions this tick, in order: the broker
          fills applied at the start of the tick ([EntryFill] /
          [EntryComplete]), then the strategy's [on_market_close] output. *)
  positions_after : Position.t list;
      (** Every position in its {b post-transition} state, after [transitions]
          were applied. A just-filled entry is [Holding] (or a partly filled
          [Entering]) here, and a position the strategy is exiting is [Exiting].
      *)
}
(** The outcome of one live tick, as seen by the order path. *)

val orders_for_tick :
  ?entry_extension_max_pct:float ->
  stop_states_before:Weinstein_stops.stop_state String.Map.t ->
  stop_states_after:Weinstein_stops.stop_state String.Map.t ->
  tick ->
  Weinstein_order_gen.suggested_order list
(** The broker orders for [tick].

    Calls {!Weinstein_order_gen.from_transitions} with [~stop_sync] built from
    the two snapshots:
    - [stop_level_before] / [stop_level_after] map a ticker to
      [Weinstein_stops.get_stop_level] of its state in [stop_states_before] /
      [stop_states_after], or [None] when the ticker has no state;
    - [positions] is [tick.positions_after]. [get_position] looks a position up
      by id in [tick.positions_after].

    So an entry fill yields one [Stop] at the installed level, and so does a
    stop-state move with no transition (a tightening, or a split rescale). See
    {!Weinstein_order_gen} for the full sync contract. [entry_extension_max_pct]
    passes straight through (default [0.0]). *)

val run_tick :
  ?entry_extension_max_pct:float ->
  stop_states:Weinstein_stops.stop_state String.Map.t ref ->
  (unit -> tick) ->
  Weinstein_order_gen.suggested_order list
(** [run_tick ~stop_states step] snapshots [!stop_states], runs [step] (the live
    tick: apply broker fills, then run the strategy, which advances the same
    [stop_states] ref), snapshots [!stop_states] again, and returns
    {!orders_for_tick} over the two snapshots. [step] must mutate the ref the
    strategy itself holds; a copy would make every level look unchanged. *)
