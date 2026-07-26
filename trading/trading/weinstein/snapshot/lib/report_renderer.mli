(** Render a {!Weekly_snapshot.t} as a Markdown report.

    This is the M6.5 weekly report renderer — a {b pure} function from a frozen
    weekly snapshot to a human-readable Markdown string. No I/O.

    {1 Output shape}

    The Markdown contains, in order:

    - Title: [# Weekly Pick Report — <YYYY-MM-DD>]
    - System version line: [System version: `<sha>`]
    - [## Macro] section: regime in bold + score
    - [## Strong sectors] section: bulleted list (or "(none)" if empty)
    - [## Long candidates (top N)]: ranked Markdown table ([N = long_limit])
    - [## Short candidates (top N)]: ranked Markdown table ([N = short_limit])
    - [## Held positions]: Markdown table
    - [## Warnings]: bulleted list of data-quality warnings (or ["(none)"])

    All section headers are always rendered, even when the underlying data list
    is empty — empty tables / lists render as ["(none)"] so a reader never sees
    a missing section. The [top N] in each candidate header echoes the effective
    limit.

    Each candidate table carries a [Resistance] column rendering the candidate's
    [resistance_grade] (the v2 sketch-derived ["<quality> (<score>)"] string, or
    the v1 binary quality label). A candidate whose grade was not computed
    ([resistance_grade = None]) renders as ["-"] so the column is never blank.

    The [Stop] cell renders the candidate's structural stop
    ([Weekly_snapshot.candidate.stop]) as [$<price>]; when
    [stop_is_structural = false] (no qualifying support floor was found for this
    symbol, so [stop] falls back to the fixed [entry * initial_stop_buffer]
    proxy) the cell carries a trailing [*] and the table gains a one-line italic
    note below it explaining the fallback — so a reader can tell a real
    structural stop apart from the proxy without cross-referencing the chart
    (issue #2084 Finding 2).

    A candidate carrying [data_suspect = true] (its most recent bar is a single
    outsized move vs the prior bar's close — see
    [Weinstein_snapshot_gen.Spike_bar_gate]) renders its [Symbol] cell with a
    trailing ["(!)"] marker, and the table gains a one-line italic note below it
    explaining the marker. The candidate is {e flagged, not dropped}: it keeps
    its rank, entry, stop, and instruction (issue #2083 Finding 3). The
    corresponding warning line in the [Warnings] section carries the observed
    move and threshold.

    Each candidate table also carries an [Instruction] column: an executable
    order derived from the generator-computed [sized_*] fields (fixed-risk
    sizing, mirroring the backtest) — e.g.
    ["BUY STOP 55 sh @ $28.49 (~$1567, 1.6% of book, risk $126); on fill place
     SELL STOP @ $26.21, GTC; cancel if unfilled by Friday close"]. A [0]-share
    unsized candidate renders ["-"]; a [0]-share result with a [sizing_note]
    renders that reason (cash / caps exhausted, invalid stop); a
    placeholder-sized candidate prefixes the ["UNSIZED — set portfolio.sexp"]
    note.

    The [Held positions] table renders one execution-ready row per held
    position: shares, entry price, current price, unrealized %, current stop,
    and a [Suggested stop] cell showing this week's recomputed Weinstein
    support-floor stop with its delta vs the current stop (["-"] when not
    recomputed).

    The [Warnings] section renders one bullet per entry in
    [Weekly_snapshot.t.warnings] verbatim (e.g. a candidate dropped by the
    sparse-tail eligibility gate, issue #2083 fix 1 — see
    [Weinstein_snapshot_gen.Sparse_tail_gate]), or ["(none)"] when the list is
    empty. This is the human-visible half of "drop candidate + emit a warning":
    a candidate that vanished from the tables above is explained here rather
    than silently missing. Spike-flagged candidates (issue #2083 fix 3) also
    contribute a line here — one that says explicitly that the candidate was
    kept, so a reader does not go hunting for a missing row.

    {1 Display caps and the tie-honesty note}

    The candidate tables are display-only caps on the {e human} report; the
    underlying {!Weekly_snapshot.t} retains the screener's full capped list and
    strategy / backtest selection is unaffected. When a table is truncated, an
    italic note is appended below it stating how many candidates were hidden and
    — crucially — how many of them {e tie the cutoff score}. Candidates arrive
    score-descending with an alphabetical tie-break, so names hidden at the
    cutoff are not "worse" than the last shown when they tie its score: the cut
    is arbitrary among equals. The note tells a reader funding a book-sized
    subset to treat the tied set as interchangeable rather than trusting the
    alphabetical order as a quality ranking.

    {1 Determinism}

    [render] is a pure function: same input snapshot → byte-identical output. No
    dependence on system time, environment, or hash ordering. The round-trip
    "render twice, identical bytes" property is pinned by the test suite.

    {1 Risk percent}

    For each candidate, the risk-percent column is computed as
    [(entry - stop) / entry * 100] (long convention) and formatted to one
    decimal place. The renderer applies the same formula for short candidates
    (caller is responsible for the sign convention of [entry] and [stop]
    relative to side). *)

val default_long_display_limit : int
(** Default number of long candidates shown in the report table (7). *)

val default_short_display_limit : int
(** Default number of short candidates shown in the report table (5). *)

val render : ?long_limit:int -> ?short_limit:int -> Weekly_snapshot.t -> string
(** [render ?long_limit ?short_limit snapshot] returns the snapshot rendered as
    a single Markdown string, terminated by a final newline. [long_limit] /
    [short_limit] cap the respective candidate tables and default to
    {!default_long_display_limit} / {!default_short_display_limit}; a truncated
    table gains the tie-honesty note described above. Always succeeds — every
    section header is emitted unconditionally. Pure function: no I/O, no
    exceptions. *)
