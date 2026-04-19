(** Pure compute helpers for the Full tier — see [full_compute.mli]. *)

open Core

type config = { tail_days : int } [@@deriving sexp, show, eq]

(** Default tail: ~7 years of trading days. Enough to hold a 30-week MA plus
    several years of daily path history — the shape the Weinstein pipeline
    expects for breakout detection and path simulation. *)
let default_config = { tail_days = 1800 }

type full_values = { bars : Types.Daily_price.t list; as_of : Date.t }
[@@deriving show, eq]

let compute_values ~bars =
  match List.last bars with
  | None -> None
  | Some last -> Some { bars; as_of = last.Types.Daily_price.date }
