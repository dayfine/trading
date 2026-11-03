(** See .mli. *)

open Core

let tolerance = 1e-6
let sell_stop_reached ~price ~stop = Float.( <= ) price (stop +. tolerance)
let buy_stop_reached ~price ~stop = Float.( >= ) price (stop -. tolerance)
