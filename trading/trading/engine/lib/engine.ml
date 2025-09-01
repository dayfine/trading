open Core
open Base

(** Trading engine for executing trades *)

(** Execution status of an order *)
type execution_status =
  | Pending
  | Filled of { price: price; quantity: quantity; time: time }
  | PartiallyFilled of { price: price; quantity: quantity; time: time }
  | Cancelled
  | Rejected of string
[@@deriving show, eq]

(** Order with execution status *)
type order = {
  id: string;
  symbol: symbol;
  side: side;
  order_type: order_type;
  quantity: quantity;
  status: execution_status;
  created_at: time;
} [@@deriving show, eq]

(** Trading engine state *)
type t = {
  orders: order list;
  next_order_id: int;
} [@@deriving show, eq]

(** Create a new trading engine *)
let create () = {
  orders = [];
  next_order_id = 1;
}

(** Generate a unique order ID *)
let generate_order_id engine =
  let id = sprintf "ORD_%06d" engine.next_order_id in
  (id, { engine with next_order_id = engine.next_order_id + 1 })

(** Submit an order to the engine *)
let submit_order engine symbol side order_type quantity =
  let (id, engine) = generate_order_id engine in
  let order = {
    id;
    symbol;
    side;
    order_type;
    quantity;
    status = Pending;
    created_at = Time.now ();
  } in
  (order, { engine with orders = order :: engine.orders })

(** Get all orders *)
let get_orders engine = engine.orders

(** Get order by ID *)
let get_order engine order_id =
  List.find engine.orders ~f:(fun order -> order.id = order_id)

(** Cancel an order *)
let cancel_order engine order_id =
  let orders = List.map engine.orders ~f:(fun order ->
    if order.id = order_id then
      { order with status = Cancelled }
    else
      order
  ) in
  { engine with orders }
