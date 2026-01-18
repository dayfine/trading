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
    (* Apply trades to portfolio *)
    let%bind updated_portfolio =
      Trading_portfolio.Portfolio.apply_trades t.portfolio trades
    in
    (* Call strategy to get transitions *)
    let%bind _transitions = _call_strategy t in
    (* TODO: Convert transitions to orders and execute (Change 8) *)
    (* Create step result *)
    let step_result =
      { date = t.current_date; portfolio = updated_portfolio; trades }
    in
    (* Advance to next date *)
    let next_date = Date.add_days t.current_date 1 in
    let t' =
      { t with current_date = next_date; portfolio = updated_portfolio }
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
