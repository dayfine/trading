open Trading_base.Types
open Status
open Types

type order_filter =
  | BySymbol of symbol
  | ByStatus of order_status
  | BySide of side
  | ActiveOnly
[@@deriving show, eq]

(* [orders] is the historical record (insert-only — Filled / Cancelled /
   Rejected orders persist for audit). [active_orders] mirrors only the
   currently-active subset (Pending + PartiallyFilled) so the per-step
   [list_orders ~filter:ActiveOnly] walk is bounded by current pending
   load instead of cumulative submissions. Without this index, hot-loop
   scenarios (e.g. Cell E h=2 on 15y, 4000+ submitted orders) pay an
   O(N) cumulative scan every simulator step — the dominant remaining
   per-day perf cost after PRs #1014 + #1015. *)
type order_manager = {
  orders : (order_id, order) Hashtbl.t;
  active_orders : (order_id, order) Hashtbl.t;
}

let _initial_size = 100

let create () =
  {
    orders = Hashtbl.create _initial_size;
    active_orders = Hashtbl.create _initial_size;
  }

(* Sync [active_orders] with the current status of [order]: insert/refresh
   when active, remove when no longer active. Idempotent. *)
let _sync_active manager order =
  if is_active order then Hashtbl.replace manager.active_orders order.id order
  else Hashtbl.remove manager.active_orders order.id

let submit_orders manager orders =
  List.map
    (fun order ->
      if Hashtbl.mem manager.orders order.id then
        error_invalid_argument ("Order with ID " ^ order.id ^ " already exists")
      else (
        Hashtbl.add manager.orders order.id order;
        _sync_active manager order;
        Result.Ok ()))
    orders

let _cancel_order manager order_id order =
  if not (is_active order) then
    error_invalid_argument ("Order " ^ order_id ^ " is not active")
  else
    let cancelled_order = update_status order Cancelled in
    Hashtbl.replace manager.orders order_id cancelled_order;
    _sync_active manager cancelled_order;
    Result.Ok ()

let cancel_orders manager order_ids =
  List.map
    (fun order_id ->
      match Hashtbl.find_opt manager.orders order_id with
      | None -> error_not_found ("Order with ID " ^ order_id ^ " not found")
      | Some order -> _cancel_order manager order_id order)
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

(* [ActiveOnly] walks [active_orders] (bounded by current pending count);
   every other branch walks the full audit table. *)
let list_orders ?filter manager =
  let collect tbl predicate =
    Hashtbl.fold
      (fun _ order acc -> if predicate order then order :: acc else acc)
      tbl []
  in
  match filter with
  | None -> collect manager.orders (fun _ -> true)
  | Some ActiveOnly -> collect manager.active_orders (fun _ -> true)
  | Some f -> collect manager.orders (fun o -> matches_filter o f)

let update_order manager order =
  match Hashtbl.find_opt manager.orders order.id with
  | None -> error_not_found ("Order with ID " ^ order.id ^ " not found")
  | Some _ ->
      Hashtbl.replace manager.orders order.id order;
      _sync_active manager order;
      Result.Ok ()
