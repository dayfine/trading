(** Stage 1-4 classification of the monthly MA series. *)

open Core

type stage = Stage1 | Stage2 | Stage3 | Stage4

let stage_label = function
  | Stage1 -> "S1"
  | Stage2 -> "S2"
  | Stage3 -> "S3"
  | Stage4 -> "S4"

(** Slope of MA at index t: (ma[t] - ma[t-k]) / k, normalised by price level.
    [k] is the lookback for slope assessment. 6 months is the canonical
    Weinstein "MA is flat/rising/falling" lookback when applied to monthly data
    (= ~26 weeks ≈ 6 months). *)
let ma_slope_pct ~ma ~prices ~k t =
  if t < k || Float.is_nan ma.(t) || Float.is_nan ma.(t - k) then Float.nan
  else (ma.(t) -. ma.(t - k)) /. prices.(t)

let stage_slope_lookback = 6
let stage_slope_threshold = 0.005

(** Classify Stage 1/2/3/4 at index t given price + MA. Canonical book rules:

    - Stage 2 (advancing): price > MA AND MA rising
    - Stage 4 (declining): price < MA AND MA falling
    - Stage 1 (basing): price ≈ MA, MA flat-or-rising
    - Stage 3 (topping): price ≈ MA, MA flat-or-falling

    Slope threshold ±0.5% of price per 6-month lookback distinguishes "flat"
    from "rising/falling". *)
let classify_stage ~prices ~ma t =
  let p = prices.(t) in
  let m = ma.(t) in
  if Float.is_nan m then Stage1
  else
    let slope = ma_slope_pct ~ma ~prices ~k:stage_slope_lookback t in
    let rising = Float.(slope > stage_slope_threshold) in
    let falling = Float.(slope < -.stage_slope_threshold) in
    let above = Float.(p > m) in
    let below = Float.(p < m) in
    match (above, below, rising, falling) with
    | true, _, true, _ -> Stage2
    | _, true, _, true -> Stage4
    | true, _, false, _ -> Stage3 (* above MA but MA flat/falling = topping *)
    | _, true, false, _ -> Stage1 (* below MA but MA flat/rising = basing *)
    | _ -> Stage1
