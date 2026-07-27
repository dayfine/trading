(** Bar-series preparation for the report charts — weekly aggregation and the
    simple moving average.

    Split out of {!Svg_chart} so that module stays what its docstring claims:
    pure geometry and markup. Nothing here knows about viewBoxes, SVG or
    snapshots; nothing in {!Svg_chart} has to reason about calendars.

    Provided here rather than taken from [analysis/technical/indicators] because
    the snapshot library deliberately carries no [analysis/] dependency. *)

val weekly_bars : Types.Daily_price.t list -> Types.Daily_price.t list
(** [weekly_bars bars] rescales each daily bar onto the split/dividend-adjusted
    basis (every price field multiplied by [adjusted_close /. close_price], so
    [close_price = adjusted_close] on the output), then aggregates the
    chronological series into weekly bars, one per ISO week: [open_price] of the
    week's first bar, the extremes of its [high_price] / [low_price], the
    [close_price] and [adjusted_close] of its last bar, and the sum of its
    volume.

    The adjusted basis is what makes the chart split-safe: entry/stop level
    lines are adjusted-scale, so raw bars would draw a fake cliff across any
    split inside the window (issue #2133). A bar with a NaN or non-positive raw
    close admits no rescale factor: it keeps its [open_price] / [high_price] /
    [low_price] unscaled and takes [adjusted_close] as its close, rather than
    blanking the chart.

    Each weekly bar is {b dated at its last daily bar}, not at the week's Monday
    — so a series ending on a Friday close ends on that Friday, which is what a
    weekly report's right-hand edge should read.

    Weeks are keyed by the Monday of each date's ISO week, so a week straddling
    a year boundary stays one bucket. Input must be chronological (oldest
    first); [[]] maps to [[]]. Pure function. *)

val sma : period:int -> float list -> float option list
(** [sma ~period values] is the simple moving average of [values],
    {b aligned to the input}: element [i] is the mean of the [period] values
    ending at [i], or [None] when fewer than [period] values precede it. The
    result therefore has the same length as [values], which is what lets a
    caller plot it against the same x-slots as the underlying series.

    A non-positive [period] yields all-[None] — there is no average of nothing.
    Pure function; never raises. *)
