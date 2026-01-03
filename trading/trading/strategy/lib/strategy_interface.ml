(** Strategy interface - pure interface definition *)

open Core

type indicator_name = string
type get_price_fn = string -> Types.Daily_price.t option
type get_indicator_fn = string -> indicator_name -> int -> float option
type state = { positions : Position.t String.Map.t }

let equal_state s1 s2 = Map.equal Position.equal s1.positions s2.positions

type output = { transitions : Position.transition list } [@@deriving show, eq]

module type STRATEGY = sig
  val on_market_close :
    get_price:get_price_fn ->
    get_indicator:get_indicator_fn ->
    positions:Position.t String.Map.t ->
    output Status.status_or

  val name : string
end
