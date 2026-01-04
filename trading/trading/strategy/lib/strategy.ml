(** Strategy factory and execution *)

open Core

include Strategy_interface
(** Re-export interface types *)

type t = {
  strategy_module : (module STRATEGY);
  name : string;
}
(** Packed strategy type - wraps a first-class STRATEGY module

    Strategies are stateless - positions are managed by the caller. **)

(** Execute strategy *)
let use_strategy ~(get_price : get_price_fn) ~(get_indicator : get_indicator_fn)
    ~(positions : Position.t String.Map.t) (strategy : t) : output Status.status_or =
  let (module S) = strategy.strategy_module in
  S.on_market_close ~get_price ~get_indicator ~positions

(** Strategy configuration - wraps concrete strategy configs *)
type config =
  | EmaConfig of Ema_strategy.config
  | BuyAndHoldConfig of Buy_and_hold_strategy.config
[@@deriving show]

(** Create strategy from config *)
let create_strategy (cfg : config) : t =
  match cfg with
  | EmaConfig cfg ->
      let strategy_module = Ema_strategy.make cfg in
      let (module S) = strategy_module in
      { strategy_module; name = S.name }
  | BuyAndHoldConfig cfg ->
      let strategy_module = Buy_and_hold_strategy.make cfg in
      let (module S) = strategy_module in
      { strategy_module; name = S.name }

(** Get strategy name *)
let get_name (strategy : t) : string = strategy.name
