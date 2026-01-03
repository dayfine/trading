(** Buy and Hold strategy - Enter position once and hold indefinitely *)

open Core

type config = {
  symbols : string list;
  position_size : float;
  entry_date : Date.t option;
}
[@@deriving show, eq]

let name = "BuyAndHold"
let _position_counter = ref 0

let _generate_position_id symbol =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-bh-%d" symbol !_position_counter

(* Check if we should enter on this date *)
let _should_enter config (price : Types.Daily_price.t) =
  match config.entry_date with
  | Some target_date -> Date.equal price.date target_date
  | None -> true

(* Execute entry: create position in Entering state *)
let _execute_entry ~symbol ~config ~price =
  let open Result.Let_syntax in
  let position_id = _generate_position_id symbol in
  let entry_price = price.Types.Daily_price.close_price in
  let date = price.Types.Daily_price.date in

  (* Create initial Entering position - engine will fill it *)
  let position =
    Position.create_entering ~id:position_id ~symbol
      ~target_quantity:config.position_size ~entry_price ~created_date:date
      ~reasoning:
        (Position.ManualDecision
           { description = "Buy and hold - initial entry" })
  in

  (* No transitions - engine will produce EntryFill and EntryComplete *)
  return ([], position)

(* Process one symbol - returns (transitions, updated_positions) *)
let _process_symbol ~get_price ~config ~positions symbol =
  let open Result.Let_syntax in
  (* Early exit if position already exists (entry already executed) *)
  if Map.mem positions symbol then return ([], positions)
  else
    (* Check if we should enter *)
    match get_price symbol with
    | Some price when _should_enter config price ->
        let%bind transitions, position =
          _execute_entry ~symbol ~config ~price
        in
        let updated_positions = Map.set positions ~key:symbol ~data:position in
        return (transitions, updated_positions)
    | _ -> return ([], positions)

let make config =
  let module M = struct
    let on_market_close ~get_price ~get_indicator:_ ~portfolio:_
        ~(state : Strategy_interface.state) =
      let open Result.Let_syntax in
      (* Use passed state parameter (functional) *)
      let%bind all_transitions, final_positions =
        List.fold_result config.symbols ~init:([], state.positions)
          ~f:(fun (acc_transitions, positions) symbol ->
            let%bind symbol_transitions, updated_positions =
              _process_symbol ~get_price ~config ~positions symbol
            in
            return (acc_transitions @ symbol_transitions, updated_positions))
      in

      let output = { Strategy_interface.transitions = all_transitions } in
      let new_state : Strategy_interface.state =
        { positions = final_positions }
      in
      return (output, new_state)

    let name = name
  end in
  let initial_state : Strategy_interface.state =
    { positions = String.Map.empty }
  in
  ((module M : Strategy_interface.STRATEGY), initial_state)
