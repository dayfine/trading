(** EMA crossover strategy *)

open Core

type config = {
  symbols : string list;
  ema_period : int;
  stop_loss_percent : float;
  take_profit_percent : float;
  position_size : float;
}
[@@deriving show, eq]

type state = {
  config : config;
  positions : Position.t String.Map.t;
}

type output = { transitions : Position.transition list }

let name = "EmaCrossover"

let init ~config = { config; positions = String.Map.empty }
let _position_counter = ref 0

let _generate_position_id symbol =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-pos-%d" symbol !_position_counter

(* Helper to process one symbol - returns (transitions, updated_positions) *)
let _process_symbol ~market_data ~get_price ~get_ema ~config ~positions symbol =
  let open Result.Let_syntax in
  let transitions = ref [] in

  (* Get current market data for this symbol *)
  let price_opt = get_price market_data symbol in
  let ema_opt = get_ema market_data symbol config.ema_period in
  let active_position = Map.find positions symbol in

  match (price_opt, ema_opt, active_position) with
  (* No position, check for entry signal *)
  | Some price, Some ema, None
    when Float.(price.Types.Daily_price.close_price > ema) ->
      (* Entry signal: price above EMA *)
      let position_id = _generate_position_id symbol in
      let entry_price = price.Types.Daily_price.close_price in
      let stop_loss = entry_price *. (1.0 -. config.stop_loss_percent) in
      let take_profit = entry_price *. (1.0 +. config.take_profit_percent) in

      (* Create entering position *)
      let position =
        Position.create_entering ~id:position_id ~symbol
          ~target_quantity:config.position_size ~entry_price
          ~created_date:price.Types.Daily_price.date
          ~reasoning:
            (TechnicalSignal
               { indicator = "EMA"; description = "Price crossed above EMA" })
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

      (* Complete entry *)
      let complete_transition =
        Position.EntryComplete
          {
            position_id;
            risk_params =
              {
                stop_loss_price = Some stop_loss;
                take_profit_price = Some take_profit;
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

      return (!transitions, updated_positions)
  (* Has position, check for exit signals *)
  | Some price, Some ema, Some position -> (
      match Position.get_state position with
      | Position.Holding holding ->
          let current_price = price.Types.Daily_price.close_price in
          let should_exit, exit_reason =
            (* Check stop loss *)
            match holding.risk_params.stop_loss_price with
            | Some stop when Float.(current_price <= stop) ->
                let loss_pct =
                  (current_price -. holding.entry_price) /. holding.entry_price
                in
                ( true,
                  Position.StopLoss
                    {
                      stop_price = stop;
                      actual_price = current_price;
                      loss_percent = loss_pct *. 100.0;
                    } )
            | _ -> (
                (* Check take profit *)
                match holding.risk_params.take_profit_price with
                | Some target when Float.(current_price >= target) ->
                    let profit_pct =
                      (current_price -. holding.entry_price)
                      /. holding.entry_price
                    in
                    ( true,
                      Position.TakeProfit
                        {
                          target_price = target;
                          actual_price = current_price;
                          profit_percent = profit_pct *. 100.0;
                        } )
                | _ ->
                    (* Check signal reversal *)
                    if Float.(current_price < ema) then
                      ( true,
                        Position.SignalReversal
                          { description = "Price crossed below EMA" } )
                    else (false, Position.PortfolioRebalancing))
          in

          if should_exit then (
            (* Trigger exit *)
            let position_id = Position.get_id position in
            let exit_transition =
              Position.TriggerExit
                {
                  position_id;
                  exit_reason;
                  exit_price = current_price;
                  trigger_date = price.Types.Daily_price.date;
                }
            in
            let%bind position_exiting =
              Position.apply_transition position exit_transition
            in

            (* Simulate immediate fill *)
            let exit_fill_transition =
              Position.ExitFill
                {
                  position_id;
                  filled_quantity = holding.quantity;
                  fill_price = current_price;
                  fill_date = price.Types.Daily_price.date;
                }
            in
            let%bind position_filled =
              Position.apply_transition position_exiting exit_fill_transition
            in

            (* Complete exit *)
            let exit_complete_transition =
              Position.ExitComplete
                { position_id; completion_date = price.Types.Daily_price.date }
            in
            let%bind position_closed =
              Position.apply_transition position_filled exit_complete_transition
            in

            transitions :=
              [
                exit_transition; exit_fill_transition; exit_complete_transition;
              ];
            let updated_positions = Map.set positions ~key:symbol ~data:position_closed in

            return (!transitions, updated_positions))
          else
            (* Hold position, no action *)
            return ([], positions)
      | _ ->
          (* Position in other state, no action *)
          return ([], positions))
  | _ ->
      (* Missing data or no signal, no action *)
      return ([], positions)

let on_market_close ~market_data ~get_price ~get_ema ~portfolio:_ ~state =
  let open Result.Let_syntax in
  let config = state.config in

  (* Process each configured symbol, threading positions through *)
  let%bind all_transitions, final_positions =
    List.fold_result config.symbols ~init:([], state.positions)
      ~f:(fun (acc_transitions, positions) symbol ->
        let%bind symbol_transitions, updated_positions =
          _process_symbol ~market_data ~get_price ~get_ema ~config ~positions symbol
        in
        return (acc_transitions @ symbol_transitions, updated_positions))
  in

  let output = { transitions = all_transitions } in
  let new_state = { config; positions = final_positions } in
  return (output, new_state)
