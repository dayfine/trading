(** Order generator - converts strategy transitions to trading orders

    TODO(simulation/stoplimit-orders): Orders should be StopLimit orders instead
    of Market orders. *)

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

let _create_order ~id ~symbol ~side ~quantity =
  let params : Trading_orders.Create_order.order_params =
    {
      symbol;
      side;
      order_type = Trading_base.Types.Market;
      quantity;
      time_in_force = Trading_orders.Types.Day;
    }
  in
  Result.map
    (Trading_orders.Create_order.create_order ~id params)
    ~f:Option.some

let _exit_order_for_position ~id position =
  let open Trading_strategy.Position in
  match get_state position with
  | Exiting { quantity; _ } ->
      _create_order ~id ~symbol:position.symbol
        ~side:(_exit_order_side position.side)
        ~quantity
  | _ -> Ok None

let _transition_to_order ~id ~positions
    (transition : Trading_strategy.Position.transition) =
  let open Trading_strategy.Position in
  match transition.kind with
  | CreateEntering { symbol; side; target_quantity; _ } ->
      _create_order ~id ~symbol ~side:(_entry_order_side side)
        ~quantity:target_quantity
  | TriggerExit _ ->
      (* After _apply_transitions, the position is in Exiting state, not Holding.
         We look up the Exiting position to get the quantity and side. *)
      Map.find positions transition.position_id
      |> Option.value_map ~default:(Ok None) ~f:(_exit_order_for_position ~id)
  | EntryFill _ | EntryComplete _ | CancelEntry _ | UpdateRiskParams _
  | ExitFill _ | ExitComplete ->
      Ok None

let transitions_to_orders ~current_date ~positions transitions =
  let open Result.Let_syntax in
  let%bind _, orders =
    List.fold_result transitions ~init:(0, []) ~f:(fun (seq, acc) transition ->
        let id = _make_id ~current_date ~seq in
        let%bind maybe_order = _transition_to_order ~id ~positions transition in
        match maybe_order with
        | Some order -> Ok (seq + 1, order :: acc)
        | None ->
            (* We still advance [seq] for ignored transitions so that any
               future re-ordering of transition kinds does not silently shift
               IDs. Sequential gaps in IDs are harmless. *)
            Ok (seq + 1, acc))
  in
  Ok (List.rev orders)
