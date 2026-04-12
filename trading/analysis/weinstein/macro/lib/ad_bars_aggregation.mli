(** Cadence conversion for {!Macro.ad_bar} breadth data.

    {!Macro.analyze} expects {b weekly}-cadence {!Macro.ad_bar} lists so that
    the lookback parameters ([ad_line_lookback], [momentum_period], ...) have
    consistent units between A-D breadth and index bars. Historical breadth
    sources ({!Ad_bars.Unicorn}, for example) load {b daily} bars, so callers
    must aggregate to weekly before passing the data into [Macro.analyze].

    This module is the canonical boundary where that normalization happens.

    All functions are pure. *)

val daily_to_weekly : Macro.ad_bar list -> Macro.ad_bar list
(** [daily_to_weekly bars] aggregates daily A-D bars into one bar per ISO week.

    The input must be sorted chronologically ascending by date. Each output bar
    sums the [advancing] and [declining] counts of the daily bars within that
    week, and is dated on the {b last} day present in the week (mirroring the
    convention used by {!Time_period.Conversion.daily_to_weekly} for price bars
    — the most recent observation's date).

    Partial weeks at the tail are included with a provisional aggregate (dated
    on whatever their last observation is). Empty input returns [[]].

    @raise Invalid_argument if [bars] is not sorted chronologically ascending.
*)
