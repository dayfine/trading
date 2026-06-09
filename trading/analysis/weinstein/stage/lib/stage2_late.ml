open Core

(** Late-Stage-2 detection (MA-deceleration warning) — see [stage2_late.mli].
    Extracted from [stage.ml] (a declared-large coordinator at its line cap) as
    a self-contained Stage-2 held-position signal, sibling to [Stage2_ma_hold].
*)

let is_late_stage2 ~get_ma ~decel_threshold ~slope_lookback : bool =
  let old_off = (2 * slope_lookback) - 1 in
  let mid_off = slope_lookback - 1 in
  match
    ( get_ma ~week_offset:old_off,
      get_ma ~week_offset:mid_off,
      get_ma ~week_offset:0 )
  with
  | Some old_ma, Some mid_ma, Some cur_ma ->
      let old_slope =
        if Float.(old_ma = 0.0) then 0.0
        else (mid_ma -. old_ma) /. Float.abs old_ma
      in
      let new_slope =
        if Float.(mid_ma = 0.0) then 0.0
        else (cur_ma -. mid_ma) /. Float.abs mid_ma
      in
      Float.(old_slope > 0.0)
      && Float.(new_slope < old_slope *. (1.0 -. decel_threshold))
  | _ -> false
