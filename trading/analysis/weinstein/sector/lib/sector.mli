open Types

(** Sector health analyzer for the Weinstein methodology.

    Applies the same stage analysis to sector indices that we apply to
    individual stocks. The sector rating feeds into the screener's second- level
    filter.

    Weinstein rule (Ch. 3): favorable chart in bullish group → 50-75% advance;
    same chart in bearish group → 5-10% gain.

    All functions are pure. *)

type config = {
  stage_config : Stage.config;
      (** Stage classifier config shared with stock analysis. *)
  rs_config : Rs.config;
      (** RS config for computing sector RS vs the broad market. *)
  strong_confidence : float;
      (** Minimum confidence for rating Strong. Combines stage and RS. Default:
          0.6. *)
  weak_confidence : float;
      (** Maximum confidence for rating Weak. Default: 0.4. *)
  stage_weight : float;
      (** Weight of stage score in overall confidence (0–1). Default: 0.40. *)
  rs_weight : float;
      (** Weight of RS score in overall confidence (0–1). Default: 0.35. *)
  constituent_weight : float;
      (** Weight of constituent breadth score in overall confidence (0–1).
          Default: 0.25. *)
}
(** Configuration for sector analysis.

    [stage_weight + rs_weight + constituent_weight] should sum to 1.0 so that
    the composite confidence stays in the [0.0, 1.0] range. *)

val default_config : config
(** [default_config] returns sensible defaults. *)

type result = {
  sector_name : string;
  stage : Stage.result;  (** Stage classification of the sector index. *)
  rs : Rs.result option;  (** RS of the sector vs the broad market. *)
  rating : Screener.sector_rating;
      (** Strong / Neutral / Weak composite rating. *)
  constituent_count : int;  (** Number of constituent stocks analysed. *)
  bullish_constituent_pct : float;
      (** Fraction of constituents in Stage 2 (0.0–1.0). *)
  rationale : string list;
}
(** Full sector analysis result. *)

val analyze :
  config:config ->
  sector_name:string ->
  sector_bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  constituent_analyses:Stock_analysis.t list ->
  prior_stage:Weinstein_types.stage option ->
  result
(** [analyze ~config ~sector_name ~sector_bars ~benchmark_bars
     ~constituent_analyses] classifies a sector.

    @param sector_bars Weekly bars for the sector index itself.
    @param benchmark_bars Weekly bars for the broad market benchmark.
    @param constituent_analyses
      Pre-computed per-stock analysis for all stocks in this sector. Used to
      compute [bullish_constituent_pct].
    @param prior_stage Previous week's sector stage for transition tracking.

    Pure function. *)

val sector_context_of : result -> Screener.sector_context
(** [sector_context_of result] converts a sector [result] into the
    [Screener.sector_context] value consumed by the screener. *)
