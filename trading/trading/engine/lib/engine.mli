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

val process_orders :
  ?can_fill:(Trading_orders.Types.order -> bool) ->
  t ->
  order_manager ->
  execution_report list status_or
(** Process pending orders from the order manager.

    For each pending order: 1. Check if execution is possible (market data
    available, price conditions met) 2. If executable, generate trade and update
    order status to Filled in manager 3. If not executable, leave as Pending
    (limit/stop not triggered)

    [?can_fill] is an optional per-order gate applied {i before} matching: an
    order for which it returns [false] is not offered to the fill logic this
    call, stays active in the manager, and is re-considered on the next call (it
    is not cancelled). [None] (the default) offers every active order, so the
    result is bit-identical to omitting the argument. Used by the simulator to
    defer next-open entry fills past stale-bar steps.

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

val stop_limit_blocked_count : t -> int
(** Diagnostic tally: StopLimit orders whose stop {b triggered} on a bar but
    whose limit was never reachable, so no fill happened.

    Counts {b bar-events, not orders}. A GTC ticket blocked on three separate
    bars contributes three, and a ticket blocked once and filled later
    contributes one — so this is an upper bound on distinct refused tickets, not
    a count of them.

    {b Why it exists.} Under [entry_extension_max_pct] the limit {i is} the
    do-not-chase cap, so a [Limit_blocked] event is the cap refusing an entry.
    That refusal is otherwise invisible: it is never a trade, never a cancel,
    and not one of the screener's own skip reasons (those are the screener's to
    enumerate, not this module's). The cap's cost side has therefore never been
    directly measured — only inferred from top-line differences that sit inside
    the run-to-run path-noise floor.

    Distinct from a stop that simply never triggered, which is not a cost of the
    cap and is not counted.

    Monotonically non-decreasing over an engine's lifetime; [0] for a fresh
    {!create}. Purely observational — no decision reads it. *)
