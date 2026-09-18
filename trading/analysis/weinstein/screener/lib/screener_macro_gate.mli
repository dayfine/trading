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
  macro_trend:Weinstein_types.market_trend ->
  Weinstein_types.breadth_state ->
  bool
(** {!longs_admitted_by_macro} on [macro_trend], {b and} a pure extra conjunct:
    when [deteriorating_blocks_longs] is set, [Weinstein_types.Deteriorating]
    additionally rejects longs — the one [Neutral]-projecting breadth state the
    27-year study measured as loss-making for entries
    ([dev/experiments/stop-width-cadence-surface-2026-09-05/README.md] §"Breadth
    state across 27 years"). [Recovering], the best cohort in the same study,
    stays admitted; [neutral_blocks_longs] would have blocked both.

    Because the three-state half reads the caller's own [macro_trend] — never a
    projection of [breadth_state] — [deteriorating_blocks_longs = false] is
    {b unconditionally}
    [longs_admitted_by_macro ~neutral_blocks_longs macro_trend], for every
    ([macro_trend], [breadth_state]) pair and every setting of
    [neutral_blocks_longs]. That is what makes it a drop-in at every three-state
    call site, and it imposes no consistency precondition on the two arguments.
    Issue #2755. *)

val longs_admitted_by_index_stage :
  index_stage_veto_blocks_longs:bool -> Weinstein_types.stage option -> bool
(** Whether the {b primary index}'s own stage admits new long entries.

    [false] on exactly one (flag, stage) pair — [index_stage_veto_blocks_longs]
    set {b and} the index classified [Weinstein_types.Stage4 _]. Every other
    pair is [true], including [None] (a caller with no index read wired). With
    the flag off the function is therefore {b unconditionally} [true], so
    [&&]-ing it into any long gate leaves that gate bit-identical — which is
    what makes it a drop-in at both the cascade
    ({!Screener.screen_with_cooldown} [?index_stage]) and the F2 resting-ticket
    re-screen.

    {b Authority.} weinstein-book-reference.md §2.1, block "Resolved 2026-09-16
    — veto or vote?". Ch. 8 ("Stage Analysis for the Market Averages") makes the
    index's Stage-4 breakdown below the 30-week MA an explicit, unconditional
    suspension of new buying — "Suspend buying even if you see a few stocks
    breaking out on their charts" — rather than one weighted vote inside the
    Weight-of-the-Evidence composite. A Stage-3 index top is caution only
    ("proceed with caution"), so [Stage3] is deliberately {e not} vetoed.

    Matching [Stage4 _] alone covers the book's "3→4 or 4" case: the transition
    week itself already classifies as [Stage4] in [Stage.result.stage] (the
    [Stage3 -> Stage4] marker rides alongside in [Stage.result.transition]).

    The short side is untouched — this is a long-admission conjunct only.
    Weinstein's Stage-4 index instruction on the short side is the opposite one
    ("begin looking for shorts"). *)

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
