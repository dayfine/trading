(** The [short_min_price] short-entry gate.

    A faithful Weinstein eligibility "dial" (default-off axis per
    [.claude/rules/experiment-flag-discipline.md]) that encodes the researched
    sub-$17 economic-margin floor on shorts
    ([dev/notes/long-short-margin-mechanics-2026-06-12.md]). The spine is
    untouched — this only narrows which short candidates are eligible. *)

val suggested_entry_price : Screener.scored_candidate -> float
(** The screener's {!Screener.scored_candidate.suggested_entry} — the price
    {!filter} gates by default. *)

val filter :
  ?price_of:(Screener.scored_candidate -> float) ->
  short_min_price:float ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ?price_of ~short_min_price candidates] drops short candidates whose
    [price_of c] is strictly below [short_min_price].

    [price_of] defaults to {!suggested_entry_price}. #3131: the strategy passes
    the ticket's actual order price instead
    ([Weinstein_strategy_config.short_min_price_on_order_price]) — under the
    default close-priced ticket the short is entered at the decision close, not
    at [suggested_entry], so a name that has already collapsed below the floor
    would otherwise pass the gate on a stale level.

    No-op when [short_min_price <= 0.0] (the default): returns [candidates]
    unchanged (bit-identical), so every existing golden/baseline replays
    unchanged. Pure when [price_of] is. See
    [Weinstein_strategy_config.short_min_price]. *)
