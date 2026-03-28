(** Weinstein trailing stop state machine.

    Implements the stop management rules from Stan Weinstein's "Secrets for
    Profiting in Bull and Bear Markets" Chapter 6, extended to support both long
    and short positions.

    The stop evolves through three states: [Initial] → [Trailing] → [Tightened].
    It is {b never moved against the position} — never lowered for a long, never
    raised for a short. See individual type docs for state semantics. *)

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
[@@deriving show, eq]

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
[@@deriving show, eq]

type config = {
  round_number_nudge : float;
      (** Distance from round number that triggers a nudge (default: 0.125). *)
  min_correction_pct : float;
      (** Minimum pullback to qualify as a correction (default: 0.08 = 8%). *)
  tighten_on_flat_ma : bool;
      (** Whether to tighten stops when the 30-week MA flattens (default: true).
      *)
  ma_flat_threshold : float;
      (** MA slope threshold below which MA is considered flat (default: 0.002).
      *)
}
[@@deriving show, eq]
(** Configuration for stop management behavior. All thresholds are configurable
    so backtesting can tune them. *)

(** {1 Default Config} *)

val default_config : config
(** Default configuration using Weinstein book values. *)

(** {1 Core Functions} *)

val compute_initial_stop :
  config:config ->
  side:position_side ->
  reference_level:float ->
  stop_state
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
