(** Retry for portfolio-rejected entry fills. See [entry_retry.mli]. *)

open Core
module Position = Trading_strategy.Position
module Order_types = Trading_orders.Types

type t = {
  max_retries : int;
  order_manager : Trading_orders.Manager.order_manager;
  spent : int String.Table.t;
}

let create ~max_retries ~order_manager =
  { max_retries; order_manager; spent = String.Table.create () }

let retries_used t ~position_id =
  Hashtbl.find t.spent position_id |> Option.value ~default:0

(* The trade side that OPENS a position of this side: a long enters on a Buy, a
   short sells to open. Mirrors [Fill_router._entry_trade_side] and
   [Cancel_handler._entry_route_key]; kept local so this module depends on
   neither's internals. *)
let _entry_trade_side :
    Trading_base.Types.position_side -> Trading_base.Types.side = function
  | Long -> Buy
  | Short -> Sell

(* True if [pos] is an unfilled resting entry ticket that [trade] would have
   opened. See the .mli for why each of the three conjuncts is required. *)
let _is_retryable_ticket ~(trade : Trading_base.Types.trade) (pos : Position.t)
    =
  match pos.state with
  | Position.Entering { filled_quantity; _ } ->
      String.equal pos.symbol trade.symbol
      && Float.equal filled_quantity 0.0
      && Trading_base.Types.equal_side (_entry_trade_side pos.side) trade.side
  | _ -> false

(* The id of the resting entry ticket [trade] belongs to, if any. *)
let _ticket_id_for ~positions ~trade =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if _is_retryable_ticket ~trade pos then Some id else None)

(* The engine stamps [status = Filled] on match without touching
   [filled_quantity] (see [Engine._process_order_with_execution]), so that pair
   is the exact signature of the provisional fill this module reverses. *)
let _is_provisionally_filled (order : Order_types.order) =
  match order.status with
  | Order_types.Filled -> Float.equal order.filled_quantity 0.0
  | _ -> false

(* Put [trade]'s originating order back to [Pending]. Located by
   [trade.order_id] — the trade names its own order exactly, so unlike
   [Fill_router]'s fallback there is nothing to guess. [false] when the order is
   missing or is not the provisional fill above, in which case the caller must
   not claim the trade. *)
let _reinstate_order t (trade : Trading_base.Types.trade) =
  match Trading_orders.Manager.get_order t.order_manager trade.order_id with
  | Ok order when _is_provisionally_filled order ->
      let (_ : Status.status) =
        Trading_orders.Manager.update_order t.order_manager
          (Order_types.update_status order Order_types.Pending)
      in
      true
  | Ok _ | Error _ -> false

(* Claim [trade] for retry if its ticket has budget AND its order can be put
   back. Budget is charged only on success, so a trade refused by the order
   check still costs nothing and follows the normal cancel path. *)
let _claim t ~position_id trade =
  let used = retries_used t ~position_id in
  if used >= t.max_retries then false
  else if not (_reinstate_order t trade) then false
  else begin
    Hashtbl.set t.spent ~key:position_id ~data:(used + 1);
    true
  end

(* One fold step: accumulate the trades NOT claimed for retry, reversed. *)
let _step t ~positions unclaimed trade =
  match _ticket_id_for ~positions ~trade with
  | Some position_id when _claim t ~position_id trade -> unclaimed
  | Some _ | None -> trade :: unclaimed

let withhold_retryable t ~positions ~rejected_trades =
  if t.max_retries <= 0 then rejected_trades
  else List.rev (List.fold rejected_trades ~init:[] ~f:(_step t ~positions))
