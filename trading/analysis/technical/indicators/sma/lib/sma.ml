open Core
open Indicator_types

(* Shared sliding-window MA implementation.  [weight_fn j] returns the weight
   for position [j] within a window, where [j=0] is the oldest observation. *)
let _compute_window_value window ~weight_fn =
  let weighted_sum =
    List.foldi window ~init:0.0 ~f:(fun j acc v ->
        acc +. (v.value *. weight_fn j))
  in
  let weight_total =
    List.foldi window ~init:0.0 ~f:(fun j acc _ -> acc +. weight_fn j)
  in
  let date = (List.last_exn window).date in
  { date; value = weighted_sum /. weight_total }

let _calculate_ma (data : indicator_value list) (period : int)
    ~(weight_fn : int -> float) ~error_label : indicator_value list =
  if period <= 0 then invalid_arg (error_label ^ " period must be positive");
  let n = List.length data in
  if n < period then []
  else
    List.init
      (n - period + 1)
      ~f:(fun i ->
        let window = List.sub data ~pos:i ~len:period in
        _compute_window_value window ~weight_fn)

let calculate_sma (data : indicator_value list) (period : int) :
    indicator_value list =
  _calculate_ma data period ~weight_fn:(fun _ -> 1.0) ~error_label:"SMA"

let calculate_weighted_ma (data : indicator_value list) (period : int) :
    indicator_value list =
  (* weight: j=0 is oldest (weight 1), j=period-1 is newest (weight period) *)
  _calculate_ma data period
    ~weight_fn:(fun j -> Float.of_int (j + 1))
    ~error_label:"WMA"
