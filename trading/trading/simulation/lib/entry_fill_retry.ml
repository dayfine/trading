(** G2a entry-fill retry — see [entry_fill_retry.mli]. *)

open Core
module Position = Trading_strategy.Position

type t = { max_retries : int; used : int String.Table.t }

let create ~max_retries = { max_retries; used = String.Table.create () }

let retries_used t ~position_id =
  Hashtbl.find t.used position_id |> Option.value ~default:0

(* Suffix marking a re-offered copy. Chosen to be absent from
   [Order_generator._make_id]'s "<date>-<seq>" alphabet so the base id can
   always be recovered by stripping at the first occurrence. *)
let _retry_suffix = "#retry"

let _base_order_id order_id =
  match String.substr_index order_id ~pattern:_retry_suffix with
  | None -> order_id
  | Some i -> String.prefix order_id i

let retry_order_id ~order_id ~attempt =
  sprintf "%s%s%d" (_base_order_id order_id) _retry_suffix attempt

(* True when [pos] is a resting ticket that [trade] could be a refused entry
   fill of: [Entering], same symbol, and a trade side that {e opens} a position
   of that side ([Fill_router.entry_trade_side] — a long ticket rests as a Buy,
   a short as a Sell).

   The side check (#2466) is what keeps a rejected {e exit} off this path. Were
   an [Exiting] and an [Entering] to coexist on one symbol, symbol-and-state
   matching alone would let a refused Sell claim the long ticket's budget and
   re-submit a copy of the {e exit} order — which, once the exit is separately
   reverted to [Holding] and its stop re-fires, leaves two live sell orders for
   one position. That pairing is unreachable under the shipped Weinstein
   strategy ([Entry_walk.held_symbols] counts [Exiting] as held), and the whole
   module is inert at the default budget, so this changes no run; it is enforced
   because the module is strategy-agnostic and must not rely on a caller's
   invariant.

   Split from [_entering_position_id] rather than written as a [when] guard on
   its [find_map]: the guard form trips the nesting linter. *)
let _is_ticket_for ~(trade : Trading_base.Types.trade) (pos : Position.t) =
  match pos.state with
  | Entering _ ->
      String.equal pos.symbol trade.symbol
      && Trading_base.Types.equal_side trade.side
           (Fill_router.entry_trade_side pos.side)
  | _ -> false

(* The id of the ticket [trade] belongs to, if any. First match wins, as
   {!Cancel_handler} does — with the side check above, at most one open ticket
   per (symbol, side) can qualify. *)
let _entering_position_id ~positions ~trade =
  Map.to_alist positions
  |> List.find ~f:(fun (_, pos) -> _is_ticket_for ~trade pos)
  |> Option.map ~f:fst

(* A fresh, unfilled copy of [order] under [id]. Everything the engine matches
   on is carried over verbatim — in particular a [StopLimit]'s trigger and cap,
   so the retry offers the same do-not-chase terms the original did. *)
let _retry_copy ~id (order : Trading_orders.Types.order) =
  {
    order with
    id;
    status = Trading_orders.Types.Pending;
    filled_quantity = 0.0;
    avg_fill_price = None;
  }

(* True when the manager accepted the copy. *)
let _submit_copy ~order_manager ~id order =
  match
    Trading_orders.Manager.submit_orders order_manager [ _retry_copy ~id order ]
  with
  | [ Ok () ] -> true
  | _ -> false

(* Re-submit a copy of the order [trade] came from. [false] when the order is
   unknown to the manager or the manager refuses the copy — in which case the
   caller falls back to cancelling, so a refusal here can never strand a
   ticket. *)
let _reoffer ~order_manager ~attempt (trade : Trading_base.Types.trade) =
  match Trading_orders.Manager.get_order order_manager trade.order_id with
  | Error _ -> false
  | Ok order ->
      _submit_copy ~order_manager
        ~id:(retry_order_id ~order_id:trade.order_id ~attempt)
        order

(* Spend one retry on [trade], whose ticket is [position_id]. [None] means the
   ticket was put back and the caller must drop the trade from its cancel list;
   [Some trade] means the re-offer failed and the ticket dies as it does today,
   without consuming budget. *)
let _spend_retry t ~order_manager ~position_id trade =
  let attempt = retries_used t ~position_id + 1 in
  if _reoffer ~order_manager ~attempt trade then (
    Hashtbl.set t.used ~key:position_id ~data:attempt;
    None)
  else Some trade

(* Decide one refused trade: [None] to retry it, [Some trade] to let it die. *)
let _handle_one t ~order_manager ~positions (trade : Trading_base.Types.trade) =
  match _entering_position_id ~positions ~trade with
  | Some position_id when retries_used t ~position_id < t.max_retries ->
      _spend_retry t ~order_manager ~position_id trade
  | Some _ | None -> Some trade

let handle_rejected_entries t ~order_manager ~positions ~rejected_trades =
  (* R1: the default budget returns the input list itself — no ledger write, no
     order-manager call, no allocation the pre-G2a path did not make. *)
  if t.max_retries <= 0 then rejected_trades
  else
    List.filter_map rejected_trades ~f:(_handle_one t ~order_manager ~positions)
