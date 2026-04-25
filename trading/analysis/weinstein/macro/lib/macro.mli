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
[@@deriving sexp]
(** One indicator reading with its signal and weight. *)

type indicator_weights = {
  w_index_stage : float;  (** Weight for index stage analysis. Default: 3.0. *)
  w_ad_line : float;  (** Weight for A-D line divergence. Default: 2.0. *)
  w_momentum_index : float;
      (** Weight for momentum index (200-day MA of A-D). Default: 2.0. *)
  w_nh_nl : float;
      (** Weight for New Highs - New Lows divergence. Default: 1.5. *)
  w_global : float;  (** Weight for global market consensus. Default: 1.5. *)
}
[@@deriving sexp]

type indicator_thresholds = {
  ad_line_lookback : int;
      (** Lookback for A-D divergence comparison (~6 months). Default: 26. *)
  momentum_period : int;  (** MA period for the momentum index. Default: 200. *)
  nh_nl_lookback : int;
      (** Lookback for NH-NL proxy comparison (~3 months). Default: 13. *)
  nh_nl_up_threshold : float;
      (** Price ratio above which NH-NL proxy is bullish. Default: 1.02. *)
  nh_nl_down_threshold : float;
      (** Price ratio below which NH-NL proxy is bearish. Default: 0.98. *)
  ad_min_bars : int;
      (** Minimum bars required to compute A-D divergence. Default: 4. *)
  nh_nl_min_bars : int;
      (** Minimum index bars required to compute NH-NL proxy. Default: 10. *)
  global_consensus_threshold : float;
      (** Fraction of markets for a global consensus signal. Default: 0.6. *)
}
[@@deriving sexp]

type config = {
  stage_config : Stage.config;  (** Config for classifying the index stage. *)
  bullish_threshold : float;  (** confidence > this → Bullish. Default: 0.65. *)
  bearish_threshold : float;  (** confidence < this → Bearish. Default: 0.35. *)
  indicator_weights : indicator_weights;
  indicator_thresholds : indicator_thresholds;
}
[@@deriving sexp]
(** Configuration for macro analysis. *)

