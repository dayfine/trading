open Core
open Stop_types
open Trading_base.Types

let seed_correction_extreme ~config ~side ~bar =
  if config.correction_must_follow_peak then bar.Types.Daily_price.close_price
  else Stop_geometry.bar_extreme ~side ~bar

let _is_new_trend_extreme ~side ~last_trend_extreme ~new_trend_extreme =
  match side with
  | Long -> Float.( > ) new_trend_extreme last_trend_extreme
  | Short -> Float.( < ) new_trend_extreme last_trend_extreme

let carried_correction_extreme ~config ~side ~last_trend_extreme
    ~new_trend_extreme ~new_correction_extreme ~bar =
  if
    config.correction_must_follow_peak
    && _is_new_trend_extreme ~side ~last_trend_extreme ~new_trend_extreme
  then bar.Types.Daily_price.close_price
  else new_correction_extreme
