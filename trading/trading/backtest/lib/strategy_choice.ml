(** Strategy selector for {!Backtest.Runner} — see [strategy_choice.mli]. *)

open Core

type t =
  | Weinstein
  | Bah_benchmark of { symbol : string }
  | Spy_only_weinstein of { symbol : string }
[@@deriving sexp, eq, show]

let default = Weinstein

let name = function
  | Weinstein -> "Weinstein"
  | Bah_benchmark { symbol } -> sprintf "Bah_benchmark(%s)" symbol
  | Spy_only_weinstein { symbol } -> sprintf "Spy_only_weinstein(%s)" symbol
