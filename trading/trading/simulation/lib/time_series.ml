(** Time series utilities implementation *)

open Core

type cadence = Daily | Weekly | Monthly [@@deriving show, eq]

let _is_last_day_of_month date =
  (* Check if the next day is in a different month *)
  let next_day = Date.add_days date 1 in
  not (Month.equal (Date.month date) (Date.month next_day))

let is_period_end ~cadence date =
  match cadence with
  | Daily -> true
  | Weekly -> Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri
  | Monthly -> _is_last_day_of_month date

let convert_cadence prices ~cadence ~as_of_date =
  match cadence with
  | Daily -> prices
  | Weekly ->
      (* Delegate to proven Conversion module from analysis/

         The include_partial_week flag controls behavior:
         - true: Include incomplete weeks (provisional mode)
         - false: Only complete weeks ending Friday (finalized mode)

         When as_of_date is provided, we want provisional mode.
      *)
      let include_partial_week = Option.is_some as_of_date in
      Time_period.Conversion.daily_to_weekly ~include_partial_week prices
  | Monthly ->
      (* TODO: Implement monthly conversion in future
         For now, return empty list to prevent issues *)
      []
