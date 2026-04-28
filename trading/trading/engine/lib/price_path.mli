(** Realistic intraday price path generation from OHLC bars.

    This module generates plausible intraday price paths from daily OHLC bars
    using Brownian bridge interpolation with auto-inferred parameters.

    Key features:
    - Non-uniform waypoint distribution (realistic intraday activity patterns)
    - Probabilistic path order (O→H→L→C vs O→L→H→C)
    - Brownian bridge interpolation between waypoints
    - Auto-inferred volatility from bar characteristics
    - Early exit optimization for unfillable orders *)

open Trading_base.Types
open Types

(** Distribution profile for intraday activity.

    Controls when during the day high/low prices are likely to occur:
    - UShaped: High activity at market open and close (realistic for many
      markets)
    - JShaped: Front-loaded activity (strong opening, fading volume)
    - ReverseJ: Back-loaded activity (building toward close)
    - Uniform: Equal probability throughout the day *)
type distribution_profile = UShaped | JShaped | ReverseJ | Uniform

type path_config = {
  profile : distribution_profile;
  total_points : int;
      (** Target number of points to generate across entire path.

          NOTE: The actual path length may differ from this value:
          - If total_points <= 4: Returns exactly 4 waypoints (O, H, L, C)
          - If total_points > 4: Returns approximately total_points ± a few
            points due to segment rounding and waypoint inclusion *)
  seed : int option;  (** Optional random seed for deterministic testing *)
  degrees_of_freedom : float;
      (** Degrees of freedom for Student's t noise distribution. Lower values
          (3-5) give heavier tails and more extreme moves. Higher values (>30)
          approach Gaussian behavior. *)
}
(** Configuration for path generation.

    If not specified, reasonable defaults are used:
    - profile: UShaped (realistic for most equity markets)
    - total_points: 390 (target resolution, actual may vary slightly)
    - seed: None (non-deterministic random path generation)
    - degrees_of_freedom: 4.0 (Student's t with moderately heavy tails)

    Points are distributed proportionally based on segment length to ensure
    uniform density regardless of waypoint timing. For example, a segment
    spanning 25% of the bar receives ~25% of total_points. *)

val default_config : path_config
(** Default path configuration: UShaped profile, 390 total points, no seed,
    df=4.0 *)

(** {1 Reusable Scratch Buffer}

    [Scratch.t] is a per-symbol mutable workspace for path generation. Allocate
    one buffer at panel-build time (one per loaded symbol) and pass it to
    [generate_path_into] on each tick — this avoids the per-tick allocation of
    intermediate float arrays / list cells inside the Brownian bridge sampler.

    The buffer is sized to hold any path up to a configured capacity.
    [generate_path_into] writes only into the prefix it needs and returns a
    fresh [intraday_path] of the appropriate length, so leftover state from
    earlier calls is invisible to callers.

    The buffer holds **only float prices** internally; the final
    [path_point list] is materialized once per call as the return value.

    Not thread-safe: a buffer must be owned by exactly one logical caller at a
    time. The intended use pattern (one buffer per loaded symbol, threaded
    through the simulator's per-tick loop) satisfies this naturally. *)
module Scratch : sig
  type t
  (** Mutable scratch buffer for path generation. *)

  val create : capacity:int -> t
  (** Create a scratch buffer that can hold paths up to [capacity] points
      (waypoints + interpolated points). Must be at least 4. *)

  val for_config : path_config -> t
  (** Convenience: create a scratch buffer sized for the given path config.
      Capacity is set to [config.total_points + slack] to absorb the small
      rounding overshoot from segment generation. *)

  val capacity : t -> int
  (** Return the buffer's capacity (max path length it can hold). *)
end

val generate_path : ?config:path_config -> price_bar -> intraday_path
(** Generate realistic intraday price path from OHLC bar.

    The path will: 1. Choose O→H→L→C or O→L→H→C probabilistically based on:
    - Direction (close vs open)
    - Volatility (higher volatility = more uncertain) 2. Place waypoints (O, H,
      L, C) at non-uniform times based on distribution profile 3. Interpolate
      between waypoints using Brownian bridge with Student's t noise

    Default configuration targets ~390 points (roughly 1-minute bars for 6.5hr
    day), though actual length may vary by a few points. Noise uses Student's
    t-distribution (df=4.0) for realistic fat tails in price moves.

    Special case: If config.total_points <= 4, returns exactly 4 waypoints
    without interpolation.

    Parameters are auto-inferred from the bar:
    - Volatility: derived from bar shape and magnitude
    - Path order probability: based on direction and volatility

    @param config Optional configuration (uses default_config if not provided)
    @param bar The OHLC bar to generate path from
    @return
      Intraday path with realistic microstructure. Length approximately matches
      config.total_points (default ~390), except when total_points <= 4 which
      returns exactly 4 waypoints.

    Allocates a fresh internal scratch buffer per call. For per-symbol hot-loop
    callers, prefer [generate_path_into] with a reused buffer. *)

val generate_path_into :
  scratch:Scratch.t -> ?config:path_config -> price_bar -> intraday_path
(** Same as [generate_path], but writes intermediate path samples into the given
    [scratch] buffer instead of allocating fresh internal storage.

    The output [intraday_path] is bit-identical to what [generate_path] would
    produce for the same [config] and [bar] — buffer reuse only affects
    allocation, not arithmetic.

    @raise Invalid_argument
      if [scratch] is too small to hold the path implied by [config]. *)

val might_fill : price_bar -> side -> order_type -> bool
(** Check if an order could possibly fill given OHLC bounds.

    This is an early exit optimization - if the OHLC bounds show that price
    never reaches the trigger level, we can skip path generation.

    Examples:
    - Buy limit at 100 when low=105: cannot fill
    - Buy stop at 110 when high=105: cannot trigger
    - Sell limit at 100 when high=95: cannot fill

    @param bar The OHLC bar
    @param side Order side (Buy or Sell)
    @param order_type The order type with price parameters
    @return true if order could possibly fill, false if impossible *)
