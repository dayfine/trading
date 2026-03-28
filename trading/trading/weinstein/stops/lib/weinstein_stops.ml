open Core
open Weinstein_types

type stop_state =
  | Initial of {
      stop_level : float;
      support_floor : float;
      entry_price : float;
    }
  | Trailing of {
      stop_level : float;
      last_correction_low : float;
      last_rally_peak : float;
      ma_at_last_adjustment : float;
      correction_count : int;
    }
  | Tightened of {
      stop_level : float;
      last_correction_low : float;
      reason : string;
    }
[@@deriving show, eq]

type stop_event =
  | Stop_hit of { trigger_price : float; stop_level : float }
  | Stop_raised of { old_level : float; new_level : float; reason : string }
  | Entered_tightening of { reason : string }
  | No_change
[@@deriving show, eq]

type config = {
  round_number_nudge : float;
  min_correction_pct : float;
  tighten_on_flat_ma : bool;
  ma_flat_threshold : float;
}
[@@deriving show, eq]

let default_config =
  {
    round_number_nudge = 0.125;
    min_correction_pct = 0.08;
    tighten_on_flat_ma = true;
    ma_flat_threshold = 0.002;
  }
