(** The cascade's first gate: which sides the macro tape admits.

    Extracted from {!Screener} when that coordinator reached the file-length cap
    ([.claude/rules/code-health-discipline.md]: extract, do not raise the
    limit). {!Screener} re-exports every value here, so callers keep writing
    [Screener.longs_admitted_by_macro].

    Every function is pure and total over the trend / breadth constructors —
    which is the point of the module: the cascade and the out-of-cascade
    consumers (the F2 resting-ticket re-screen, the diagnostics) must ask the
    same question of the same tape, and a shared total function is what stops
    them drifting. *)

val longs_admitted_by_macro :
  neutral_blocks_longs:bool -> Weinstein_types.market_trend -> bool
(** Whether the macro tape admits new {b long} entries, at three-state
    resolution. [Bearish] always blocks; [Neutral] blocks only when
    [neutral_blocks_longs] is set; [Bullish] always admits.

    [neutral_blocks_longs] defaults to [false] in every config = the historical
    gate. Setting it {e tightens} Weinstein's unconditional macro gate so a
    non-confirmed ([Neutral]) tape no longer admits buys. The short-side gate is
    unaffected. *)

val longs_admitted_by_breadth :
  neutral_blocks_longs:bool ->
  deteriorating_blocks_longs:bool ->
  Weinstein_types.breadth_state ->
  bool
(** {!longs_admitted_by_macro} read at {!Weinstein_types.breadth_state}
    resolution: the three-state gate is applied to the projected trend
    ([Weinstein_types.market_trend_of_breadth_state]), and then
    [deteriorating_blocks_longs] may additionally reject
    [Weinstein_types.Deteriorating] — the one [Neutral]-projecting state the
    27-year study measured as loss-making for entries
    ([dev/experiments/stop-width-cadence-surface-2026-09-05/README.md] §"Breadth
    state across 27 years"). [Recovering], the best cohort in the same study,
    stays admitted; [neutral_blocks_longs] would have blocked both.

    With [deteriorating_blocks_longs = false] this is exactly
    {!longs_admitted_by_macro} on the projected trend, so it is a drop-in for
    every three-state call site. Issue #2755. *)

val shorts_admitted_by_macro :
  neutral_blocks_shorts:bool -> Weinstein_types.market_trend -> bool
(** Short-side mirror of {!longs_admitted_by_macro}: [Bullish] always blocks;
    [Neutral] blocks only when [neutral_blocks_shorts] is set; [Bearish] always
    admits (the book's short-only-in-a-confirmed-bear rule,
    weinstein-book-reference.md §Short-Selling Rules). The long-side gate is
    unaffected. *)

val breadth_state_or_projection :
  macro_trend:Weinstein_types.market_trend ->
  Weinstein_types.breadth_state option ->
  Weinstein_types.breadth_state
(** The breadth state a caller supplied, or — when it supplied none —
    [Weinstein_types.breadth_state_of_market_trend macro_trend].

    The projection never yields [Deteriorating] or [Recovering], so a caller
    with no breadth-direction read gets the three-state gate back exactly,
    whatever [deteriorating_blocks_longs] is set to. That is what makes the flag
    inert unless [Macro.config.breadth_direction] is enabled. *)
