open Types

(** Overhead resistance mapping for Weinstein breakout grading.

    Implements Weinstein's grading system (Ch. 4):
    - A+ (Virgin territory): stock has never traded above this price, or hasn't
      in [virgin_lookback_bars] bars. No trapped sellers.
    - A (Clean): no significant resistance in the [chart_lookback_bars] window.
    - B (Moderate): some resistance overhead but not dense.
    - C (Heavy): dense trading zone just above breakout. Stock will use up
      buying power getting through.

    Config fields are expressed in bars (not years or weeks) so the module works
    at any time granularity — weekly, monthly, or other cadences. The Weinstein
    defaults assume weekly bars: [chart_lookback_bars = 130] (~2.5 yr) and
    [virgin_lookback_bars = 520] (~10 yr).

    Older resistance is less potent. Prior trading ranges become ceilings.

    All functions are pure. *)

type config = {
  chart_lookback_bars : int;
      (** Number of bars to analyse for zone density. Bars beyond this tail are
          excluded from zone counts. Default: 130 (~2.5 years of weekly bars).
      *)
  virgin_lookback_bars : int;
      (** If no bar in this tail had a high above [breakout_price], classify as
          [Virgin_territory]. Must be ≥ [chart_lookback_bars]. Default: 520 (~10
          years of weekly bars). *)
  congestion_band_pct : float;
      (** Price band width as a fraction of [breakout_price]. Bars are bucketed
          into bands of this width starting from [breakout_price]. Default: 0.05
          (5%). *)
  heavy_resistance_bars : int;
      (** Minimum bars in a zone to classify as [Heavy_resistance]. Default: 8.
      *)
  moderate_resistance_bars : int;
      (** Minimum bars in a zone to classify as [Moderate_resistance] (below
          heavy threshold). Default: 3. *)
}
(** Configuration for resistance analysis. All counts are in bars so callers can
    tune for any time granularity without converting to years or weeks. *)

val default_config : config
(** Sensible defaults for weekly bars:
    [{chart_lookback_bars=130; virgin_lookback_bars=520;
     congestion_band_pct=0.05; heavy_resistance_bars=8;
     moderate_resistance_bars=3}]. *)

type resistance_zone = {
  price_low : float;
  price_high : float;
  weeks_of_trading : int;
      (** Number of bars in this zone (name kept as "weeks" for readability when
          using weekly data). *)
  age_years : float;
      (** Fractional years since the most recent bar in this zone. Older = less
          potent. *)
}
(** A price band with accumulated prior trading activity. *)

type result = {
  quality : Weinstein_types.overhead_quality;
      (** Graded quality of overhead resistance. *)
  breakout_price : float;  (** The price level being analysed. *)
  zones_above : resistance_zone list;
      (** Resistance zones above [breakout_price], sorted by price ascending. *)
  nearest_zone : resistance_zone option;
      (** The lowest zone above [breakout_price], if any. *)
}
(** Result of resistance analysis at a given breakout price. *)

type callbacks = {
  get_high : bar_offset:int -> float option;
      (** Bar high at [bar_offset] bars back from the newest bar. [bar_offset:0]
          is the newest bar; offsets past available depth return [None]. *)
  get_low : bar_offset:int -> float option;
      (** Bar low at [bar_offset] bars back. *)
  get_date : bar_offset:int -> Core.Date.t option;
      (** Bar date at [bar_offset] bars back. Used for [age_years]. *)
  n_bars : int;
      (** Total number of bars in the underlying source — i.e. the largest
          [bar_offset] for which any of the above closures returns [Some]. Used
          by the analyzer to bound the virgin / chart window walks. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}. The
    panel-backed adapter and {!callbacks_from_bars} both produce this shape. *)

val callbacks_from_bars : bars:Daily_price.t list -> callbacks
(** [callbacks_from_bars ~bars] precomputes [bar_offset]-indexed closures over
    [bars] (newest bar at offset 0). Constructor used internally by {!analyze};
    exposed for tests / panel adapters that already hold a [Daily_price.t list].
*)

val analyze :
  config:config ->
  bars:Daily_price.t list ->
  breakout_price:float ->
  as_of_date:Core.Date.t ->
  result
(** [analyze ~config ~bars ~breakout_price ~as_of_date] maps overhead resistance
    above [breakout_price].

    @param bars
      Price bars in chronological order (oldest first). The function uses the
      last [virgin_lookback_bars] for the virgin check and the last
      [chart_lookback_bars] for zone density analysis.
    @param breakout_price The price level to grade resistance above.
    @param as_of_date Reference date used to compute [age_years] for each zone.

    Pure function: same inputs always produce the same output.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It builds a {!callbacks} record via {!callbacks_from_bars} and delegates.
    Behaviour is bit-identical to the callback API for the same underlying
    [bars]. *)

val analyze_with_callbacks :
  config:config ->
  callbacks:callbacks ->
  breakout_price:float ->
  as_of_date:Core.Date.t ->
  result
(** [analyze_with_callbacks ~config ~callbacks ~breakout_price ~as_of_date] is
    the indicator-callback shape of {!analyze}. Used by panel-backed callers
    that read bar fields via per-cell closures rather than walking a
    {!Daily_price.t list}.

    Walks two bar windows back from the newest bar (offset 0):
    - the [config.virgin_lookback_bars] tail for the virgin-territory check,
    - the [config.chart_lookback_bars] tail for zone density analysis.

    The walks read [callbacks.get_high], [callbacks.get_low], and
    [callbacks.get_date] at offsets [0 .. min (n_bars - 1) (lookback - 1)]. The
    smaller of [n_bars] and the configured lookback bounds the walk; offsets
    past [n_bars] are treated as missing.

    Pure function: same callback outputs always produce the same result. *)
