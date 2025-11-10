(** Engine-specific types for order execution and market simulation *)

open Trading_base.Types

type market_data = {
  symbol : symbol;
  bid : price option;  (** Best bid price (highest price buyers will pay) *)
  ask : price option;  (** Best ask price (lowest price sellers will accept) *)
  last : price option;  (** Last traded price *)
  timestamp : Time_ns_unix.t;  (** When this market data was recorded *)
}
[@@deriving show, eq]
(** Market data for a single symbol at a point in time. Contains bid/ask prices
    and last trade price for execution decisions. *)

(** Market state containing current market data for all symbols. Provides O(1)
    lookup of market data by symbol. *)
type market_state
(** Opaque type - internal implementation uses Hashtbl for efficiency *)

(** Fill status indicates whether an order execution was successful.
    - Filled: Order completely executed with trades generated
    - PartiallyFilled: Only part of order executed (not used in Phase 1-6)
    - Unfilled: Order could not be executed (e.g., limit price not met) *)
type fill_status = Filled | PartiallyFilled | Unfilled [@@deriving show, eq]

type execution_report = {
  order_id : string;  (** ID of the order that was executed *)
  status : fill_status;
      (** Whether order was filled, partially filled, or unfilled *)
  filled_quantity : quantity;  (** Total quantity that was filled *)
  remaining_quantity : quantity;  (** Quantity not filled (for partial fills) *)
  average_price : price option;
      (** Average execution price (None if unfilled) *)
  trades : trade list;  (** List of trades generated (empty if unfilled) *)
  timestamp : Time_ns_unix.t;  (** When execution was attempted *)
}
[@@deriving show, eq]
(** Execution report contains the result of attempting to execute an order.
    Includes fill status, executed trades, and execution details. *)

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
