open Core
open Stop_types

let _validate_factor factor =
  if Float.( <= ) factor 0.0 then
    invalid_arg
      (Printf.sprintf "Stop_split_adjust.scale: factor must be > 0.0, got %f"
         factor)

let scale ~factor state =
  _validate_factor factor;
  match state with
  | Initial { stop_level; reference_level } ->
      Initial
        {
          stop_level = stop_level /. factor;
          reference_level = reference_level /. factor;
        }
  | Trailing
      {
        stop_level;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
        correction_observed_since_reset;
      } ->
      Trailing
        {
          stop_level = stop_level /. factor;
          last_correction_extreme = last_correction_extreme /. factor;
          last_trend_extreme = last_trend_extreme /. factor;
          ma_at_last_adjustment = ma_at_last_adjustment /. factor;
          correction_count;
          correction_observed_since_reset;
        }
  | Tightened { stop_level; last_correction_extreme; reason } ->
      Tightened
        {
          stop_level = stop_level /. factor;
          last_correction_extreme = last_correction_extreme /. factor;
          reason;
        }
