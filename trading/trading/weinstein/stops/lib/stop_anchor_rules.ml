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

(* ---- tightened_can_ratchet ---- *)

let _deeper ~side a b =
  match side with Long -> Float.min a b | Short -> Float.max a b

let _pullback_pct ~side ~peak ~low =
  match side with
  | Long -> (peak -. low) /. peak
  | Short -> (low -. peak) /. peak

let _reaction_confirmed ~config ~side ~peak ~low ~close =
  Float.( >= )
    (_pullback_pct ~side ~peak ~low)
    config.tightened_min_reaction_pct
  && Stop_geometry.is_recovery ~side ~close ~trend_extreme:peak

let _tightened ~stop_level ~low ~peak ~reason =
  Tightened
    {
      stop_level;
      last_correction_extreme = low;
      reason;
      swing_peak = Some peak;
    }

(* A confirmed reaction: raise to just under its low when that beats the stop
   (never lowered), and restart the swing at this bar's close either way. *)
let _on_confirmed ~config ~side ~stop_level ~low ~reason ~close =
  let candidate =
    Stop_geometry.tightened_stop_candidate ~config ~side ~correction_extreme:low
  in
  let restart level =
    _tightened ~stop_level:level ~low:close ~peak:close ~reason
  in
  if Stop_geometry.is_better_stop ~side ~current:stop_level ~candidate then
    ( restart candidate,
      Stop_raised
        {
          old_level = stop_level;
          new_level = candidate;
          reason = Printf.sprintf "%s (reaction low)" reason;
        } )
  else (restart stop_level, No_change)

(* No confirmation: a new extreme close starts a new swing (so the low is
   always printed after its peak); otherwise keep deepening the pullback. *)
let _extend_swing ~side ~stop_level ~peak ~low ~reason ~close =
  let state =
    if
      _is_new_trend_extreme ~side ~last_trend_extreme:peak
        ~new_trend_extreme:close
    then _tightened ~stop_level ~low:close ~peak:close ~reason
    else _tightened ~stop_level ~low ~peak ~reason
  in
  (state, No_change)

let ratchet_tightened_swing ~config ~side ~stop_level ~last_correction_extreme
    ~swing_peak ~reason ~bar =
  let close = bar.Types.Daily_price.close_price in
  match swing_peak with
  | None -> (_tightened ~stop_level ~low:close ~peak:close ~reason, No_change)
  | Some peak ->
      let low =
        _deeper ~side last_correction_extreme
          (Stop_geometry.bar_extreme ~side ~bar)
      in
      if _reaction_confirmed ~config ~side ~peak ~low ~close then
        _on_confirmed ~config ~side ~stop_level ~low ~reason ~close
      else _extend_swing ~side ~stop_level ~peak ~low ~reason ~close
