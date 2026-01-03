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

let name = "EmaCrossover"
let _position_counter = ref 0

let _generate_position_id symbol =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-pos-%d" symbol !_position_counter

(* Check for entry signal: price above EMA *)
let _has_entry_signal ~price ~ema = Float.(price > ema)

(* Execute entry: create position in Entering state *)
let _execute_entry ~symbol ~config ~price ~ema:_ =
  let open Result.Let_syntax in
  let position_id = _generate_position_id symbol in
  let entry_price = price.Types.Daily_price.close_price in
  let date = price.Types.Daily_price.date in

  (* Create initial Entering position - engine will fill it *)
  let position =
    Position.create_entering ~id:position_id ~symbol
      ~target_quantity:config.position_size ~entry_price ~created_date:date
      ~reasoning:
        (Position.TechnicalSignal
           { indicator = "EMA"; description = "Price crossed above EMA" })
  in

  (* No transitions - engine will produce EntryFill and EntryComplete *)
  return ([], position)

(* Check if exit condition is met and return (should_exit, exit_reason) *)
let _check_exit_signal ~current_price ~ema ~risk_params ~entry_price =
  let open Position in
  (* Check stop loss first *)
  if
    Option.is_some risk_params.stop_loss_price
    && Float.(current_price <= Option.value_exn risk_params.stop_loss_price)
  then
    let stop = Option.value_exn risk_params.stop_loss_price in
    let loss_pct = (current_price -. entry_price) /. entry_price in
    ( true,
      StopLoss
        {
          stop_price = stop;
          actual_price = current_price;
          loss_percent = loss_pct *. 100.0;
        } )
  else if
    Option.is_some risk_params.take_profit_price
    && Float.(current_price >= Option.value_exn risk_params.take_profit_price)
  then
    let target = Option.value_exn risk_params.take_profit_price in
    let profit_pct = (current_price -. entry_price) /. entry_price in
    ( true,
      TakeProfit
        {
          target_price = target;
          actual_price = current_price;
          profit_percent = profit_pct *. 100.0;
        } )
  else if Float.(current_price < ema) then
    (true, SignalReversal { description = "Price crossed below EMA" })
  else (false, PortfolioRebalancing)

(* Execute exit: produce TriggerExit transition only *)
let _execute_exit ~position ~quantity:_ ~price ~exit_reason =
  (* Only produce TriggerExit - engine will produce ExitFill and ExitComplete *)
  Result.return
    ( [
        {
          Position.position_id = position.Position.id;
          date = price.Types.Daily_price.date;
          kind =
            TriggerExit
              { exit_reason; exit_price = price.Types.Daily_price.close_price };
        };
      ],
      position )

(* Process one symbol - returns (transitions, updated_positions) *)
let _process_symbol ~get_price ~get_indicator ~config ~positions symbol =
  let open Result.Let_syntax in
  let price_opt = get_price symbol in
  let ema_opt = get_indicator symbol "EMA" config.ema_period in
  let active_position = Map.find positions symbol in

  match (price_opt, ema_opt, active_position) with
  (* Entry: no position and entry signal *)
  | Some price, Some ema, None
    when _has_entry_signal ~price:price.Types.Daily_price.close_price ~ema ->
      let%bind transitions, position =
        _execute_entry ~symbol ~config ~price ~ema
      in
      let updated_positions = Map.set positions ~key:symbol ~data:position in
      return (transitions, updated_positions)
  (* Exit check: has position in Holding state *)
  | Some price, Some ema, Some position -> (
      match Position.get_state position with
      | Position.Holding holding ->
          let current_price = price.Types.Daily_price.close_price in
          let should_exit, exit_reason =
            _check_exit_signal ~current_price ~ema
              ~risk_params:holding.risk_params ~entry_price:holding.entry_price
          in
          if should_exit then
            let%bind transitions, final_position =
              _execute_exit ~position ~quantity:holding.quantity ~price
                ~exit_reason
            in
            let updated_positions =
              Map.set positions ~key:symbol ~data:final_position
            in
            return (transitions, updated_positions)
          else return ([], positions)
      | _ -> return ([], positions))
  (* All other cases: no action *)
  | _ -> return ([], positions)

let make config =
  let module M = struct
    let on_market_close ~get_price ~get_indicator ~portfolio:_
        ~(state : Strategy_interface.state) =
      let open Result.Let_syntax in
      (* Use passed state parameter (functional) *)
      let%bind all_transitions, final_positions =
        List.fold_result config.symbols ~init:([], state.positions)
          ~f:(fun (acc_transitions, positions) symbol ->
            let%bind symbol_transitions, updated_positions =
              _process_symbol ~get_price ~get_indicator ~config ~positions
                symbol
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
