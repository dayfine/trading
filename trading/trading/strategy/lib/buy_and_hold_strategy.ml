(** Buy and Hold strategy - Enter position once and hold indefinitely *)

open Core

type config = {
  symbols : string list;
  position_size : float;
  entry_date : Date.t option;
}
[@@deriving show, eq]

type state = {
  config : config;
  positions : Position.t String.Map.t;
  entries_executed : bool String.Map.t;
}

type output = { transitions : Position.transition list }

let name = "BuyAndHold"

let init ~config =
  {
    config;
    positions = String.Map.empty;
    entries_executed = String.Map.empty;
  }

let _position_counter = ref 0

let _generate_position_id symbol =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-bh-%d" symbol !_position_counter

(* Helper to process one symbol - returns (transitions, updated_positions, updated_entries) *)
let _process_symbol ~market_data ~get_price ~config ~positions ~entries_executed
    symbol =
  let open Result.Let_syntax in
  let transitions = ref [] in

  (* Get current market data for this symbol *)
  let price_opt = get_price market_data symbol in
  let entry_executed = Map.find entries_executed symbol |> Option.value ~default:false in
  let active_position = Map.find positions symbol in

  match (price_opt, entry_executed, active_position) with
  (* Entry: not yet executed and price available *)
  | Some price, false, None ->
      (* Check if we should enter today *)
      let should_enter =
        match config.entry_date with
        | Some target_date ->
            Date.equal price.Types.Daily_price.date target_date
        | None -> true (* Enter immediately if no specific date *)
      in

      if should_enter then (
        let position_id = _generate_position_id symbol in
        let entry_price = price.Types.Daily_price.close_price in

        (* Create entering position *)
        let position =
          Position.create_entering ~id:position_id ~symbol
            ~target_quantity:config.position_size ~entry_price
            ~created_date:price.Types.Daily_price.date
            ~reasoning:
              (Position.ManualDecision
                 { description = "Buy and hold - initial entry" })
        in

        (* Simulate immediate fill at entry price *)
        let fill_transition =
          Position.EntryFill
            {
              position_id;
              filled_quantity = config.position_size;
              fill_price = entry_price;
              fill_date = price.Types.Daily_price.date;
            }
        in
        let%bind position_filled =
          Position.apply_transition position fill_transition
        in

        (* Complete entry with no exit criteria (hold indefinitely) *)
        let complete_transition =
          Position.EntryComplete
            {
              position_id;
              risk_params =
                {
                  stop_loss_price = None;
                  take_profit_price = None;
                  max_hold_days = None;
                };
              completion_date = price.Types.Daily_price.date;
            }
        in
        let%bind position_holding =
          Position.apply_transition position_filled complete_transition
        in

        transitions := [ fill_transition; complete_transition ];
        let updated_positions = Map.set positions ~key:symbol ~data:position_holding in
        let updated_entries = Map.set entries_executed ~key:symbol ~data:true in

        return (!transitions, updated_positions, updated_entries))
      else
        (* Not the entry date yet, do nothing *)
        return ([], positions, entries_executed)
  (* Already holding position - do nothing (hold indefinitely) *)
  | _, true, Some _position -> return ([], positions, entries_executed)
  (* Default: no action *)
  | _ -> return ([], positions, entries_executed)

let on_market_close ~market_data ~get_price ~get_ema:_ ~portfolio:_ ~state =
  let open Result.Let_syntax in
  let config = state.config in

  (* Process each configured symbol, threading positions and entries through *)
  let%bind all_transitions, final_positions, final_entries =
    List.fold_result config.symbols
      ~init:([], state.positions, state.entries_executed)
      ~f:(fun (acc_transitions, positions, entries) symbol ->
        let%bind symbol_transitions, updated_positions, updated_entries =
          _process_symbol ~market_data ~get_price ~config ~positions
            ~entries_executed:entries symbol
        in
        return
          ( acc_transitions @ symbol_transitions,
            updated_positions,
            updated_entries ))
  in

  let output = { transitions = all_transitions } in
  let new_state =
    { config; positions = final_positions; entries_executed = final_entries }
  in
  return (output, new_state)
