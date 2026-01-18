(** Order generator - converts strategy transitions to trading orders *)

open Core

let transition_to_order (transition : Trading_strategy.Position.transition) =
  let open Trading_strategy.Position in
  match transition.kind with
  | CreateEntering { symbol; target_quantity; entry_price = _; reasoning = _ }
    ->
      (* Create a Market Buy order for the target quantity *)
      let params : Trading_orders.Create_order.order_params =
        {
          symbol;
          side = Trading_base.Types.Buy;
          order_type = Trading_base.Types.Market;
          quantity = target_quantity;
          time_in_force = Trading_orders.Types.Day;
        }
      in
      let open Result.Let_syntax in
      let%bind order = Trading_orders.Create_order.create_order params in
      Ok (Some order)
  | TriggerExit { exit_reason = _; exit_price = _ } ->
      (* For TriggerExit, we need to look up the position to get the quantity.
         However, TriggerExit is applied to an existing position, and we need
         that position's data. The transition itself doesn't carry the quantity.

         For now, we'll note this limitation - the simulator needs to handle
         TriggerExit by looking up the position and providing the quantity.
         This function returns None for TriggerExit since we don't have enough
         context here. The simulator should handle this case directly. *)
      Ok None
  | EntryFill _ | EntryComplete _ | CancelEntry _ | UpdateRiskParams _
  | ExitFill _ | ExitComplete ->
      (* These transitions don't generate orders - they respond to fills
         or update position state *)
      Ok None

let transitions_to_orders transitions =
  let open Result.Let_syntax in
  let%bind orders =
    List.fold_result transitions ~init:[] ~f:(fun acc transition ->
        let%bind maybe_order = transition_to_order transition in
        match maybe_order with
        | Some order -> Ok (order :: acc)
        | None -> Ok acc)
  in
  Ok (List.rev orders)
