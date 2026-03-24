open Types

(** Overhead resistance mapping for Weinstein breakout grading.

    Implements Weinstein's grading system (Ch. 4):
    - A+ (Virgin territory): stock has never traded above this price, or hasn't
      in [virgin_years] years. No trapped sellers.
    - A (Clean): no significant resistance on the [chart_years]-year chart.
    - B (Moderate): some resistance overhead but not dense.
    - C (Heavy): dense trading zone just above breakout. Stock will use up
      buying power getting through.

    Older resistance is less potent. Prior trading ranges become ceilings.

    All functions are pure. *)

type config = {
  chart_years : float;
      (** How many years of history to analyse for resistance. Default: 2.5
          (Weinstein's "2.5-year chart"). *)
  virgin_years : float;
      (** If no trading above the breakout level for this many years, classify
          as virgin territory. Default: 10.0. *)
  congestion_band_pct : float;
      (** Price band (as fraction of breakout price) within which prior bars
          count as "resistance". Default: 0.05 (5%). *)
  heavy_resistance_weeks : int;
      (** Minimum number of weeks with prior trading in the congestion zone to
          classify as Heavy resistance. Default: 8. *)
  moderate_resistance_weeks : int;
      (** Minimum weeks for Moderate (< heavy threshold). Default: 3. *)
}
(** Configuration for resistance analysis. *)

val default_config : config
(** [default_config] returns Weinstein's recommended defaults. *)

type resistance_zone = {
  price_low : float;
  price_high : float;
  weeks_of_trading : int;
      (** How many weekly bars had trading within this zone. *)
  age_years : float;
      (** How old the most recent bar in this zone is. Older = less potent. *)
}
(** A price zone with accumulated trading activity. *)

type result = {
  quality : Weinstein_types.overhead_quality;
      (** Graded quality of overhead resistance. *)
  breakout_price : float;  (** The price level being analysed. *)
  zones_above : resistance_zone list;
      (** All resistance zones above [breakout_price] (sorted by price). *)
  nearest_zone : resistance_zone option;
      (** The first resistance zone above [breakout_price], if any. *)
}
(** Result of resistance analysis at a given breakout price. *)

val analyze :
  config:config ->
  bars:Daily_price.t list ->
  breakout_price:float ->
  as_of_date:Core.Date.t ->
  result
(** [analyze ~config ~bars ~breakout_price ~as_of_date] maps overhead resistance
    above [breakout_price].

    @param config Resistance parameters.
    @param bars
      Historical weekly price bars (chronological, oldest first). Typically
      covers [chart_years] of history.
    @param breakout_price The price level to grade resistance above.
    @param as_of_date The reference date for computing zone age.

    Pure function: same inputs → same output. *)
