open Core
open Stop_types
open Trading_base.Types

let nudge_round_number ~config ~side price =
  Stop_nudge.nudge_round_number ~nudge:config.round_number_nudge ~side price

let bar_extreme ~side ~bar =
  match side with
  | Long -> bar.Types.Daily_price.low_price
  | Short -> bar.Types.Daily_price.high_price

(* One shared body for both candidate flavours: the only difference between the
   trailing and tightened candidates is which buffer they read off the config. *)
let _buffered ~config ~side ~correction_extreme ~buf =
  let adjusted =
    match side with
    | Long -> correction_extreme *. (1.0 -. buf)
    | Short -> correction_extreme *. (1.0 +. buf)
  in
  nudge_round_number ~config ~side adjusted

let stop_candidate ~config ~side ~correction_extreme =
  _buffered ~config ~side ~correction_extreme
    ~buf:config.trailing_stop_buffer_pct

let tightened_stop_candidate ~config ~side ~correction_extreme =
  _buffered ~config ~side ~correction_extreme
    ~buf:config.tightened_stop_buffer_pct

let is_better_stop ~side ~current ~candidate =
  match side with
  | Long -> Float.( > ) candidate current
  | Short -> Float.( < ) candidate current

let is_correction ~config ~side ~trend_extreme ~correction_extreme =
  let pullback =
    match side with
    | Long -> (trend_extreme -. correction_extreme) /. trend_extreme
    | Short -> (correction_extreme -. trend_extreme) /. trend_extreme
  in
  Float.( >= ) pullback config.min_correction_pct

let is_recovery ~side ~close ~trend_extreme =
  match side with
  | Long -> Float.( >= ) close trend_extreme
  | Short -> Float.( <= ) close trend_extreme
