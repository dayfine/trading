(** Order management interface for CRUD operations *)

open Trading_base.Types
open Status
open Types

type order_manager
(** Opaque type representing an order management system *)

val create : unit -> order_manager
(** Create a new order manager instance *)

val submit_order : order_manager -> order -> status
(** Submit a single order to the manager *)

val submit_orders : order_manager -> order list -> status list
(** Submit multiple orders at once. Returns list of results for each order *)

val cancel_order : order_manager -> order_id -> status
(** Cancel a single order by ID *)

val cancel_orders : order_manager -> order_id list -> status list
(** Cancel multiple orders by ID. Returns list of results for each order *)

val get_order : order_manager -> order_id -> order status_or
(** Retrieve an order by ID *)

(** List orders with optional filters *)
type order_filter =
  | BySymbol of symbol
  | ByStatus of order_status
  | BySide of side
  | ActiveOnly
[@@deriving show, eq]

val list_orders : ?filter:order_filter -> order_manager -> order list
(** List all orders, optionally filtered *)

val cancel_all : order_manager -> unit
(** Cancel all active orders *)
