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
