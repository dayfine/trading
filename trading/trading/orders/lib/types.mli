(** Order types and related definitions *)

open Trading_base.Types

type order_id = string [@@deriving show, eq]
(** Unique identifier for an order *)

(** Time in force specifies how long an order remains active:
    - Day: Order expires at the end of the trading day
    - GTC: Good Till Cancelled, remains active until explicitly cancelled
    - IOC: Immediate Or Cancel, execute immediately or cancel
    - FOK: Fill Or Kill, must be filled completely immediately or cancelled *)
type time_in_force = Day | GTC | IOC | FOK [@@deriving show, eq]

(** Order status represents the current state of an order:
    - Pending: Order has been submitted but not yet executed
    - PartiallyFilled: Order has been partially executed with given quantity
    - Filled: Order has been completely executed
    - Cancelled: Order has been cancelled before completion
    - Rejected: Order was rejected by the broker with reason *)
type order_status =
  | Pending
  | PartiallyFilled of quantity
  | Filled
  | Cancelled
  | Rejected of string
[@@deriving show, eq]

type order = {
  id : order_id;  (** Unique order identifier *)
  symbol : symbol;  (** Trading symbol *)
  side : side;  (** Buy or Sell *)
  order_type : order_type;  (** Market, Limit, Stop, or StopLimit *)
  quantity : quantity;  (** Total quantity to trade *)
  time_in_force : time_in_force;  (** How long order remains active *)
  status : order_status;  (** Current order status *)
  filled_quantity : quantity;  (** Amount already filled *)
  avg_fill_price : price option;  (** Average price of fills, if any *)
  created_at : Time_ns_unix.t;  (** Time when order was created *)
  updated_at : Time_ns_unix.t;  (** Time when order was last updated *)
}
[@@deriving show, eq]
(** Core order record containing all order information *)

val update_status : order -> order_status -> order
(** Update the status of an order and refresh the updated timestamp *)

val is_active : order -> bool
(** Check if an order is currently active (Pending or PartiallyFilled) *)

val is_filled : order -> bool
(** Check if an order has been completely filled *)

val remaining_quantity : order -> quantity
(** Calculate the remaining unfilled quantity *)
