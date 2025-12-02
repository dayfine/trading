(** Realistic intraday price path generation from OHLC bars *)

open Core
open Trading_base.Types
open Types

type distribution_profile = UShaped | JShaped | ReverseJ | Uniform

type path_config = {
  profile : distribution_profile;
  points_per_segment : int;
  seed : int option;
}

let default_config = { profile = UShaped; points_per_segment = 130; seed = None }

(** {1 Volatility Inference} *)

(** Infer intraday volatility from bar characteristics.

    Uses (high-low)/(open-close) ratio as a proxy:
    - Higher ratio indicates more intraday fighting/volatility
    - Lower ratio indicates directional move with less noise

    Returns a scaling factor for Brownian noise (typical range 0.5 to 2.0) *)
let _infer_volatility_scale (bar : price_bar) : float =
  let range = bar.high_price -. bar.low_price in
  let body = Float.abs (bar.close_price -. bar.open_price) in
  (* Avoid division by zero for doji bars *)
  let body_safe = Float.max body (range *. 0.01) in
  let ratio = range /. body_safe in
  (* Typical ratio is 2-3; scale to reasonable noise level *)
  let base_scale = 0.3 in
  base_scale *. Float.min ratio 4.0

(** {1 Path Order Determination} *)

(** Decide probabilistically whether high comes before low.

    For upward bars (close > open), high is more likely first.
    For downward bars (close < open), low is more likely first.
    But higher volatility increases randomness.

    Returns true if high should come before low. *)
let _decide_high_first (random_state : Random.State.t) (bar : price_bar) : bool =
  let direction = bar.close_price -. bar.open_price in
  let volatility_scale = _infer_volatility_scale bar in
  (* Base probability: 0.5 (random) *)
  (* Direction bias: +0.3 if upward, -0.3 if downward *)
  (* Volatility randomness: high vol reduces bias *)
  let direction_bias =
    if Float.(direction >= 0.0) then 0.3 /. volatility_scale
    else -0.3 /. volatility_scale
  in
  let prob_high_first = 0.5 +. direction_bias in
  let prob_clamped = Float.max 0.2 (Float.min 0.8 prob_high_first) in
  Float.(Random.State.float random_state 1.0 < prob_clamped)

(** {1 Distribution Profiles and Time Sampling} *)

(** Density function for distribution profile at time t ∈ [0,1] *)
let _density_function (profile : distribution_profile) (t : float) : float =
  match profile with
  | UShaped ->
      (* Higher density at both ends *)
      2.0 *. ((t *. t) +. ((1.0 -. t) *. (1.0 -. t)))
  | JShaped ->
      (* Exponential decay from start *)
      Float.exp (-3.0 *. t)
  | ReverseJ ->
      (* Exponential growth toward end *)
      Float.exp (3.0 *. (t -. 1.0))
  | Uniform -> 1.0

(** Find approximate maximum of density function for rejection sampling *)
let _find_max_density (profile : distribution_profile) : float =
  match profile with
  | UShaped -> 2.0
  | JShaped -> 1.0
  | ReverseJ -> 1.0
  | Uniform -> 1.0

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

(** Generate waypoint times for O, H, L, C based on distribution profile.

    Returns [t_open; t_high_or_low; t_low_or_high; t_close]
    where times are in [0, 1] representing fraction of day. *)
let _generate_waypoint_times (random_state : Random.State.t)
    (profile : distribution_profile) (_high_first : bool) : float list =
  match profile with
  | UShaped | Uniform ->
      (* High and low can occur anywhere in middle 60% of day *)
      let middle_start = 0.2 in
      let middle_end = 0.8 in
      let t1 =
        middle_start
        +. Random.State.float random_state (middle_end -. middle_start)
      in
      let t2 =
        middle_start
        +. Random.State.float random_state (middle_end -. middle_start)
      in
      (* Sort to ensure monotonic time *)
      let t_first, t_second =
        if Float.(t1 < t2) then (t1, t2) else (t2, t1)
      in
      [ 0.0; t_first; t_second; 1.0 ]
  | JShaped ->
      (* High/Low occur early *)
      [ 0.0; 0.25; 0.35; 1.0 ]
  | ReverseJ ->
      (* High/Low occur late *)
      [ 0.0; 0.65; 0.75; 1.0 ]

