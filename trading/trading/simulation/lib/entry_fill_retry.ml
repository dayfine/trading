(** G2a entry-fill retry — see [entry_fill_retry.mli]. *)

open Core
module Position = Trading_strategy.Position

type t = int String.Table.t

let create () : t = String.Table.create ()

let retries_used (ledger : t) ~position_id =
  Hashtbl.find ledger position_id |> Option.value ~default:0

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

(* The [Entering] position holding a ticket for [symbol], if any. Same
   (symbol, state) match {!Cancel_handler} uses to find the position a refused
   entry belongs to, so the two agree on which trades are entry rejections. *)
let _entering_position_id ~positions ~symbol =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, (pos : Position.t)) ->
      match pos.state with
      | Entering _ when String.equal pos.symbol symbol -> Some id
      | _ -> None)

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

(* Re-submit a copy of the order [trade] came from. Returns the attempt number
   consumed on success, [None] when the order is unknown to the manager or the
   manager refuses the copy — in which case the caller must fall back to
   cancelling, so a refusal here can never strand a ticket. *)
let _reoffer ~order_manager ~attempt (trade : Trading_base.Types.trade) =
  match Trading_orders.Manager.get_order order_manager trade.order_id with
  | Error _ -> None
  | Ok order -> (
      let id = retry_order_id ~order_id:trade.order_id ~attempt in
      match
        Trading_orders.Manager.submit_orders order_manager
          [ _retry_copy ~id order ]
      with
      | [ Ok () ] -> Some attempt
      | _ -> None)

(* Decide one refused trade: [None] to retry it (the caller drops it from the
   cancel list), [Some trade] to let it die as it does today. *)
let _handle_one ledger ~max_retries ~order_manager ~positions
    (trade : Trading_base.Types.trade) =
  match _entering_position_id ~positions ~symbol:trade.symbol with
  | None -> Some trade
  | Some position_id -> (
      let used = retries_used ledger ~position_id in
      if used >= max_retries then Some trade
      else
        match _reoffer ~order_manager ~attempt:(used + 1) trade with
        | None -> Some trade
        | Some attempt ->
            Hashtbl.set ledger ~key:position_id ~data:attempt;
            None)

let handle_rejected_entries ledger ~max_retries ~order_manager ~positions
    ~rejected_trades =
  (* R1: the default budget returns the input list itself — no ledger write, no
     order-manager call, no allocation the pre-G2a path did not make. *)
  if max_retries <= 0 then rejected_trades
  else
    List.filter_map rejected_trades
      ~f:(_handle_one ledger ~max_retries ~order_manager ~positions)
