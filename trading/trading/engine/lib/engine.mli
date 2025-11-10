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

val get_market_data :
  t -> symbol -> (price option * price option * price option) option
(** Query current market data for a symbol. Returns (bid, ask, last) tuple.
    Returns None until market data management is implemented (Phase 6+). *)

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
