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

type callbacks = {
  stage : Stage.callbacks;
      (** Nested Stage callbacks for classifying the sector index itself. Built
          via {!Stage.callbacks_from_bars} or a panel adapter. *)
  rs : Rs.callbacks;
      (** Nested RS callbacks for the sector-vs-benchmark relative strength.
          Built via {!Rs.callbacks_from_bars} or a panel adapter. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}.

    Sector analysis itself does not read bar fields directly — it only delegates
    to {!Stage.classify_with_callbacks} and {!Rs.analyze_with_callbacks}. The
    bundle therefore wraps just those two nested callback records. The
    constituent-breadth and confidence computations operate on the
    already-computed [constituent_analyses : Stock_analysis.t list] and need no
    callbacks. *)

val callbacks_from_bars :
  config:config ->
  sector_bars:Daily_price.t list ->
  benchmark_bars:Daily_price.t list ->
  callbacks
(** [callbacks_from_bars ~config ~sector_bars ~benchmark_bars] builds a
    {!callbacks} record by delegating to {!Stage.callbacks_from_bars} (using
    [sector_bars]) and {!Rs.callbacks_from_bars} (using [stock_bars=sector_bars]
    and [benchmark_bars]).

    Used internally by {!analyze}; exposed for callers (e.g. tests or future
    panel adapters that already hold both bar lists) that want to delegate to
    {!analyze_with_callbacks} via the same plumbing. *)

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

    Pure function.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It builds a {!callbacks} record via {!callbacks_from_bars} and delegates.
    Behaviour is bit-identical to the callback API for the same underlying
    [(sector_bars, benchmark_bars)] input. *)

val analyze_with_callbacks :
  config:config ->
  sector_name:string ->
  callbacks:callbacks ->
  constituent_analyses:Stock_analysis.t list ->
  prior_stage:Weinstein_types.stage option ->
  result
(** [analyze_with_callbacks ~config ~sector_name ~callbacks
     ~constituent_analyses ~prior_stage] is the indicator-callback shape of
    {!analyze}. Used by panel-backed callers that read indicator values via
    panel views rather than walking [Daily_price.t list]s for the sector's Stage
    / RS sub-analyses.

    @param config Same configuration as {!analyze}.
    @param sector_name Same as {!analyze}.
    @param callbacks
      Bundle of indicator callbacks. [callbacks.stage] backs
      {!Stage.classify_with_callbacks} for the sector index; [callbacks.rs]
      backs {!Rs.analyze_with_callbacks} for sector-vs-benchmark RS.
    @param constituent_analyses Same as {!analyze}.
    @param prior_stage Same as {!analyze}.

    Pure function: same callback outputs and same [constituent_analyses] /
    [prior_stage] always produce the same [result]. The wrapper {!analyze}
    guarantees byte-identical results for any [(sector_bars, benchmark_bars)]
    input by constructing callbacks that index the same pre-computed series the
    bar-list path computes internally. *)

val sector_context_of : result -> Screener.sector_context
(** [sector_context_of result] converts a sector [result] into the
    [Screener.sector_context] value consumed by the screener. *)
