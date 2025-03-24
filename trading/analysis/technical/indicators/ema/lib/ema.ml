open Core
open Ta_ocaml.Ta
open Indicator_types

let calculate_ema (data : indicator_value list) (period : int) :
    indicator_value list =
  let prices = Array.of_list (List.map ~f:(fun d -> d.value) data) in
  match ema prices period with
  | Ok result ->
      let dates = List.map ~f:(fun d -> d.date) data in
      List.map2_exn
        (List.drop dates (period - 1))
        (Array.to_list result)
        ~f:(fun date value -> { date; value })
  | Error msg -> failwith msg
