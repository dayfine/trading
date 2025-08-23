open Core
open Base

(** Trading simulation and backtesting *)

(** Market data point *)
type market_data = {
  symbol: symbol;
  timestamp: time;
  open_price: price;
  high_price: price;
  low_price: price;
  close_price: price;
  volume: int;
} [@@deriving show, eq]

(** Simulation configuration *)
type config = {
  initial_cash: money;
  commission_rate: float; (* percentage *)
  slippage: float; (* percentage *)
} [@@deriving show, eq]

(** Simulation state *)
type t = {
  config: config;
  portfolio: Portfolio.t;
  engine: Engine.t;
  current_prices: price Map.M(String).t;
  trades: trade list;
} [@@deriving show, eq]

(** Trade record *)
and trade = {
  timestamp: time;
  symbol: symbol;
  side: side;
  quantity: quantity;
  price: price;
  commission: money;
  slippage: money;
} [@@deriving show, eq]

(** Create a new simulation *)
let create config =
  let portfolio = Portfolio.create config.initial_cash in
  let engine = Engine.create () in
  {
    config;
    portfolio;
    engine;
    current_prices = Map.empty (module String);
    trades = [];
  }

(** Update market data *)
let update_market_data simulation market_data_list =
  let price_map = List.fold market_data_list ~init:Map.empty (module String) ~f:(fun acc data ->
    Map.set acc ~key:data.symbol ~data:data.close_price
  ) in
  { simulation with current_prices = price_map }

(** Calculate commission for a trade *)
let calculate_commission simulation trade_value =
  let commission_amount = trade_value *. simulation.config.commission_rate /. 100.0 in
  { amount = commission_amount; currency = simulation.config.initial_cash.currency }

(** Calculate slippage for a trade *)
let calculate_slippage simulation trade_value =
  let slippage_amount = trade_value *. simulation.config.slippage /. 100.0 in
  { amount = slippage_amount; currency = simulation.config.config.initial_cash.currency }

(** Execute a trade *)
let execute_trade simulation symbol side quantity price =
  let trade_value = Float.of_int quantity *. price in
  let commission = calculate_commission simulation trade_value in
  let slippage = calculate_slippage simulation trade_value in

  let trade = {
    timestamp = Time.now ();
    symbol;
    side;
    quantity;
    price;
    commission;
    slippage;
  } in

  (* Update portfolio *)
  let portfolio = match side with
    | Buy -> Portfolio.add_position simulation.portfolio symbol quantity price
    | Sell -> Portfolio.remove_position simulation.portfolio symbol quantity
  in

  (* Update cash *)
  let cash_change = match side with
    | Buy -> -(trade_value +. commission.amount +. slippage.amount)
    | Sell -> trade_value -. commission.amount -. slippage.amount
  in
  let updated_cash = { portfolio.cash with amount = portfolio.cash.amount +. cash_change } in
  let portfolio = { portfolio with cash = updated_cash } in

  (* Update portfolio value *)
  let portfolio = Portfolio.update_portfolio_value portfolio simulation.current_prices in

  {
    simulation with
    portfolio;
    trades = trade :: simulation.trades;
  }

(** Submit an order to the simulation *)
let submit_order simulation order_request =
  let validation = Orders.validate_order_request order_request in
  match validation with
  | Orders.Invalid errors ->
    (None, simulation, String.concat ~sep:", " errors)
  | Orders.Valid ->
    let (order, engine) = Engine.submit_order simulation.engine
      order_request.symbol
      order_request.side
      order_request.order_type
      order_request.quantity in

    (* For simulation, we'll execute market orders immediately *)
    let simulation = match order_request.order_type with
      | Market ->
        let current_price = Map.find simulation.current_prices order_request.symbol in
        (match current_price with
         | Some price -> execute_trade simulation order_request.symbol order_request.side order_request.quantity price
         | None -> simulation)
      | _ -> simulation
    in

    (Some order, { simulation with engine }, "Order submitted successfully")

(** Get simulation results *)
let get_results simulation =
  let summary = Portfolio.get_summary simulation.portfolio in
  let total_trades = List.length simulation.trades in
  let total_commission = List.fold simulation.trades ~init:0.0 ~f:(fun acc trade -> acc +. trade.commission.amount) in
  let total_slippage = List.fold simulation.trades ~init:0.0 ~f:(fun acc trade -> acc +. trade.slippage.amount) in

  {
    summary;
    total_trades;
    total_commission;
    total_slippage;
    trades = List.rev simulation.trades; (* Return in chronological order *)
  }

(** Run a simple backtest *)
let run_backtest config market_data_list strategy =
  let simulation = create config in
  let simulation = update_market_data simulation market_data_list in

  (* Apply strategy to each market data point *)
  let simulation = List.fold market_data_list ~init:simulation ~f:(fun sim data ->
    let orders = strategy sim data in
    List.fold orders ~init:sim ~f:(fun sim order ->
      let (_, updated_sim, _) = submit_order sim order in
      updated_sim
    )
  ) in

  get_results simulation
