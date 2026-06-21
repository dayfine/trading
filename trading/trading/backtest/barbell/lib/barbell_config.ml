open Core

type t = {
  enable : bool; [@sexp.default false]
  floor_weight : float; [@sexp.default 0.0]
  rebalance_weeks : int; [@sexp.default 1]
}
[@@deriving sexp, eq, show]

let default = { enable = false; floor_weight = 0.0; rebalance_weeks = 1 }
let _days_per_week = 7
let rebalance_stride_days t = Int.max 1 (t.rebalance_weeks * _days_per_week)

let validate t =
  if Float.( < ) t.floor_weight 0.0 || Float.( > ) t.floor_weight 1.0 then
    Error
      (Printf.sprintf "floor_weight must be in [0.0, 1.0]: %f" t.floor_weight)
  else if t.rebalance_weeks < 1 then
    Error (Printf.sprintf "rebalance_weeks must be >= 1: %d" t.rebalance_weeks)
  else Ok ()
