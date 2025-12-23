(** Market data interface for strategy access to prices and indicators

    This module defines the interface that strategies use to access historical
    price data and technical indicators during backtesting.

    Note: The implementation of this interface (including data loading,
    preprocessing, and indicator computation) is handled by a separate data
    processing pipeline. This module only defines the contract.
*)

open Core

(** {1 Types} *)

(** Indicator value with date *)
type indicator_value = { date : Date.t; value : float } [@@deriving show, eq]

(** {1 Market Data Interface} *)

module type MARKET_DATA = sig
  type t
  (** Abstract market data view *)

  (** {2 Date Navigation} *)

  val current_date : t -> Date.t
  (** Get the current date in the simulation *)

  val advance : t -> date:Date.t -> t
  (** Advance to a new date, returning updated view.
      Only data up to the new date is visible (no lookahead). *)

  (** {2 Price Data Access} *)

  val get_price : t -> symbol:string -> Types.Daily_price.t option
  (** Get the latest price data for a symbol at current date *)

  val get_price_history :
    t -> symbol:string -> ?lookback_days:int -> unit -> Types.Daily_price.t list
  (** Get historical prices for a symbol (up to current date).

      @param lookback_days If provided, limit history to last N days.
                          If None, returns all available history.
      @return List of prices in chronological order (oldest first) *)

  (** {2 Technical Indicators} *)

  val get_ema : t -> symbol:string -> period:int -> float option
  (** Get EMA value for a symbol at current date.

      @param symbol The symbol to query
      @param period EMA period (e.g., 30 for 30-day EMA)
      @return EMA value at current date, or None if not available *)

  val get_ema_series :
    t ->
    symbol:string ->
    period:int ->
    ?lookback_days:int ->
    unit ->
    indicator_value list
  (** Get EMA series up to current date.

      @param lookback_days If provided, limit series to last N days
      @return List of EMA values in chronological order *)

  (** Future indicators can be added here:
      - get_sma : Simple Moving Average
      - get_rsi : Relative Strength Index
      - get_bollinger_bands : Bollinger Bands
      - get_macd : Moving Average Convergence Divergence
      etc.
  *)
end
