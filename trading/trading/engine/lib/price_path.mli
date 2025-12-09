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
  total_points : int;  (** Total points to generate across entire path *)
  seed : int option;  (** Optional random seed for deterministic testing *)
  degrees_of_freedom : float;
      (** Degrees of freedom for Student's t noise distribution. Lower values
          (3-5) give heavier tails and more extreme moves. Higher values (>30)
          approach Gaussian behavior. *)
}
(** Configuration for path generation.

    If not specified, reasonable defaults are used:
    - profile: UShaped (realistic for most equity markets)
    - total_points: 390 (distributed proportionally across segments)
    - seed: None (non-deterministic random path generation)
    - degrees_of_freedom: 4.0 (Student's t with moderately heavy tails)

    Points are distributed proportionally based on segment length to ensure
    uniform density regardless of waypoint timing. For example, a segment
    spanning 25% of the bar receives 25% of total_points. *)

val default_config : path_config
(** Default path configuration: UShaped profile, 390 total points, no seed,
    df=4.0 *)

val generate_path : ?config:path_config -> price_bar -> intraday_path
(** Generate realistic intraday price path from OHLC bar.

    The path will: 1. Choose O→H→L→C or O→L→H→C probabilistically based on:
    - Direction (close vs open)
    - Volatility (higher volatility = more uncertain) 2. Place waypoints (O, H,
      L, C) at non-uniform times based on distribution profile 3. Interpolate
      between waypoints using Brownian bridge with Student's t noise

    Default configuration generates ~390 points (roughly 1-minute bars for 6.5hr
    day). Noise uses Student's t-distribution (df=4.0) for realistic fat tails
    in price moves.

    Parameters are auto-inferred from the bar:
    - Volatility: derived from bar shape and magnitude
    - Path order probability: based on direction and volatility

    @param config Optional configuration (uses default_config if not provided)
    @param bar The OHLC bar to generate path from
    @return Intraday path with realistic microstructure (typically ~390 points)
*)

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
