(** Engine-specific types for order execution *)

open Trading_base.Types

(** OHLC price bar for a symbol.

    The bar represents price action over a time period (e.g., daily, hourly).
    The engine simulates execution by generating intraday paths through the OHLC
    points to determine if/when orders would fill.

    TODO: Add configurable bar granularity (daily, hourly, minute) TODO: Add
    volume data for more realistic execution modeling *)
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

type path_point = { price : price } [@@deriving show, eq]
(** A point along the intraday price path.

    The path is an ordered sequence, so timing is implicit from list position.
*)

type intraday_path = path_point list [@@deriving show, eq]
(** An intraday price path is a sequence of points showing how price evolved
    during the bar period.

    The engine generates this path from OHLC bars to simulate realistic order
    execution. The path ensures we visit all OHLC points in a plausible order.
    Path resolution (number of points) is configurable via
    path_config.total_points (default: 390, representing 1-minute bars for a
    6.5hr trading day). *)

type fill_result = { price : price } [@@deriving show, eq]
(** Result of checking if an order would fill on a given path.

    Contains the fill price. *)

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

type engine_config = { commission : commission_config } [@@deriving show, eq]
(** Engine configuration controlling execution behavior and costs.

    Note: Slippage is naturally modeled by the granularity of the intraday price
    path (~390 points per day). Stop and market orders fill at the current path
    point price when triggered, giving realistic slippage based on path
    resolution. *)
