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

let _generate_position_id (symbol : string) : string =
  _position_counter := !_position_counter + 1;
  Printf.sprintf "%s-pos-%d" symbol !_position_counter

(* Check for entry signal: price above EMA *)
let _has_entry_signal ~(price : float) ~(ema : float) : bool =
  Float.(price > ema)

(* Execute entry: create CreateEntering transition *)
let _execute_entry ~(symbol : string) ~(config : config)
    ~(price : Types.Daily_price.t) ~ema:_ : Position.transition list =
  let position_id = _generate_position_id symbol in
  let entry_price = price.Types.Daily_price.close_price in
  let date = price.Types.Daily_price.date in

  (* Produce CreateEntering transition - engine will create and fill position *)
  [
    {
      Position.position_id;
      date;
      kind =
        CreateEntering
          {
            symbol;
            target_quantity = config.position_size;
            entry_price;
            reasoning =
              TechnicalSignal
                { indicator = "EMA"; description = "Price crossed above EMA" };
          };
    };
  ]

(* Check if exit condition is met and return (should_exit, exit_reason) *)
let _check_exit_signal ~(current_price : float) ~(ema : float)
    ~(risk_params : Position.risk_params) ~(entry_price : float) :
    bool * Position.exit_reason =
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
let _execute_exit ~(position : Position.t) ~quantity:_
    ~(price : Types.Daily_price.t) ~(exit_reason : Position.exit_reason) :
    Position.transition list =
  (* Only produce TriggerExit - engine will produce ExitFill and ExitComplete *)
  [
    {
      Position.position_id = position.Position.id;
      date = price.Types.Daily_price.date;
      kind =
        TriggerExit
          { exit_reason; exit_price = price.Types.Daily_price.close_price };
    };
  ]

(* Process one symbol - returns transitions only *)
let _process_symbol ~(get_price : Strategy_interface.get_price_fn)
    ~(get_indicator : Strategy_interface.get_indicator_fn) ~(config : config)
    ~(positions : Position.t String.Map.t) (symbol : string) :
    Position.transition list =
  let price_opt = get_price symbol in
  let ema_opt = get_indicator symbol "EMA" config.ema_period in
  let active_position = Map.find positions symbol in

  match (price_opt, ema_opt, active_position) with
  (* Entry: no position and entry signal *)
  | Some price, Some ema, None
    when _has_entry_signal ~price:price.Types.Daily_price.close_price ~ema ->
      _execute_entry ~symbol ~config ~price ~ema
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
            _execute_exit ~position ~quantity:holding.quantity ~price
              ~exit_reason
          else []
      | _ -> [])
  (* All other cases: no action *)
  | _ -> []

let make (config : config) : (module Strategy_interface.STRATEGY) =
  let module M = struct
    let on_market_close ~get_price ~get_indicator ~positions =
      (* Process all symbols and collect transitions *)
      let all_transitions =
        List.concat_map config.symbols ~f:(fun symbol ->
            _process_symbol ~get_price ~get_indicator ~config ~positions symbol)
      in

      let output = { Strategy_interface.transitions = all_transitions } in
      Result.return output

    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
