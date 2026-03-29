open Types

(** Stage classifier for the Weinstein methodology.

    Classifies a stock into one of four stages based on weekly price bars and
    the relationship between price and its moving average.

    All functions are pure: same inputs always produce the same output. *)

type config = {
  ma_period : int;  (** Number of weeks for the moving average. Default: 30. *)
  ma_weighted : bool;
      (** If true, use linearly weighted MA; otherwise simple MA. Default: true.
      *)
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
}
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
    [result]. *)

(** {2 Followup / Known Improvements}

    {3 Segmentation-based MA direction}

    MA direction is currently determined by a simple two-point slope comparison
    ([MA_now] vs [MA_lookback_ago]). A more robust alternative would use the
    piecewise linear segmentation in
    [analysis/technical/trend/lib/segmentation.ml]: fit a regression to the MA
    series over a rolling window and classify the most recent segment's slope as
    Rising/Flat/Declining. This would reduce false direction flips from
    short-term noise and better identify the transition out of Stage 1
    base-building periods.

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
