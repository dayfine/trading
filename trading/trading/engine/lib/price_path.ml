(* @large-module: price path generation covers multiple interpolation modes and order-fill simulation *)
(** Realistic intraday price path generation from OHLC bars *)

open Core
open Trading_base.Types
open Types

type distribution_profile = UShaped | JShaped | ReverseJ | Uniform

type path_config = {
  profile : distribution_profile;
  total_points : int;
  seed : int option;
  degrees_of_freedom : float;
      (** Degrees of freedom for Student's t noise distribution.
          - Lower values (3-5): Heavier tails, more extreme moves (realistic for
            finance)
          - Higher values (>30): Approaches Gaussian distribution
          - Default: 4.0 for moderately fat tails *)
}

let default_config =
  {
    profile = UShaped;
    total_points = 390;
    seed = None;
    degrees_of_freedom = 4.0;
  }

(** {1 Scratch Buffer}

    See [.mli] for the public contract. *)

(* [_capacity_slack_for_config] +8 absorbs the rounding overshoot from
   segment generation (4 waypoints plus interpolated points between each
   pair). *)
let _capacity_slack_for_config = 8
let _min_scratch_capacity = 4

(* Pool tuning for transient workspaces inside [Price_path]. The hottest
   pool consumer is [_sample_student_t], which acquires a 1-slot float
   accumulator on every call (called once per interpolated bar point, ~390
   times per [generate_path_into] call). With [max_size = 4] the pool
   never grows past a handful of buffers in steady state, and
   [initial_size = 1] keeps each buffer minimal. *)
let _student_t_pool_initial_size = 1
let _student_t_pool_max_size = 4

module Scratch = struct
  type t = { path_points : float array; student_t_pool : Buffer_pool.t }

  let create ~capacity =
    if capacity < _min_scratch_capacity then
      invalid_arg
        (Printf.sprintf "Price_path.Scratch.create: capacity %d < min %d"
           capacity _min_scratch_capacity);
    {
      path_points = Array.create ~len:capacity 0.0;
      student_t_pool =
        Buffer_pool.create ~initial_size:_student_t_pool_initial_size
          ~max_size:_student_t_pool_max_size;
    }

  let required_capacity (c : path_config) =
    Int.max _min_scratch_capacity (c.total_points + _capacity_slack_for_config)

  let for_config (c : path_config) = create ~capacity:(required_capacity c)
  let capacity t = Array.length t.path_points
  let student_t_pool t = t.student_t_pool
end

(** {1 Utility Functions} *)

(** Clamp a value to a range [min_val, max_val] *)
let _clamp ~min_val ~max_val x = Float.max min_val (Float.min max_val x)

(** {1 Volatility Inference} *)

(** Infer intraday volatility scaling factor from bar characteristics.

    Combines two factors using geometric mean: 1. Shape: (high-low)/(open-close)
    \- measures choppiness vs directionality
    - ratio ≈ 1.0: Very directional (minimal wicks)
    - ratio ≈ 2.5: Typical intraday volatility
    - ratio ≥ 5.0: High volatility (large wicks, indecision)

    2. Magnitude: (high-low)/open - measures size of move relative to price
    - ~1%: Small move
    - ~2%: Typical daily range
    - ~4%+: Large move

    Returns scaling factor for Brownian noise:
    - ~1.0 for typical volatility (shape=1.0, magnitude=1.0)
    - <1.0 for low volatility (small, directional moves)
    - >1.0 for high volatility (large, choppy moves)
    - Capped at ~2.0 for extreme cases *)
let _infer_volatility_scale (bar : price_bar) : float =
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

(** {1 Path Order Determination} *)

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
  let volatility_scale = _infer_volatility_scale bar in
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

let _decide_high_first (random_state : Random.State.t) (bar : price_bar) : bool
    =
  let body = bar.close_price -. bar.open_price in
  if Float.(body = 0.0) then Random.State.bool random_state
  else _decide_high_first_directional random_state bar body

(** {1 Distribution Profiles and Time Sampling} *)

(** Density function for intraday activity distribution at normalized time t ∈
    [0,1].

    These model when during the trading day high/low prices are likely to occur:

    - UShaped: High activity at open and close (t=0 and t=1), low mid-day
      Formula: 2(t² + (1-t)²) Models typical equity market pattern (opening
      rush, lunch lull, closing rush)

    - JShaped: Front-loaded activity, exponentially decaying Formula: exp(-3t)
      Models strong opening that fades throughout the day

    - ReverseJ: Back-loaded activity, exponentially growing Formula: exp(3(t-1))
      Models building momentum toward the close

    - Uniform: Equal probability throughout the day Formula: 1.0

    Returns relative density (not normalized to integrate to 1). *)
