open Types

(** Macro market regime analyzer for the Weinstein methodology.

    Analyzes the "forest" (Weinstein Ch. 3, 8): multiple weighted indicators
    that determine whether to be aggressive, defensive, or neutral.

    Indicators and weights (configurable):
    - DJI/SPX stage (weight 3.0): Stage 1→2 or 2 = Bullish; Stage 3→4 or 4 =
      Bearish
    - A-D line divergence (weight 2.0)
    - Momentum index / A-D MA (weight 2.0)
    - New Highs minus New Lows (weight 1.5)
    - Global market consensus (weight 1.5)

    confidence = weighted_bullish / weighted_total > 0.65 → Bullish; < 0.35 →
    Bearish; otherwise Neutral.

    All functions are pure. *)

type indicator_reading = {
  name : string;
  signal : [ `Bullish | `Bearish | `Neutral ];
  weight : float;
  detail : string;
}
(** One indicator reading with its signal and weight. *)

type config = {
  stage_config : Stage.config;  (** Config for classifying the index stage. *)
  bullish_threshold : float;  (** confidence > this → Bullish. Default: 0.65. *)
  bearish_threshold : float;  (** confidence < this → Bearish. Default: 0.35. *)
  indicator_weights : indicator_weights;
}
(** Configuration for macro analysis. *)

and indicator_weights = {
  w_index_stage : float;  (** Weight for index stage analysis. Default: 3.0. *)
  w_ad_line : float;  (** Weight for A-D line divergence. Default: 2.0. *)
  w_momentum_index : float;
      (** Weight for momentum index (200-day MA of A-D). Default: 2.0. *)
  w_nh_nl : float;
      (** Weight for New Highs - New Lows divergence. Default: 1.5. *)
  w_global : float;  (** Weight for global market consensus. Default: 1.5. *)
}

val default_indicator_weights : indicator_weights
(** [default_indicator_weights] returns Weinstein's reference weights. *)

val default_config : config
(** [default_config] returns sensible defaults. *)

type ad_bar = {
  date : Core.Date.t;
  advancing : int;  (** Number of NYSE advancing issues. *)
  declining : int;  (** Number of NYSE declining issues. *)
}
(** A-D line data for one period. *)

type result = {
  index_stage : Stage.result;
      (** Stage classification of the primary index (DJI or SPX). *)
  indicators : indicator_reading list;
      (** All indicator readings with individual signals. *)
  trend : Weinstein_types.market_trend;  (** Composite market trend. *)
  confidence : float;  (** 0.0–1.0. Weighted fraction of bullish indicators. *)
  regime_changed : bool;  (** True if [trend] differs from [prior]'s trend. *)
  rationale : string list;
      (** Human-readable explanation of the composite signal. *)
}
(** Result of macro analysis. *)

val analyze :
  config:config ->
  index_bars:Daily_price.t list ->
  ad_bars:ad_bar list ->
  global_index_bars:(string * Daily_price.t list) list ->
  prior_stage:Weinstein_types.stage option ->
  prior:result option ->
  result
(** [analyze ~config ~index_bars ~ad_bars ~global_index_bars ~prior_stage
     ~prior] computes the current macro regime.

    @param index_bars
      Weekly bars for the primary index (DJI or SPX), chronological
      oldest-first.
    @param ad_bars Daily A-D data. May be empty if not available.
    @param global_index_bars
      Weekly bars for each global index, as [(name, bars)] pairs. May be empty.
    @param prior_stage Prior week's index stage (for transition detection).
    @param prior
      Prior week's macro result (for regime_changed detection). [None] on first
      call.

    Pure function. *)
