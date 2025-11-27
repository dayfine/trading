(** Trading engine - simulated broker for order execution *)

open Trading_base.Types
open Trading_orders.Manager
open Status
open Types

type t
(** Opaque stateful engine - acts as a simulated broker with internal market
    state *)

val create : engine_config -> t
(** Create a new engine instance with given configuration.

    Example:
    {[
      let config = { commission = { per_share = 0.01; minimum = 1.0 } } in
      let engine = Engine.create config
    ]} *)

val update_market : t -> price_quote list -> unit
(** Update market data for one or more symbols. Called by simulation to feed
    current market prices to the engine.

    Example:
    {[
      let quotes =
        [
          {
            symbol = "AAPL";
            bid = Some 150.0;
            ask = Some 150.5;
            last = Some 150.25;
          };
          {
            symbol = "GOOGL";
            bid = Some 2800.0;
            ask = Some 2805.0;
            last = Some 2802.5;
          };
        ]
      in
      Engine.update_market engine quotes
    ]} *)

val process_orders : t -> order_manager -> execution_report list status_or
(** Process pending orders from the order manager.

    For each pending order: 1. Check if execution is possible (market data
    available, price conditions met) 2. If executable, generate trade and update
    order status to Filled in manager 3. If not executable, leave as Pending
    (limit/stop not triggered)

    Returns list of execution reports for orders that were processed.

    Example:
    {[
      let reports = Engine.process_orders engine order_mgr in
      match reports with
      | Ok reports ->
          let trades = List.concat_map reports ~f:(fun r -> r.trades) in
          Portfolio.apply_trades portfolio trades
      | Error err -> (* handle error *)
    ]} *)

val process_mini_bars :
  t ->
  symbol ->
  order_manager ->
  mini_bar list ->
  execution_report list status_or
(** Process a sequence of mini-bars for backtesting order execution.

    For the given symbol, processes mini-bars sequentially: 1. Check stop
    orders: if stop condition met, trigger and convert to market/limit 2.
    Execute market orders at mini-bar close price 3. Execute limit orders if
    price crosses limit threshold 4. Generate trades for filled orders 5. Update
    order statuses in manager

    Stop order state is maintained across mini-bars within a single call.

    Returns list of execution reports for orders that executed.

    Example:
    {[
      let mini_bars = Price_path.generate_mini_bars daily_price in
      let reports =
        Engine.process_mini_bars engine "AAPL" order_mgr mini_bars
      in
      match reports with
      | Ok reports ->
          let trades = List.concat_map reports ~f:(fun r -> r.trades) in
          Portfolio.apply_trades portfolio trades
      | Error err -> (* handle error *)
    ]} *)
