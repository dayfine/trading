(** Order generator - converts strategy transitions to trading orders

    TODO: Orders should be StopLimit orders instead of Market orders. *)

open Core

let _create_order ~symbol ~side ~quantity =
  let params : Trading_orders.Create_order.order_params =
    {
      symbol;
      side;
      order_type = Trading_base.Types.Market;
      quantity;
      time_in_force = Trading_orders.Types.Day;
    }
  in
  Result.map (Trading_orders.Create_order.create_order params) ~f:Option.some

let _transition_to_order ~positions
    (transition : Trading_strategy.Position.transition) =
  let open Trading_strategy.Position in
  match transition.kind with
  | CreateEntering { symbol; target_quantity; _ } ->
      _create_order ~symbol ~side:Trading_base.Types.Buy
        ~quantity:target_quantity
  | TriggerExit _ ->
      Map.find positions transition.position_id
      |> Option.value_map ~default:(Ok None) ~f:(fun position ->
             match get_state position with
             | Holding { quantity; _ } ->
                 _create_order ~symbol:position.symbol
                   ~side:Trading_base.Types.Sell ~quantity
             | _ -> Ok None)
  | EntryFill _ | EntryComplete _ | CancelEntry _ | UpdateRiskParams _
  | ExitFill _ | ExitComplete ->
      Ok None

let transitions_to_orders ~positions transitions =
  let open Result.Let_syntax in
  let%bind orders =
    List.fold_result transitions ~init:[] ~f:(fun acc transition ->
        let%bind maybe_order = _transition_to_order ~positions transition in
        match maybe_order with
        | Some order -> Ok (order :: acc)
        | None -> Ok acc)
  in
  Ok (List.rev orders)
