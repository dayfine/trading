open Core
open Types.Daily_price

(* Check if two dates are in the same week *)
let _is_same_week (d1 : Date.t) (d2 : Date.t) : bool =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

(* Check if a date is a weekend *)
let _is_weekend (date : Date.t) : bool =
  let day = Date.day_of_week date in
  Day_of_week.equal day Day_of_week.Sat || Day_of_week.equal day Day_of_week.Sun

(* Check if a date is a Friday (end of trading week) *)
let _is_friday (date : Date.t) : bool =
  Day_of_week.equal (Date.day_of_week date) Day_of_week.Fri

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

(* Aggregate a week of data into a single weekly bar *)
let _aggregate_week (week_data : t list) : t =
  match week_data with
  | [] -> failwith "Cannot aggregate empty week"
  | [ single ] -> single
  | _ :: _ ->
      (* week_data is in reverse chronological order (last day first) *)
      let last = List.hd_exn week_data in
      let first = List.last_exn week_data in
      {
        date = last.date;
        open_price = first.open_price;
        high_price =
          List.map week_data ~f:(fun d -> d.high_price)
          |> List.max_elt ~compare:Float.compare
          |> Option.value_exn;
        low_price =
          List.map week_data ~f:(fun d -> d.low_price)
          |> List.min_elt ~compare:Float.compare
          |> Option.value_exn;
        close_price = last.close_price;
        volume = List.sum (module Int) week_data ~f:(fun d -> d.volume);
        adjusted_close = last.adjusted_close;
      }

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

let daily_to_weekly ?(weekdays_only = false) ?(include_partial_week = true) data
    =
  (* Recursively process data points, maintaining:
     - acc: list of completed weekly bars (aggregated)
     - curr_week: entries in the current week being processed (reverse chronological)
     - prev_date: last processed date (for chronological validation)
  *)
  let rec aux acc curr_week prev_date = function
    | [] -> (
        (* End of data - handle any remaining week *)
        match curr_week with
        | [] -> List.rev acc (* No remaining week *)
        | week_data ->
            (* Check if the last day is a Friday (complete week) *)
            let last = List.hd_exn week_data in
            let is_complete_week = _is_friday last.date in
            if include_partial_week || is_complete_week then
              (* Aggregate the week and add to results *)
              List.rev (_aggregate_week week_data :: acc)
            else
              List.rev
                acc (* Skip incomplete week when include_partial_week=false *))
    | data :: rest ->
        (* Process the current data point *)
        let curr_week', prev_date' =
          _process_data_point ~weekdays_only ~prev_date ~curr_week data
        in
        (* If we've moved to a new week, aggregate previous week and add to acc *)
        let acc' =
          match curr_week with
          | _ :: _
            when not (_is_same_week (List.hd_exn curr_week).date data.date) ->
              _aggregate_week curr_week :: acc
          | _ -> acc
        in
        aux acc' curr_week' prev_date' rest
  in
  aux [] [] None data
