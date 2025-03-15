open Ta_ocaml.Ta

type date = {
  year : int;
  month : int;
  day : int
}

let parse_date date_str =
  try
    Scanf.sscanf date_str "%d-%d-%d" (fun y m d ->
      { year = y; month = m; day = d })
  with _ -> failwith "Invalid date format"

let parse_csv_line line =
  match String.split_on_char ',' line with
  | date_str :: _ :: _ :: _ :: close :: _ -> (parse_date date_str, float_of_string close)
  | _ -> failwith "Invalid CSV line format"

let is_same_week d1 d2 =
  let open Unix in
  let t1 = mktime { tm_sec = 0; tm_min = 0; tm_hour = 0;
                    tm_mday = d1.day; tm_mon = d1.month - 1; tm_year = d1.year - 1900;
                    tm_wday = 0; tm_yday = 0; tm_isdst = false } in
  let t2 = mktime { tm_sec = 0; tm_min = 0; tm_hour = 0;
                    tm_mday = d2.day; tm_mon = d2.month - 1; tm_year = d2.year - 1900;
                    tm_wday = 0; tm_yday = 0; tm_isdst = false } in
  let week1 = (fst t1) /. (24. *. 3600. *. 7.) |> floor in
  let week2 = (fst t2) /. (24. *. 3600. *. 7.) |> floor in
  week1 = week2

let daily_to_weekly data =
  let rec aux acc curr_week = function
    | [] -> List.rev (match curr_week with [] -> acc | (d, p) :: _ -> (d, p) :: acc)
    | (date, price) :: rest ->
        match curr_week with
        | [] -> aux acc [(date, price)] rest
        | (last_date, _) :: _ ->
            if is_same_week last_date date then
              aux acc ((date, price) :: curr_week) rest
            else
              aux ((last_date, price) :: acc) [(date, price)] rest
  in
  aux [] [] data

let calculate_30_week_ema data =
  let weekly_data = daily_to_weekly data in
  let prices = Array.of_list (List.map snd weekly_data) in
  match ema prices 30 with
  | Ok result ->
      let dates = List.map fst weekly_data in
      List.combine (List.drop (30-1) dates) (Array.to_list result)
  | Error msg -> failwith msg

let read_csv_file filename =
  let ic = open_in filename in
  let rec read_lines acc =
    try
      let line = input_line ic in
      if String.contains line 'D' then  (* Skip header *)
        read_lines acc
      else
        read_lines (parse_csv_line line :: acc)
    with End_of_file ->
      close_in ic;
      List.rev acc
  in
  read_lines []
