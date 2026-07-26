(** Strategy-side adapter for the entry arm of the liquidity-realism overlay.

    Wraps the pure {!Liquidity_gate.filter} with the bar-plumbing it needs: it
    builds the [dollar_adv_for] lookup from the screening cycle's {!Bar_reader}
    via {!Liquidity_metric.dollar_adv}, then applies the gate. Kept out of
    {!Weinstein_strategy_screening} so that coordinator stays under the
    file-length cap.

    No-op at [min_entry_dollar_adv = 0.0]: returns the candidate list
    bit-identical. (The default is [1_000_000.0] since the 2026-07-10
    realism-defaults flip, so the gate is armed by default; setting the
    threshold to [0.0] reproduces the pre-flip behaviour.) Pure with respect to
    the supplied bar reader. *)

open Core

val apply :
  config:Liquidity_config.t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [apply ~config ~bar_reader ~current_date candidates] drops entry candidates
    (long AND short) whose trailing dollar-ADV — computed from bars available at
    [current_date] (no lookahead), over [config.adv_lookback_days] and reduced
    by [config.adv_aggregation] / [config.adv_trim_pct] — is below
    [config.min_entry_dollar_adv].

    Delegates the keep/drop decision to {!Liquidity_gate.filter}; this function
    only supplies the [dollar_adv_for] lookup. *)
