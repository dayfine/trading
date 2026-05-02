open Types

(** Moving average type for the stage classifier.

    [Sma] is a simple moving average; [Wma] is a linearly weighted MA (gives
    more weight to recent bars); [Ema] is an exponential MA (via ta-lib).
    Weinstein's book specifies a plain 30-week SMA, but [Wma] is a common
    practical substitute; [Ema] is available for parameter-tuning experiments.
*)
type ma_type = Sma | Wma | Ema [@@deriving show, eq, sexp]

(** Method for determining MA direction (Rising/Flat/Declining).

    [MaSlope] — current behavior (default): compare [MA_now] to
    [MA_lookback_ago] and classify by slope_pct vs threshold.

    [Segmentation] — feature-flagged alternative (M5.4 E2): runs piecewise
    linear regression over the MA series via
    {!Trend.Segmentation.segment_by_trends} and uses the most recent segment's
    trend. Reduces false direction flips from short-term noise. The
    [Trend.Trend_type.t] result maps as: [Increasing → Rising],
    [Decreasing → Declining], [Flat | Unknown → Flat]. *)
type stage_method = MaSlope | Segmentation [@@deriving show, eq, sexp]

(** Stage classifier for the Weinstein methodology.

    Classifies a stock into one of four stages based on weekly price bars and
    the relationship between price and its moving average.

    All functions are pure: same inputs always produce the same output. *)

type config = {
  ma_period : int;  (** Number of weeks for the moving average. Default: 30. *)
  ma_type : ma_type;
      (** Which moving average to use. Default: [Wma] (linearly weighted). *)
  slope_threshold : float;
      (** Minimum |slope_pct| to classify MA as Rising or Declining. Below this
          is Flat. Default: 0.005 (0.5% per [slope_lookback] weeks). *)
  slope_lookback : int;
      (** How many weeks back to measure MA slope. Default: 4. *)
  confirm_weeks : int;
      (** Number of recent weeks used to determine whether price is consistently
          above or below the MA. Default: 6. *)
  late_stage2_decel : float;
      (** MA slope deceleration threshold to flag late Stage 2 warning. A
          reading this much below the recent peak slope triggers [late=true].
          Default: 0.5 (50% deceleration from recent peak). *)
  stage_method : stage_method;
      (** Method for determining MA direction. Default: [MaSlope] (current
          behavior). [Segmentation] enables the feature-flagged piecewise linear
          regression path (see {!stage_method}). *)
}
[@@deriving sexp]
(** Configuration for stage classification. All thresholds are configurable to
    enable parameter tuning via backtesting. *)

val default_config : config
(** [default_config] provides sensible defaults for all parameters. *)

type result = {
  stage : Weinstein_types.stage;  (** The classified stage. *)
  ma_value : float;  (** Current MA value (last computed data point). *)
  ma_direction : Weinstein_types.ma_direction;  (** Direction of the MA. *)
  ma_slope_pct : float;
      (** Slope as a fraction: (MA_now - MA_lookback_ago) / MA_lookback_ago.
          Positive = rising, negative = declining. *)
  transition : (Weinstein_types.stage * Weinstein_types.stage) option;
      (** If the stage changed vs [prior_stage], this is [Some (from, to)];
          otherwise [None]. *)
  above_ma_count : int;
      (** Number of the last [confirm_weeks] bars where close > MA. *)
}
(** Result of a single stage classification call. *)

val classify :
  config:config ->
  bars:Daily_price.t list ->
  prior_stage:Weinstein_types.stage option ->
  result
(** [classify ~config ~bars ~prior_stage] classifies the current stage.

    @param config Classification parameters.
    @param bars
      Weekly price bars in chronological order (oldest first). Must contain at
      least [config.ma_period] bars for a valid result. Fewer bars returns the
      most recent inferable stage or [Stage1].
    @param prior_stage
      The stage from the previous week's classification. Used to disambiguate a
      flat MA (Stage 1 vs Stage 3). [None] on the first call — the classifier
      uses the long-term MA trend as a heuristic instead.

    Pure function: same [bars] and [prior_stage] always produce the same
    [result].

    Implementation note: this is a thin wrapper over {!classify_with_callbacks}.
    It precomputes the full MA series from [bars] and builds
    [get_ma]/[get_close] closures that index the resulting arrays. Behaviour is
    bit-identical to the callback API for the same underlying bars. *)

type callbacks = {
  get_ma : week_offset:int -> float option;
      (** MA value at [week_offset] weeks back (offset 0 = current week). *)
  get_close : week_offset:int -> float option;
      (** Bar adjusted close at [week_offset] weeks back. *)
}
(** Bundle of indicator callbacks consumed by {!classify_with_callbacks}.

    Higher-level callback APIs (e.g. {!Stock_analysis.analyze_with_callbacks})
    embed this record so they can thread Stage's callbacks through one nested
    bundle rather than re-exposing the individual closures at every layer. *)

