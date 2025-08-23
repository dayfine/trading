(** Trading simulation and backtesting *)

(** Market data point *)
type market_data = {
  symbol: Base.symbol;
  timestamp: Base.time;
  open_price: Base.price;
  high_price: Base.price;
  low_price: Base.price;
  close_price: Base.price;
  volume: int;
}

(** Simulation configuration *)
type config = {
  initial_cash: Base.money;
  commission_rate: float; (* percentage *)
  slippage: float; (* percentage *)
}

(** Simulation state *)
type t = {
  config: config;
  portfolio: Portfolio.t;
  engine: Engine.t;
  current_prices: Base.price Map.M(String).t;
  trades: trade list;
}

(** Trade record *)
and trade = {
  timestamp: Base.time;
  symbol: Base.symbol;
  side: Base.side;
  quantity: Base.quantity;
  price: Base.price;
  commission: Base.money;
  slippage: Base.money;
}

(** Create a new simulation *)
val create : config -> t

(** Update market data *)
val update_market_data : t -> market_data list -> t

(** Calculate commission for a trade *)
val calculate_commission : t -> float -> Base.money

(** Calculate slippage for a trade *)
val calculate_slippage : t -> float -> Base.money

(** Execute a trade *)
val execute_trade : t -> Base.symbol -> Base.side -> Base.quantity -> Base.price -> t

(** Submit an order to the simulation *)
val submit_order : t -> Orders.order_request -> Engine.order option * t * string

(** Get simulation results *)
val get_results : t -> {
  summary: Portfolio.get_summary;
  total_trades: int;
  total_commission: float;
  total_slippage: float;
  trades: trade list;
}

(** Run a simple backtest *)
val run_backtest : config -> market_data list -> (t -> market_data -> Orders.order_request list) -> get_results
