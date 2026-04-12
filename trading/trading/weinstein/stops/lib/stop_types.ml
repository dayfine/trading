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
    }
  | Tightened of {
      stop_level : float;
      last_correction_extreme : float;
      reason : string;
    }
[@@deriving show, eq, sexp]

type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening of { reason : string }
  | No_change
[@@deriving show, eq, sexp]

type config = {
  round_number_nudge : float;
  min_correction_pct : float;
  tighten_on_flat_ma : bool;
  ma_flat_threshold : float;
  trailing_stop_buffer_pct : float;
  tightened_stop_buffer_pct : float;
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
  }
