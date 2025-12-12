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
let _decide_high_first (random_state : Random.State.t) (bar : price_bar) : bool
    =
  let body = bar.close_price -. bar.open_price in

  (* Edge case: doji bar (no direction) - use pure random *)
  if Float.(body = 0.0) then Random.State.bool random_state
  else
    let volatility_scale = _infer_volatility_scale bar in

    (* Constants for probability calculation *)
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

    (* Direction bias: positive for bullish, negative for bearish *)
    let direction_bias =
      let raw_bias =
        if Float.(body > 0.0) then max_direction_bias else -.max_direction_bias
      in
      raw_bias *. confidence_factor
    in

    (* Combine and clamp to valid probability range *)
    let prob_high_first = neutral_prob +. direction_bias in
    let prob_clamped =
      _clamp ~min_val:min_prob ~max_val:max_prob prob_high_first
    in

    (* Make random decision based on calculated probability *)
    Float.(Random.State.float random_state 1.0 < prob_clamped)

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

    Returns [idx_open; idx_first_extreme; idx_second_extreme; idx_close] as bar
    indices in [0, resolution-1].

    Note: The order of high vs low is determined separately by
    _decide_high_first. *)
let _generate_waypoint_indices (random_state : Random.State.t)
    (profile : distribution_profile) (resolution : int) : int list =
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
      [ 0; t_first; t_second; resolution - 1 ]
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
      [ 0; t_first; t_second; resolution - 1 ]

(** {1 Brownian Bridge Segment Generation} *)

(** Generate a single sample from standard normal distribution N(0,1).

    Uses Box-Muller transform to convert uniform random variables to Gaussian.
*)
let _sample_standard_normal (random_state : Random.State.t) : float =
  let u1 = Random.State.float random_state 1.0 in
  let u2 = Random.State.float random_state 1.0 in
  Float.sqrt (-2.0 *. Float.log u1) *. Float.cos (2.0 *. Float.pi *. u2)

(** Generate a single sample from Student's t-distribution with given degrees of
    freedom.

    Student's t has heavier tails than Gaussian, better modeling extreme moves
    in financial markets. Lower df = heavier tails.

    Algorithm: 1. Sample Z ~ N(0,1) 2. Sample V ~ Chi-squared(df) = sum of df
    squared standard normals 3. Return T = Z / sqrt(V/df)

    For df > 30, this closely approximates a Gaussian distribution. *)
let _sample_student_t (random_state : Random.State.t) (df : float) : float =
  (* Sample standard normal for numerator *)
  let z = _sample_standard_normal random_state in
  (* Sample chi-squared(df) for denominator
     Chi-squared(df) = sum of df independent squared standard normals *)
  let chi_squared =
    let rec sum_squares count acc =
      if count <= 0 then acc
      else
        let normal_sample = _sample_standard_normal random_state in
        sum_squares (count - 1) (acc +. (normal_sample *. normal_sample))
    in
    sum_squares (Float.to_int df) 0.0
  in
  (* Student's t = Z / sqrt(V/df) *)
  z /. Float.sqrt (chi_squared /. df)

(** Generate price segment between two waypoints using Brownian bridge.

    The bridge ensures we hit the target price while adding realistic noise.
    Noise is sampled from Student's t-distribution for fat tails.

    @param start_price Starting price
    @param end_price Ending price (must reach exactly)
    @param n_points Number of intermediate points to generate
    @param volatility_scale Scaling factor for noise amplitude
    @param degrees_of_freedom
      Student's t degrees of freedom (lower = heavier tails)
    @param resolution
      Total path resolution (waypoint indices are in [0, resolution-1])
    @param low_bound Lower price bound (from bar)
    @param high_bound Upper price bound (from bar)
    @return List of path_points from start to end *)
let _generate_bridge_segment ~random_state ~start_price ~end_price ~n_points
    ~volatility_scale ~degrees_of_freedom ~resolution ~low_bound ~high_bound :
    path_point list =
  (* Noise scaling based on Brownian motion properties:
     - Variance of Brownian motion scales linearly with time
     - Standard deviation scales with sqrt(time)
     - dt = fraction of full bar this segment spans (0.0 to 1.0)
     - Each step covers time dt/(n_points+1), so noise ~ sqrt(dt/(n_points+1)) *)
  let dt = Float.of_int n_points /. Float.of_int resolution in
  let noise_scale =
    volatility_scale *. Float.sqrt (dt /. Float.of_int (n_points + 1))
  in
  let rec generate_points i current_price acc =
    if i > n_points then List.rev acc
    else
      (* Brownian bridge: adjust drift to ensure we reach endpoint *)
      let remaining_steps = n_points + 1 - i in
      let needed_drift =
        (end_price -. current_price) /. Float.of_int remaining_steps
      in
      (* Add Student's t noise scaled by volatility for realistic fat tails *)
      let noise =
        _sample_student_t random_state degrees_of_freedom *. noise_scale
      in
      let new_price = current_price +. needed_drift +. noise in
      (* Clamp to bar bounds using helper *)
      let clamped_price =
        _clamp ~min_val:low_bound ~max_val:high_bound new_price
      in
      let point : path_point = { price = clamped_price } in
      generate_points (i + 1) clamped_price (point :: acc)
  in
  generate_points 1 start_price []

(** {1 Main Path Generation} *)

let generate_path ?(config = default_config) (bar : price_bar) : intraday_path =
  (* Initialize random state based on seed *)
  let random_state =
    match config.seed with
    | Some seed -> Random.State.make [| seed |]
    | None -> Random.State.make_self_init ()
  in
  (* Step 1: Decide path order *)
  let high_first = _decide_high_first random_state bar in
  let waypoint_prices =
    if high_first then
      [ bar.open_price; bar.high_price; bar.low_price; bar.close_price ]
    else [ bar.open_price; bar.low_price; bar.high_price; bar.close_price ]
  in
  (* Step 2: Generate waypoint indices *)
  let waypoint_indices =
    _generate_waypoint_indices random_state config.profile config.total_points
  in
  (* Step 3: Infer volatility *)
  let volatility_scale = _infer_volatility_scale bar in
  (* Step 4: Generate path segments between waypoints *)
  (* Special case: if total_points <= 4, just return waypoints without interpolation *)
  if config.total_points <= 4 then
    List.map waypoint_prices ~f:(fun price -> ({ price } : path_point))
  else
    (* Standard case: interpolate between waypoints with Brownian bridge *)
    let rec generate_segments prices indices acc =
      match (prices, indices) with
      | p1 :: p2 :: rest_prices, idx1 :: idx2 :: rest_indices ->
          (* Create opening point if this is first segment *)
          let acc' =
            if List.is_empty acc then ({ price = p1 } : path_point) :: acc
            else acc
          in
          (* Each segment gets points proportional to its length
             Since waypoint indices are in [0, total_points-1],
             segment_length directly gives us the number of points *)
          let n_points = idx2 - idx1 in
          (* Generate bridge segment *)
          let segment =
            _generate_bridge_segment ~random_state ~start_price:p1 ~end_price:p2
              ~n_points ~volatility_scale
              ~degrees_of_freedom:config.degrees_of_freedom
              ~resolution:config.total_points ~low_bound:bar.low_price
              ~high_bound:bar.high_price
          in
          (* Add ending waypoint and continue *)
          let waypoint : path_point = { price = p2 } in
          let acc'' = waypoint :: List.rev_append segment acc' in
          generate_segments (p2 :: rest_prices) (idx2 :: rest_indices) acc''
      | _, _ -> List.rev acc
    in
    generate_segments waypoint_prices waypoint_indices []

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
