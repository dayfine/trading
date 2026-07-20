(** The [short_borrow_availability] short-entry gate (margin M3a).

    A faithful Weinstein short-side eligibility "dial" (default-off axis per
    [.claude/rules/experiment-flag-discipline.md]) modelling
    {b borrow availability}: a short can only be opened if shares are locatable
    to borrow. We have no locate feed, so borrow supply is proxied by
    {b trailing dollar-ADV} — a thinly-traded name has little float circulating
    and is the canonical hard-to-borrow / no-locate case. Short candidates whose
    dollar-ADV is below the floor are dropped ("no borrow available"); long
    candidates are never affected (borrow is a short-only concern).

    The spine is untouched ([.claude/rules/weinstein-faithful-core.md] W1): this
    only narrows which {e short} candidates are eligible, exactly as
    {!Short_min_price_gate} narrows shorts by price and the liquidity overlay
    narrows both sides by tradeable ADV. It composes {e after} those gates in
    {!Entry_assembly}; a dropped short simply never reaches the entry walk (same
    convention as the sibling assembly-stage gates — a per-candidate audit trace
    would require threading the recorder into {!Entry_assembly}, a documented
    follow-up seam, not this PR).

    {b Cadence caveat.} Borrow availability is modelled at weekly-screen cadence
    off trailing daily bars; it cannot see an intraweek borrow recall or a gap
    squeeze. Stress-path buy-in modelling is M3b / M4 territory, not this gate.

    Pure with respect to the supplied bar reader / lookup. *)

open Core

val filter :
  min_dollar_adv:float ->
  dollar_adv_for:(string -> float option) ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~min_dollar_adv ~dollar_adv_for candidates] drops {b short}
    candidates whose trailing dollar-ADV (via [dollar_adv_for candidate.ticker])
    is strictly below [min_dollar_adv] — i.e. no borrow is available. Long
    candidates always pass.

    A short is {b kept} when [dollar_adv_for] returns [None] (no liquidity
    reading — a missing reading must never drop a candidate) or [Some adv] with
    [adv >= min_dollar_adv].

    No-op when [min_dollar_adv <= 0.0] (the default): returns [candidates]
    unchanged (bit-identical), so every existing golden/baseline replays
    unchanged. Pure. See
    [Weinstein_strategy_config.short_borrow_min_dollar_adv]. *)

val apply :
  min_dollar_adv:float ->
  lookback_days:int ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** Strategy-side adapter: builds the [dollar_adv_for] lookup from [bar_reader]
    via {!Liquidity_metric.dollar_adv} over [lookback_days] of bars available at
    [current_date] (no lookahead), then delegates to {!filter}. No-op at
    [min_dollar_adv <= 0.0]. *)
