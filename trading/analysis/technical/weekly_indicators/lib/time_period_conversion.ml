open Core
open Types.Daily_price

(* Check if two dates are in the same week *)
let _is_same_week (d1 : Date.t) (d2 : Date.t) : bool =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

(* Check if a date is a weekend *)
let _is_weekend (date : Date.t) : bool =
  let day = Date.day_of_week date in
  Day_of_week.equal day Day_of_week.Sat || Day_of_week.equal day Day_of_week.Sun

(* Validate date based on weekdays_only setting *)
let _validate_weekday ~weekdays_only date =
  if weekdays_only && _is_weekend date then
    raise
      (Invalid_argument "Weekend dates not allowed when weekdays_only is true")

(* Validate chronological ordering *)
let _validate_ordering prev curr =
  if Date.compare prev curr >= 0 then
    raise
      (Invalid_argument
         "Data must be sorted chronologically by date with no duplicates")

(* Process a new data point *)
let _process_data_point ~weekdays_only ~prev_date ~curr_week data =
  _validate_weekday ~weekdays_only data.date;
  Option.iter prev_date ~f:(fun prev -> _validate_ordering prev data.date);
  match curr_week with
  | [] -> ([ data ], Some data.date)
  | last :: _ ->
      if _is_same_week last.date data.date then
        (data :: curr_week, Some data.date)
      else ([ data ], Some data.date)

let daily_to_weekly ?(weekdays_only = false) data =
  (* Recursively process data points, maintaining:
     - acc: list of completed weekly entries (last entry of each week)
     - curr_week: entries in the current week being processed
     - prev_date: last processed date (for chronological validation)
  *)
  let rec aux acc curr_week prev_date = function
    | [] -> (
        (* End of data - handle any remaining week *)
        match curr_week with
        | [] -> List.rev acc (* No remaining week *)
        | data :: _ ->
            List.rev (data :: acc) (* Add last entry of remaining week *))
    | data :: rest ->
        (* Process the current data point *)
        let curr_week', prev_date' =
          _process_data_point ~weekdays_only ~prev_date ~curr_week data
        in
        (* If we've moved to a new week, add the last entry of previous week to acc *)
        let acc' =
          match curr_week with
          | last :: _ when not (_is_same_week last.date data.date) ->
              last :: acc
          | _ -> acc
        in
        aux acc' curr_week' prev_date' rest
  in
  aux [] [] None data
