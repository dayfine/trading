open Core

let is_screening_day_view ?(holiday_fallback = false)
    (view : Snapshot_runtime.Snapshot_bar_views.weekly_view) =
  view.n > 0
  &&
  let last = view.dates.(view.n - 1) in
  Day_of_week.equal Day_of_week.Fri (Date.day_of_week last)
  || (holiday_fallback && Exchange_calendar.is_last_trading_day_of_week last)

let for_config (config : Weinstein_strategy_config.config) view =
  is_screening_day_view ~holiday_fallback:config.screen_holiday_friday_weeks
    view
