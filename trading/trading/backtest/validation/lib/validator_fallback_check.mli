(** V16 + V17: the fallback-exit quality report.

    Both checks encode one principle
    ([dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms"):

    {e "Stale exit is a fallback mechanism, like force_liquidation; they should
       ideally never happen, and any instance we spot should lead to a data fix
       or a quality flag that requires double-checking in analysis."}

    So a non-zero count here is not a strategy result to interpret — it is a
    worklist. Zero is the target; each finding routes to a data fix or an
    explicit whitelist decision.

    Split out from {!Validator_row_checks} because, like V15, they ask a
    different question from V1-V14: not "was this decision sound?" but "did the
    machinery have to invent this trade because the data ran out?" Both are
    EXPECTATION, not INVARIANT — a fallback is a signal about the warehouse, not
    a broken strategy contract.

    Motivating record: the canonical 26y run's seven [stale_force_exit] rows
    (WLL1, RBAK, PCYC, CY x2, CHS, AZPN) were all cash-deal delistings that the
    safety net priced correctly {b by accident} — the last close happened to
    equal the deal price. They were also invisible: their label never reached
    [trades.csv] (#2687, fixed alongside these checks), so the column was blank
    and nothing counted them. CY additionally shows the net hiding a real
    defect, which is what V17 exists to catch. *)

open Validator_types

val check_v16 : inputs -> Validator_step.finding
(** V16 (EXP): no round trip was closed by a fallback safety net — i.e. no row's
    [exit_trigger] is in [config.fallback_exit_labels] ([stale_force_exit],
    [margin_call], [maintenance_reduce], [buyin_stress], and the two
    force-liquidation labels).

    ["delisted"] is deliberately {b not} in that list: since
    {!Trading_simulation.Delisted_exit_runner}, a held position whose
    [active_through] marker has passed exits at its last real close as an
    EXPECTED event. Counting it would bury the real defects under routine
    corporate actions, which is exactly the failure this check exists to end.

    Each violation's [detail] names the trigger, both dates and both prices, so
    a specimen can be chased in the warehouse without re-running the backtest.
    Never {!Validator_step.Skip}s — it reads only [trades.csv] columns, so every
    row is evaluable and the count is exact. A run with zero fallback exits
    passes and prints nothing. *)

val fallback_exit_count : report -> int
(** The V16 violation count in [report], or [0] when V16 was disabled or did not
    run. Lets {!Validator_report} surface the count without re-deriving the
    check, and keeps the [QUALITY-FLAG] line and the report body reading from
    one number. *)

val check_v17 : inputs -> Validator_step.finding
(** V17 (EXP): no entry was filled against a bar already more than
    [config.stale_entry_days] days old — the CY shape, where an entry landed on
    2020-04-18 and again on 2020-04-25 for a symbol whose series had ended on
    2020-04-15.

    At the default [stale_entry_days = 7] those two entries split, which is the
    intended reading rather than a miss: 2020-04-18 is 3 days stale — an
    ordinary long weekend, so it passes — and 2020-04-25 is 10 days stale, so it
    is reported. The comparison is strict ([gap > stale_entry_days]), so a gap
    exactly equal to the threshold passes; the default was chosen to sit
    strictly below the specimen's 10-day gap rather than on it.

    No artifact carries the decision date (the audit's [entry_context] does not
    record it), so the check asks the bars the equivalent question: how old was
    the most recent daily bar at or before the fill date? A gap larger than the
    threshold means the fill priced against a bar that was no longer live.

    Calendar days, not bars, so the threshold's default has to clear an ordinary
    long weekend plus a holiday — see {!Validator_types.check_config}. A row is
    {!Validator_step.Skip}ped when the symbol is absent from the bar store or
    its entry has no daily bars, and when every stored bar postdates the entry.

    With a populated [active_through] the admission-time case is removed by
    [Delisted_entry_gate] (#2695); a ticket admitted on the marker day can still
    fill a few days later, under this check's threshold, so a zero count is
    evidence by margin, not by construction (the position is exited at the
    marker and the symbol leaves the tradeable set), so a non-zero count on a
    rebuilt warehouse is a build defect. *)
