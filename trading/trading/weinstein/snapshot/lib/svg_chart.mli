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
    - an optional {b moving-average} overlay ([polyline.ma]) when [?ma_period]
      is given — see {!render},
    - the {b close-price polyline} ([polyline.px]) across the window,
    - one horizontal {b level line} per entry in [levels] ([line.lvl.lvl-entry]
      / [.lvl-stop] / [.lvl-ref] by {!level_kind}), each carrying a [<title>]
      with the level's label so hovering names it,
    - when [?annotate] is set, right-margin {b level labels} ([text.lvl-label])
      and a {b last-close marker} ([circle.last]).

    By default no text is positioned in or beside the plot: the numeric values
    already appear in the surrounding card, and keeping labels out of the
    geometry keeps the sparkline legible at report scale. Level labels survive
    as the [<title>] tooltips and in the root element's [aria-label]. A
    standalone-readable chart opts in via [?annotate].

    The fragment carries no styling of its own — colours, stroke widths and
    fills come from the embedding page's stylesheet ({!Html_page.css}) via the
    class names above.

    {1 Price domain}

    The vertical domain spans the union of every bar's high and low, every level
    price, both [?band] bounds, and every defined moving-average value. Levels
    and the average are therefore {b always} inside the viewBox, even when the
    stop sits far below the visible price range — a stop line clipped off the
    bottom of the chart would be worse than useless. A degenerate (zero-width)
    domain is padded, so no coordinate can be [nan] or [inf].

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

val weekly_bars : Types.Daily_price.t list -> Types.Daily_price.t list
(** [weekly_bars bars] aggregates a chronological daily series into weekly bars,
    one per ISO week: [open_price] of the week's first bar, the extremes of its
    [high_price] / [low_price], the [close_price] and [adjusted_close] of its
    last bar, and the sum of its volume.

    Each weekly bar is {b dated at its last daily bar}, not at the week's Monday
    — so a series ending on a Friday close ends on that Friday, which is what a
    weekly report's right-hand edge should read.

    Weeks are keyed by the Monday of each date's ISO week, so a week straddling
    a year boundary stays one bucket. Input must be chronological (oldest
    first); [[]] maps to [[]]. Pure function.

    Provided here rather than taken from [analysis/technical/indicators] because
    the snapshot library deliberately carries no [analysis/] dependency. *)

val render :
  ?width:int ->
  ?height:int ->
  ?band:float * float ->
  ?ma_period:int ->
  ?annotate:bool ->
  bars:Types.Daily_price.t list ->
  levels:level list ->
  unit ->
  string option
(** [render ?width ?height ?band ?ma_period ?annotate ~bars ~levels ()] returns
    the SVG fragment, or [None] when [bars] has fewer than two entries — a
    single point is not a chart, and the caller is expected to degrade to a
    chart-less cell.

    [bars] must be in chronological order (oldest first), as returned by
    [Bar_reader.daily_bars_for] or by {!weekly_bars}. Only the most recent
    {!max_bars} are drawn. The module is cadence-agnostic: it draws whatever
    series it is handed.

    [?band] shades the region between two prices across the full plot width
    (order of the pair is irrelevant). Omit it for an unshaded chart.

    [?ma_period] overlays a simple moving average of [close_price] over that
    many bars as [polyline.ma]. It is computed over the {b whole} of [bars] and
    then restricted to the drawn window, so history supplied beyond the window
    yields an average defined across the full chart width rather than one that
    only begins [ma_period] marks in. Positions with fewer than [ma_period]
    values behind them are simply not plotted; fewer than two plotted points
    emits no polyline at all. Omitted (or non-positive) → no overlay, and the
    output is byte-identical to the pre-[?ma_period] renderer.

    [?annotate] (default [false]) makes the chart readable standalone: it
    reserves a right-hand gutter and emits one [text.lvl-label] per level plus a
    [circle.last] marker on the most recent close (whose [<title>] names the
    close and its date). Label baselines are laid out top-to-bottom and pushed
    apart to a minimum gap, so an entry and a stop a few cents apart do not
    overprint; the emitted markup keeps the caller's level order regardless.
    [false] leaves both the geometry and the output exactly as they were before
    this parameter existed.

    Never raises. Pure function: no I/O. *)
