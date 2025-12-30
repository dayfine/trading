(** Strategy abstraction and dispatch *)

open Core

type output = { transitions : Position.transition list }
[@@deriving show, eq]
(** Common output type for all strategies *)

(** Abstract strategy module signature *)
module type STRATEGY = sig
  type config [@@deriving show, eq]
  type state

  val init : config:config -> state

  val on_market_close :
    market_data:'a ->
    get_price:('a -> string -> Types.Daily_price.t option) ->
    get_indicator:('a -> string -> string -> int -> float option) ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (output * state) Status.status_or

  val name : string
end

(** Packed strategy type for value-based dispatch *)
type t =
  | EmaStrategy of { config : Ema_strategy.config; state : Ema_strategy.state }
  | BuyAndHoldStrategy of {
      config : Buy_and_hold_strategy.config;
      state : Buy_and_hold_strategy.state;
    }

(** Execute a strategy's on_market_close logic *)
let execute ~market_data ~get_price ~get_indicator ~portfolio strategy =
  (* Helper to get EMA for backwards compatibility *)
  let get_ema market_data symbol period =
    get_indicator market_data symbol "EMA" period
  in
  match strategy with
  | EmaStrategy { config; state } ->
      let open Result.Let_syntax in
      let%bind ema_output, new_state =
        Ema_strategy.on_market_close ~market_data ~get_price ~get_ema ~portfolio
          ~state
      in
      let output = { transitions = ema_output.Ema_strategy.transitions } in
      return (output, EmaStrategy { config; state = new_state })
  | BuyAndHoldStrategy { config; state } ->
      let open Result.Let_syntax in
      let%bind bh_output, new_state =
        Buy_and_hold_strategy.on_market_close ~market_data ~get_price ~get_ema
          ~portfolio ~state
      in
      let output = { transitions = bh_output.Buy_and_hold_strategy.transitions } in
      return (output, BuyAndHoldStrategy { config; state = new_state })

(** Strategy configuration *)
type config =
  | EmaConfig of Ema_strategy.config
  | BuyAndHoldConfig of Buy_and_hold_strategy.config
[@@deriving show]

(** Create strategy from config *)
let create_strategy = function
  | EmaConfig cfg ->
      let state = Ema_strategy.init ~config:cfg in
      EmaStrategy { config = cfg; state }
  | BuyAndHoldConfig cfg ->
      let state = Buy_and_hold_strategy.init ~config:cfg in
      BuyAndHoldStrategy { config = cfg; state }

(** Get strategy name *)
let get_name = function
  | EmaStrategy _ -> Ema_strategy.name
  | BuyAndHoldStrategy _ -> Buy_and_hold_strategy.name
