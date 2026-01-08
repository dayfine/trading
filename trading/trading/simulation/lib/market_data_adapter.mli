(** Market data adapter for strategies

    This module adapts the simulator's price data into the format expected by
    trading strategies. It provides accessor functions that match the
    Strategy_interface requirements while preventing lookahead bias by only
    returning data up to the current simulation date.

    {1 Overview}

    The adapter bridges the gap between:
    - Simulator's format: [symbol_prices list] with all historical data
    - Strategy's format: [get_price_fn] and [get_indicator_fn] closures

    {1 Lookahead Prevention}

    The adapter tracks the current simulation date and ensures strategies can
    only access data up to (and including) that date. This prevents lookahead
    bias during backtesting.

    {1 Usage Example}

    {[
      let adapter =
        Market_data_adapter.create
          ~prices:simulator.deps.prices
          ~current_date:simulator.current_date
      in

      (* Get price for a symbol at current date *)
      let price_opt = Market_data_adapter.get_price adapter "AAPL" in

      (* Get indicator value at current date *)
      let ema_opt =
        Market_data_adapter.get_indicator adapter "AAPL" "EMA" 20
      in
    ]} *)

open Core

type t
(** Market data adapter instance *)

val create :
  prices:Simulator.symbol_prices list -> current_date:Date.t -> t
(** Create a market data adapter from simulator's price data

    @param prices
      List of symbol prices from simulator dependencies
    @param current_date Current simulation date (for lookahead prevention) *)

val get_price : t -> string -> Types.Daily_price.t option
(** Get price data for a symbol at the current date

    Returns [None] if:
    - Symbol is not found in the price data
    - No price data exists for the current date
    - The current date is in the future relative to available data

    @param adapter The market data adapter
    @param symbol The trading symbol (e.g., "AAPL")
    @return [Some price] if available at current date, [None] otherwise *)

val get_indicator : t -> string -> string -> int -> float option
(** Get indicator value for a symbol at the current date

    In Change 1, this always returns [None]. Will be implemented in Change 2.

    @param adapter The market data adapter
    @param symbol The trading symbol (e.g., "AAPL")
    @param indicator_name The indicator type (e.g., "EMA", "SMA")
    @param period The indicator period (e.g., 20 for 20-period EMA)
    @return [Some value] if available, [None] otherwise *)
