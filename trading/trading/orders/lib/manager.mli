(** Order management interface for CRUD operations *)

open Trading_base.Types
open Status
open Types

type order_manager
(** Opaque type representing an order management system *)

val create : unit -> order_manager
(** Create a new order manager instance *)

val submit_orders : order_manager -> order list -> status list
(** Submit orders to the manager. Returns list of results for each order - same
    length and order as input. Common errors: Already_exists (order ID already
    exists) *)

val cancel_orders : order_manager -> order_id list -> status list
(** Cancel orders by ID. Returns list of results for each order - same length
    and order as input. Common errors: NotFound (order doesn't exist),
    Invalid_argument (order not active) *)

val get_order : order_manager -> order_id -> order status_or
(** Retrieve an order by ID. Common errors: NotFound (order doesn't exist) *)

(** List orders with optional filters *)
type order_filter =
  | BySymbol of symbol
  | ByStatus of order_status
  | BySide of side
  | ActiveOnly
[@@deriving show, eq]

val list_orders : ?filter:order_filter -> order_manager -> order list
(** List all orders, optionally filtered *)
