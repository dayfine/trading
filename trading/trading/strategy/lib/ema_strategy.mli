(** EMA crossover strategy *)

type config = {
  symbols : string list;  (** Symbols to trade *)
  ema_period : int;
  stop_loss_percent : float;  (** e.g., 0.05 = -5% *)
  take_profit_percent : float;  (** e.g., 0.10 = +10% *)
  position_size : float;  (** Number of shares to trade per symbol *)
}
[@@deriving show, eq]
(** Strategy configuration *)

type state = {
  config : config;
  positions : Position.t Core.String.Map.t;
      (** Active positions indexed by symbol (max one per symbol) *)
}
(** Strategy state *)

type output = { transitions : Position.transition list }
(** Strategy output - same structure as Strategy.output *)

val init : config:config -> state
(** Initialize strategy *)

val on_market_close :
  market_data:'a ->
  get_price:('a -> string -> Types.Daily_price.t option) ->
  get_ema:('a -> string -> int -> float option) ->
  portfolio:Trading_portfolio.Portfolio.t ->
  state:state ->
  (output * state) Status.status_or
(** Execute strategy logic after market close *)

val name : string
(** Strategy name *)
