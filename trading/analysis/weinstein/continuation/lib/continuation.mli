(** Continuation-buy detector for Weinstein's Ch. 3 "continuation buy" pattern.

    A continuation buy is a late-Stage-2 re-entry pattern: a stock already in a
    clear Stage 2 advance pulls back to its 30-week MA, consolidates near the MA
    for a few weeks, and then breaks out anew above the top of the
    consolidation. The book treats this as a second-chance buy when the initial
    breakout was missed, BUT only when the MA is clearly trending higher (a
    flattening MA disqualifies — see [ma_slope_min]).

    Authority: [docs/design/weinstein-book-reference.md] §4.6 "Continuation Buys
    (Ch. 3)" and the design plan [dev/plans/continuation-buys-2026-05-13.md].

    This module implements Interpretation B from the plan: detection of the
    pattern so it can be admitted as a NEW position-entering candidate (for
    symbols not already held). Interpretation A (pyramid adds to existing
    holdings) is deferred behind a core-module decision.

    All functions are pure. *)

type pullback_band = { low : float; high : float } [@@deriving sexp]
(** Acceptable range of [close / ma_30w] at the pullback bar. Default:
    [{ low = 0.95; high = 1.05 }]. A bar's close/MA ratio inside this band
    counts as "pulled back close to the MA" for §3.(b). *)

type config = {
  ma_slope_min : float;
      (** Minimum MA slope (as a fraction over [Stage.config.slope_lookback]
          weeks) for §3.(a). The book wants the MA "clearly trending higher" — a
          stricter threshold than the Stage classifier's [slope_threshold]
          (which only distinguishes Flat from Rising). Default: 0.01 (1% over
          the slope-lookback window). *)
  pullback_band : pullback_band;
      (** Acceptable [close / ma_30w] range at the pullback bar. Default:
          [{ low = 0.95; high = 1.05 }]. *)
  pullback_lookback_weeks : int;
      (** How many weeks back to scan for a pullback bar. Default: 8. *)
  consolidation_range_pct : float;
      (** Maximum [(window_high - window_low) / avg_close] over the
          consolidation window for §3.(c). Default: 0.10 (10%). *)
  consolidation_weeks : int;
      (** Number of bars (ending at the as-of bar) used to compute the
          consolidation range. Default: 4. *)
}
[@@deriving sexp]
(** Detector configuration. All thresholds are configurable to enable parameter
    tuning via backtesting. *)

val default_config : config
(** [default_config] provides sensible defaults per the design plan §8. *)

type result = {
  is_continuation : bool;
      (** [true] iff all five preconditions (a)-(e) fired. (e) — volume
          confirmation — is left to the {!Stock_analysis} caller, which has
          access to the existing [Volume.result]. This module checks (a)-(d): MA
          slope, pullback proximity, consolidation tightness, and recent new
          high above the consolidation top. *)
  pullback_low : float option;
      (** Low of the bar identified as the pullback bar (the bar in the lookback
          window whose [close / ma_30w] sits inside [pullback_band]). Used by
          the caller as the structural stop floor for the continuation entry.
          [None] when no pullback bar was identified. *)
  consolidation_high : float option;
      (** Highest [high] across the [consolidation_weeks] bars BEFORE the
          current bar (offsets 1 .. consolidation_weeks). The current bar
          (offset 0) is intentionally excluded — it represents the breakout,
          which must exceed the base it just left. [None] when the window is
          incomplete or when the range gate failed. *)
  ma_slope_observed : float;
      (** The MA slope read from the stage callbacks. Surfaced so the caller
          (and tests) can sanity-check the slope-floor gate. *)
}
[@@deriving sexp]
(** Detector output. *)

type callbacks = {
  get_ma : week_offset:int -> float option;
      (** 30-week MA at [week_offset] weeks back (offset 0 = current). *)
  get_close : week_offset:int -> float option;
      (** Bar close at [week_offset] weeks back. *)
  get_high : week_offset:int -> float option;
      (** Bar high at [week_offset] weeks back. *)
  get_low : week_offset:int -> float option;
      (** Bar low at [week_offset] weeks back. *)
}
(** Bundle of indicator callbacks consumed by {!analyze_with_callbacks}. Shaped
    to be trivially constructed from {!Stock_analysis.callbacks} (the [stage]
    sub-bundle plus [get_high] / a [get_low] adapter). *)

val analyze_with_callbacks : config:config -> callbacks:callbacks -> result
(** [analyze_with_callbacks ~config ~callbacks] runs the four-precondition
    detection ((a) MA slope ≥ [ma_slope_min], (b) pullback to MA inside
    [pullback_band] within [pullback_lookback_weeks], (c) consolidation range ≤
    [consolidation_range_pct] over [consolidation_weeks], (d) current close
    above the consolidation high). Returns a {!result} whose [is_continuation]
    field is [true] iff all four fired.

    Pure function: same callback outputs always produce the same result. *)
