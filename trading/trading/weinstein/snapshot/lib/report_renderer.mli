(** Render a {!Weekly_snapshot.t} as a Markdown report.

    This is the M6.5 weekly report renderer — a {b pure} function from a frozen
    weekly snapshot to a human-readable Markdown string. No I/O.

    {1 Output shape}

    The Markdown contains, in order:

    - Title: [# Weekly Pick Report — <YYYY-MM-DD>]
    - System version line: [System version: `<sha>`]
    - [## Macro] section: regime in bold + score
    - [## Strong sectors] section: bulleted list (or "(none)" if empty)
    - [## Long candidates (top 10)]: ranked Markdown table
    - [## Short candidates (top 5)]: ranked Markdown table
    - [## Held positions]: Markdown table

    All section headers are always rendered, even when the underlying data list
    is empty — empty tables / lists render as ["(none)"] so a reader never sees
    a missing section.

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

val render : Weekly_snapshot.t -> string
(** [render snapshot] returns the snapshot rendered as a single Markdown string,
    terminated by a final newline. Always succeeds — every section header is
    emitted unconditionally. Pure function: no I/O, no exceptions. *)
