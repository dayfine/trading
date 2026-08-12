(** Bar-shape inference for intraday path generation. See [.mli]. *)

open Core
open Types

(** Clamp a value to a range [min_val, max_val] *)
let _clamp ~min_val ~max_val x = Float.max min_val (Float.min max_val x)

let clamp = _clamp

(** Infer intraday volatility scaling factor from bar characteristics.

    Geometric mean of two factors: shape (high-low)/(open-close) measuring
    choppiness vs directionality, and magnitude (high-low)/open relative to a 2%
    typical daily range. Returns a Brownian noise scale capped at ~2.0. *)
let infer_volatility_scale (bar : price_bar) : float =
  let range = bar.high_price -. bar.low_price in
  if Float.(range = 0.0) then 0.0 (* Completely flat bar *)
  else
    let body = Float.abs (bar.close_price -. bar.open_price) in

    (* Shape factor: how choppy vs directional *)
    let shape_factor =
      if Float.(body = 0.0) then 2.0 (* Pure doji: maximum choppiness *)
      else
        let ratio = range /. body in
        let typical_ratio = 2.5 in
        Float.min (ratio /. typical_ratio) 2.0
    in

    (* Magnitude factor: size of move relative to price *)
    let range_pct = range /. bar.open_price in
    let typical_range_pct = 0.02 in
    (* 2% daily range is typical *)
    let magnitude_factor = Float.min (range_pct /. typical_range_pct) 2.0 in

    (* Combine factors - geometric mean to avoid extreme products *)
    Float.sqrt (shape_factor *. magnitude_factor)

(** Decide probabilistically whether high comes before low.

    Logic:
    - Bullish bars (close > open): high more likely to come first (rally then
      pullback)
    - Bearish bars (close < open): low more likely to come first (sell-off then
      bounce)
    - Higher volatility reduces our confidence, making outcome more random

    Probability calculation:
    - Start at 50% (neutral)
    - Apply directional bias (up to ±30%)
    - Reduce bias when volatility is high (less predictable paths)
    - Clamp to [20%, 80%] to maintain some randomness

    Examples:
    - Low vol bullish bar: ~65-75% chance high comes first
    - High vol bullish bar: ~55-60% chance high comes first
    - Doji (no direction): exactly 50% chance

    Returns true if high should come before low. *)
let _decide_high_first_directional random_state bar body =
  let volatility_scale = infer_volatility_scale bar in
  let neutral_prob = 0.5 in
  (* Base: 50/50 *)
  let max_direction_bias = 0.3 in
  (* Maximum influence from direction *)
  let min_prob = 0.2 in
  (* Never go below 20% *)
  let max_prob = 0.8 in
  (* Never go above 80% *)
  (* Confidence: how much to trust the direction signal
     - Low/typical volatility (≤1.0): full confidence, use max bias (0.3)
     - High volatility (~1.5): reduced confidence, bias ≈ 0.2
     - Very high volatility (~2.0): low confidence, bias ≈ 0.15 *)
  let confidence_factor = 1.0 /. Float.max volatility_scale 1.0 in
  let raw_bias =
    if Float.(body > 0.0) then max_direction_bias else -.max_direction_bias
  in
  let direction_bias = raw_bias *. confidence_factor in
  let prob_clamped =
    _clamp ~min_val:min_prob ~max_val:max_prob (neutral_prob +. direction_bias)
  in
  Float.(Random.State.float random_state 1.0 < prob_clamped)

let decide_high_first (random_state : Random.State.t) (bar : price_bar) : bool =
  let body = bar.close_price -. bar.open_price in
  if Float.(body = 0.0) then Random.State.bool random_state
  else _decide_high_first_directional random_state bar body

let seed_for_bar (bar : price_bar) : int =
  Hashtbl.hash
    (bar.symbol, bar.open_price, bar.high_price, bar.low_price, bar.close_price)
