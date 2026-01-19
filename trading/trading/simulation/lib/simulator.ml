(** Simulation engine for backtesting trading strategies *)

open Core

(** {1 Input Types} *)

type config = {
  start_date : Date.t;
  end_date : Date.t;
  initial_cash : float;
  commission : Trading_engine.Types.commission_config;
}
[@@deriving show, eq]

type dependencies = {
  symbols : string list;
  data_dir : Fpath.t;
  strategy : (module Trading_strategy.Strategy_interface.STRATEGY);
  engine : Trading_engine.Engine.t;
  order_manager : Trading_orders.Manager.order_manager;
  market_data_adapter : Market_data_adapter.t;
}

let create_deps ~symbols ~data_dir ~strategy ~commission =
  let engine_config = { Trading_engine.Types.commission } in
  let engine = Trading_engine.Engine.create engine_config in
  let order_manager = Trading_orders.Manager.create () in
  let market_data_adapter = Market_data_adapter.create ~data_dir in
  { symbols; data_dir; strategy; engine; order_manager; market_data_adapter }

(** {1 Simulator Types} *)

type step_result = {
  date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  trades : Trading_base.Types.trade list;
}
[@@deriving show, eq]

type step_outcome =
  | Stepped of t * step_result
  | Completed of Trading_portfolio.Portfolio.t

and t = {
  config : config;
  deps : dependencies;
  current_date : Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Trading_strategy.Position.t String.Map.t;
  pending_entry_transitions : Trading_strategy.Position.transition list;
}

(** {1 Creation} *)

let create ~config ~deps =
  let portfolio =
    Trading_portfolio.Portfolio.create ~initial_cash:config.initial_cash ()
  in
  {
    config;
    deps;
    current_date = config.start_date;
    portfolio;
    positions = String.Map.empty;
    pending_entry_transitions = [];
  }

(** {1 Running} *)

let submit_orders t orders =
  Trading_orders.Manager.submit_orders t.deps.order_manager orders

let _is_complete t = Date.( >= ) t.current_date t.config.end_date

(** Convert Daily_price to engine price_bar *)
let _to_price_bar (symbol : string) (daily_price : Types.Daily_price.t) :
    Trading_engine.Types.price_bar =
  {
    Trading_engine.Types.symbol;
    open_price = daily_price.open_price;
    high_price = daily_price.high_price;
    low_price = daily_price.low_price;
    close_price = daily_price.close_price;
  }

(** Get all price bars for today using market data adapter *)
let _get_today_bars t =
  List.filter_map t.deps.symbols ~f:(fun symbol ->
      match
        Market_data_adapter.get_price t.deps.market_data_adapter ~symbol
          ~date:t.current_date
      with
      | None -> None
      | Some daily_price -> Some (_to_price_bar symbol daily_price))

(** Extract trades from execution reports *)
let _extract_trades reports =
  List.concat_map reports ~f:(fun report -> report.Trading_engine.Types.trades)

(** Create get_price function for strategy *)
let _make_get_price t : Trading_strategy.Strategy_interface.get_price_fn =
 fun symbol ->
  Market_data_adapter.get_price t.deps.market_data_adapter ~symbol
    ~date:t.current_date

(** Create get_indicator function for strategy *)
let _make_get_indicator t : Trading_strategy.Strategy_interface.get_indicator_fn
    =
 fun symbol indicator_name period cadence ->
  Market_data_adapter.get_indicator t.deps.market_data_adapter ~symbol
    ~indicator_name ~period ~cadence ~date:t.current_date

(** Call strategy and get transitions *)
let _call_strategy t =
  let (module S) = t.deps.strategy in
  let get_price = _make_get_price t in
  let get_indicator = _make_get_indicator t in
  let open Result.Let_syntax in
  let%bind output =
    S.on_market_close ~get_price ~get_indicator ~positions:t.positions
  in
  Ok output.transitions

(** Find pending entry transition by symbol *)
let _find_entry_transition_by_symbol symbol transitions =
  List.find transitions
    ~f:(fun (transition : Trading_strategy.Position.transition) ->
      match transition.kind with
      | CreateEntering { symbol = s; _ } -> String.equal s symbol
      | _ -> false)

(** Create position from entry transition and apply fill *)
let _create_position_from_entry ~date ~transition ~trade =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  (* Create position in Entering state *)
  let%bind position = create_entering transition in
  (* Apply EntryFill *)
  let fill_transition =
    {
      position_id = position.id;
      date;
      kind =
        EntryFill
          {
            filled_quantity = trade.Trading_base.Types.quantity;
            fill_price = trade.Trading_base.Types.price;
          };
    }
  in
  let%bind position = apply_transition position fill_transition in
  (* Apply EntryComplete to move to Holding *)
  let complete_transition =
    {
      position_id = position.id;
      date;
      kind =
        EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  in
  apply_transition position complete_transition

(** Update positions from buy trades (new entries) *)
let _update_positions_from_buys ~date ~positions ~pending_transitions ~trades =
  let open Result.Let_syntax in
  let buy_trades =
    List.filter trades ~f:(fun trade ->
        match trade.Trading_base.Types.side with
        | Trading_base.Types.Buy -> true
        | Trading_base.Types.Sell -> false)
  in
  List.fold_result buy_trades ~init:positions ~f:(fun acc trade ->
      match
        _find_entry_transition_by_symbol trade.Trading_base.Types.symbol
          pending_transitions
      with
      | None -> Ok acc (* No matching transition, skip *)
      | Some transition ->
          let%bind position =
            _create_position_from_entry ~date ~transition ~trade
          in
          Ok (Map.set acc ~key:position.id ~data:position))

(** Apply exit fill and complete to position *)
let _apply_exit_to_position ~date ~position ~trade =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  (* Apply ExitFill *)
  let fill_transition =
    {
      position_id = position.id;
      date;
      kind =
        ExitFill
          {
            filled_quantity = trade.Trading_base.Types.quantity;
            fill_price = trade.Trading_base.Types.price;
          };
    }
  in
  let%bind position = apply_transition position fill_transition in
  (* Apply ExitComplete to move to Closed *)
  let complete_transition =
    { position_id = position.id; date; kind = ExitComplete }
  in
  apply_transition position complete_transition

(** Find position in Exiting state by symbol *)
let _find_exiting_position_by_symbol symbol positions =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, position) ->
         match Trading_strategy.Position.get_state position with
         | Exiting _
           when String.equal position.Trading_strategy.Position.symbol symbol ->
             Some (id, position)
         | _ -> None)

