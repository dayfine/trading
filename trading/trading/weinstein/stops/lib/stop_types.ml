open Core

type stop_state =
  | Initial of {
      stop_level : float;
      reference_level : float;
          (** Support floor (long) or resistance ceiling (short) at entry *)
    }
  | Trailing of {
      stop_level : float;
      last_correction_extreme : float;
      last_trend_extreme : float;
      ma_at_last_adjustment : float;
      correction_count : int;
      correction_observed_since_reset : bool;
    }
  | Tightened of {
      stop_level : float;
      last_correction_extreme : float;
      reason : string;
      swing_peak : float option; [@sexp.option]
    }
[@@deriving show, eq, sexp]

type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening of { reason : string }
  | No_change
[@@deriving show, eq, sexp]

(* Standard ATR lookback (Wilder's 14-period) used as the [sexp.default] for
   [vol_scaled_stop_atr_period]. A named constant so the bare literal lives in
   one exempt binding rather than inline in the field's [@sexp.default]. *)
let default_vol_scaled_stop_atr_period = 14

(* Book Ch. 6 "at least 8 to 10 percent" -- the only correction depth the book
   gives; used as the [sexp.default] for [tightened_min_reaction_pct]. *)
let default_tightened_min_reaction_pct = 0.08

type config = {
  round_number_nudge : float;
  min_correction_pct : float;
  tighten_on_flat_ma : bool;
  ma_flat_threshold : float;
  trailing_stop_buffer_pct : float;
  tightened_stop_buffer_pct : float;
  support_floor_lookback_bars : int;
  max_stop_distance_pct : float;
  trigger_on_weekly_close : bool; [@sexp.default false]
  vol_scaled_stop_atr_mult : float; [@sexp.default 0.0]
  vol_scaled_stop_atr_period : int;
      [@sexp.default default_vol_scaled_stop_atr_period]
  catastrophic_stop_pct : float; [@sexp.default 0.0]
  support_floor_anchor_mode : Support_floor.anchor_mode;
      [@sexp.default Support_floor.Wick]
  support_floor_anchor_scope : Support_floor.anchor_scope;
      [@sexp.default Support_floor.Window_extreme]
  split_safe_floors : bool; [@sexp.default false]
  reset_anchor_on_stalled_cycle : bool; [@sexp.default true]
  stop_skip_entry_bar : bool; [@sexp.default true]
  stop_ma_same_basis : bool; [@sexp.default false]
  correction_must_follow_peak : bool; [@sexp.default false]
  tightened_can_ratchet : bool; [@sexp.default false]
  tightened_min_reaction_pct : float;
      [@sexp.default default_tightened_min_reaction_pct]
  short_tightened_ratchet_follows_decline : bool; [@sexp.default false]
}
[@@deriving show, eq, sexp]

let default_config =
  {
    round_number_nudge = 0.125;
    min_correction_pct = 0.08;
    tighten_on_flat_ma = true;
    ma_flat_threshold = 0.002;
    trailing_stop_buffer_pct = 0.01;
    tightened_stop_buffer_pct = 0.005;
    support_floor_lookback_bars = 90;
    max_stop_distance_pct = 0.15;
    trigger_on_weekly_close = false;
    vol_scaled_stop_atr_mult = 0.0;
    vol_scaled_stop_atr_period = default_vol_scaled_stop_atr_period;
    catastrophic_stop_pct = 0.0;
    support_floor_anchor_mode = Support_floor.Wick;
    support_floor_anchor_scope = Support_floor.Window_extreme;
    split_safe_floors = false;
    reset_anchor_on_stalled_cycle = true;
    stop_skip_entry_bar = true;
    stop_ma_same_basis = false;
    correction_must_follow_peak = false;
    tightened_can_ratchet = false;
    tightened_min_reaction_pct = default_tightened_min_reaction_pct;
    short_tightened_ratchet_follows_decline = false;
  }
