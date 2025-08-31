(** Trading engine for executing trades *)

(** Execution status of an order *)
type execution_status =
  | Pending
  | Filled of { price: Base.price; quantity: Base.quantity; time: Base.time }
  | PartiallyFilled of { price: Base.price; quantity: Base.quantity; time: Base.time }
  | Cancelled
  | Rejected of string

(** Order with execution status *)
type order = {
  id: string;
  symbol: Base.symbol;
  side: Base.side;
  order_type: Base.order_type;
  quantity: Base.quantity;
  status: execution_status;
  created_at: Base.time;
}

(** Trading engine state *)
type t = {
  orders: order list;
  next_order_id: int;
}

(** Create a new trading engine *)
val create : unit -> t

(** Generate a unique order ID *)
val generate_order_id : t -> string * t

(** Submit an order to the engine *)
val submit_order : t -> Base.symbol -> Base.side -> Base.order_type -> Base.quantity -> order * t

(** Get all orders *)
val get_orders : t -> order list

(** Get order by ID *)
val get_order : t -> string -> order option

(** Cancel an order *)
val cancel_order : t -> string -> t
