open Core
module CI = Composition_inputs

(* Tickers carried in a [staleness_report.sample] (a logging aid, not a gate). *)
let sample_size = 10

(* Whether [d] is a weekday (Mon–Fri). Holidays are not modelled, so a
   "trading day" here is a weekday — see the [.mli] freshness-gate docs. *)
let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

(* Count weekdays strictly after [end_date] up to and including [date] — i.e.
   how many trading days the last bar ([end_date]) lags [date]. [0] when
   [end_date >= date] (the symbol is fresh, or ahead). *)
let _trading_days_late ~end_date ~date =
  if Date.( >= ) end_date date then 0
  else
    Date.dates_between ~min:(Date.add_days end_date 1) ~max:date
    |> List.count ~f:_is_weekday

let is_fresh_enough ~date ~max_staleness_trading_days
    (entry : CI.inventory_entry) =
  _trading_days_late ~end_date:entry.data_end_date ~date
  <= max_staleness_trading_days

type staleness_report = { excluded_count : int; sample : string list }
[@@deriving sexp, show, eq]

let report ~excluded =
  {
    excluded_count = List.length excluded;
    sample = List.take excluded sample_size;
  }