let _density_function (profile : distribution_profile) (t : float) : float =
  match profile with
  | UShaped ->
      (* Quadratic U-shape: sum of squared distances from both ends
         - At t=0 or t=1: density = 2.0 (peak)
         - At t=0.5: density = 1.0 (trough) *)
      let peak_density = 2.0 in
      let dist_from_start = t in
      let dist_from_end = 1.0 -. t in
      peak_density
      *. ((dist_from_start *. dist_from_start)
         +. (dist_from_end *. dist_from_end))
  | JShaped ->
      (* Exponential decay: density drops 95% from start to end
         - At t=0: density = 1.0
         - At t=1: density ≈ 0.05 *)
      let decay_rate = 3.0 in
      Float.exp (-.decay_rate *. t)
  | ReverseJ ->
      (* Exponential growth: density increases 20x from start to end
         - At t=0: density ≈ 0.05
         - At t=1: density = 1.0 *)
      let growth_rate = 3.0 in
      Float.exp (growth_rate *. (t -. 1.0))
  | Uniform ->
      (* Constant density throughout *)
      1.0

(** Maximum density value for rejection sampling.

    For rejection sampling to work, we need the maximum possible density to use
    as the acceptance threshold. These values are the analytical maxima of each
    density function. *)
let _find_max_density (profile : distribution_profile) : float =
  match profile with
  | UShaped ->
      (* Maximum at endpoints (t=0 or t=1) *)
      2.0
  | JShaped ->
      (* Maximum at start (t=0) where exp(-3*0) = 1.0 *)
      1.0
  | ReverseJ ->
      (* Maximum at end (t=1) where exp(3*0) = 1.0 *)
      1.0
  | Uniform ->
      (* Constant density *)
      1.0

(** Sample a single time point from density function using rejection sampling *)
let _sample_time_from_density (random_state : Random.State.t)
    (profile : distribution_profile) : float =
  let density = _density_function profile in
  let max_density = _find_max_density profile in
  let rec sample () =
    let t = Random.State.float random_state 1.0 in
    let acceptance = Random.State.float random_state max_density in
    if Float.(acceptance < density t) then t else sample ()
  in
  sample ()

(** Ensure two waypoint indices are unique and sorted.

    Takes two unsorted indices and returns a sorted, unique pair. If both
    indices are equal, adjusts the second to be different while maintaining
    monotonicity and staying within bounds [1, resolution-2].

    @param resolution Total bar resolution (e.g., 390)
    @param t1 First index (may be unsorted)
    @param t2 Second index (may be unsorted)
    @return (t_first, t_second) where t_first < t_second *)
let _ensure_unique_waypoints (resolution : int) (t1 : int) (t2 : int) :
    int * int =
  (* Sort to ensure monotonic ordering *)
  let t_first, t_second = if t1 < t2 then (t1, t2) else (t2, t1) in
  (* Ensure uniqueness: all 4 waypoints [0, t_first, t_second, resolution-1] must be distinct *)
  if t_first = t_second then
    (* Need to separate them while maintaining monotonicity *)
    if t_second < resolution - 2 then (t_first, t_second + 1)
      (* Increment t_second *)
    else (t_first - 1, t_second) (* Decrement t_first *)
  else (t_first, t_second)

(** Generate waypoint indices for O, H, L, C based on distribution profile.

    Places high/low waypoints at different points in time based on activity
    pattern. All non-uniform profiles use rejection sampling from their density
    functions:
    - UShaped: Sampled from U-shaped density (more likely at open/close, less
      mid-day)
    - JShaped: Sampled from exponential decay (more likely early, less likely
      late)
    - ReverseJ: Sampled from exponential growth (less likely early, more likely
      late)
    - Uniform: Random placement in middle 60% (skip early/late extremes for
      robustness)

    Returns (idx_open, idx_first_extreme, idx_second_extreme, idx_close) as bar
    indices in [0, resolution-1].

    Note: The order of high vs low is determined separately by
    _decide_high_first. *)
