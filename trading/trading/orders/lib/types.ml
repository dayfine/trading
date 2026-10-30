open Sexplib0.Sexp_conv
open Trading_base.Types

type order_id = string [@@deriving show, eq, sexp]
type time_in_force = Day | GTC | IOC | FOK [@@deriving show, eq, sexp]

type order_status =
  | Pending
  | PartiallyFilled of quantity
  | Filled
  | Cancelled
  | Rejected of string
[@@deriving show, eq, sexp]

type order = {
  id : order_id;
  symbol : symbol;
  side : side;
  order_type : order_type;
  quantity : quantity;
  time_in_force : time_in_force;
  status : order_status;
  filled_quantity : quantity;
  avg_fill_price : price option;
  created_at : Utc_time.t;
  updated_at : Utc_time.t;
}
[@@deriving show, eq, sexp]

let update_status order new_status =
  { order with status = new_status; updated_at = Time_ns_unix.now () }

let is_active order =
  match order.status with
  | Pending | PartiallyFilled _ -> true
  | Filled | Cancelled | Rejected _ -> false

let is_filled order = match order.status with Filled -> true | _ -> false
let remaining_quantity order = order.quantity -. order.filled_quantity
