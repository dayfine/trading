(** Trading engine - simulated broker for order execution *)

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

val update_market :
  ?path_config:Price_path.path_config -> t -> price_bar list -> unit
(** Update market data for one or more symbols. Called by simulation to feed
    OHLC bars to the engine.

    The engine generates intraday price paths from these bars to determine order
    execution. Each bar represents price action over a time period (typically
    daily).

    @param path_config
      Optional configuration for path generation. Defaults to
      Price_path.default_config. Use a fixed seed for deterministic testing:
      {[
        let path_config = { Price_path.default_config with seed = Some 42 } in
        Engine.update_market ~path_config engine bars
      ]}

    Example:
    {[
      let bars =
        [
          {
            symbol = "AAPL";
            open_price = 150.0;
            high_price = 152.0;
            low_price = 149.5;
            close_price = 151.0;
          };
          {
            symbol = "GOOGL";
            open_price = 2800.0;
            high_price = 2850.0;
            low_price = 2790.0;
            close_price = 2820.0;
          };
        ]
      in
      Engine.update_market engine bars
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
