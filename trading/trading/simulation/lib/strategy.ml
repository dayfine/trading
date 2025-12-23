(** Strategy interface for pluggable trading algorithms *)

(** {1 Strategy Output} *)

type strategy_output = {
  intent_actions : Intent.intent_action list;
  orders_to_submit : Trading_orders.Types.order list;
}
[@@deriving show, eq]

(** {1 Strategy Module Signature} *)

module type STRATEGY = sig
  type config
  type state

  val name : string
  val init : config:config -> state

  val on_market_close :
    market_data:(module Market_data.MARKET_DATA with type t = 'a) ->
    market_data_instance:'a ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (strategy_output * state) Status.status_or
end