val callbacks_from_bars :
  config:config -> bars:Types.Daily_price.t list -> callbacks
(** [callbacks_from_bars ~config ~bars] precomputes the MA series from [bars]
    and returns a {!callbacks} record whose closures index the resulting arrays.
    The constructor [{ classify }] uses internally; exposed for callers that
    already hold a [bars] list and want to delegate to
    {!classify_with_callbacks} via the same plumbing. Behaviour matches
    {!classify}: an empty MA series produces a [get_ma ~week_offset:0 = None],
    which the callback entry handles by returning the Stage1 default result. *)

val classify_with_callbacks :
  config:config ->
  get_ma:(week_offset:int -> float option) ->
  get_close:(week_offset:int -> float option) ->
  prior_stage:Weinstein_types.stage option ->
  result
(** [classify_with_callbacks ~config ~get_ma ~get_close ~prior_stage] is the
    indicator-callback shape of {!classify}. Used by panel-backed callers that
    read indicator values via {!Strategy_interface.get_indicator_fn} rather than
    walking a [Daily_price.t list].

    @param config Classification parameters (same as {!classify}).
    @param get_ma
      Returns the configured moving-average value at [week_offset] weeks back
      from the current week ([week_offset:0] = current week, [1] = previous,
      etc.). Returns [None] for offsets where the MA is not yet available
      (warmup) or out of range. [get_ma ~week_offset:0] returning [None]
      triggers the Stage1 default-result early-return (matches the "empty MA
      series" branch in {!classify}).
    @param get_close
      Returns the bar close (adjusted for splits/dividends in panel-backed
      callers) at [week_offset] weeks back. Used by the [above_ma_count]
      computation to determine whether price is above the MA. [None] = no bar at
      that offset (treated as not-above and stops the count walk).
    @param prior_stage Same as {!classify}.

    Pure function: same callback outputs and [prior_stage] always produce the
    same [result]. The wrapper {!classify} guarantees byte-identical results for
    any [bars] input by constructing callbacks that index the same pre-computed
    MA series.

    Walk-back semantics for the lookback MA: when
    [get_ma ~week_offset:slope_lookback] returns [None] (not enough MA history),
    this function walks down through smaller offsets
    [slope_lookback - 1, slope_lookback - 2, ...] until it finds a defined MA.
    This mirrors the [List.hd_exn ma_series] fallback in {!classify} when
    [n <= slope_lookback]. *)

(** {2 Followup / Known Improvements}

    {3 Segmentation-based MA direction}

    Wired as of M5.4 E2 behind the [stage_method = Segmentation] feature flag
    (default remains [MaSlope] for byte-identical legacy behavior). The
    [Segmentation] path runs piecewise linear regression over the MA series via
    {!Trend.Segmentation.segment_by_trends} and uses the most recent segment's
    trend. A/B sweep is tracked as a follow-up experiment.

    {3 Incremental [classify_step]}

    [classify] recomputes the full MA series from all [bars] on every call. For
    the simulation loop (where the screener runs weekly and adds one bar at a
    time) this is O(n) per step. When simulation performance becomes a
    bottleneck, add:

    {[
      val classify_step :
        config:config -> prev_result:result -> new_bar:Daily_price.t -> result
    ]}

    [classify_step] would maintain an incremental MA state (e.g. a sliding
    window of the last [ma_period] closes) and update the MA value with the
    single new bar in O(1), reusing the rest of [classify]'s logic. The existing
    [classify] stays as the "cold-start" entry point.

    {3 State machine functor for [_classify_new_stage]}

    [_classify_new_stage] encodes the valid transitions between Stage 1–4. A
    well-defined state machine functor would make the states, guards, and
    transitions explicit (e.g. Stage1 → Stage2 is valid; Stage1 → Stage4 is
    not). This would also benefit the Weinstein stop state machine in
    [weinstein/portfolio_risk], which tracks the same lifecycle. Consider a
    shared [Stage_machine] functor if the two state machines diverge enough to
    need independent parameterisation.

    {3 Shared MA slope utility}

    [_compute_ma_slope] duplicates a pattern also present in the RS analyser
    (slope of the RS moving average) and likely the macro analyser (index MA
    slope). Consider extracting a small [Ma_utils] module under
    [analysis/technical/indicators/] with a [slope] function:

    {[
      val slope :
        lookback:int ->
        threshold:float ->
        (Date.t * float) list ->
        ma_direction * float
    ]}

    This would eliminate the per-module slope implementations and give a single
    tested home for the two-point slope classification logic. *)
