open Core
open Ta_ocaml.Ta

type ema_result = {
  date : Date.t;
  value : float;
} [@@deriving eq]

let calculate_ema_from_weekly data period =
  let prices =
    Array.of_list (List.map ~f:(fun d -> d.Types.Daily_price.close_price) data)
  in
  match ema prices period with
  | Ok result ->
      let dates = List.map ~f:(fun d -> d.Types.Daily_price.date) data in
      List.map2_exn
        (List.drop dates (period - 1))
        (Array.to_list result)
        ~f:(fun date value -> { date; value })
  | Error msg -> failwith msg

let calculate_ema_from_daily data period =
  let weekly_data = Time_period_conversion.daily_to_weekly data in
  calculate_ema_from_weekly weekly_data period
