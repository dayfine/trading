(** The [liquidity_gate] entry gate — the entry arm of the liquidity-realism
    overlay.

    A faithful Weinstein eligibility "dial" (default-off axis per
    [.claude/rules/experiment-flag-discipline.md]) that drops entry candidates —
    long AND short — whose trailing dollar-ADV is too low to trade into safely.
    The spine is untouched ([.claude/rules/weinstein-faithful-core.md] W1): this
    only narrows which candidates are eligible, exactly as
    {!Short_min_price_gate} narrows shorts.

    The gate is pure: it consults a caller-supplied [dollar_adv_for] lookup
    rather than reading bars itself, so it carries no dependency on the bar
    plumbing and is testable in isolation. The strategy supplies a lookup backed
    by {!Liquidity_metric.dollar_adv} over the screening cycle's bar reader. *)

val filter :
  min_entry_dollar_adv:float ->
  dollar_adv_for:(string -> float option) ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~min_entry_dollar_adv ~dollar_adv_for candidates] drops candidates
    whose trailing dollar-ADV (via [dollar_adv_for candidate.ticker]) is
    strictly below [min_entry_dollar_adv].

    A candidate is {b kept} when [dollar_adv_for] returns [None] (no liquidity
    reading — a missing reading must never drop a candidate) or [Some adv] with
    [adv >= min_entry_dollar_adv].

    No-op when [min_entry_dollar_adv <= 0.0] (the default): returns [candidates]
    unchanged (bit-identical), so every existing golden/baseline replays
    unchanged. Pure. See [Liquidity_config.min_entry_dollar_adv]. *)
