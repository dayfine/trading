(** Strategy interface - pure interface definition *)

open Core

type indicator_name = string
(** Indicator name (e.g., "EMA", "SMA", "RSI") *)

type get_price_fn = string -> Types.Daily_price.t option
(** Function to get price for a symbol.

    Arguments:
    - symbol: Stock ticker (e.g., "AAPL", "GOOGL")

    Returns: Some price data if available, None otherwise *)

type get_indicator_fn =
  string -> indicator_name -> int -> Types.Cadence.t -> float option
(** Function to get an indicator value.

    Arguments:
    - symbol: Stock ticker (e.g., "AAPL")
    - indicator_name: Indicator type (e.g., "EMA", "SMA")
    - period: Lookback period (e.g., 20 for 20-period EMA)
    - cadence: Time cadence (Daily, Weekly, Monthly)

    Returns: Some value if indicator can be computed, None otherwise *)

type output = { transitions : Position.transition list } [@@deriving show, eq]

module type STRATEGY = sig
  val on_market_close :
    get_price:get_price_fn ->
    get_indicator:get_indicator_fn ->
    positions:Position.t String.Map.t ->
    output Status.status_or

  val name : string
end
