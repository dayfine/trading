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

    All section headers are always rendered, even when the underlying data list
    is empty — empty tables / lists render as ["(none)"] so a reader never sees
    a missing section. The [top N] in each candidate header echoes the effective
    limit.

    Each candidate table carries a [Resistance] column rendering the candidate's
    [resistance_grade] (the v2 sketch-derived ["<quality> (<score>)"] string, or
    the v1 binary quality label). A candidate whose grade was not computed
    ([resistance_grade = None]) renders as ["-"] so the column is never blank.

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
