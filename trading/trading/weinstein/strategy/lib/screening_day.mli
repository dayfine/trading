(** Which ticks are weekly-review ("screening") days.

    Split out of {!Weinstein_strategy_screening} (#3139), which sits at its file
    length cap. *)

val is_screening_day_view :
  ?holiday_fallback:bool ->
  Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  bool
(** Stops are adjusted daily; screening runs only on Fridays (weekly review).

    Takes the panel weekly view directly. The screening day is the date of the
    most recent bar in the view (the Friday of the latest week, by week-bucket
    aggregation); an empty view is never a screening day.

    [holiday_fallback] (default [false], #3139; config
    [screen_holiday_friday_weeks]) also accepts the last trading day of a week
    whose Friday the exchange is closed for — e.g. the Thursday before Good
    Friday — per {!Exchange_calendar}. Off, this is the plain Friday test, so
    the default path is bit-identical to before the flag existed. *)

val for_config :
  Weinstein_strategy_config.config ->
  Snapshot_runtime.Snapshot_bar_views.weekly_view ->
  bool
(** {!is_screening_day_view} with [holiday_fallback] taken from
    [config.screen_holiday_friday_weeks]. The one call every Friday-cadence pass
    uses, so they cannot disagree about which day is the review day. *)
