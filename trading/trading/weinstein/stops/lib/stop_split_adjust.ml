open Core
open Stop_types

let _validate_factor factor =
  if Float.( <= ) factor 0.0 then
    invalid_arg
      (Printf.sprintf "Stop_split_adjust.scale: factor must be > 0.0, got %f"
         factor)

let _scale_trailing ~sp ~stop_level ~last_correction_extreme ~last_trend_extreme
    ~ma_at_last_adjustment ~correction_count ~correction_observed_since_reset =
  Trailing
    {
      stop_level = sp stop_level;
      last_correction_extreme = sp last_correction_extreme;
      last_trend_extreme = sp last_trend_extreme;
      ma_at_last_adjustment = sp ma_at_last_adjustment;
      correction_count;
      correction_observed_since_reset;
    }

let _scale_tightened ~sp ~stop_level ~last_correction_extreme ~reason =
  Tightened
    {
      stop_level = sp stop_level;
      last_correction_extreme = sp last_correction_extreme;
      reason;
    }

let scale ~factor state =
  _validate_factor factor;
  let sp x = x /. factor in
  match state with
  | Initial { stop_level; reference_level } ->
      Initial
        { stop_level = sp stop_level; reference_level = sp reference_level }
  | Trailing
      {
        stop_level;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
        correction_observed_since_reset;
      } ->
      _scale_trailing ~sp ~stop_level ~last_correction_extreme
        ~last_trend_extreme ~ma_at_last_adjustment ~correction_count
        ~correction_observed_since_reset
  | Tightened { stop_level; last_correction_extreme; reason } ->
      _scale_tightened ~sp ~stop_level ~last_correction_extreme ~reason
