(** Weinstein trailing stop state machine — types and configuration.

    See [weinstein_trading.stops] for the full implementation including
    [update], [compute_initial_stop], and [check_stop_hit]. *)

(** {1 Types} *)

(** Current stop management state for a single position. *)
type stop_state =
  | Initial of {
      stop_level : float;  (** Current stop price *)
      support_floor : float;
          (** Support level at breakout — initial reference *)
      entry_price : float;  (** Entry price of the position *)
    }
  | Trailing of {
      stop_level : float;  (** Current stop price — never lowered *)
      last_correction_low : float;
          (** Low of most recent correction — potential next stop level *)
      last_rally_peak : float;
          (** Peak of most recent rally — confirms recovery *)
      ma_at_last_adjustment : float;
          (** 30-week MA value when stop was last raised *)
      correction_count : int;  (** Number of correction cycles completed *)
    }
  | Tightened of {
      stop_level : float;
          (** Current stop price — closer to market than Trailing *)
      last_correction_low : float;  (** Low of most recent correction *)
      reason : string;  (** Why tightening was triggered *)
    }
[@@deriving show, eq]

(** Event produced by [update] describing what happened to the stop. *)
type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
      (** Price fell through stop level — position should be exited *)
  | Stop_raised of { old_level : float; new_level : float; reason : string }
      (** Stop level was ratcheted up *)
  | Entered_tightening of { reason : string }
      (** Transitioned from Trailing to Tightened *)
  | No_change  (** No adjustment this period *)
[@@deriving show, eq]

(** Configuration for stop management behavior. All thresholds are configurable
    so backtesting can tune them. *)
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

(** {1 Default Config} *)

val default_config : config
(** Default configuration using Weinstein book values. *)