val default_indicator_weights : indicator_weights
(** [default_indicator_weights] returns Weinstein's reference weights. *)

val default_indicator_thresholds : indicator_thresholds
(** [default_indicator_thresholds] returns Weinstein's reference thresholds. *)

val default_config : config
(** [default_config] returns sensible defaults. *)

type ad_bar = {
  date : Core.Date.t;
  advancing : int;  (** Number of NYSE advancing issues in the period. *)
  declining : int;  (** Number of NYSE declining issues in the period. *)
}
(** A-D line data for one period.

    {b Cadence contract}: {!analyze} interprets [ad_bar list] as {b weekly} data
    so that its bar-count lookback parameters (e.g. [ad_line_lookback],
    [momentum_period]) are unit-consistent with [index_bars]. Loaders such as
    [Ad_bars.Unicorn] return daily bars; callers must aggregate them with
    {!Ad_bars_aggregation.daily_to_weekly} before passing them into [analyze].
*)

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
    @param ad_bars
      {b Weekly}-cadence A-D breadth data, chronological oldest-first. Each bar
      holds the week's total advancing and declining issue counts. May be empty
      if breadth data is not available. Callers that start from a daily feed
      must aggregate first via {!Ad_bars_aggregation.daily_to_weekly}.
    @param global_index_bars
      Weekly bars for each global index, as [(name, bars)] pairs. May be empty.
    @param prior_stage Prior week's index stage (for transition detection).
    @param prior
      Prior week's macro result (for regime_changed detection). [None] on first
      call.

    Pure function.

    Implementation note: this is a thin wrapper over {!analyze_with_callbacks}.
    It builds a {!callbacks} record via {!callbacks_from_bars} (which
    precomputes the cumulative A-D line, the momentum-MA scalar, and
    per-global-index {!Stage.callbacks}) and threads it through. Behaviour is
    bit-identical to the callback API for the same underlying bar lists. *)

type callbacks = {
  index_stage : Stage.callbacks;
      (** Stage callbacks for the primary index. Threaded into
          {!Stage.classify_with_callbacks} to compute [index_stage]. *)
  get_index_close : week_offset:int -> float option;
      (** Primary-index adjusted close at [week_offset] weeks back (offset 0 =
          current week). Used by the A-D divergence and NH-NL proxy comparisons
          (which read close at offset 0 and at the lookback offset). [None] = no
          bar at that offset (warmup or out of range). *)
  get_cumulative_ad : week_offset:int -> float option;
      (** Cumulative A-D line value at [week_offset] weeks back. The cumulative
          series is [sum_{i <= k} (advancing_i - declining_i)] stored as a float
          for the panel-shaped layout (the bar-list constructor folds the same
          int sum and converts at the boundary). [None] = no A-D bar at that
          offset. *)
  get_ad_momentum_ma : week_offset:int -> float option;
      (** A-D momentum MA at [week_offset] weeks back. The MA is the simple mean
          of the most recent [min momentum_period n] A-D net values (advancing −
          declining) ending at [week_offset]. Only [week_offset:0] is consumed
          by {!analyze_with_callbacks}; higher offsets are permitted to return
          [None]. *)
  global_index_stages : (string * Stage.callbacks) list;
      (** Per-global-index Stage callbacks, as [(name, callbacks)] pairs. The
          list shape mirrors [global_index_bars] in the bar-list API:
          {!analyze_with_callbacks} iterates each entry, classifies its stage
          via {!Stage.classify_with_callbacks}, and aggregates the consensus
          signal. May be empty when no global breadth data is available. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}.

    Macro analysis reads:
    - The primary index Stage (via the nested {!index_stage} callbacks).
    - Two index-close samples (recent + lookback) for A-D divergence and the
      NH-NL proxy.
    - Two cumulative A-D samples (recent + lookback) for the divergence check,
      plus the depth of the cumulative series (walked by probing
      {!get_cumulative_ad} until [None]).
    - The momentum MA scalar at offset 0.
    - One Stage classification per entry in {!global_index_stages}. *)

val callbacks_from_bars :
  config:config ->
  index_bars:Daily_price.t list ->
  ad_bars:ad_bar list ->
  global_index_bars:(string * Daily_price.t list) list ->
  callbacks
(** [callbacks_from_bars ~config ~index_bars ~ad_bars ~global_index_bars] builds
    a {!callbacks} record:

    - {!index_stage} delegates to {!Stage.callbacks_from_bars} over
      [index_bars].
    - {!get_index_close} reads [index_bars] adjusted_close at the matching
      offset.
    - {!get_cumulative_ad} indexes a precomputed cumulative-A-D float array
      built by folding [ad_bars] once.
    - {!get_ad_momentum_ma} returns the precomputed scalar MA at offset 0
      ([None] otherwise, and [None] when [ad_bars] is empty).
    - {!global_index_stages} pairs each [(name, bars)] in [global_index_bars]
      with [Stage.callbacks_from_bars ~config:config.stage_config ~bars].

    Used internally by {!analyze}; exposed so that callers (e.g. tests or future
    panel-backed paths) can build the bundle the same way the wrapper does. *)

val analyze_with_callbacks :
  config:config ->
  callbacks:callbacks ->
  prior_stage:Weinstein_types.stage option ->
  prior:result option ->
  result
(** [analyze_with_callbacks ~config ~callbacks ~prior_stage ~prior] is the
    indicator-callback shape of {!analyze}. Used by panel-backed callers that
    read indicator values via the strategy's panel views rather than walking bar
    lists.

    @param config Same configuration as {!analyze}.
    @param callbacks
      Bundle of indicator callbacks. See the {!callbacks} record for the
      contract on each closure.
    @param prior_stage Same as {!analyze}.
    @param prior Same as {!analyze}.

    Pure function: same callback outputs and inputs always produce the same
    [result]. The wrapper {!analyze} guarantees byte-identical results for any
    bar-list inputs by constructing callbacks that index the same precomputed
    series the bar-list path used to walk inline. *)
