(** The [short_min_price] short-entry gate.

    A faithful Weinstein eligibility "dial" (default-off axis per
    [.claude/rules/experiment-flag-discipline.md]) that encodes the researched
    sub-$17 economic-margin floor on shorts
    ([dev/notes/long-short-margin-mechanics-2026-06-12.md]). The spine is
    untouched — this only narrows which short candidates are eligible. *)

val filter :
  short_min_price:float ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~short_min_price candidates] drops short candidates whose
    {!Screener.scored_candidate.suggested_entry} is strictly below
    [short_min_price].

    No-op when [short_min_price <= 0.0] (the default): returns [candidates]
    unchanged (bit-identical), so every existing golden/baseline replays
    unchanged. Pure. See [Weinstein_strategy_config.short_min_price]. *)
