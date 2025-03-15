open Types
open Ta_ocaml.Ta

let calculate_30_week_ema data =
  let weekly_data = Date.daily_to_weekly data in
  let prices = Array.of_list (List.map (fun d -> d.close) weekly_data) in
  match ema prices 30 with
  | Ok result ->
      let dates = List.map (fun d -> d.date) weekly_data in
      List.combine (List.drop (30-1) dates) (Array.to_list result)
  | Error msg -> failwith msg

let calculate_from_file filename =
  match Csv_parser.read_file filename with
  | data -> calculate_30_week_ema data
  | exception Failure msg -> failwith (Printf.sprintf "Error reading file: %s" msg)
