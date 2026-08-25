(** Render a {!Weekly_snapshot.t} as a self-contained HTML page.

    The Phase C weekly report — a {b pure} function from a frozen weekly
    snapshot (plus, optionally, the bars to chart) to a single HTML string. No
    I/O. It renders {e alongside} {!Report_renderer}, which keeps producing the
    Markdown form; neither replaces the other.

    "Self-contained" is literal: the page inlines its stylesheet, embeds every
    chart as inline SVG, references no external asset, and requires no
    JavaScript to read. Saving the file or mailing it preserves it exactly. The
    one outbound reference is a TradingView {e link} per symbol
    ({!Report_card.tradingview_href}), which fetches nothing.

    {1 Output shape}

    The document is [<!DOCTYPE html>] + [<head>] (charset, viewport, title,
    inline {!Html_page.css}) + [<body>]. Inside the body:

    - [<header>] — title, as-of date, system version, macro-regime chip
      ({!Report_masthead.header}). The macro context is masthead furniture
      rather than a section of its own: it gates every row below it.
    - the counts strip ({!Report_masthead.counts_strip}).
    - [Strong sectors] — chips (or ["(none)"]).
    - [Long candidates (top N)] — the chart legend, then one {!Candidate_card}
      per shown candidate ([N = long_limit]).
    - [Short candidates (top N)] — the same, [N = short_limit].
    - [Held positions] — the same chart legend, then one card per position.
    - [Warnings] — one [<li>] per entry in [Weekly_snapshot.t.warnings], in the
      snapshot's own order (or ["(none)"]). This is the report's drop-reasons
      section,
      {b but the property that a dropped ticker is explained rather than
         silently absent belongs to the generator}, not to this renderer:
      whether a drop produced a warning line is decided by
      [Weinstein_snapshot_gen]'s gates when the snapshot is written. All this
      function guarantees is that whatever is on file is displayed, unfiltered.
    - [<footer>] — {!Report_masthead.closing_notes}.

    Every section header is emitted unconditionally; empty data renders as
    ["(none)"] so a reader never sees a missing section.

    The candidate and held sections are {b cards}, not tables — see
    {!Report_card}. The Markdown report keeps its tables; this is the one place
    the two formats deliberately diverge in layout while agreeing, cell for
    cell, on content.

    {1 Semantics carried over from the Markdown report}

    All of these are shared with {!Report_renderer} through {!Report_shared}, so
    the two formats cannot drift:

    - {b Structural vs fallback stop.} A candidate with
      [stop_is_structural = false] renders its [Stop] figure with a trailing [*]
      {e and} a ["fallback stop"] chip, and the section gains
      {!Report_shared.stop_fallback} (issue #2084 Finding 2).
    - {b Data-suspect marker.} A candidate with [data_suspect = true] gains a
      ["(!) data-suspect"] chip and the section gains
      {!Report_shared.data_suspect}. The candidate is {e flagged, not dropped}:
      rank, entry, stop and ticket are unchanged (issue #2083 Finding 3).
    - {b Entry reconciliation.} A reconciled candidate carries a chip whose text
      is {!Report_shared.close_vs_entry}; an {!Entry_reconciliation.Extended}
      one additionally marks its card and its ticket strip, and the section
      gains {!Report_shared.entry_reconciliation} (issue #2103). The extended
      card keeps its rank in its own side's section and keeps its ticket — the
      order simply will not fill at the current price (issue #2404).
    - {b Order ticket.} Each card's bottom strip is {!Report_shared.instruction}
      verbatim — the broker-facing text is character-identical across the two
      formats.
    - {b Tie-honesty note.} A display-capped section gains
      {!Report_shared.truncation}.

    {1 Charts}

    Each card carries an inline {!Svg_chart}: the most recent
    {!Svg_chart.max_bars} {b weekly} closes — ~21 months, aggregated from the
    supplied dailies by {!Svg_series.weekly_bars} — the 30-week moving average,
    a shaded entry-to-stop band, dashed entry and stop lines named in a
    right-hand gutter, and a marker on the last close. Held positions chart
    their fill price and their {e current} stop.

    The 30-week average is the trend line stage analysis is defined against
    (weinstein-book-reference.md §1 "The Four Stages"), which is why a chart
    meant for checking a Stage-2 entry shows it. It is {b computed} from the
    supplied bars, never stored.

    Every chart is tagged [data-chart="<arm>:<symbol>"] with [arm] one of
    ["long"], ["short"], ["held"] — so the three rendering arms are separable by
    anything reading the page programmatically.

    {b Bars are not part of the snapshot.} [Weekly_snapshot.t] carries no price
    history by design ({!Weekly_snapshot} §Design: the on-disk schema is
    decoupled from analysis types), so the caller supplies them through
    [?bars_for]. This keeps [render] pure and leaves the frozen record untouched
    by a rendering concern.

    {b Missing bars degrade, they do not fail.} A symbol whose lookup yields
    fewer than two {e weekly} bars renders a ["no chart data"] marker in place
    of the chart; the card — and the rest of the page — is otherwise complete.
    The default [?bars_for] ({!no_bars}) returns nothing for every symbol, so
    rendering a snapshot with no bar source at hand still produces a full,
    readable report.

    {1 Escaping}

    Every snapshot-sourced string is escaped via {!Html_page.escape} before it
    reaches the output — including the values that become CSS-class modifiers
    and the symbol that becomes a link target. Snapshot text originates in
    vendor feeds and config files, so it is not trusted markup.

    {1 Determinism}

    [render] is a pure function: same inputs → byte-identical output. No
    dependence on system time, environment or hash ordering. The "render twice,
    identical bytes" property is pinned by the test suite, as it is for the
    Markdown renderer. *)

type bar_source = symbol:string -> Types.Daily_price.t list
(** Chart-data lookup: {b daily} bars for a symbol, oldest first — the shape
    [Bar_reader.daily_bars_for] already returns. The renderer aggregates them to
    weekly itself. Returning [[]] for an unknown symbol is normal and expected;
    see {!no_bars}. *)

val no_bars : bar_source
(** The empty bar source: returns [[]] for every symbol, so every card renders
    the chart-less marker. The default for {!render}. *)

val render :
  ?long_limit:int ->
  ?short_limit:int ->
  ?bars_for:bar_source ->
  Weekly_snapshot.t ->
  string
(** [render ?long_limit ?short_limit ?bars_for snapshot] returns the complete
    HTML document, terminated by a final newline.

    [long_limit] / [short_limit] cap the respective candidate sections and
    default to {!Report_renderer.default_long_display_limit} /
    {!Report_renderer.default_short_display_limit} — the same caps the Markdown
    report uses, so both formats show the same rows. A truncated section gains
    the tie-honesty note.

    [bars_for] supplies chart data and defaults to {!no_bars}.

    Always succeeds. Pure function: no I/O, no exceptions. *)
