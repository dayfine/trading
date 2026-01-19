(** Order generator - converts strategy transitions to trading orders *)

open Core

let transition_to_order ~positions
    (transition : Trading_strategy.Position.transition) =
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
  | TriggerExit _ -> (
      (* Look up the position to get the quantity to sell *)
      match Map.find positions transition.position_id with
      | None -> Ok None (* Position not found, skip *)
      | Some position -> (
          match get_state position with
          | Holding { quantity; _ } ->
              let params : Trading_orders.Create_order.order_params =
                {
                  symbol = position.symbol;
                  side = Trading_base.Types.Sell;
                  order_type = Trading_base.Types.Market;
                  quantity;
                  time_in_force = Trading_orders.Types.Day;
                }
              in
              let open Result.Let_syntax in
              let%bind order =
                Trading_orders.Create_order.create_order params
              in
              Ok (Some order)
          | _ -> Ok None (* Position not in Holding state, skip *)))
  | EntryFill _ | EntryComplete _ | CancelEntry _ | UpdateRiskParams _
  | ExitFill _ | ExitComplete ->
      (* These transitions don't generate orders - they respond to fills
         or update position state *)
      Ok None

let transitions_to_orders ~positions transitions =
  let open Result.Let_syntax in
  let%bind orders =
    List.fold_result transitions ~init:[] ~f:(fun acc transition ->
        let%bind maybe_order = transition_to_order ~positions transition in
        match maybe_order with
        | Some order -> Ok (order :: acc)
        | None -> Ok acc)
  in
  Ok (List.rev orders)
