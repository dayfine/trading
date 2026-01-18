(** Time series utilities implementation *)

open Core

let _is_last_day_of_month date =
  let next_day = Date.add_days date 1 in
  not (Month.equal (Date.month date) (Date.month next_day))

let is_period_end ~cadence date =
  match (cadence : Types.Cadence.t) with
  | Daily -> true
  | Weekly -> Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri
  | Monthly -> _is_last_day_of_month date

let convert_cadence prices ~cadence ~as_of_date =
  match (cadence : Types.Cadence.t) with
  | Daily -> prices
  | Weekly ->
      let include_partial_week = Option.is_some as_of_date in
      Time_period.Conversion.daily_to_weekly ~include_partial_week prices
  | Monthly ->
      (* TODO: Implement monthly conversion in future *)
      []
