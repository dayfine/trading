(** Engine-specific types for order execution *)

open Trading_base.Types

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
