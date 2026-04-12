(** Weinstein trailing stop state machine.

    Implements the stop management rules from Stan Weinstein's "Secrets for
    Profiting in Bull and Bear Markets" Chapter 6, extended to support both long
    and short positions.

    The stop evolves through three states: [Initial] → [Trailing] → [Tightened].
    It is {b never moved against the position} — never lowered for a long, never
    raised for a short. See individual type docs for state semantics. *)

open Weinstein_types
open Trading_base.Types

include module type of Stop_types
(** @inline *)

(** {1 Core Functions} *)

val compute_initial_stop :
  config:config -> side:position_side -> reference_level:float -> stop_state
(** Compute the initial stop level at the time of entry.

    For a long, [reference_level] is the support floor; the stop is placed just
    below it. For a short, [reference_level] is the resistance ceiling; the stop
    is placed just above it. A round-number nudge is applied in both cases. *)

val check_stop_hit :
  state:stop_state -> side:position_side -> bar:Types.Daily_price.t -> bool
(** [true] if the bar's trigger price crossed the stop level.

    Long: triggered by [low_price ≤ stop_level]. Short: triggered by
    [high_price ≥ stop_level]. *)

val get_stop_level : stop_state -> float
(** Extract the current stop price from any state. *)

(** {1 Update} *)

val update :
  config:config ->
  side:position_side ->
  state:stop_state ->
  current_bar:Types.Daily_price.t ->
  ma_value:float ->
  ma_direction:ma_direction ->
  stage:stage ->
  stop_state * stop_event
(** Advance the stop state machine by one price period.

    - [config]: tuning parameters for stop behavior.
    - [side]: direction of the position ([Long] or [Short]).
    - [state]: current stop state.
    - [current_bar]: OHLCV bar for this period.
    - [ma_value]: current 30-week moving average value.
    - [ma_direction]: whether the MA is rising, flat, or falling this period.
    - [stage]: Weinstein stage classification for this period.

    Calling cadence is the caller's responsibility — typically once per weekly
    bar, but the function itself is period-agnostic.

    The stop is never moved against the position (never lowered for long, never
    raised for short). *)
