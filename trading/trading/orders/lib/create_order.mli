(** Module for creating orders from structured data *)

open Trading_base.Types
open Status
open Types

type order_params = {
  symbol : symbol;
  side : side;
  order_type : order_type;
  quantity : quantity;
  time_in_force : time_in_force;
}
[@@deriving show, eq]
(** Order creation parameters *)

val create_order : ?now_time:Time_ns_unix.t -> order_params -> order status_or
(** Create an order from structured parameters with validation *)
