(** Daily universe-breadth loader — percent-above-MA and new-52-week-high/low
    counts.

    Complements {!Ad_bars} (advance/decline counts). Where A-D answers "how many
    issues rose today", this series answers "how much of the universe is in an
    uptrend, and how many names are making fresh lows". It backs
    {!Breadth_direction}'s five-state read.

    {b Both columns are adaptations, not Weinstein's own statistics.} The
    antecedent for [n_above150] is the Ch. 3 participation gauge — the weekly
    percentage of NYSE stocks "in Stages 1 and 2" of the Chart 3-11 footnote,
    which he charts against the DJI and reads by direction — approximated here
    by the share of a point-in-time top-3000 universe trading above its 150-day
    (≈ 30-week) MA. [nl52] is the new-low half of the Ch. 8
    new-highs-minus-new-lows gauge, carried as a count (and downstream as a
    share of the universe) rather than as his NET of highs minus lows. See
    [docs/design/weinstein-book-reference.md] §2.8 "Participation percentage
    (Ch. 3)" and §2.4.

    {1 Format}

    One CSV, [data_dir/breadth/synthetic_breadth_daily.csv], with the header row

    {v date,n,n_above150,nh52,nl52,advances,declines v}

    and ISO ([YYYY-MM-DD]) dates. The [advances] / [declines] columns are
    {b ignored} here — A-D breadth already has its own loader and its own
    (weekly) cadence contract; carrying a second copy would invite the two to
    disagree.

    The committed series ([trading/test_data/breadth/]) was computed over the
    per-year point-in-time top-3000 universes with a 150-day MA and 52-week
    high/low windows; provenance and generator live in
    [dev/experiments/yearly-trade-review-2026-09-04/breadth/README.md].

    {1 Graceful degradation}

    A missing or unreadable file returns [[]], exactly as {!Ad_bars} does, so
    breadth is an optional macro input: {!Breadth_series_cache} then answers
    every query with [None] and {!Breadth_direction} falls back to projecting
    the three-state trend. Malformed rows are skipped individually. *)

val load : data_dir:string -> Macro_types.breadth_bar list
(** [load ~data_dir] reads [data_dir/breadth/synthetic_breadth_daily.csv] and
    returns its rows sorted by date ascending, deduped by date (last row for a
    date wins).

    Rows whose [n] (universe count) is below {!min_universe_count} are dropped:
    the generator emits a row for every date any constituent traded, so exchange
    holidays surface as one- or two-symbol rows whose percentages are noise
    (100% above MA off a single name). Dropping them at the boundary keeps
    {!Breadth_series_cache}'s trading-row arithmetic — "the row 5·k rows back is
    k weeks back" — true.

    Missing file, unreadable file, or a file with no usable rows: [[]]. *)

val min_universe_count : int
(** Minimum [n] for a row to be kept by {!load}. Constituent counts in the
    committed series run ~1,900-2,900 on real sessions and 1-2 on holidays, so
    any cut in between is equivalent; this one is stated as a named constant
    rather than inlined so the contract above is checkable. *)
