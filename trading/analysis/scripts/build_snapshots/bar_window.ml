(** Inclusive date-windowing of a symbol's daily bars — see [bar_window.mli]. *)

open Core

let _at_or_after start (b : Types.Daily_price.t) = Date.( >= ) b.date start
let _at_or_before end_ (b : Types.Daily_price.t) = Date.( <= ) b.date end_

let filter ?start ?end_ bars =
  let bars =
    match start with
    | None -> bars
    | Some start -> List.filter bars ~f:(_at_or_after start)
  in
  match end_ with
  | None -> bars
  | Some end_ -> List.filter bars ~f:(_at_or_before end_)