let _generate_waypoint_indices (random_state : Random.State.t)
    (profile : distribution_profile) (resolution : int) : int * int * int * int
    =
  match profile with
  | UShaped | JShaped | ReverseJ ->
      (* Sample from density using rejection sampling
         - UShaped: extremes more likely at open/close (U-shaped density)
         - JShaped: extremes more likely early (exponential decay)
         - ReverseJ: extremes more likely late (exponential growth) *)
      let t1_normalized = _sample_time_from_density random_state profile in
      let t2_normalized = _sample_time_from_density random_state profile in
      (* Convert normalized time [0,1] to bar indices [0, resolution-1] *)
      let t1_idx = Float.to_int (t1_normalized *. Float.of_int resolution) in
      let t2_idx = Float.to_int (t2_normalized *. Float.of_int resolution) in
      (* Clamp to (0, resolution-1) exclusive to avoid overlap with open/close *)
      let t1_clamped = Int.max 1 (Int.min (resolution - 2) t1_idx) in
      let t2_clamped = Int.max 1 (Int.min (resolution - 2) t2_idx) in
      (* Ensure uniqueness and sort *)
      let t_first, t_second =
        _ensure_unique_waypoints resolution t1_clamped t2_clamped
      in
      (0, t_first, t_second, resolution - 1)
  | Uniform ->
      (* Uniform: place extremes randomly in middle 60% to avoid edge effects
         - Skip first 20% (opening volatility/gaps)
         - Skip last 20% (closing cross volatility)
         - Sample two random indices in [20%, 80%] range *)
      let pct_start = 0.20 in
      let pct_end = 0.80 in
      let middle_start = Float.to_int (Float.of_int resolution *. pct_start) in
      let middle_end = Float.to_int (Float.of_int resolution *. pct_end) in
      let range = middle_end - middle_start in
      let t1 = middle_start + Random.State.int random_state range in
      let t2 = middle_start + Random.State.int random_state range in
      (* Ensure uniqueness and sort *)
      let t_first, t_second = _ensure_unique_waypoints resolution t1 t2 in
      (0, t_first, t_second, resolution - 1)

(** {1 Brownian Bridge Segment Generation} *)

(** Generate a single sample from standard normal distribution N(0,1).

    Uses Box-Muller transform to convert uniform random variables to Gaussian.
*)
let _sample_standard_normal (random_state : Random.State.t) : float =
  let u1 = Random.State.float random_state 1.0 in
  let u2 = Random.State.float random_state 1.0 in
  Float.sqrt (-2.0 *. Float.log u1) *. Float.cos (2.0 *. Float.pi *. u2)

(** Sample Student's t-distribution: T = Z / sqrt(V/df), with Z ~ N(0,1) and V ~
    Chi-squared(df). Heavier tails than Gaussian for low df. The chi-squared sum
    uses a 1-slot [float array] accumulator borrowed from [pool] (PR-4 of the
    engine-pooling plan); previously this was a [ref 0.0] allocated per call.
    The accumulation order is the same left-fold [for] loop as before — seeded
    goldens stay bit-equal. *)
let _sample_student_t ~pool (random_state : Random.State.t) (df : float) : float
    =
  let z = _sample_standard_normal random_state in
  let acc = Buffer_pool.acquire pool ~capacity:1 () in
  acc.(0) <- 0.0;
  for _ = 1 to Float.to_int df do
    let s = _sample_standard_normal random_state in
    acc.(0) <- acc.(0) +. (s *. s)
  done;
  let chi_squared = acc.(0) in
  Buffer_pool.release pool acc;
  z /. Float.sqrt (chi_squared /. df)

(** Brownian bridge: write [n_points] interpolated prices into
    [out.(out_start .. out_start + n_points - 1)] from [start_price] toward
    [end_price]. The endpoint is NOT written; callers append it. FP order
    matches the previous list-based version. *)