(** Update positions from sell trades (exits) *)
let _update_positions_from_sells ~date ~positions ~trades =
  let open Result.Let_syntax in
  let sell_trades =
    List.filter trades ~f:(fun trade ->
        match trade.Trading_base.Types.side with
        | Trading_base.Types.Sell -> true
        | Trading_base.Types.Buy -> false)
  in
  List.fold_result sell_trades ~init:positions ~f:(fun acc trade ->
      match
        _find_exiting_position_by_symbol trade.Trading_base.Types.symbol acc
      with
      | None -> Ok acc (* No matching exiting position, skip *)
      | Some (id, position) ->
          let%bind updated = _apply_exit_to_position ~date ~position ~trade in
          Ok (Map.set acc ~key:id ~data:updated))

(** Apply TriggerExit transitions to positions *)
let _apply_trigger_exits ~positions ~transitions =
  let open Result.Let_syntax in
  let exit_transitions =
    List.filter transitions
      ~f:(fun (t : Trading_strategy.Position.transition) ->
        match t.kind with TriggerExit _ -> true | _ -> false)
  in
  List.fold_result exit_transitions ~init:positions ~f:(fun acc transition ->
      match Map.find acc transition.position_id with
      | None -> Ok acc (* Position not found, skip *)
      | Some position ->
          let%bind updated =
            Trading_strategy.Position.apply_transition position transition
          in
          Ok (Map.set acc ~key:transition.position_id ~data:updated))

(** Extract CreateEntering transitions for pending tracking *)
let _extract_entry_transitions transitions =
  List.filter transitions ~f:(fun (t : Trading_strategy.Position.transition) ->
      match t.kind with CreateEntering _ -> true | _ -> false)

let step t =
  if _is_complete t then Ok (Completed t.portfolio)
  else
    (* Get today's OHLC bars for all symbols *)
    let today_bars = _get_today_bars t in
    (* Update engine with today's market data *)
    Trading_engine.Engine.update_market t.deps.engine today_bars;
    (* Process pending orders against today's prices *)
    let open Result.Let_syntax in
    let%bind execution_reports =
      Trading_engine.Engine.process_orders t.deps.engine t.deps.order_manager
    in
    (* Extract trades from execution reports *)
    let trades = _extract_trades execution_reports in
    (* Update positions from trades:
       1. Create new positions from buy trades (matching pending entry transitions)
       2. Close positions from sell trades (matching exiting positions) *)
    let%bind positions_after_buys =
      _update_positions_from_buys ~date:t.current_date ~positions:t.positions
        ~pending_transitions:t.pending_entry_transitions ~trades
    in
    let%bind positions_after_sells =
      _update_positions_from_sells ~date:t.current_date
        ~positions:positions_after_buys ~trades
    in
    (* Apply trades to portfolio *)
    let%bind updated_portfolio =
      Trading_portfolio.Portfolio.apply_trades t.portfolio trades
    in
    (* Call strategy to get transitions (now with updated positions) *)
    let t_with_positions = { t with positions = positions_after_sells } in
    let%bind transitions = _call_strategy t_with_positions in
    (* Apply TriggerExit transitions to positions (moves Holding -> Exiting) *)
    let%bind positions_with_exits =
      _apply_trigger_exits ~positions:positions_after_sells ~transitions
    in
    (* Convert transitions to orders and submit for next day execution *)
    let%bind orders =
      Order_generator.transitions_to_orders ~positions:positions_with_exits
        transitions
    in
    let _order_statuses = submit_orders t orders in
    (* Extract CreateEntering transitions for tracking *)
    let new_pending = _extract_entry_transitions transitions in
    (* Create step result *)
    let step_result =
      { date = t.current_date; portfolio = updated_portfolio; trades }
    in
    (* Advance to next date *)
    let next_date = Date.add_days t.current_date 1 in
    let t' =
      {
        t with
        current_date = next_date;
        portfolio = updated_portfolio;
        positions = positions_with_exits;
        pending_entry_transitions = new_pending;
      }
    in
    return (Stepped (t', step_result))

let run t =
  let rec loop t acc =
    match step t with
    | Error e -> Error e
    | Ok (Completed portfolio) -> Ok (List.rev acc, portfolio)
    | Ok (Stepped (t', step_result)) -> loop t' (step_result :: acc)
  in
  loop t []
