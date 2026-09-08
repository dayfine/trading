(** Never admit a symbol whose delisting marker has already passed (#2693).

    A symbol's [active_through] (the warehouse manifest's per-symbol last-active
    day, surfaced by [Snapshot_runtime.Daily_panels.active_through_for] and read
    here through {!Bar_reader.snapshot_callbacks}) says the series ENDS on that
    date because the security stopped existing — a cash merger, an acquisition,
    a bankruptcy delisting. Once [as_of > active_through] the symbol is no
    longer {b admitted} as an entry candidate: there is no security left to
    trade, and the "current price" the entry path would read is the last print
    of a dead series.

    {b Scope: admission, not fill.} This gate runs where candidates are
    assembled. A ticket admitted on the marker day itself (kept deliberately, to
    mirror the exit's boundary) is a resting order that can still fill on a
    later step — [Market_state] keeps serving a dark symbol's final bar, resting
    orders are not re-screened (`enable_entry_ticket_rescreen` defaults false;
    `entry_order_max_rest_weeks` 52), and the delisted exit acts only on a
    broker position, never on an unfilled ticket. That residual is one to a few
    days (a fill before the next weekly screen) and sat under the post-run V17
    threshold of 7 days, so a clean V17 from this gate alone was evidence by
    margin, not by construction. It is now {b closed} by
    {!Trading_simulation.Delisted_ticket_cancel} (#2696), which cancels the
    resting ticket and retires its order on the first step past the marker — the
    same [Date.(d < date)] boundary, run from {!Forced_exit_step} before the
    step's order processing. The three guards compose: this gate blocks new
    tickets, that module retires the one admitted on the marker day, and
    [Delisted_exit_runner] closes anything that filled before either. Every
    stale entry measured on 2026-09-06 (FII ×2, CY) was an admission-time entry
    weeks after the marker, which this gate removes.

    This is the entry-side mirror of the simulator's [Delisted_exit_runner]
    (#2692), and it uses the same predicate with the same boundary —
    [Date.(as_of <= active_through)] means still tradeable, so the marker day
    itself is a trading day on both sides.

    {2 Data-driven, not a strategy mechanism — no config flag}

    There is deliberately no knob. Whether a candidate is dropped is a function
    of the {b data} (does the warehouse carry a marker for this symbol?), not of
    a tuning choice — see [dev/plans/delisting-data-fix-2026-09-06.md]
    §"Principle: fallbacks are quality flags, not mechanisms". Every warehouse
    built before #2691 leaves [active_through] [None] on every symbol, so every
    lookup returns [None], every such run is a no-op and every golden is
    bit-identical; that is [experiment-flag-discipline.md] R1's default-off
    obligation met structurally rather than by a flag. On a marker-carrying
    warehouse the gate fires without a spec change.

    {2 What it fixes (measured 2026-09-06)}

    The acceptance run of the rebuilt 2000-vintage warehouse
    ([dev/experiments/warehouse-rebuild-2026-09-06/], record spec at salt 0)
    reported the [delisted] exit working and zero fallback exits, but three
    entries opened on symbols whose marker had already passed:

    {v
    symbol  entry date   active_through  staleness  outcome
    FII     2020-03-28   2020-01-31       57 days   delisted exit 2 days later, -$845
    FII     2020-04-04   2020-01-31       64 days   delisted exit 2 days later, -$844
    CY      2020-04-25   2020-04-15       10 days   delisted exit 2 days later, -$122
    v}

    Each was closed within two days by the run's own [delisted] exit — the exit
    side was already correct; admission was not. Neither existing guard covered
    it: [entry_max_bar_age_days] ({!Entry_recency_gate}) is 0 in the record
    convention, and the screener's point-in-time filter is behind
    [enable_pi_filter] (default [false]). Both stay as they are — this gate is
    unconditional because the marker is data, not a mechanism.

    {2 Relation to the screener's pre-prune}

    {!Weinstein_strategy_screening.prune_universe_by_active_through} drops
    symbols already delisted at the {e fold's start} — a one-shot cost
    optimisation over the universe, evaluated once per run. This gate is a
    {e per-screen} exclusion evaluated on every screening date, so it catches
    the symbols that delist {e during} the fold, which the pre-prune by
    construction cannot. The two are complementary; neither subsumes the other.

    Composes last in {!Entry_assembly}; a dropped candidate simply never reaches
    the entry walk (the same convention as the sibling assembly-stage gates — a
    per-candidate audit trace would require threading the recorder into
    {!Entry_assembly}, a documented follow-up seam, not this PR). Pure with
    respect to the supplied lookup. *)

open Core

val filter :
  as_of:Date.t ->
  active_through_for:(string -> Date.t option) ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [filter ~as_of ~active_through_for candidates] drops candidates (long AND
    short) whose marker [d], per [active_through_for candidate.ticker],
    satisfies [Date.(d < as_of)].

    A candidate is {b kept} when [active_through_for] returns [None] (no marker
    — still trading, or a warehouse that carries no markers at all) or when
    [Date.(as_of <= d)], which keeps the marker day itself and any future
    marker. Pure. *)

val apply :
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** Strategy-side adapter: builds the [active_through_for] lookup from
    [bar_reader]'s {!Bar_reader.snapshot_callbacks} — the same manifest field
    the simulator's [delisted] exit reads, so the entry and exit sides cannot
    disagree about when a symbol stopped existing — then delegates to {!filter}.
    The lookup is an O(1) manifest hashtable read per candidate, so the gate
    costs one lookup per screened candidate and reads no bars. *)
