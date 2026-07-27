(** Inline SVG price/volume sparkline — a {b pure} function from a bar series
    plus a set of horizontal price levels to an SVG fragment. No I/O.

    Built for the HTML weekly report ({!Html_report_renderer}), which embeds one
    sparkline per candidate and per held position so a reader can see the base,
    the breakout/entry level and the stop without leaving the page. The module
    knows nothing about snapshots — it takes bars and levels, so it is reusable
    by any renderer.

    {1 What is drawn}

    Inside a [viewBox="0 0 <width> <height>"], back to front:

    - an optional shaded {b band} ([?band]) spanning the full plot width between
      two prices — used for the entry-to-stop risk band,
    - a {b volume} strip along the bottom: one [rect.vol] per bar, height
      proportional to that bar's volume over the window maximum,
    - the {b close-price polyline} ([polyline.px]) across the window,
    - one horizontal {b level line} per entry in [levels] ([line.lvl.lvl-entry]
      / [.lvl-stop] / [.lvl-ref] by {!level_kind}), each carrying a [<title>]
      with the level's label so hovering names it.

    No text is positioned inside the plot: the numeric values already appear in
    the surrounding table, and keeping labels out of the geometry keeps the
    sparkline legible at report scale. Level labels survive as the [<title>]
    tooltips and in the root element's [aria-label].

    The fragment carries no styling of its own — colours, stroke widths and
    fills come from the embedding page's stylesheet ({!Html_page.css}) via the
    class names above.

    {1 Price domain}

    The vertical domain spans the union of every bar's high and low, every level
    price, and both [?band] bounds. Levels are therefore {b always} inside the
    viewBox, even when the stop sits far below the visible price range — a stop
    line clipped off the bottom of the chart would be worse than useless. A
    degenerate (zero-width) domain is padded, so no coordinate can be [nan] or
    [inf].

    {1 Determinism}

    {!render} is pure: same bars + levels → byte-identical SVG. Coordinates are
    emitted at fixed precision; there is no dependence on time, environment or
    hash ordering. *)

type level_kind =
  | Entry  (** Breakout / fill price. Rendered with class [lvl-entry]. *)
  | Stop  (** Protective stop. Rendered with class [lvl-stop]. *)
  | Reference  (** Any other annotation. Rendered with class [lvl-ref]. *)

type level = {
  label : string;
      (** Human-readable name for the line (e.g. ["entry $28.49"]). Escaped
          before it reaches the output; appears as a [<title>] tooltip and in
          the root [aria-label]. *)
  price : float;  (** Price the horizontal line is drawn at. *)
  kind : level_kind;  (** Drives the CSS class. *)
}

val default_width : int
(** Width of the emitted [viewBox] when [?width] is omitted (260). *)

val default_height : int
(** Height of the emitted [viewBox] when [?height] is omitted (80). *)

val max_bars : int
(** Longest window drawn (90 bars). A longer series is truncated to its most
    recent {!max_bars} bars — a weekly report's sparkline is about the current
    base, and more points than this are indistinguishable at report scale. *)

val render :
  ?width:int ->
  ?height:int ->
  ?band:float * float ->
  bars:Types.Daily_price.t list ->
  levels:level list ->
  unit ->
  string option
(** [render ?width ?height ?band ~bars ~levels ()] returns the SVG fragment, or
    [None] when [bars] has fewer than two entries — a single point is not a
    chart, and the caller is expected to degrade to a chart-less cell.

    [bars] must be in chronological order (oldest first), as returned by
    [Bar_reader.daily_bars_for]. Only the most recent {!max_bars} are drawn.

    [?band] shades the region between two prices across the full plot width
    (order of the pair is irrelevant). Omit it for an unshaded chart.

    Never raises. Pure function: no I/O. *)
