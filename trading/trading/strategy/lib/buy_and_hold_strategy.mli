(** Buy and Hold strategy - Enter position once and hold indefinitely *)

type config = {
  symbols : string list;  (** Symbols to buy and hold *)
  position_size : float;  (** Number of shares to buy per symbol *)
  entry_date : Core.Date.t option;
      (** Optional specific entry date. If None, enter on first signal *)
}
[@@deriving show, eq]
(** Strategy configuration *)

type state = {
  config : config;
  positions : Position.t Core.String.Map.t;
      (** Positions indexed by symbol (max one per symbol) *)
  entries_executed : bool Core.String.Map.t;
      (** Track which symbols have been entered *)
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
