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
      [Raised] and [Tightened_ratchet] always move it, [Entered_tightening] may
      (HPQ-wein-450's moved 19.78 -> 22.38). Stop moves made {b outside} the
      state machine — split adjustment, the late-Stage-2 tighten, the
      extension-stop runner — are not recorded as rows and are invisible to V22;
      they show up only as a row's [stop_before] differing from the previous
      row's [stop_after].
    - A {i stretch} starts at the position's first row, or at the row that last
      moved the stop, and runs to the row that next moves it, or to the
      position's last row. Its length is the calendar span between the two
      dates.
    - A {i completed correction + recovery that did not raise} is a
      [Cycle_stalled] row (the book §5.2 cycle test passed, but the candidate
      did not beat the resting stop)
      {b whose predecessor row is [Correction_not_recovered]}: the update before
      showed a correction of at least [min_correction_pct] on file, not yet
      recovered, and this one recovered it. [correction_count_before] is not the
      discriminator.
    - The position fires when any stretch is long enough {b and} holds at least
      one such row. The specimen reports the longest qualifying stretch, the
      number of counted stalls in it, and the last counted stall's stop,
      candidate, MA, correction extreme and extreme/MA ratio.

    {b Why the predecessor.} Under the default
    [correction_must_follow_peak = false] the correction extreme is a running
    low that may print {i before} the trend peak, on any cycle — the post-reset
    freshness guard only needs one bar to touch the reset close. A pure advance
    of ~8.7% then completes a cycle on the bar that first makes the depth, so
    the predecessor is [No_correction_yet] (or [Seeded_trailing] / none).
    CMG-wein-744's 2019-07-29 stall is that shape: low 717.24 on 07-02, peak
    close 779.86 on 07-26, largest pullback 4.4%. The predecessor is the
    {b previous update}: [Stop_decision.push] replaces a hold head only with a
    newer hold, so the row before a [Cycle_stalled] is always the decision of
    the update just before it, never an older hold. [Anchor_not_fresh],
    [Cycle_stalled] and [Raised] predecessors would need the whole correction
    and recovery inside one bar and are not counted either; none occurs in the
    measured runs.

    {b Necessary, not sufficient.} While [correction_must_follow_peak = false],
    a [Correction_not_recovered] predecessor can in principle still read a low
    from before the peak (the peak rises past 8.7% over that low and the next
    close sits just under it), and a dip and recovery inside a single bar
    counts. The filter removes the phantoms the record can identify, not all of
    them.

    This covers both readings of the issue in one rule: a position held [>= N]
    weeks with a completed cycle and no raise at all (the whole hold is one
    stretch), and one whose last raise is [>= N] weeks old while cycles kept
    completing. Holds neither start nor end a stretch.

    {b Holding period.} The stop-decision date span, not [trades.csv]: the same
    for closed and still-open positions (the latter have no [trades.csv] row),
    and no fill-date join is needed. The first row is the first stop update
    after the fill (the [Seeded_trailing] row), so the span undercounts the hold
    by at most one update interval.

    {b Why EXPECTATION.} A stall is often the rule working: the cycle candidate
    is [min (correction extreme, MA)] less a buffer, and in a steep advance the
    30-week MA lags the correction lows, so the candidate sits under the resting
    stop until the MA catches up (FDX-wein-1233). The check counts how often
    that holds a stop for a quarter or more; it is not a bug on its own. The
    extreme/MA ratio in the specimen separates that lag (~1.0-1.4) from the
    #2982 basis mix, where an adjusted MA under raw lows puts the ratio at the
    cumulative split factor.

    {b Measured.} No committed [trade_audit.sexp] carries [stop_decisions] yet
    (the five under [dev/warmup-fix-runs/after-fix1-stop-log/] predate #2986).
    The default was measured on two runs of committed specs at this commit —
    [goldens-small/covid-recovery-2020-2024] and [six-year-2018-2023], the
    302-symbol small universe, over the [trading/test_data] store; calibration
    only, not a performance read. "with rows" counts audit records carrying stop
    decisions (2 and 6 more have none and skip). The runs share 2020-2023, so 11
    firing positions appear in both.

    Every [Cycle_stalled] row's predecessor, per run (covid / six-year):
    [Correction_not_recovered] 47 / 48 (27 / 28 of them first cycles),
    [No_correction_yet] 41 / 46, [Seeded_trailing] 1 / 1. No other tag occurs,
    so the whitelist above and a blacklist of [No_correction_yet] /
    [Seeded_trailing] select the same rows here.

    {v
    run                 with rows  span>=13w  fire@13w  fire@4/8/17/26w
    covid-2020-2024     212        39         15        33/31/11/2
    six-year-2018-2023  260        47         19        35/29/13/3
    v}

    23 distinct positions fire at 13 weeks. 22 are long and MA-bound (MA below
    the correction extreme on every counted stall); 1 is a short (FOXA 2022)
    bound by its correction high at extreme/MA 1.00. 19 never raised at all; 4
    raised at some other point in the hold. 20 read extreme/MA 1.00-1.34, the
    lag case. 3 read higher: CMG-wein-744 51.7 (CMG's 2024 50:1 split, adjusted
    MA ~15 under raw lows ~770 — the #2982 shape), FAST 2.17 (2024 2:1 split),
    FANG 1.56. Against the earlier [correction_count_before > 0] filter (14 / 17
    fires), the predecessor rule drops 4 positions whose only counted stalls
    were phantom-shaped (HPQ-wein-450, MRK, RMD, TRGP) and adds 6 whose genuine
    stall was a first cycle (AIG, CMI, EVRG, FOXA, PM, VMC). 13 weeks is the
    issue's horizon and sits mid-slope: 8 weeks fires on 29-31, 17 weeks on
    11-13, 26 weeks on 2-3.

    {b Specimens} (the six-year run): CMG-wein-744 fires — held 2019-02-19 to
    2019-11-08 (37 weeks) at stop 581.65, never raised, two counted stalls
    (2019-06-10, 2019-08-29) with candidates 12.90 and 14.74, and two
    phantom-shaped ones that do not count. KHC-wein-1463 fires on one counted
    first-cycle stall (2021-03-26). HPQ-wein-450 is clean: both stalls follow
    [No_correction_yet]. FDX-wein-1233 is clean: its first raise came 64 days
    after its first row.

    {b Skips}, each with its own [skip_reason], never a silent pass:
    - no audit loaded ([audit_absent = Some reason]): every position the run
      knows of (round trips + open positions, or audit records if more) skipped
      with [reason];
    - an audit loaded but not one record carries a stop decision (a pre-#2986
      artefact): the same count, reason
      ["trade_audit.sexp carries no stop_decisions (pre-#2986 artefact)"];
    - otherwise, each audit record with no rows (e.g. exited before its first
      stop update): skipped, reason ["position has no stop-decision rows"]. *)
