open Core
open Types.Daily_price

(* Check if a date is a weekend *)
let _is_weekend (date : Date.t) : bool =
  let day = Date.day_of_week date in
  Day_of_week.equal day Day_of_week.Sat || Day_of_week.equal day Day_of_week.Sun

(* Check if a date is a Friday (end of trading week) *)
let _is_friday (date : Date.t) : bool =
  Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri

let _reject_weekend bar =
  if _is_weekend bar.date then
    raise
      (Invalid_argument "Weekend dates not allowed when weekdays_only is true")

(* Validate weekday-only setting before delegating to the generic bucketer.
   Done as a pre-pass so [Week_bucketing] can stay domain-agnostic. *)
let _validate_weekdays_only data = List.iter data ~f:_reject_weekend

(* Aggregate one week of daily bars (reverse chronological order) into a single
   weekly bar. The bar is dated on the most recent day in the week, the open
   comes from the earliest day, and high/low/volume are reduced over the week. *)
let _aggregate_week (week_rev : t list) : t =
  let last = List.hd_exn week_rev in
  let first = List.last_exn week_rev in
  let high_price =
    List.map week_rev ~f:(fun d -> d.high_price)
    |> List.max_elt ~compare:Float.compare
    |> Option.value_exn
  in
  let low_price =
    List.map week_rev ~f:(fun d -> d.low_price)
    |> List.min_elt ~compare:Float.compare
    |> Option.value_exn
  in
  {
    date = last.date;
    open_price = first.open_price;
    high_price;
    low_price;
    close_price = last.close_price;
    volume = List.sum (module Int) week_rev ~f:(fun d -> d.volume);
    adjusted_close = last.adjusted_close;
  }

(* Drop a trailing partial week if its last observed day is not a Friday. The
   weekly buckets returned by [Week_bucketing] preserve chronological order, so
   "trailing" is just the last element. *)
let _drop_trailing_partial weekly =
  match List.rev weekly with
  | [] -> []
  | last :: _ when _is_friday last.date -> weekly
  | _ :: rest_rev -> List.rev rest_rev

let daily_to_weekly ?(weekdays_only = false) ?(include_partial_week = true) data
    =
  if weekdays_only then _validate_weekdays_only data;
  let weekly =
    Week_bucketing.bucket_weekly
      ~get_date:(fun (b : t) -> b.date)
      ~aggregate:_aggregate_week data
  in
  if include_partial_week then weekly else _drop_trailing_partial weekly
