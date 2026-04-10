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
    ~(price : Types.Daily_price.t) ~ema:_ : Position.transition =
  let position_id = _generate_position_id symbol in
  let entry_price = price.Types.Daily_price.close_price in
  let date = price.Types.Daily_price.date in

  let reasoning =
    Position.TechnicalSignal
      { indicator = "EMA"; description = "Price crossed above EMA" }
  in
  (* Produce CreateEntering transition - engine will create and fill position *)
  {
    Position.position_id;
    date;
    kind =
      CreateEntering
        {
          symbol;
          side = Long;
          target_quantity = config.position_size;
          entry_price;
          reasoning;
        };
  }

let _stop_loss_exit current_price entry_price stop =
  let loss_pct = (current_price -. entry_price) /. entry_price in
  Some
    (Position.StopLoss
       {
         stop_price = stop;
         actual_price = current_price;
         loss_percent = loss_pct *. 100.0;
       })

let _take_profit_exit current_price entry_price target =
  let profit_pct = (current_price -. entry_price) /. entry_price in
  Some
    (Position.TakeProfit
       {
         target_price = target;
         actual_price = current_price;
         profit_percent = profit_pct *. 100.0;
       })

let _ema_reversal =
  Position.SignalReversal { description = "Price crossed below EMA" }

let _check_take_profit_or_reversal ~current_price ~ema ~risk_params ~entry_price
    =
  match risk_params.Position.take_profit_price with
  | Some target when Float.(current_price >= target) ->
      _take_profit_exit current_price entry_price target
  | _ when Float.(current_price < ema) -> Some _ema_reversal
  | _ -> None

(* Check if exit condition is met and return exit_reason if should exit *)
let _check_exit_signal ~(current_price : float) ~(ema : float)
    ~(risk_params : Position.risk_params) ~(entry_price : float) :
    Position.exit_reason option =
  match risk_params.stop_loss_price with
  | Some stop when Float.(current_price <= stop) ->
      _stop_loss_exit current_price entry_price stop
  | _ ->
      _check_take_profit_or_reversal ~current_price ~ema ~risk_params
        ~entry_price

(* Execute exit: produce TriggerExit transition only *)
let _execute_exit ~(position : Position.t) ~quantity:_
    ~(price : Types.Daily_price.t) ~(exit_reason : Position.exit_reason) :
    Position.transition =
  (* Only produce TriggerExit - engine will produce ExitFill and ExitComplete *)
  {
    Position.position_id = position.Position.id;
    date = price.Types.Daily_price.date;
    kind =
      TriggerExit
        { exit_reason; exit_price = price.Types.Daily_price.close_price };
  }

(* Find a position for a given symbol.
   The positions map is keyed by position_id, so we need to search by symbol. *)
let _find_position_for_symbol positions symbol =
  Map.to_alist positions
  |> List.find_map ~f:(fun (_id, pos) ->
      if String.equal pos.Position.symbol symbol then Some pos else None)

let _check_exit price ema position =
  match Position.get_state position with
  | Position.Holding holding ->
      let current_price = price.Types.Daily_price.close_price in
      let exit_reason_opt =
        _check_exit_signal ~current_price ~ema ~risk_params:holding.risk_params
          ~entry_price:holding.entry_price
      in
      Option.map exit_reason_opt ~f:(fun exit_reason ->
          _execute_exit ~position ~quantity:holding.quantity ~price ~exit_reason)
  | _ -> None

(* Process one symbol - returns optional transition *)
let _process_symbol ~(get_price : Strategy_interface.get_price_fn)
    ~(get_indicator : Strategy_interface.get_indicator_fn) ~(config : config)
    ~(positions : Position.t String.Map.t) (symbol : string) :
    Position.transition option =
  let price_opt = get_price symbol in
  (* Use Daily cadence for EMA computation *)
  let ema_opt =
    get_indicator symbol "EMA" config.ema_period Types.Cadence.Daily
  in
  let active_position = _find_position_for_symbol positions symbol in
  match (price_opt, ema_opt, active_position) with
  | Some price, Some ema, None
    when _has_entry_signal ~price:price.Types.Daily_price.close_price ~ema ->
      Some (_execute_entry ~symbol ~config ~price ~ema)
  | Some price, Some ema, Some position -> _check_exit price ema position
  | _ -> None

let _on_market_close config ~get_price ~get_indicator ~positions
    ?portfolio_value:_ () =
  let all_transitions =
    List.filter_map config.symbols ~f:(fun symbol ->
        _process_symbol ~get_price ~get_indicator ~config ~positions symbol)
  in
  Result.return { Strategy_interface.transitions = all_transitions }

let make (config : config) : (module Strategy_interface.STRATEGY) =
  let module M = struct
    let on_market_close = _on_market_close config
    let name = name
  end in
  (module M : Strategy_interface.STRATEGY)
