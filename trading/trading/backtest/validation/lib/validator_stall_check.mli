(** V22 — stalled trailing-stop ratchet (issue #3002 part C), read directly from
    the weekly stop-decision record [trade_audit.sexp] carries since #2986
    ({!Weinstein_stops.Stop_decision}) instead of from a replay. *)

open Validator_types

val check_v22 : inputs -> Validator_step.finding
(** V22 (EXPECTATION) — stalled ratchet. Flags a position whose stop decisions
    contain a {b no-move stretch} of at least [config.stalled_ratchet_min_weeks]
    weeks (default [13]; [x 7] calendar days, inclusive) inside which at least
    one {b completed} correction cycle stalled.

    {b The rule, in record terms.} One pass over [stop_histories], per position,
    oldest row first:
    - A row {i moves} the stop iff [stop_after <> stop_before]. The state
      machine never lowers a stop, so every move is a raise or a tightening:
      [Raised] and [Tightened_ratchet] always move it, [Entered_tightening] may.
    - A {i stretch} starts at the position's first row, or at the row that last
      moved the stop, and runs to the row that next moves it, or to the
      position's last row. Its length is the calendar span between the two
      dates.
    - A {i completed correction + recovery that did not raise} is a
      [Cycle_stalled] row — the book §5.2 cycle test (a correction of at least
      [min_correction_pct] and a close back through the prior extreme) passed,
      but the candidate did not beat the resting stop. Only rows with
      [correction_count_before > 0] count, unless
      [config.stalled_ratchet_count_first_cycle]: the first cycle is anchored on
      the entry-seeded extreme and can complete on a pure advance with no
      pullback, which the record alone cannot tell from a real one. [Raised] is
      the only other completed-cycle tag and always moves the stop, so it ends a
      stretch instead.
    - The position fires when any stretch is long enough {b and} holds at least
      one such row. The specimen reports the longest qualifying stretch, the
      number of stalled cycles in it, and the last stalled row's stop,
      candidate, MA, correction extreme and extreme/MA ratio.

    This covers both readings of the issue in one rule: a position held [>= N]
    weeks with a completed cycle and no raise at all (the whole hold is one
    stretch), and one whose last raise is [>= N] weeks old while cycles kept
    completing. Holds (the four no-move reasons) neither start nor end a
    stretch; since [Stop_decision.push] collapses a run of same-ISO-week holds
    to its latest row and never collapses a [Cycle_stalled] row, the collapse
    changes neither a stretch's end dates nor its stall count.

    {b Holding period.} The stop-decision date span, not [trades.csv]: the same
    for closed and still-open positions (the latter have no [trades.csv] row),
    and no fill-date join is needed. The first row is the first stop update
    after the fill (the [Seeded_trailing] row), so the span undercounts the hold
    by at most one update interval.

    {b Why EXPECTATION.} A stall is often the rule working: the cycle candidate
    is [min (correction extreme, MA)] less a buffer, and in a steep advance the
    30-week MA lags the correction lows, so the candidate sits under the resting
    stop until the MA catches up (FDX-wein-1233 below). The check counts how
    often that holds a stop for a quarter or more; it is not a bug on its own.
    The extreme/MA ratio in the specimen separates that lag (~1.0-1.4) from the
    #2982 basis mix, where an adjusted MA under raw lows puts the ratio at the
    cumulative split factor.

    {b Measured.} No committed [trade_audit.sexp] carries [stop_decisions] yet
    (the five under [dev/warmup-fix-runs/after-fix1-stop-log/] predate #2986).
    The default was measured on two runs of committed specs at this commit —
    [goldens-small/covid-recovery-2020-2024] and [six-year-2018-2023], the
    302-symbol small universe, over the [trading/test_data] store; calibration
    only, not a performance read. "with rows" counts audit records carrying stop
    decisions (2 and 6 more have none and skip). The runs share 2020-2023, so 10
    firing positions appear in both:

    {v
    run                 with rows  span>=13w  fire@13w  fire@13w-first  fire@4/8/17/26w
    covid-2020-2024     212        39         14        21              23/23/10/1
    six-year-2018-2023  260        47         17        30              23/22/14/3
    v}

    All 21 distinct firing positions are long and MA-bound (MA below the
    correction extreme on every counted stall); 16 never raised at all and 5
    raised at some other point in the hold. 18 read extreme/MA 1.03-1.34, the
    lag case. 3 read higher: CMG-wein-744 51.7 (CMG's 2024 50:1 split, adjusted
    MA ~15 under raw lows ~770 — the #2982 shape), FAST 2.17 (2024 2:1 split),
    FANG 1.56. 13 weeks is the issue's horizon and sits mid-slope: 8 weeks fires
    on 22-23, 17 weeks on 10-14, 26 weeks on 1-3. Counting the first cycle
    ([fire@13w-first]) adds 7 and 13 positions whose qualifying stretch rests on
    a possibly-phantom first-cycle stall.

    {b Specimens} (the six-year run): CMG-wein-744 fires — held 2019-02-19 to
    2019-11-08 (37 weeks) at stop 581.65, never raised, four [Cycle_stalled]
    rows (three with [correction_count_before > 0]) whose candidates were
    10.38-14.74. FDX-wein-1233 is clean — three stalls from 2020-07-30 to
    2020-08-27, then [Raised] on 2020-09-15, 64 days after its first row.

    {b Skips}, each with its own [skip_reason], never a silent pass:
    - no audit loaded ([audit_absent = Some reason]): every position the run
      knows of (round trips + open positions, or audit records if more) skipped
      with [reason];
    - an audit loaded but not one record carries a stop decision (a pre-#2986
      artefact): the same count, reason
      ["trade_audit.sexp carries no stop_decisions (pre-#2986 artefact)"];
    - otherwise, each audit record with no rows (e.g. exited before its first
      stop update): skipped, reason ["position has no stop-decision rows"]. *)
