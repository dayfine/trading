(** One Friday of the Weinstein strategy, captured stage by stage.

    {!run} drives the strategy's own Friday path and keeps what each stage saw
    and decided, for {!Friday_trace_printer.render}. It decides nothing itself:

    - the macro gate is
      {!Weinstein_strategy.Weinstein_strategy_macro.run_macro_only} and the
      screen, ranking and entry walk are one
      {!Weinstein_strategy.Weinstein_strategy_macro.entry_transitions_if_active}
      call, the two functions [on_market_close] runs on a Friday. Their outcomes
      are read back through the strategy's {!Weinstein_strategy.Audit_recorder}:
      cascade drops, walk decisions, entry events.
    - the per-stock inputs, stages, sector ratings, ranking order and stop
      measurements are recomputed for display through the same exported
      functions the screen uses, on copies of the strategy state.

    [test_friday_demo.ml] checks {!run}'s orders against [on_market_close] on
    the same fixture, so this module cannot drift from production unnoticed.

    Not covered: A-D, breadth and global-index inputs to the macro gate (the
    demo has none), and the exits and stop updates a held position would get;
    with no positions they have nothing to do. *)

type inputs = {
  config : Weinstein_strategy.Weinstein_strategy_config.config;
  bar_reader : Weinstein_strategy.Bar_reader.t;
  ticker_sectors : (string, string) Core.Hashtbl.t;
  portfolio : Trading_strategy.Portfolio_view.t;
}

val price_on :
  Weinstein_strategy.Bar_reader.t ->
  Core.Date.t ->
  string ->
  Types.Daily_price.t option
(** [price_on bar_reader date symbol] is [symbol]'s bar dated [date]: the
    [get_price] a simulator hands [on_market_close] that day. *)

val strategy :
  inputs ->
  state:Weinstein_strategy.Weinstein_strategy_state.t ->
  (module Trading_strategy.Strategy_interface.STRATEGY)
(** The real strategy over [inputs], running on [state]. *)

val warm_up :
  inputs ->
  fridays:Core.Date.t list ->
  Weinstein_strategy.Weinstein_strategy_state.t
(** [warm_up inputs ~fridays] runs {!strategy}'s [on_market_close] on each of
    [fridays] (oldest first) from a fresh state and returns the state it leaves:
    last Friday's stage per stock and sector ETF, the macro read, and so on.
    Raises if [on_market_close] returns an error on any of them. *)

val run :
  inputs ->
  state:Weinstein_strategy.Weinstein_strategy_state.t ->
  Core.Date.t ->
  Friday_trace.t
(** [run inputs ~state friday] runs the strategy's Friday screen for [friday]
    against [state], advancing it as [on_market_close] would, and returns each
    stage's result. [friday] must be a screening day for the primary index. *)
