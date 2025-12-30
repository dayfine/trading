(** Generate trading orders from position transitions *)

open Core

(* Helper to find position by ID *)
let _find_position_by_id positions position_id =
  Map.fold positions ~init:None ~f:(fun ~key:_ ~data:position acc ->
      match acc with
      | Some _ -> acc
      | None ->
          if String.equal (Position.get_id position) position_id then Some position
          else None)

(* Generate order from a single transition *)
let _order_from_transition ~positions transition =
  let open Result.Let_syntax in
  match transition with
  | Position.EntryFill { position_id; filled_quantity; fill_price; _ } -> (
      match _find_position_by_id positions position_id with
      | None ->
          Error
            (Status.invalid_argument_error
               (Printf.sprintf "Position not found for EntryFill: %s" position_id))
      | Some position ->
          let symbol = Position.get_symbol position in
          let%bind order =
            Trading_orders.Create_order.create_order
              {
                symbol;
                side = Trading_base.Types.Buy;
                quantity = filled_quantity;
                order_type = Trading_base.Types.Limit fill_price;
                time_in_force = Trading_orders.Types.GTC;
              }
          in
          return (Some order))
  | Position.ExitFill { position_id; filled_quantity; fill_price; _ } -> (
      match _find_position_by_id positions position_id with
      | None ->
          Error
            (Status.invalid_argument_error
               (Printf.sprintf "Position not found for ExitFill: %s" position_id))
      | Some position ->
          let symbol = Position.get_symbol position in
          let%bind order =
            Trading_orders.Create_order.create_order
              {
                symbol;
                side = Trading_base.Types.Sell;
                quantity = filled_quantity;
                order_type = Trading_base.Types.Limit fill_price;
                time_in_force = Trading_orders.Types.GTC;
              }
          in
          return (Some order))
  (* Other transitions don't generate orders *)
  | Position.EntryComplete _ | Position.CancelEntry _ | Position.TriggerExit _
  | Position.UpdateRiskParams _ | Position.ExitComplete _ ->
      return None

let from_transitions ~positions ~transitions =
  let open Result.Let_syntax in
  (* Convert each transition, collecting successful order generations *)
  let%bind order_options =
    Result.all (List.map transitions ~f:(_order_from_transition ~positions))
  in
  (* Filter out None values *)
  return (List.filter_map order_options ~f:Fn.id)
