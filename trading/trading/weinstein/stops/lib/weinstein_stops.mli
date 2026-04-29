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

module Support_floor = Support_floor
(** Derives the prior correction extreme from a bar history — correction low for
    longs, counter-rally high for shorts. Feeds the [reference_level] argument
    to {!compute_initial_stop}. See the module doc for algorithm details. *)

module Stop_split_adjust = Stop_split_adjust
(** Apply a stock-split factor to a {!stop_state}. Used by the strategy to keep
    absolute stop prices in lockstep with the broker-side share-count rescale on
    a corporate-action split. See the module doc for the contract. *)

(** {1 Core Functions} *)

val compute_initial_stop :
  config:config -> side:position_side -> reference_level:float -> stop_state
(** Compute the initial stop level at the time of entry.

    For a long, [reference_level] is the support floor; the stop is placed just
    below it. For a short, [reference_level] is the resistance ceiling; the stop
    is placed just above it. A round-number nudge is applied in both cases. *)

val compute_initial_stop_with_floor :
  config:config ->
  side:position_side ->
  entry_price:float ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  fallback_buffer:float ->
  stop_state
(** Compute the initial stop using a real support floor derived from bar
    history, falling back to a fixed-buffer proxy when no qualifying correction
    is found.

    When {!Support_floor.find_recent_level} returns [Some floor] (using
    [config.support_floor_lookback_bars] and [config.min_correction_pct]), that
    value is used as the [reference_level]. Otherwise the function falls back to
    [entry_price *. fallback_buffer] for a long, or
    [entry_price /. fallback_buffer] for a short — behaviourally identical to
    the caller's prior direct call to {!compute_initial_stop} with that proxy.

    The returned state is always {!Initial}; the trailing state machine is
    seeded elsewhere (see {!update}).

    Typical use by callers:
    - [entry_price]: the candidate's suggested entry (breakout price).
    - [bars]: the accumulated daily bar history for the symbol.
    - [as_of]: the entry date (usually today's market-close date).
    - [fallback_buffer]: the same buffer the caller used before this primitive
      existed — e.g. 1.02 for a 2% loose stop on the long side.

    Implementation note: this is a thin wrapper over
    {!compute_initial_stop_with_floor_with_callbacks}. It builds a {!callbacks}
    record via {!callbacks_from_bars} (which applies [as_of] filtering and
    [config.support_floor_lookback_bars] truncation up-front) and threads it
    through. Behaviour is bit-identical to the callback API for the same
    underlying bar inputs. *)

(** {1 Callback API} *)

type callbacks = Support_floor.callbacks
(** Bundle of bar-field callbacks for the support-floor lookup, re-exported from
    {!Support_floor.callbacks}. The bundle exposes a {b pre-windowed} view of
    the daily bars: [as_of] filtering and lookback truncation are applied at
    construction time, leaving a contiguous, cap-trimmed window that the
    algorithm scans by day offset alone. Day offset [0] is the most recent bar;
    offset [n_days - 1] is the oldest. See {!Support_floor.callbacks} for
    field-level documentation. *)

val callbacks_from_bars :
  config:config ->
  bars:Types.Daily_price.t list ->
  as_of:Core.Date.t ->
  callbacks
(** [callbacks_from_bars ~config ~bars ~as_of] constructs a callback bundle by
    delegating to {!Support_floor.callbacks_from_bars} with
    [lookback_bars = config.support_floor_lookback_bars]. Used internally by
    {!compute_initial_stop_with_floor}; exposed so panel-backed callers and
    tests can build the bundle the same way the wrapper does. *)

val compute_initial_stop_with_floor_with_callbacks :
  config:config ->
  side:position_side ->
  entry_price:float ->
  callbacks:callbacks ->
  fallback_buffer:float ->
  stop_state
(** [compute_initial_stop_with_floor_with_callbacks ~config ~side ~entry_price
     ~callbacks ~fallback_buffer] is the indicator-callback shape of
    {!compute_initial_stop_with_floor}. [bars] and [as_of] are baked into the
    [callbacks] bundle and no longer parameters here.

    Pure function: same callback outputs and inputs always produce the same
    [stop_state]. The wrapper {!compute_initial_stop_with_floor} guarantees
    byte-identical results for any bar-list inputs by constructing callbacks
    that index the same precomputed window the bar-list path used to walk
    inline. *)

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
