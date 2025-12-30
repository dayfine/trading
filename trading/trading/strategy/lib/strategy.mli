(** Strategy abstraction and polymorphic dispatch

    This module provides a unified interface for all trading strategies, enabling
    polymorphic strategy execution through value-based dispatch.

    {1 Design Philosophy}

    Strategies are self-contained decision-making units that:
    - Observe market data and portfolio state
    - Make trading decisions (entry/exit signals)
    - Generate position transitions and trading orders
    - Maintain their own internal state

    The strategy abstraction separates {i what} a strategy does (trading logic)
    from {i how} it's executed (dispatch mechanism), allowing different strategy
    implementations to be used interchangeably.

    {1 Key Concepts}

    {b Strategy State}: Each strategy maintains its own state (positions, indicators,
    counters, etc.). The state is immutable - [on_market_close] returns a new state.

    {b Position Transitions}: Strategies generate [Position.transition] events that
    describe desired position lifecycle changes (e.g., EntryFill, TriggerExit). These
    transitions are applied to positions to update their state.

    {b Trading Orders}: Strategies also generate trading orders (buy/sell) that represent
    the actual market instructions needed to execute the strategy's decisions.

    {b Value-Based Dispatch}: The [t] type is a GADT variant that packages different
    strategy types together, enabling polymorphic execution while preserving type safety.

    {1 Usage Example}

    {[
      (* Create different strategies *)
      let ema_config = { symbol = "AAPL"; ema_period = 20; ... } in
      let bh_config = { symbol = "MSFT"; position_size = 100.0; ... } in

      let strategies = [
        Strategy.create_ema ~config:ema_config;
        Strategy.create_buy_and_hold ~config:bh_config;
      ] in

      (* Execute all strategies uniformly *)
      let results = List.map strategies ~f:(fun strategy ->
        Strategy.execute ~market_data ~get_price ~get_ema ~portfolio strategy
      ) in
    ]} *)


(** Common output type for all strategies *)
type output = {
  transitions : Position.transition list;
      (** Position state transitions to apply.

          These transitions describe the intended changes to position states
          (e.g., EntryFill, ExitComplete). The simulation engine or live trading
          system will apply these transitions to update position states.

          Example: [EntryFill { position_id = "AAPL-1"; filled_quantity = 100.0; ... }]
          tells the system that 100 shares were filled for position AAPL-1.

          Note: Trading orders are generated separately from transitions using
          {!Order_generator.from_transitions}. This separates strategy decisions
          (what to do) from execution details (how to do it). *) }
[@@deriving show, eq]

(** Abstract strategy module signature *)
module type STRATEGY = sig
  type config [@@deriving show, eq]
  (** Strategy-specific configuration *)

  type state
  (** Strategy-specific state *)

  val init : config:config -> state
  (** Initialize strategy with configuration *)

  val on_market_close :
    market_data:'a ->
    get_price:('a -> string -> Types.Daily_price.t option) ->
    get_indicator:('a -> string -> string -> int -> float option) ->
    portfolio:Trading_portfolio.Portfolio.t ->
    state:state ->
    (output * state) Status.status_or
  (** Execute strategy logic after market close

      Called once per trading day after the market closes to make trading decisions.

      {b Important}: The returned state reflects the strategy's view AFTER the proposed
      transitions have been applied. For example, if the strategy decides to enter a
      position, the returned state will have [active_position = Some position] where
      the position is already in the Holding state (after EntryFill + EntryComplete
      transitions).

      This means:
      - Input [state]: Current state before this day's decisions
      - Output [state]: Expected state after transitions are applied
      - Output [transitions]: The transitions needed to achieve the new state
      - Output [orders]: The market orders to execute those transitions

      The caller (simulation engine or live trading system) is responsible for:
      1. Applying the transitions to update position states
      2. Submitting orders to the market/broker
      3. Feeding the new state back into the next [on_market_close] call

      @param market_data Generic market data source
      @param get_price Function to retrieve price for a symbol
      @param get_indicator Function to retrieve indicator value (symbol, indicator_name, period)
          Example: [get_indicator market_data "AAPL" "EMA" 20] returns 20-period EMA
      @param portfolio Current portfolio state (positions, cash, etc.)
      @param state Current strategy state (before today's decisions)
      @return (output, new_state) where:
          - output contains transitions and orders to execute
          - new_state is the expected state after transitions are applied *)

  val name : string
  (** Strategy name for identification *)
end

(** Packed strategy type for value-based dispatch *)
type t =
  | EmaStrategy of { config : Ema_strategy.config; state : Ema_strategy.state }
  | BuyAndHoldStrategy of {
      config : Buy_and_hold_strategy.config;
      state : Buy_and_hold_strategy.state;
    }

(** Strategy configuration - aggregates all strategy types *)
type config =
  | EmaConfig of Ema_strategy.config
  | BuyAndHoldConfig of Buy_and_hold_strategy.config
[@@deriving show]

val create_strategy : config -> t
(** Create a strategy from configuration

    Performs dispatch based on config type and initializes the strategy state.

    Example:
    {[
      let ema_cfg = { symbol = "AAPL"; ema_period = 20; ... } in
      let strategy = create_strategy (EmaConfig ema_cfg)
    ]} *)

val execute :
  market_data:'a ->
  get_price:('a -> string -> Types.Daily_price.t option) ->
  get_indicator:('a -> string -> string -> int -> float option) ->
  portfolio:Trading_portfolio.Portfolio.t ->
  t ->
  (output * t) Status.status_or
(** Execute a strategy's on_market_close logic *)

val get_name : t -> string
(** Get strategy name *)
