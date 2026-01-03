(** Strategy factory and execution *)

open Core

include Strategy_interface
(** Re-export interface types *)

type t = {
  strategy_module : (module STRATEGY);
  state_ref : state ref;
  name : string;
}
(** Packed strategy type - wraps a first-class STRATEGY module with state

    All strategies now share the same state type (positions map), so no need for
    existential quantification. **)

(** Execute strategy *)
let use_strategy ~(get_price : get_price_fn) ~(get_indicator : get_indicator_fn)
    ~(portfolio : Trading_portfolio.Portfolio.t) (strategy : t) :
    (output * t) Status.status_or =
  let (module S) = strategy.strategy_module in
  let open Result.Let_syntax in
  let%bind output, new_state =
    S.on_market_close ~get_price ~get_indicator ~portfolio
      ~state:!(strategy.state_ref)
  in
  strategy.state_ref := new_state;
  return (output, strategy)

(** Strategy configuration - wraps concrete strategy configs *)
type config =
  | EmaConfig of Ema_strategy.config
  | BuyAndHoldConfig of Buy_and_hold_strategy.config
[@@deriving show]

(** Create strategy from config *)
let create_strategy (cfg : config) : t =
  match cfg with
  | EmaConfig cfg ->
      let strategy_module, initial_state = Ema_strategy.make cfg in
      let (module S) = strategy_module in
      { strategy_module; state_ref = ref initial_state; name = S.name }
  | BuyAndHoldConfig cfg ->
      let strategy_module, initial_state = Buy_and_hold_strategy.make cfg in
      let (module S) = strategy_module in
      { strategy_module; state_ref = ref initial_state; name = S.name }

(** Get strategy name *)
let get_name (strategy : t) : string = strategy.name
