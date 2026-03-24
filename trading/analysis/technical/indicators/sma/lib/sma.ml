open Core
open Indicator_types

let calculate_sma (data : indicator_value list) (period : int) :
    indicator_value list =
  if period <= 0 then invalid_arg "SMA period must be positive";
  let n = List.length data in
  if n < period then []
  else
    List.init (n - period + 1) ~f:(fun i ->
        let window = List.sub data ~pos:i ~len:period in
        let sum = List.sum (module Float) window ~f:(fun v -> v.value) in
        let date = (List.last_exn window).date in
        { date; value = sum /. Float.of_int period })

let calculate_weighted_ma (data : indicator_value list) (period : int) :
    indicator_value list =
  if period <= 0 then invalid_arg "WMA period must be positive";
  let n = List.length data in
  if n < period then []
  else
    let weight_sum = Float.of_int (period * (period + 1) / 2) in
    List.init (n - period + 1) ~f:(fun i ->
        let window = List.sub data ~pos:i ~len:period in
        let weighted_sum =
          List.foldi window ~init:0.0 ~f:(fun j acc v ->
              (* weight: j=0 is oldest (weight 1), j=period-1 is newest (weight period) *)
              acc +. (v.value *. Float.of_int (j + 1)))
        in
        let date = (List.last_exn window).date in
        { date; value = weighted_sum /. weight_sum })
