open Core
open Trading_base.Types
open Stop_types

let trailing_high_of_state = function
  | Trailing { last_trend_extreme; _ } -> Some last_trend_extreme
  | Initial _ | Tightened _ -> None

let trigger_level ~pct ~trailing_high ~side =
  match side with
  | Long -> trailing_high *. (1.0 -. pct)
  | Short -> trailing_high *. (1.0 +. pct)

let check_hit ~armed ~pct ~trailing_high ~bar ~side =
  if (not armed) || Float.( <= ) pct 0.0 then false
  else
    let level = trigger_level ~pct ~trailing_high ~side in
    match side with
    | Long -> Float.( <= ) bar.Types.Daily_price.low_price level
    | Short -> Float.( >= ) bar.Types.Daily_price.high_price level
