(** Strategy factory and execution

    This module provides factory functions for creating strategies and
    polymorphic execution without pattern matching.

    {1 Usage Example}

    {[
      (* Create strategies using factory *)
      let strategies = [
        Strategy.create_strategy (Strategy.EmaConfig {
          symbols = ["AAPL"]; ema_period = 20; ...
        });
        Strategy.create_strategy (Strategy.BuyAndHoldConfig {
          symbols = ["MSFT"]; position_size = 100.0; ...
        });
      ] in

      (* Execute uniformly - no pattern matching needed *)
      (* Partially apply market_data to accessor functions *)
      let get_price_fn = get_price market_data in
      let get_indicator_fn = get_indicator market_data in
      let results = List.map strategies ~f:(fun strategy ->
        Strategy.use_strategy ~get_price:get_price_fn ~get_indicator:get_indicator_fn
          ~portfolio strategy
      ) in
    ]} *)

include module type of Strategy_interface
(** Re-export interface types for convenience *)

type t
(** Packed strategy type

    Encapsulates any strategy implementation with its config and state. The
    internal representation is abstract - strategies are executed through
    {!use_strategy} without pattern matching. *)

(** Strategy configuration - aggregates all strategy types

    Each variant corresponds to a concrete strategy implementation. The specific
    config types are defined in the respective strategy modules. *)
type config =
  | EmaConfig of Ema_strategy.config
  | BuyAndHoldConfig of Buy_and_hold_strategy.config
[@@deriving show]
(** Strategy configuration - wraps concrete strategy configs

    Instead of duplicating config structure, this type directly references the
    config types from individual strategy modules. *)

val create_strategy : config -> t
(** Create a strategy from configuration

    Performs dispatch based on config type and initializes the strategy state.

    Example:
    {[
      let ema_cfg : Ema_strategy.config =
        {
          symbols = [ "AAPL" ];
          ema_period = 20;
          stop_loss_percent = 0.05;
          take_profit_percent = 0.10;
          position_size = 100.0;
        }
      in
      let strategy = create_strategy (EmaConfig ema_cfg)
    ]} *)

val use_strategy :
  get_price:get_price_fn ->
  get_indicator:get_indicator_fn ->
  portfolio:Trading_portfolio.Portfolio.t ->
  t ->
  (output * t) Status.status_or
(** Execute a strategy's logic without pattern matching

    This function dispatches to the appropriate strategy implementation
    transparently, without requiring the caller to know which specific strategy
    is being executed.

    The accessor functions should already have market_data partially applied.
    Example:
    {[
      let get_price_fn = get_price market_data in
      let get_indicator_fn = get_indicator market_data in
      use_strategy ~get_price:get_price_fn ~get_indicator:get_indicator_fn
        ~portfolio strategy
    ]} *)

val get_name : t -> string
(** Get strategy name *)
