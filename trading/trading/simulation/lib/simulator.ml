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
  portfolio_value : float;
  trades : Trading_base.Types.trade list;
  orders_submitted : Trading_orders.Types.order list;
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
  }

(** {1 Running} *)

let _submit_orders t orders =
  let _ = Trading_orders.Manager.submit_orders t.deps.order_manager orders in
  orders

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

(** Compute total portfolio value (cash + position market values).

    Uses close prices from today's bars to value positions. If a position's
    symbol has no price data for today, its market value is assumed to be zero
    (the position is illiquid). *)
let _compute_portfolio_value ~portfolio ~today_bars =
  let prices =
    List.map today_bars ~f:(fun bar ->
        (bar.Trading_engine.Types.symbol, bar.close_price))
  in
  match
    Trading_portfolio.Calculations.portfolio_value
      portfolio.Trading_portfolio.Portfolio.positions portfolio.current_cash
      prices
  with
  | Ok value -> value
  | Error _ -> portfolio.current_cash

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

(** Find position by symbol and state *)
let _find_position_by_symbol_state positions ~symbol ~state_match =
  Map.to_alist positions
  |> List.find_map ~f:(fun (id, pos) ->
      if
        String.equal pos.Trading_strategy.Position.symbol symbol
        && state_match (Trading_strategy.Position.get_state pos)
      then Some (id, pos)
      else None)

(** Apply a fill to a position (works for both entry and exit fills).

    TODO: Upon EntryComplete, we should place stop-loss and take-profit orders
    immediately based on risk_params. This requires either: 1. Returning the
    orders to place alongside the updated position, or 2. Having the simulator
    check for newly-Holding positions and place orders. For now, risk_params are
    set to None and protective orders are not placed. *)
let _apply_fill ~date ~position ~trade ~is_entry =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  let fill_kind =
    if is_entry then
      EntryFill
        {
          filled_quantity = trade.Trading_base.Types.quantity;
          fill_price = trade.Trading_base.Types.price;
        }
    else
      ExitFill
        {
          filled_quantity = trade.Trading_base.Types.quantity;
          fill_price = trade.Trading_base.Types.price;
        }
  in
  let fill_trans = { position_id = position.id; date; kind = fill_kind } in
  let%bind pos = apply_transition position fill_trans in
  let complete_kind =
    if is_entry then
      EntryComplete
        {
          risk_params =
            {
              stop_loss_price = None;
              take_profit_price = None;
              max_hold_days = None;
            };
        }
    else ExitComplete
  in
  let complete_trans = { position_id = pos.id; date; kind = complete_kind } in
  apply_transition pos complete_trans

(** Update positions from trades.

    Matches trades to positions by symbol and position state (not trade side),
    supporting both long positions (buy to enter, sell to exit) and short
    positions (sell to enter, buy to exit). *)
let _update_positions_from_trades ~date ~positions ~trades =
  let open Result.Let_syntax in
  let open Trading_strategy.Position in
  (* Cases to try: (state_match, is_entry) *)
  let fill_cases =
    [
      ((function Entering _ -> true | _ -> false), true);
      ((function Exiting _ -> true | _ -> false), false);
    ]
  in
  List.fold_result trades ~init:positions ~f:(fun acc trade ->
      let symbol = trade.Trading_base.Types.symbol in
      let matched =
        List.find_map fill_cases ~f:(fun (state_match, is_entry) ->
            _find_position_by_symbol_state acc ~symbol ~state_match
            |> Option.map ~f:(fun (id, pos) -> (id, pos, is_entry)))
      in
      match matched with
      | Some (id, pos, is_entry) ->
          let%bind updated = _apply_fill ~date ~position:pos ~trade ~is_entry in
          Ok (Map.set acc ~key:id ~data:updated)
      | None -> Ok acc)

(** Apply transitions to positions (CreateEntering creates new, TriggerExit
    updates existing) *)
let _apply_transitions ~positions ~transitions =
  let open Result.Let_syntax in
  List.fold_result transitions ~init:positions ~f:(fun acc trans ->
      match trans.Trading_strategy.Position.kind with
      | CreateEntering _ ->
          let%bind pos = Trading_strategy.Position.create_entering trans in
          Ok (Map.set acc ~key:pos.id ~data:pos)
      | TriggerExit _ -> (
          match Map.find acc trans.position_id with
          | None -> Ok acc
          | Some pos ->
              let%bind updated =
                Trading_strategy.Position.apply_transition pos trans
              in
              Ok (Map.set acc ~key:trans.position_id ~data:updated))
      | _ -> Ok acc)

let step t =
  if _is_complete t then Ok (Completed t.portfolio)
  else
    let open Result.Let_syntax in
    (* Get today's prices and update engine *)
    let today_bars = _get_today_bars t in
    Trading_engine.Engine.update_market t.deps.engine today_bars;
    (* Process pending orders and apply fills to positions *)
    let%bind execution_reports =
      Trading_engine.Engine.process_orders t.deps.engine t.deps.order_manager
    in
    let trades = _extract_trades execution_reports in
    let%bind positions =
      _update_positions_from_trades ~date:t.current_date ~positions:t.positions
        ~trades
    in
    (* Apply trades to portfolio *)
    let%bind portfolio =
      Trading_portfolio.Portfolio.apply_trades t.portfolio trades
    in
    (* Call strategy and apply transitions (creates new positions, triggers exits) *)
    let%bind transitions = _call_strategy { t with positions } in
    let%bind positions = _apply_transitions ~positions ~transitions in
    (* Generate and submit orders for next day *)
    let%bind orders =
      Order_generator.transitions_to_orders ~positions transitions
    in
    let orders_submitted = _submit_orders t orders in
    (* Compute portfolio value using today's close prices *)
    let portfolio_value = _compute_portfolio_value ~portfolio ~today_bars in
    (* Advance to next date *)
    let step_result =
      {
        date = t.current_date;
        portfolio;
        portfolio_value;
        trades;
        orders_submitted;
      }
    in
    let next_date = Date.add_days t.current_date 1 in
    return
      (Stepped
         ({ t with current_date = next_date; portfolio; positions }, step_result))

let get_config t = t.config

let run t =
  let rec loop t acc =
    match step t with
    | Error e -> Error e
    | Ok (Completed portfolio) -> Ok (List.rev acc, portfolio)
    | Ok (Stepped (t', step_result)) -> loop t' (step_result :: acc)
  in
  loop t []
