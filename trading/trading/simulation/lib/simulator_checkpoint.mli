(** Serialisable simulator state for resumable backtests (#3477 PR 3).

    {!t} holds every simulator-owned item the state inventory
    ([dev/notes/resumable-backtest-state-inventory.md]) marks S, as plain data
    with sexp derivers: no closures, no hash tables, and every collection in a
    canonical order so equal states print equal. Strategy state (PR 4) and
    recorders (PR 5) are deliberately absent.

    {!capture_deps} / {!restore_deps} cover the dependency-owned half; the
    simulator-owned half is read and written by [Simulator.Checkpoint], which
    can see the simulator's private record. *)

type deps_state = {
  orders : Trading_orders.Types.order list;
      (** Every order the manager has ever accepted, in insertion order. Order
          statuses are carried, so resting and filled orders round-trip alike;
          re-submitting in this order reproduces the insertion sequence. *)
  engine : Trading_engine.Engine.snapshot;
  entry_fill_retry : Entry_fill_retry.snapshot;
  cash_yield_total : float option;  (** [None] when interest is not armed. *)
  dividends : Trading_simulation_dividends.Dividend_crediting.snapshot option;
      (** [None] when dividends are not armed. *)
  stale_hold_log : Stale_hold.event list;  (** Newest first, as stored. *)
}
[@@deriving sexp]

type t = {
  current_date : Core.Date.t;
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Trading_strategy.Position.t Core.String.Map.t;
  steps : Trading_simulation_types.Simulator_types.step_result list;
      (** The accumulated step history, oldest first. *)
  last_known_prices : (string * float) list;  (** Sorted by symbol. *)
  valuation_failure_count : int;
  order_links : Fill_router.snapshot;
  deps : deps_state;
}
[@@deriving sexp]

val capture_deps :
  order_manager:Trading_orders.Manager.order_manager ->
  engine:Trading_engine.Engine.t ->
  entry_fill_retry:Entry_fill_retry.t ->
  cash_credits:Cash_credits.t ->
  stale_hold_log:Stale_hold.Log.t ->
  deps_state
(** Read the dependency-owned state. *)

val restore_deps :
  order_manager:Trading_orders.Manager.order_manager ->
  engine:Trading_engine.Engine.t ->
  entry_fill_retry:Entry_fill_retry.t ->
  cash_credits:Cash_credits.t ->
  stale_hold_log:Stale_hold.Log.t ->
  deps_state ->
  unit Status.status_or
(** Write [deps_state] into freshly built dependencies, in place. The order
    manager must be empty. [Error] when the checkpoint armed interest or
    dividends that these dependencies do not (or the reverse), or an order is
    refused. *)