let _generate_bridge_segment_into ~random_state ~pool ~out ~out_start
    ~start_price ~end_price ~n_points ~volatility_scale ~degrees_of_freedom
    ~resolution ~low_bound ~high_bound =
  (* Noise scales with sqrt(time): each step covers dt/(n_points+1) of the
     bar's [dt = n_points/resolution] fraction. *)
  let dt = Float.of_int n_points /. Float.of_int resolution in
  let noise_scale =
    volatility_scale *. Float.sqrt (dt /. Float.of_int (n_points + 1))
  in
  let current_price = ref start_price in
  for i = 1 to n_points do
    let remaining_steps = n_points + 1 - i in
    let needed_drift =
      (end_price -. !current_price) /. Float.of_int remaining_steps
    in
    let noise =
      _sample_student_t ~pool random_state degrees_of_freedom *. noise_scale
    in
    let new_price = !current_price +. needed_drift +. noise in
    let clamped_price =
      _clamp ~min_val:low_bound ~max_val:high_bound new_price
    in
    out.(out_start + i - 1) <- clamped_price;
    current_price := clamped_price
  done

(** {1 Main Path Generation} *)

(** Append one segment of prices to [out] from [cursor]; return the new cursor.
    First segment writes [p1] as slot 0; subsequent ones inherit it from the
    previous segment's endpoint. *)
let _append_segment_into ~random_state ~pool ~volatility_scale
    ~degrees_of_freedom ~total_points ~low_bound ~high_bound ~out ~cursor p1 p2
    idx1 idx2 =
  let cursor =
    if cursor = 0 then (
      out.(0) <- p1;
      1)
    else cursor
  in
  let n_points = idx2 - idx1 in
  _generate_bridge_segment_into ~random_state ~pool ~out ~out_start:cursor
    ~start_price:p1 ~end_price:p2 ~n_points ~volatility_scale
    ~degrees_of_freedom ~resolution:total_points ~low_bound ~high_bound;
  let cursor = cursor + n_points in
  out.(cursor) <- p2;
  cursor + 1

(** Interpolate three pairs of waypoints into [out]; return final cursor (=
    total length written). *)
let _generate_segments_into ~random_state ~pool ~volatility_scale
    ~degrees_of_freedom ~total_points ~low_bound ~high_bound ~out
    ~waypoint_prices ~waypoint_indices =
  let p0, p1, p2, p3 = waypoint_prices in
  let i0, i1, i2, i3 = waypoint_indices in
  let append =
    _append_segment_into ~random_state ~pool ~volatility_scale
      ~degrees_of_freedom ~total_points ~low_bound ~high_bound ~out
  in
  let cursor = append ~cursor:0 p0 p1 i0 i1 in
  let cursor = append ~cursor p1 p2 i1 i2 in
  append ~cursor p2 p3 i2 i3

(** Materialize the public [path_point list] from the populated prefix
    [out.(0..len-1)]. This is the only required allocation per call. *)
let _path_of_array (out : float array) ~len : intraday_path =
  let acc = ref [] in
  for i = len - 1 downto 0 do
    acc := ({ price = out.(i) } : path_point) :: !acc
  done;
  !acc

let _waypoint_prices_of_bar (bar : price_bar) ~high_first =
  if high_first then
    (bar.open_price, bar.high_price, bar.low_price, bar.close_price)
  else (bar.open_price, bar.low_price, bar.high_price, bar.close_price)

let _generate_path_with_scratch ~scratch ~config (bar : price_bar) :
    intraday_path =
  let random_state =
    match config.seed with
    | Some seed -> Random.State.make [| seed |]
    | None -> Random.State.make_self_init ()
  in
  let high_first = _decide_high_first random_state bar in
  let waypoint_prices = _waypoint_prices_of_bar bar ~high_first in
  let waypoint_indices =
    _generate_waypoint_indices random_state config.profile config.total_points
  in
  let volatility_scale = _infer_volatility_scale bar in
  if config.total_points <= 4 then
    let p0, p1, p2, p3 = waypoint_prices in
    [ { price = p0 }; { price = p1 }; { price = p2 }; { price = p3 } ]
  else
    let pool = Scratch.student_t_pool scratch in
    let len =
      _generate_segments_into ~random_state ~pool ~volatility_scale
        ~degrees_of_freedom:config.degrees_of_freedom
        ~total_points:config.total_points ~low_bound:bar.low_price
        ~high_bound:bar.high_price ~out:scratch.Scratch.path_points
        ~waypoint_prices ~waypoint_indices
    in
    _path_of_array scratch.Scratch.path_points ~len

let generate_path_into ~scratch ?(config = default_config) (bar : price_bar) :
    intraday_path =
  (* Required size matches [Scratch.for_config] so any buffer sized via that
     helper is always accepted. *)
  let required = Scratch.required_capacity config in
  if Scratch.capacity scratch < required then
    invalid_arg
      (Printf.sprintf
         "Price_path.generate_path_into: scratch capacity %d < required %d"
         (Scratch.capacity scratch) required);
  _generate_path_with_scratch ~scratch ~config bar

let generate_path ?(config = default_config) (bar : price_bar) : intraday_path =
  _generate_path_with_scratch ~scratch:(Scratch.for_config config) ~config bar

(** {1 Early Exit Optimization} *)

let rec might_fill (bar : price_bar) (side : side) (order_type : order_type) :
    bool =
  match order_type with
  | Market -> true (* Market orders always fill *)
  | Limit limit_price -> (
      match side with
      | Buy ->
          (* Buy limit fills if price reaches or goes below limit *)
          Float.(bar.low_price <= limit_price)
      | Sell ->
          (* Sell limit fills if price reaches or goes above limit *)
          Float.(bar.high_price >= limit_price))
  | Stop stop_price -> (
      match side with
      | Buy ->
          (* Buy stop triggers if price reaches or goes above stop *)
          Float.(bar.high_price >= stop_price)
      | Sell ->
          (* Sell stop triggers if price reaches or goes below stop *)
          Float.(bar.low_price <= stop_price))
  | StopLimit (stop_price, limit_price) ->
      (* Stop must trigger AND limit must be reachable *)
      might_fill bar side (Stop stop_price)
      && might_fill bar side (Limit limit_price)
