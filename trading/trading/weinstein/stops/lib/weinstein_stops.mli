(** Weinstein trailing stop state machine.

    Implements the stop management rules from Stan Weinstein's "Secrets for
    Profiting in Bull and Bear Markets" Chapter 6, extended to support both long
    and short positions.

    The stop evolves through three states: [Initial] → [Trailing] → [Tightened].
    It is {b never moved against the position} — never lowered for a long, never
    raised for a short. See individual type docs for state semantics. *)

open Weinstein_types
open Trading_base.Types

(** {1 Types} *)

(** Current stop management state for a single position. *)
type stop_state =
  | Initial of {
      stop_level : float;  (** Current stop price *)
      reference_level : float;
          (** Support floor (long) or resistance ceiling (short) at entry *)
    }
  | Trailing of {
      stop_level : float;
          (** Current stop price — never moved against position *)
      last_correction_extreme : float;
          (** Extreme of most recent correction: Long = pullback low; Short =
              counter-rally high *)
      last_trend_extreme : float;
          (** Extreme of most recent trend leg: Long = rally peak; Short =
              decline trough *)
      ma_at_last_adjustment : float;
          (** 30-week MA value when stop was last adjusted *)
      correction_count : int;  (** Number of correction cycles completed *)
    }
  | Tightened of {
      stop_level : float;
          (** Current stop price — closer to market than Trailing *)
      last_correction_extreme : float;
          (** Extreme of most recent correction (see [Trailing] docs) *)
      reason : string;  (** Why tightening was triggered *)
    }
[@@deriving show, eq, sexp]

(** Event produced by [update] describing what happened to the stop. *)
type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
      (** Price crossed the stop level — position should be exited *)
  | Stop_raised of { old_level : float; new_level : float; reason : string }
      (** Stop level was adjusted in the position's favour (raised for long,
          lowered for short) *)
  | Entered_tightening of { reason : string }
      (** Transitioned from Trailing to Tightened *)
  | No_change  (** No adjustment this period *)
[@@deriving show, eq, sexp]

type config = {
  round_number_nudge : float;
      (** Distance from round number that triggers a nudge (default: 0.125). *)
  min_correction_pct : float;
      (** Minimum pullback to qualify as a correction (default: 0.08 = 8%).

          Future improvement: derive this threshold from the security's
          historical or implied volatility rather than using a fixed value. A
          more volatile stock needs a wider threshold to avoid counting noise as
          a meaningful correction. *)
  tighten_on_flat_ma : bool;
      (** Whether to tighten stops when the 30-week MA flattens (default: true).
      *)
  ma_flat_threshold : float;
      (** MA slope threshold below which MA is considered flat (default: 0.002).
      *)
  trailing_stop_buffer_pct : float;
      (** Buffer applied below a correction low (long) or above a correction
          high (short) when computing a trailing stop candidate (default: 0.01 =
          1%). *)
  tightened_stop_buffer_pct : float;
      (** Tighter buffer used in the Tightened state (default: 0.005 = 0.5%).
          Smaller than [trailing_stop_buffer_pct] to keep the stop close to
          market once tightening is triggered. *)
}
[@@deriving show, eq, sexp]
(** Configuration for stop management behavior. All thresholds are configurable
    so backtesting can tune them. *)

(** {1 Default Config} *)

val default_config : config
(** Default configuration using Weinstein book values. *)

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
