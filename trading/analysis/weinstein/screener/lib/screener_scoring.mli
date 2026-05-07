(** Scoring types, signal helpers, and price utilities for the Weinstein cascade
    screener.

    All functions are pure. Extracted from [Screener] to keep the cascade
    coordinator within the 500-line linter cap. Callers outside the screener
    library should reference these types through {!Screener}, which re-exports
    this module via [include]. *)

(** Sector health rating used by the screener gate. *)
type sector_rating = Strong | Neutral | Weak [@@deriving show, eq, sexp]

type sector_context = {
  sector_name : string;
  rating : sector_rating;
  stage : Weinstein_types.stage;
}
[@@deriving sexp]
(** Minimal sector context the screener needs per stock. *)

type scoring_weights = {
  w_stage2_breakout : int;
      (** Weight for a clean Stage2 transition from Stage1. Default: 30. *)
  w_strong_volume : int;
      (** Weight for Strong volume confirmation. Default: 20. *)
  w_adequate_volume : int;
      (** Weight for Adequate volume confirmation. Default: 10. *)
  w_positive_rs : int;
      (** Weight for positive RS trend (Positive_rising or Bullish_crossover).
          Default: 20. *)
  w_bullish_rs_crossover : int;
      (** Additional weight for RS crossing from negative to positive. Default:
          10. *)
  w_clean_resistance : int;
      (** Weight for Virgin_territory or Clean overhead. Default: 15. *)
  w_sector_strong : int;  (** Weight bonus for a Strong sector. Default: 10. *)
  w_late_stage2_penalty : int;
      (** Negative weight for late Stage2 flag. Default: -15. *)
}
[@@deriving sexp]
(** Scoring weights for each positive signal. All are configurable. *)

val default_scoring_weights : scoring_weights
(** [default_scoring_weights] provides the reference weights. *)

type grade_thresholds = { a_plus : int; a : int; b : int; c : int; d : int }
[@@deriving sexp]
(** Score cutoffs for each grade. All are configurable. *)

val default_grade_thresholds : grade_thresholds
(** [default_grade_thresholds] provides the reference thresholds. *)

val score_long :
  weights:scoring_weights ->
  sector:sector_context ->
  Stock_analysis.t ->
  int * string list
(** [score_long ~weights ~sector a] computes the long-side weighted score and
    rationale list for [a]. *)

val score_short :
  weights:scoring_weights ->
  sector:sector_context ->
  Stock_analysis.t ->
  int * string list
(** [score_short ~weights ~sector a] computes the short-side weighted score and
    rationale list for [a]. *)

val grade_of_score : thresholds:grade_thresholds -> int -> Weinstein_types.grade
(** [grade_of_score ~thresholds score] converts a numeric score to a grade
    letter using the configured cutoffs. *)

val suggested_entry : entry_buffer_pct:float -> float -> float
(** [suggested_entry ~entry_buffer_pct breakout_price] returns the suggested
    entry price: breakout price plus a small configurable buffer, rounded to the
    nearest cent. *)

val suggested_stop : initial_stop_pct:float -> float -> float
(** [suggested_stop ~initial_stop_pct entry] returns the long initial stop:
    [entry * (1 - initial_stop_pct)]. *)

val swing_target : breakout:float -> base_low_opt:float option -> float option
(** [swing_target ~breakout ~base_low_opt] estimates the Weinstein swing target:
    [breakout + (breakout - base_low)]. Returns [None] when [base_low_opt] is
    absent or [breakout <= base_low]. *)

val base_low : base_low_proxy_pct:float -> Stock_analysis.t -> float option
(** [base_low ~base_low_proxy_pct a] returns a proxy for the prior base low:
    [ma_value * (1 - base_low_proxy_pct)]. Returns [None] when [ma_value <= 0].
*)
