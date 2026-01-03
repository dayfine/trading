(** Strategy interface - pure interface definition *)

type indicator_name = string
type get_price_fn = string -> Types.Daily_price.t option
type get_indicator_fn = string -> indicator_name -> int -> float option
type output = { transitions : Position.transition list } [@@deriving show, eq]

module type STRATEGY = sig
  type state

  val on_market_close :
    get_price:get_price_fn ->
    get_indicator:get_indicator_fn ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (output * state) Status.status_or

  val name : string
end
