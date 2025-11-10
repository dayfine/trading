open Trading_base.Types
open Status
open Types

type order_filter =
  | BySymbol of symbol
  | ByStatus of order_status
  | BySide of side
  | ActiveOnly
[@@deriving show, eq]

type order_manager = { orders : (order_id, order) Hashtbl.t }

let _initial_size = 100
let create () = { orders = Hashtbl.create _initial_size }

let submit_orders manager orders =
  List.map
    (fun order ->
      if Hashtbl.mem manager.orders order.id then
        error_invalid_argument ("Order with ID " ^ order.id ^ " already exists")
      else (
        Hashtbl.add manager.orders order.id order;
        Result.Ok ()))
    orders

let cancel_orders manager order_ids =
  List.map
    (fun order_id ->
      match Hashtbl.find_opt manager.orders order_id with
      | None -> error_not_found ("Order with ID " ^ order_id ^ " not found")
      | Some order ->
          if not (is_active order) then
            error_invalid_argument ("Order " ^ order_id ^ " is not active")
          else
            let cancelled_order = update_status order Cancelled in
            Hashtbl.replace manager.orders order_id cancelled_order;
            Result.Ok ())
    order_ids

let get_order manager order_id =
  match Hashtbl.find_opt manager.orders order_id with
  | None -> error_not_found ("Order with ID " ^ order_id ^ " not found")
  | Some order -> Result.Ok order

let matches_filter order = function
  | BySymbol symbol -> order.symbol = symbol
  | ByStatus status -> order.status = status
  | BySide side -> order.side = side
  | ActiveOnly -> is_active order

let list_orders ?filter manager =
  match filter with
  | None -> Hashtbl.fold (fun _ order acc -> order :: acc) manager.orders []
  | Some f ->
      Hashtbl.fold
        (fun _ order acc ->
          if matches_filter order f then order :: acc else acc)
        manager.orders []

let update_order manager order =
  match Hashtbl.find_opt manager.orders order.id with
  | None -> error_not_found ("Order with ID " ^ order.id ^ " not found")
  | Some _ ->
      Hashtbl.replace manager.orders order.id order;
      Result.Ok ()
