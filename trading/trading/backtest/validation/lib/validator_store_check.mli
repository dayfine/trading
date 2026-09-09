(** V18: a stored per-symbol series that is not a plausible equity price series.

    A sibling of {!Validator_splice_check} and split out for the same reason it
    was: this is a question about the BAR STORE — whether the numbers handed to
    the strategy describe a tradeable US equity at all — not about a strategy
    decision (V1/V2/V8/V9/V10) or about a fill (V13/V14). It differs from V15 in
    what it looks at rather than what it asks: V15 inspects the two bars either
    side of a fill and so can only see a discontinuity a trade happened to land
    on, while V18 reads the whole series and is keyed to the SYMBOL. *)

open Validator_types

val check_v18 : inputs -> Validator_step.finding
(** V18 (EXP): no symbol the run touched has a stored series failing either
    store-sanity rule.

    - {b Level.} The symbol's {b median} daily close exceeds
      [config.store_median_close_max] (default $10,000). Median rather than mean
      so a handful of correctly-scaled prints mixed into a mis-scaled series
      cannot mask it.
    - {b Phantom print.} Some bar's close moved more than
      [config.store_zero_volume_move_pct] percent (default 90, strict) against
      the immediately preceding bar's close while that bar's volume was at or
      below [config.store_zero_volume_max] (default 0). Real >90% one-bar moves
      happen and they happen on volume; one nobody traded is the feed, not the
      market. The volume test is evaluated first and short-circuits, so a traded
      bar is clean whatever its move was.

    Either rule alone flags. The unit of evaluation is the {b symbol}, not the
    trade: symbols are deduped across [inputs.trades] and
    [inputs.open_positions] and each is keyed to the earliest date the run put
    capital into it, so a symbol traded ten times yields one specimen rather
    than ten copies crowding the report's 10-specimen cap.

    {2 The specimen}

    A violation always reports the median close and the series span, and
    additionally the offending bar's date, close, prior close and volume when
    the phantom-print rule fired — enough to find the defect in the warehouse
    without re-running anything. The MEL specimen reads:
    ["median close 172140.00 over 2427 bars (2008-11-06..2018-06-28), above the
     10000.00 ceiling; bar 2017-02-08 close 12.20 (-99.99% vs prior close
     175002.00) on volume 0"].

    {2 Skips}

    A symbol is {!Validator_step.Skip}ped and counted, never passed, when it is
    absent from the bar store, when its store entry carries fewer daily bars
    than [config.store_min_bars] (a median over five bars is not evidence the
    series is sane), or when the phantom rule found nothing but could not
    evaluate every pair — a non-positive prior close admits no ratio. As in V13
    and V15, no un-evaluable row is invisible in the report. A violation
    outranks an un-evaluable pair, so a symbol that trips the level rule is
    reported rather than skipped.

    Note the series is the one {!Validator_artifacts.load_bars} truncates at the
    run end, so the median describes the window the run could see, not the
    symbol's whole history in the store.

    {2 Why EXPECTATION, not INVARIANT}

    The level rule flags a legitimately high-priced instrument by design: BRK.A
    trades above $400k and its median close would exceed any ceiling low enough
    to catch MEL. There is no test that separates "mis-mapped listing" from
    "expensive share class" from the price series alone — MEL's two halves are
    each individually possible, and only a human who knows what MEL {i is} can
    say which. So the check flags for a human rather than hard-failing a run,
    and a run that legitimately holds such an instrument raises
    [store_median_close_max] rather than disabling the check. Both directions
    are pinned in the tests. The phantom-print rule carries no such ambiguity,
    but shares the check's severity; promote via [severity_overrides] if a
    prevention gate is ever armed on it.

    Motivating defect: issue #2732 — [MEL] in the top-3000-2000 vintage, 2,353
    of 2,427 bars above $1,000 (2017-01 around $167k-177k) with $8-12 bars mixed
    in on near-zero volume. An arm bought 1 share at $175,002 on 2017-01-30 (at
    that price one share IS the ticket) and the 12.2 print on 2017-02-08, volume
    0, gapped it through the stop for -$171,654, -99.99%. The canonical 26y
    record carries a MEL trade. *)
