(** Order generator - converts strategy transitions to trading orders. See .mli
    for the entry fill-model contract (#2158 Phase 2). *)

open Core

(** Convert position side to order side for entry *)
let _entry_order_side (side : Trading_strategy.Position.position_side) =
  match side with
  | Long -> Trading_base.Types.Buy
  | Short -> Trading_base.Types.Sell

(** Convert position side to order side for exit (opposite of entry) *)
let _exit_order_side (side : Trading_strategy.Position.position_side) =
  match side with
  | Long -> Trading_base.Types.Sell
  | Short -> Trading_base.Types.Buy

(* G6 fix: order IDs are minted from scenario-time inputs (current_date + a
   per-call sequence index) so that two structurally identical simulations
   produce bit-identical IDs regardless of wall-clock or process forking.
   The IDs are hashtable keys in [Trading_orders.Manager.orders]; unstable
   IDs caused different bucket placement -> different [list_orders]
   iteration order in [Engine.process_orders] -> different fill order ->
   metric drift on long-horizon backtests. *)
let _make_id ~current_date ~seq =
  Printf.sprintf "%s-%03d" (Date.to_string current_date) seq

let _create_order ?(order_type = Trading_base.Types.Market) ~id ~symbol ~side
    ~quantity () =
  let params : Trading_orders.Create_order.order_params =
    {
      symbol;
      side;
      order_type;
      quantity;
      time_in_force = Trading_orders.Types.Day;
    }
  in
  Result.map
    (Trading_orders.Create_order.create_order ~id params)
    ~f:Option.some

(* Entry order type under the optional do-not-chase cap (#2158 Phase 2): a
   stop-limit that triggers at the breakout entry and refuses fills beyond
   [entry_price * (1 +/- pct/100)] (long/short mirrored) — the same cap
   arithmetic as [Weinstein_order_gen._entry_cap], in the same
   percentage-point units as the [entry_extension_max_pct] config field.
   [None] = the historical Market fill model. *)
let _entry_order_type ~entry_extension_max_pct
    ~(side : Trading_strategy.Position.position_side) ~entry_price =
  match entry_extension_max_pct with
  | None -> Trading_base.Types.Market
  | Some pct ->
      let frac = pct /. 100.0 in
      let cap =
        match side with
        | Long -> entry_price *. (1.0 +. frac)
        | Short -> entry_price *. (1.0 -. frac)
      in
      Trading_base.Types.StopLimit (entry_price, cap)

let _exit_order_for_position ~id position =
  let open Trading_strategy.Position in
  match get_state position with
  | Exiting { target_quantity; _ } ->
      (* Size the exit order at [target_quantity], not the full held [quantity]:
         the two are equal for a full exit but differ for a partial trim. *)
      _create_order ~id ~symbol:position.symbol
        ~side:(_exit_order_side position.side)
        ~quantity:target_quantity ()
  | _ -> Ok None

let _transition_to_order ~id ~positions ~entry_extension_max_pct
    (transition : Trading_strategy.Position.transition) =
  let open Trading_strategy.Position in
  match transition.kind with
  | CreateEntering { symbol; side; target_quantity; entry_price; _ } ->
      _create_order
        ~order_type:
          (_entry_order_type ~entry_extension_max_pct ~side ~entry_price)
        ~id ~symbol ~side:(_entry_order_side side) ~quantity:target_quantity ()
  | TriggerExit _ | TriggerPartialExit _ ->
      (* After _apply_transitions, the position is in Exiting state, not Holding.
         We look up the Exiting position to get the target quantity and side. *)
      Map.find positions transition.position_id
      |> Option.value_map ~default:(Ok None) ~f:(_exit_order_for_position ~id)
  | EntryFill _ | EntryComplete _ | CancelEntry _ | CancelExit _
  | UpdateRiskParams _ | ExitFill _ | ExitComplete ->
      Ok None

(** Advance the (seq, accumulator) pair with [maybe_order], recording the (order
    id, position id) link when an order was produced.

    [seq] is always incremented even when no order is produced — this keeps IDs
    stable regardless of how transition kinds are reordered in the caller.
    Sequential gaps in IDs are harmless. *)
let _accumulate_order ~position_id (seq, acc, links) maybe_order =
  match maybe_order with
  | Some order ->
      ( seq + 1,
        order :: acc,
        (order.Trading_orders.Types.id, position_id) :: links )
  | None -> (seq + 1, acc, links)

(* One fold step: mint the next id, build the order (if any), accumulate. *)
let _order_step ~current_date ~positions ~entry_extension_max_pct
    (seq, acc, links) transition =
  let open Result.Let_syntax in
  let id = _make_id ~current_date ~seq in
  let%bind maybe_order =
    _transition_to_order ~id ~positions ~entry_extension_max_pct transition
  in
  Ok
    (_accumulate_order
       ~position_id:transition.Trading_strategy.Position.position_id
       (seq, acc, links) maybe_order)

let transitions_to_orders ~current_date ~positions ?entry_extension_max_pct
    transitions =
  let open Result.Let_syntax in
  let%bind _, orders, links =
    List.fold_result transitions ~init:(0, [], [])
      ~f:(_order_step ~current_date ~positions ~entry_extension_max_pct)
  in
  Ok (List.rev orders, List.rev links)
