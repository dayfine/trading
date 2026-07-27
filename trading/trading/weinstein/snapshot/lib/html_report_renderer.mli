(** Render a {!Weekly_snapshot.t} as a self-contained HTML page.

    The Phase C weekly report — a {b pure} function from a frozen weekly
    snapshot (plus, optionally, the bars to chart) to a single HTML string. No
    I/O. It renders {e alongside} {!Report_renderer}, which keeps producing the
    Markdown form; neither replaces the other.

    "Self-contained" is literal: the page inlines its stylesheet, embeds every
    chart as inline SVG, references no external asset, and requires no
    JavaScript to read. Saving the file or mailing it preserves it exactly.

    {1 Output shape}

    The document is [<!DOCTYPE html>] + [<head>] (charset, viewport, title,
    inline {!Html_page.css}) + [<body>]. Inside the body, in the same order as
    the Markdown report so the two are cross-readable:

    - [<h1>] title [Weekly Pick Report — <YYYY-MM-DD>]
    - system-version line
    - [Macro] section: regime in bold + score
    - [Strong sectors] section: [<ul>] (or ["(none)"])
    - [Long candidates (top N)]: ranked table ([N = long_limit])
    - [Short candidates (top N)]: ranked table ([N = short_limit])
    - [Held positions]: table
    - [Warnings]: [<ul>] of data-quality warnings (or ["(none)"])

    Every section header is emitted unconditionally; empty data renders as
    ["(none)"] so a reader never sees a missing section.

    {1 Semantics carried over from the Markdown report}

    All four of these are shared with {!Report_renderer} through
    {!Report_shared}, so the two formats cannot drift:

    - {b Structural vs fallback stop.} A candidate with
      [stop_is_structural = false] renders its [Stop] cell with a trailing [*]
      and the table gains {!Report_shared.stop_fallback} below it, explaining
      that the stop is the fixed [entry * initial_stop_buffer] proxy rather than
      a real support floor (issue #2084 Finding 2).
    - {b Data-suspect marker.} A candidate with [data_suspect = true] renders a
      ["(!)"] marker beside its symbol and the table gains
      {!Report_shared.data_suspect}. The candidate is {e flagged, not dropped}:
      rank, entry, stop and instruction are unchanged (issue #2083 Finding 3).
    - {b Drop reasons.} The [Warnings] section renders one bullet per entry in
      [Weekly_snapshot.t.warnings] — the human-visible half of "drop candidate

    + emit a warning", so a candidate missing from the tables above is explained
      rather than silently absent.

    - {b Tie-honesty note.} A display-capped table gains
      {!Report_shared.truncation}, stating how many candidates were hidden and
      how many of them tie the cutoff score.

    {1 Charts}

    Each candidate row and each held-position row carries a [Chart] cell holding
    an inline {!Svg_chart} sparkline: the price/volume window, a shaded band
    between entry and stop, a dashed entry line and a dashed stop line. Held
    positions chart their fill price and their {e current} stop.

    Every chart cell is tagged [data-chart="<arm>:<symbol>"] with [arm] one of
    ["long"], ["short"], ["held"] — so the three arms are separable by anything
    reading the page programmatically.

    {b Bars are not part of the snapshot.} [Weekly_snapshot.t] carries no price
    history by design ({!Weekly_snapshot} §Design: the on-disk schema is
    decoupled from analysis types), so the caller supplies them through
    [?bars_for]. This keeps [render] pure and leaves the frozen record untouched
    by a rendering concern.

    {b Missing bars degrade, they do not fail.} A symbol whose lookup returns
    fewer than two bars renders a ["no chart data"] marker in place of the
    sparkline; the row — and the rest of the page — is otherwise complete. The
    default [?bars_for] ({!no_bars}) returns nothing for every symbol, so
    rendering a snapshot with no bar source at hand still produces a full,
    readable report.

    {1 Escaping}

    Every snapshot-sourced string is escaped via {!Html_page.escape} before it
    reaches the output. Snapshot text originates in vendor feeds and config
    files, so it is not trusted markup.

    {1 Determinism}

    [render] is a pure function: same inputs → byte-identical output. No
    dependence on system time, environment or hash ordering. The "render twice,
    identical bytes" property is pinned by the test suite, as it is for the
    Markdown renderer. *)

type bar_source = symbol:string -> Types.Daily_price.t list
(** Chart-data lookup: daily bars for a symbol, oldest first — the shape
    [Bar_reader.daily_bars_for] already returns. Returning [[]] for an unknown
    symbol is normal and expected; see {!no_bars}. *)

val no_bars : bar_source
(** The empty bar source: returns [[]] for every symbol, so every row renders
    the chart-less marker. The default for {!render}. *)

val render :
  ?long_limit:int ->
  ?short_limit:int ->
  ?bars_for:bar_source ->
  Weekly_snapshot.t ->
  string
(** [render ?long_limit ?short_limit ?bars_for snapshot] returns the complete
    HTML document, terminated by a final newline.

    [long_limit] / [short_limit] cap the respective candidate tables and default
    to {!Report_renderer.default_long_display_limit} /
    {!Report_renderer.default_short_display_limit} — the same caps the Markdown
    report uses, so both formats show the same rows. A truncated table gains the
    tie-honesty note.

    [bars_for] supplies chart data and defaults to {!no_bars}.

    Always succeeds. Pure function: no I/O, no exceptions. *)
