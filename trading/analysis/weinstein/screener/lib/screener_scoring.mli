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
  w_early_stage2 : int option; [@sexp.default None]
      (** Weight for an early-Stage2 entry ([weeks_advancing <= 4] without an
          observed Stage1→Stage2 breakout). [None] (default) preserves the
          historical coupling [w_stage2_breakout / 2] — behaviourally
          bit-identical to pre-field behaviour. [Some v] decouples the
          early-entry weight from the breakout weight, making the breakout/early
          {e ratio} configurable rather than fixed at 2:1.

          {b Why [@sexp.default None] and not [@sexp.option]:}
          [Backtest.Overlay_validator] derives the set of valid override
          key-paths from the {e serialized} base config, so a field omitted from
          [sexp_of_config] (which [@sexp.option] does when [None]) cannot be
          targeted by a [config_overrides] / [Variant_matrix] axis — the runner
          rejects [screening_config.weights.w_early_stage2] as an unresolvable
          key. [@sexp.default None] keeps the field present in the serialized
          form (so the axis resolves) while still parsing a missing field to
          [None] (so older config sexps round-trip).

          Motivation: the breakout-vs-early ranking is invariant to
          [w_stage2_breakout]'s magnitude (both scale together via [/ 2]), so
          the M5.4 weight-magnitude sweep could never test it. The
          cascade-selection-inversion forensics (2026-06-10) found confirmed
          Stage1→2 breakouts under-perform early-Stage2 entries on win-rate yet
          are scored +30 vs +15 — this field is the axis that lets an experiment
          flatten or invert that premium. Default-off per
          [.claude/rules/experiment-flag-discipline.md]. *)
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
      (** Weight for Virgin_territory or Clean overhead (long side), and for
          Clean support below a breakdown (short side). Default: 15. *)
  w_virgin_support : int option; [@sexp.default None]
      (** Short-side weight for {b Virgin_territory support below} a breakdown —
          no prior buyers waiting below to cushion the fall, the most explosive
          short setup. [None] falls back to [w_clean_resistance] (the pre-field
          behaviour where Virgin and Clean support scored identically and so
          could not differentiate otherwise-identical Stage-4 short candidates).
          The default [Some 20] ranks Virgin support strictly above Clean (15),
          which is what spreads the short-candidate ranking — the
          {!Screener._support_signal} flattening that collapsed every Stage-4 /
          Strong-volume short to one score (e.g. the 2026-06-12 weekly picks,
          all score 50). Affects {b only} the short path; [_resistance_signal]
          (long side) is unchanged.

          {b Why [@sexp.default None] and not [@sexp.option]:} same reason as
          [w_early_stage2] — [Overlay_validator] derives valid override
          key-paths from the serialized base config, so a [None]-omitted field
          cannot be an axis. [@sexp.default None] keeps the field present in the
          serialized form (axis resolves) while parsing a missing field to
          [None] (older config sexps round-trip). *)
  w_sector_strong : int;  (** Weight bonus for a Strong sector. Default: 10. *)
  w_late_stage2_penalty : int;
      (** Negative weight for late Stage2 flag. Default: -15. *)
}
[@@deriving sexp]
(** Scoring weights for each positive signal. All are configurable.

    {b Field-name spellings for sweep overlays.} The ten fields above are the
    {e exact} keys that any sweep overlay or config patch must use to mutate
    these weights:
    - [w_stage2_breakout]
    - [w_early_stage2]
    - [w_strong_volume]
    - [w_adequate_volume]
    - [w_positive_rs]
    - [w_bullish_rs_crossover]
    - [w_clean_resistance]
    - [w_virgin_support]
    - [w_sector_strong]
    - [w_late_stage2_penalty]

    These are the field-name spellings that sweep overlays must use —
    [runner.ml:_apply_overrides] does not deep-merge by alias; an overlay with a
    non-matching key silently no-ops (see PR #1061). Friendly shorthand such as
    [weights.rs] / [weights.volume] / [weights.breakout] / [weights.sector] will
    be silently ignored, producing an "inert sweep" where every cell runs with
    [default_scoring_weights] and metrics collapse to a single point. See
    [dev/notes/screener-weights-inertness-2026-05-13.md] for the P4
    investigation that surfaced this. *)

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
