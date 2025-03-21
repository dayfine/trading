open Core
open Ta_ocaml.Ta

let calculate_30_week_ema data =
  let weekly_data = Time_period_conversion.daily_to_weekly data in
  let prices = Array.of_list (List.map ~f:(fun d -> d.Types.Daily_price.close_price) weekly_data) in
  match ema prices 30 with
  | Ok result ->
      let dates = List.map ~f:(fun d -> d.Types.Daily_price.date) weekly_data in
      List.zip_exn (List.drop dates (30 - 1)) (Array.to_list result)
  | Error msg -> failwith msg
