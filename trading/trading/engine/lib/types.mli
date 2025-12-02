(** Engine-specific types for order execution *)

open Trading_base.Types

(** OHLC price bar for a symbol.

    The bar represents price action over a time period (e.g., daily, hourly).
    The engine simulates execution by generating intraday paths through the OHLC
    points to determine if/when orders would fill.

    TODO: Add configurable bar granularity (daily, hourly, minute)
    TODO: Add volume data for more realistic execution modeling *)
type price_bar = {
  symbol : symbol;
  open_price : price;
  high_price : price;
  low_price : price;
  close_price : price;
}
[@@deriving show, eq]
(** Price bar for a symbol with OHLC data *)

(** {1 Intraday Price Path Types} *)

(** Default resolution for intraday paths (390 sub-bars).

    For daily OHLC bars, this corresponds to 1-minute bars (6.5hr × 60min = 390).
    For hourly bars, each sub-bar would represent ~9 seconds.
    The abstraction allows the same path generation logic to work across timeframes. *)
val default_bar_resolution : int

(** A point along the intraday price path.

    bar_index ranges from 0 (bar open) to 389 (bar close) by default.
    For daily bars, each index represents a 1-minute sub-bar.
    For hourly bars, each index represents a ~9-second sub-bar. *)
type path_point = { bar_index : int; price : price } [@@deriving show, eq]

(** An intraday price path is a sequence of points showing how price evolved
    during the bar period.

    The engine generates this path from OHLC bars to simulate realistic
    order execution. The path ensures we visit all OHLC points in a plausible
    order. Default paths contain ~390 points. *)
type intraday_path = path_point list [@@deriving show, eq]

(** Result of checking if an order would fill on a given path.

    Contains the fill price and the bar_index when the fill would occur. *)
type fill_result = { price : price; bar_index : int } [@@deriving show, eq]

(** Fill status indicates whether an order execution was successful.
    - Filled: Order completely executed with trades generated
    - PartiallyFilled: Only part of order executed (not used in Phase 1-6)
    - Unfilled: Order could not be executed (e.g., limit price not met) *)
type fill_status = Filled | PartiallyFilled | Unfilled [@@deriving show, eq]

type execution_report = {
  order_id : string;  (** ID of the order that was executed *)
  status : fill_status;
      (** Whether order was filled, partially filled, or unfilled *)
  trades : trade list;  (** List of trades generated (empty if unfilled) *)
}
[@@deriving show, eq]
(** Execution report contains the result of attempting to execute an order.
    Additional details like filled_quantity, average_price can be derived from
    the trades list. *)

type commission_config = {
  per_share : float;  (** Commission per share traded *)
  minimum : float;  (** Minimum commission per trade *)
}
[@@deriving show, eq]
(** Commission configuration for calculating trading costs. Commissions are
    calculated as: max(per_share * quantity, minimum) *)

type engine_config = {
  commission : commission_config;  (** How to calculate trade commissions *)
}
[@@deriving show, eq]
(** Engine configuration controlling execution behavior and costs *)
