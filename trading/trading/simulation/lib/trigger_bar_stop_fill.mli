(** Same-bar fills for protective-stop exits
    ([sim_stop_exit_fill_on_trigger_bar], default off; issue #2961).

    The book (weinstein-book-reference.md §5.7, Ch. 6) treats the protective
    stop as a resting sell-stop that executes the day its level trades. The
    stops pass already detects the trigger on that day's bar (the bar's low for
    a long, high for a short) and emits a [TriggerExit] whose reason is
    [StopLoss { stop_price; _ }]; by default {!Order_generator} then turns it
    into a Market order that fills at the NEXT bar's open. With this module
    armed, that exit is instead re-issued as a [Stop stop_price] order and run
    through the engine against the SAME bar (step T), so it fills at the first
    intraday-path price at or through the stop — the open when the bar gapped
    below the stop (long), otherwise the first path point past the stop (the
    engine's usual stop-fill rule, with commission and slippage as for any
    engine fill). The trade is dated step T.

    {b Scope.} Only exits whose reason is [StopLoss]. Every other exit keeps the
    Market / next-open model: laggard rotation, Stage-3 force exits, liquidity,
    extension stop, volume eject, macro trim — and the force-liquidation
    breaker, which emits [StrategySignal { label = "force_liquidation" }] since
    2026-09-14, not [StopLoss]. The stops-pass [StopLoss] and the single-symbol
    SPY strategy's stop exit are the only [StopLoss] emitters.

    {b Level in force.} [stop_price] is the level the stops pass checked bar T
    against, and that is the level in force BEFORE bar T:
    [Weinstein_stops.update] tests the hit against the incoming state and
    returns it unchanged on [Stop_hit] (the trail is only raised on a bar that
    did not hit), and [Stops_runner] builds the exit from that pre-advance
    state. So a same-bar fill never uses a level derived from bar T itself.

    {b Conversion guard.} An exit converts only when its symbol has a fresh bar
    this step AND that bar trades through [stop_price] (low [<=] stop for a
    Sell, high [>=] stop for a Buy). A trigger the bar does not reach — e.g. a
    catastrophic-stop exit (its [stop_price] field carries the structural level,
    which the bar did not reach) — stays a Market order. Should the engine still
    leave a converted order unfilled, it is turned back into a Market order in
    place, so it fills at the next fresh open exactly as with the flag off. *)

val select :
  enabled:bool ->
  transitions:Trading_strategy.Position.transition list ->
  order_links:(string * string) list ->
  today_bars:Trading_engine.Types.price_bar list ->
  Trading_orders.Types.order list ->
  Trading_orders.Types.order list * Trading_orders.Types.order list
(** [select ~enabled ~transitions ~order_links ~today_bars orders] partitions
    [orders] into [(stop_orders, rest)]. [stop_orders] are the Market orders
    that close a position whose [TriggerExit] in [transitions] carries
    [StopLoss { stop_price; _ }] (matched through [order_links], the
    [(order_id, position_id)] pairs {!Order_generator} returned), re-typed as
    [Stop stop_price] and passing the conversion guard. [rest] keeps every other
    order unchanged and in order. With [enabled = false] the result is
    [([], orders)]. *)

val execute :
  engine:Trading_engine.Engine.t ->
  order_manager:Trading_orders.Manager.order_manager ->
  date:Core.Date.t ->
  Trading_orders.Types.order list ->
  Trading_base.Types.trade list Status.status_or
(** [execute ~engine ~order_manager ~date stop_orders] submits [stop_orders],
    runs one engine pass restricted to exactly those orders against the bars the
    engine already holds for this step, and returns their fills re-stamped with
    [date] ({!Fill_date_stamp}). A converted order the pass did not fill is
    reverted to [Market] in the order manager. [[]] in, [Ok []] out, with no
    engine or manager call. *)
