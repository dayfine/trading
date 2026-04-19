open Core
open Types

let true_range ~prev_close (bar : Daily_price.t) : float =
  let range = bar.high_price -. bar.low_price in
  let gap_up = Float.abs (bar.high_price -. prev_close) in
  let gap_down = Float.abs (bar.low_price -. prev_close) in
  Float.max range (Float.max gap_up gap_down)

(* The first bar is skipped — TR is undefined without a prior close. Output
   length is [List.length bars - 1] for [bars] of length ≥ 2; empty otherwise. *)
let true_range_series (bars : Daily_price.t list) : float list =
  match bars with
  | [] | [ _ ] -> []
  | first :: rest ->
      let _, trs =
        List.fold rest ~init:(first.close_price, [])
          ~f:(fun (prev_close, acc) bar ->
            let tr = true_range ~prev_close bar in
            (bar.close_price, tr :: acc))
      in
      List.rev trs

let _average xs =
  let n = List.length xs in
  if n = 0 then 0.0 else List.fold xs ~init:0.0 ~f:( +. ) /. Float.of_int n

let atr ~period (bars : Daily_price.t list) : float option =
  if period <= 0 then invalid_arg "Atr.atr: period must be positive";
  if List.length bars < period + 1 then None
  else
    let trs = true_range_series bars in
    let n = List.length trs in
    if n < period then None
    else
      let window = List.sub trs ~pos:(n - period) ~len:period in
      Some (_average window)
