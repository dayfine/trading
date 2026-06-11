(** Harvest-rotate runner — trims a fraction of held long winners that show the
    earliest Stage-3 topping precursor, freeing capital to recycle into fresh
    Stage-2 leaders through the existing entry pipeline.

    {1 Motivation}

    The [late] sub-flag of [Stage2 { late }] (MA-slope deceleration, the
    earliest top-warning the classifier produces) is computed every week but
    consumed only to gate new entries — never to act on a position already held.
    The cross-regime diagnosis
    [dev/notes/stage-lifecycle-pivot-diagnosis-2026-06-03.md] shows [late] fired
    weeks-to-months before 6 of 7 major single-name / index tops.

    This runner reads [late] for held long positions and {b trims a fraction}
    [harvest_fraction] of the position (the book's "sell half as the Stage-3 top
    forms"). The freed capital recycles through the existing entry pipeline on a
    later cycle into a fresh Stage-2 leader — the trader's "rotate into
    leadership."

    {1 Decoupled MVP scope}

    This runner only emits the {b trim} ([TriggerPartialExit]) transition. It
    does {e not} detect, pair, or atomically execute a specific cash-blocked
    entry candidate against the freed capital — the freed cash simply recycles
    through the normal entry path next cycle. Coupling the trim to a specific
    blocked, better-ranked candidate (the [alternatives_considered] /
    [Insufficient_cash] signal) is a deliberate later refinement, out of scope
    here. See [dev/plans/harvest-rotate-rigorous-test-2026-06-10.md].

    {1 Weinstein authority (W1–W3)}

    This is the {b exit-aggressiveness} dial (the trader preset — "get out as
    the Stage-3 top starts forming") combined with {b rotate-into-leadership},
    both Weinstein's ("The Trader's Way"). It is a faithful adaptation of
    [docs/design/weinstein-book-reference.md] §Stage 3 detail (Ch. 2): "Traders:
    exit with profits. Investors: sell half, protect remaining half with tight
    sell-stop below support." The MA-deceleration [late] signal is the leading
    edge of that topping process; trimming a fraction there is exactly the
    book's "sell half" applied a beat earlier on the earliest topping precursor.

    The trim is {b structural} — a fixed fraction of the position on a topping
    signal — not an arbitrary profit target divorced from price/stage.

    The strategy {b spine} is untouched: stage classification, the Stage-2-only
    buy rule, breakout+volume entry, the macro/sector gate, and relative
    strength are all unaffected. This runner only reduces the size of an
    existing held long when it begins to top.

    {1 Cadence & side}

    Weekly cadence (Friday only), mirroring {!Late_stage2_stop_runner}: the
    [late] flag is a weekly-MA property, so off-cadence ticks are a no-op to
    avoid intra-week classification noise. Long positions only — this is a
    long-only "trim the topping winner" dial; short-side topping semantics
    differ (book §6.3) and are out of scope, so short positions are never
    trimmed. *)

open Core
open Trading_strategy

val update :
  harvest_fraction:float ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  prior_stages:Weinstein_types.stage Hashtbl.M(String).t ->
  current_date:Core.Date.t ->
  Position.transition list
(** [update ~harvest_fraction ~is_screening_day ~positions ~get_price
     ~prior_stages ~current_date] returns one [TriggerPartialExit] transition
    for every held long position whose current stage is
    [Stage2 { late = true }].

    Each emitted transition trims [held_quantity *. effective_fraction] of the
    position at [exit_price = close] (the current bar's close from [get_price]),
    with [exit_reason = StrategySignal { label = "harvest_rotate"; ... }] where
    [effective_fraction = Float.min 1.0 harvest_fraction]. The runner reads the
    position's current stage from [prior_stages] (written by
    {!Stops_runner.update} earlier in the same tick).

    {2 Behaviour}

    {ul
     {- Returns [[]] when [is_screening_day = false] (weekly cadence; the [late]
        flag is a weekly property).
     }
     {- Returns [[]] when [positions] is empty. }
     {- Returns [[]] when [harvest_fraction <= 0.0] (a non-positive fraction is
        the no-op: nothing to trim).
     }
     {- For each held long position in the [Holding] state:
        - Skips unless the stage in [prior_stages] is [Stage2 { late = true }].
          A [Stage2 { late = false }] read, any other stage, or a missing stage
          entry produces no transition.
        - Skips when [get_price] has no bar for the symbol.
        - Otherwise emits [TriggerPartialExit] with
          [target_quantity = held_quantity *. effective_fraction] and
          [exit_price = close]. [harvest_fraction] is clamped to [1.0] so a
          fraction [>= 1.0] trims the whole position (equivalent to a full exit,
          per {!Position.transition_kind.TriggerPartialExit}).
     }
     {- Short positions and non-[Holding] states are skipped without emitting. }
    }

    {2 No-op default}

    This runner is gated entirely by its caller on
    [config.enable_harvest_rotate]; it is only invoked when that flag is [true].
    With the flag default-off the runner never runs, so behaviour is
    bit-identical to baseline regardless of [harvest_fraction]. *)
