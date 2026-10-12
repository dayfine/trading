(** US equity-exchange full-day closure calendar, computed from the published
    holiday rules (no data file, no lookahead).

    The strategy only runs on days that have an index bar, so on a Thursday
    before a holiday Friday it cannot tell from its data that Friday will not
    trade. The exchange publishes its holiday schedule years ahead, so asking
    "is the rest of this week closed?" uses information a live operator has on
    the Thursday — it is a calendar lookup, not future price data.

    Scope: full-day weekday closures only (early closes still trade). The rules
    are the NYSE ones in force over the backtest window (2000 onwards): New
    Year's Day, Martin Luther King Jr. Day, Washington's Birthday, Good Friday,
    Memorial Day, Juneteenth (from 2022), Independence Day, Labor Day,
    Thanksgiving and Christmas, with the NYSE weekend-shift rule — a fixed-date
    holiday on a Sunday closes the Monday after; on a Saturday it closes the
    Friday before, {b except} New Year's Day, whose Saturday is not observed
    (the exchange stays open the preceding Friday, 31 December). Plus the
    unscheduled closures that fall on a Friday or empty a whole week: 11-14
    September 2001 and the 11 June 2004 national day of mourning. Other
    unscheduled closures (e.g. 29-30 October 2012) are mid-week, so they cannot
    change which day ends a week with a Friday session, and are not listed. *)

open Core

val is_closed : Date.t -> bool
(** [is_closed d] is [true] when [d] is a weekday on which the exchange is
    closed for the whole day. Weekends return [false] (they are not "holidays";
    callers ask about weekdays). *)

val is_last_trading_day_of_week : Date.t -> bool
(** [is_last_trading_day_of_week d] is [true] when [d] is a weekday, the
    exchange is open on [d], and every later weekday of [d]'s Monday-Friday week
    is closed. A normal Friday is [true]; the Thursday before a Friday holiday
    is [true]; an ordinary Thursday is [false]. *)
