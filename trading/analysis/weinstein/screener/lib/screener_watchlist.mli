(** Long-side watchlist construction for the Weinstein screener.

    The watchlist is the "not a buy, but worth watching" bucket of the weekly
    report. Two kinds of entry land here:

    - near-miss breakout candidates (grade C or D) that did not clear the buy
      floor, and
    - {b demoted failed breakouts} — candidates the failed-breakout
      re-validation gate removed from the buy list. Their entry carries the drop
      reason from {!Screener_admission.failed_breakout_reason} so the report
      shows why a would-be buy disappeared (weinstein-book-reference.md §Buy
      Criteria: a close back below the breakout level after the breakout week is
      a failed breakout).

    Extracted from {!Screener} to keep the cascade coordinator within the
    declared-large file-length cap. All functions are pure. *)

open Screener_scoring

val entry :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  early_stage2_max_weeks:int ->
  failed_breakout_tolerance_pct:float ->
  buy_tickers:Core.String.Set.t ->
  Stock_analysis.t * sector_context ->
  (string * string) option
(** [entry ...] classifies one (analysis, sector) pair as a watchlist row
    [(ticker, reason)], or [None] when it does not belong on the watchlist.

    Order of decision: not a breakout candidate → [None]; already in
    [buy_tickers] → [None]; failed-breakout gate fires →
    [Some (ticker, drop_reason)]; otherwise the grade-C/D near-miss rule.

    [failed_breakout_tolerance_pct <= 0.0] (the default) disables the
    failed-breakout arm entirely, making this bit-identical to the historical
    grade-only watchlist on every input. *)

val build :
  weights:scoring_weights ->
  thresholds:grade_thresholds ->
  early_stage2_max_weeks:int ->
  failed_breakout_tolerance_pct:float ->
  candidates:(Stock_analysis.t * sector_context) list ->
  buy_tickers:Core.String.Set.t ->
  buys_active:bool ->
  (string * string) list
(** [build ...] maps {!entry} over [candidates], preserving input order. Returns
    [[]] when [buys_active] is [false] (the macro gate closed the long side — no
    buys, hence nothing to watch for a buy). *)