(** {1 Brownian Bridge Segment Generation} *)

(** Generate a single sample from standard normal distribution.

    Uses Box-Muller transform. *)
let _sample_gaussian (random_state : Random.State.t) : float =
  let u1 = Random.State.float random_state 1.0 in
  let u2 = Random.State.float random_state 1.0 in
  Float.sqrt (-2.0 *. Float.log u1) *. Float.cos (2.0 *. Float.pi *. u2)

(** Generate price segment between two waypoints using Brownian bridge.

    The bridge ensures we hit the target price while adding realistic noise.
    Volatility is scaled by the inferred volatility from the bar.

    @param start_price Starting price
    @param end_price Ending price (must reach exactly)
    @param start_time Starting fraction of day
    @param end_time Ending fraction of day
    @param n_points Number of intermediate points to generate
    @param volatility_scale Scaling factor for noise amplitude
    @param low_bound Lower price bound (from bar)
    @param high_bound Upper price bound (from bar)
    @return List of path_points from start to end *)
let _generate_bridge_segment ~random_state ~start_price ~end_price ~start_time
    ~end_time ~n_points ~volatility_scale ~low_bound ~high_bound : path_point list
    =
  if n_points <= 0 then []
  else
    let dt = (end_time -. start_time) /. Float.of_int (n_points + 1) in
    let noise_scale = volatility_scale *. Float.sqrt dt in
    let rec generate_points i current_price current_time acc =
      if i > n_points then List.rev acc
      else
        (* Brownian bridge: adjust drift to ensure we reach endpoint *)
        let remaining_steps = n_points + 1 - i in
        let needed_drift =
          (end_price -. current_price) /. Float.of_int remaining_steps
        in
        (* Add Gaussian noise scaled by volatility *)
        let noise = _sample_gaussian random_state *. noise_scale in
        let new_price = current_price +. needed_drift +. noise in
        (* Clamp to bar bounds *)
        let clamped_price = Float.max low_bound (Float.min high_bound new_price) in
        let new_time = current_time +. dt in
        let point : path_point =
          { fraction_of_day = new_time; price = clamped_price }
        in
        generate_points (i + 1) clamped_price new_time (point :: acc)
    in
    generate_points 1 start_price start_time []

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
  (* Step 2: Generate waypoint times *)
  let waypoint_times =
    _generate_waypoint_times random_state config.profile high_first
  in
  (* Step 3: Infer volatility *)
  let volatility_scale = _infer_volatility_scale bar in
  (* Step 4: Generate path segments between waypoints *)
  let rec generate_segments prices times acc =
    match (prices, times) with
    | p1 :: p2 :: rest_prices, t1 :: t2 :: rest_times ->
        (* Create opening point if this is first segment *)
        let acc' =
          if List.is_empty acc then
            ({ fraction_of_day = t1; price = p1 } : path_point) :: acc
          else acc
        in
        (* Generate bridge segment *)
        let segment =
          _generate_bridge_segment ~random_state ~start_price:p1 ~end_price:p2
            ~start_time:t1 ~end_time:t2 ~n_points:config.points_per_segment
            ~volatility_scale ~low_bound:bar.low_price
            ~high_bound:bar.high_price
        in
        (* Add ending waypoint *)
        let waypoint : path_point = { fraction_of_day = t2; price = p2 } in
        let acc'' = waypoint :: (List.rev segment @ acc') in
        generate_segments (p2 :: rest_prices) (t2 :: rest_times) acc''
    | _, _ -> List.rev acc
  in
  generate_segments waypoint_prices waypoint_times []

(** {1 Early Exit Optimization} *)

let rec can_fill (bar : price_bar) (side : side) (order_type : order_type) : bool =
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
      can_fill bar side (Stop stop_price)
      && can_fill bar side (Limit limit_price)
