(** Strategy interface - pure interface definition with no concrete
    implementations

    This module defines the contract that all trading strategies must follow. It
    contains only type definitions and signatures, with no dependencies on
    concrete strategy implementations. *)

(** {1 Market Data Access} *)

type indicator_name = string
(** Indicator name (e.g., "EMA", "SMA", "RSI") *)

type get_price_fn = string -> Types.Daily_price.t option
(** Function type for retrieving price data for a symbol

    The market data source is already captured in the function closure.

    Parameters:
    - [string]: Symbol (e.g., "AAPL")

    Returns [Some price] if price data is available, [None] otherwise *)

type get_indicator_fn =
  string -> indicator_name -> int -> Types.Cadence.t -> float option
(** Function type for retrieving indicator values

    The market data source is already captured in the function closure.

    Parameters:
    - [string]: Symbol (e.g., "AAPL")
    - [indicator_name]: Indicator type (e.g., "EMA", "SMA")
    - [int]: Period (e.g., 20 for 20-period EMA)
    - [Types.Cadence.t]: Time cadence (Daily, Weekly, Monthly)

    Returns [Some value] if indicator is available, [None] otherwise *)

(** {1 Strategy Output} *)

type output = {
  transitions : Position.transition list;
      (** Position state transitions to apply.

          These transitions describe all desired position state changes
          including creating new positions (CreateEntering), updating existing
          positions (TriggerExit, UpdateRiskParams), and handling fills
          (EntryFill, ExitFill). The simulation engine or live trading system
          will apply these transitions to update position states. *)
}
[@@deriving show, eq]
(** Common output type for all strategies *)

(** {1 Strategy Interface} *)

(** Abstract strategy module signature

    All trading strategies must implement this interface. Strategies are pure
    functions that analyze market data and current positions to produce
    transitions. *)
module type STRATEGY = sig
  val on_market_close :
    get_price:get_price_fn ->
    get_indicator:get_indicator_fn ->
    positions:Position.t Core.String.Map.t ->
    output Status.status_or
  (** Execute strategy logic after market close

      Called once per trading day after the market closes to make trading
      decisions. Market data is already captured in the accessor functions.

      Strategies are pure functions: given market data and current positions,
      they produce transitions. The caller (engine/tests) is responsible for
      tracking positions and applying transitions.

      @param get_price
        Function to retrieve price for a symbol (market data already captured)
      @param get_indicator
        Function to retrieve indicator value for a symbol (market data already
        captured)
      @param positions
        Current positions map (symbol -> position). Caller owns and manages this
        state.
      @return output containing transitions to execute *)

  val name : string
  (** Strategy name for identification *)
end
