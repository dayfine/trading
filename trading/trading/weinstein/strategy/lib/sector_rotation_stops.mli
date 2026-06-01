(** Per-position trailing-stop helpers for the sector-rotation Weinstein
    strategy.

    Extracted from [sector_rotation_weinstein_strategy.ml] so the strategy
    module stays under the file-length limit. These helpers wrap
    {!Weinstein_stops} for the long/flat sector-rotation use case: each held
    symbol carries its own [stop_state], seeded from a support-floor lookup on
    entry, advanced daily by {!Weinstein_stops.update}, and triggered by
    {!Weinstein_stops.check_stop_hit}.

    The helpers do NOT hold mutable state themselves — they are pure functions
    over an existing [stop_state]. The strategy threads a
    [stop_state String.Map.t ref] across ticks. *)

open Core
open Trading_strategy

val seed_initial :
  stops_config:Weinstein_stops.config ->
  bar_reader:Bar_reader.t ->
  fallback_buffer:float ->
  symbol:string ->
  entry_price:float ->
  as_of:Date.t ->
  Weinstein_stops.stop_state
(** [seed_initial ~stops_config ~bar_reader ~fallback_buffer ~symbol
     ~entry_price ~as_of] computes the initial trailing-stop state for a long
    entry, anchored on the support-floor lookup over the symbol's daily bars at
    [as_of]. Falls back to [entry_price *. fallback_buffer] when no qualifying
    correction is found. *)

val seed_or_keep :
  stops_config:Weinstein_stops.config ->
  bar_reader:Bar_reader.t ->
  fallback_buffer:float ->
  symbol:string ->
  existing:Weinstein_stops.stop_state option ->
  pos:Position.t ->
  bar:Types.Daily_price.t ->
  Weinstein_stops.stop_state
(** [seed_or_keep ~stops_config ~bar_reader ~fallback_buffer ~symbol ~existing
     ~pos ~bar] returns [existing] when set, otherwise seeds a fresh stop state
    anchored on [pos]'s recorded entry price + date (not today's bar). Used to
    lazily seed the stop the first time a Holding position is observed. *)

val step :
  stops_config:Weinstein_stops.config ->
  stage_result:Stage.result option ->
  state:Weinstein_stops.stop_state ->
  pos:Position.t ->
  bar:Types.Daily_price.t ->
  Weinstein_stops.stop_state * Position.transition option
(** [step ~stops_config ~stage_result ~state ~pos ~bar] advances the trailing
    stop one tick.

    On any day: if the bar triggers the stop level, returns the
    (unchanged-state, exit-transition) pair. Otherwise:
    - On a non-weekly-close day: state unchanged, no transition.
    - On Friday with a [stage_result]: state advanced via
      {!Weinstein_stops.update}, exit transition emitted only if the update
      reports a [Stop_hit].
    - On Friday without a [stage_result] (warmup): state unchanged. *)
