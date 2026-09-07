(** The simulator step's forced-exit phase: both runners, in the one order that
    is correct, plus the announcement that makes their labels visible.

    Extracted from [simulator.ml] so the ordering below lives in one place with
    a name, rather than as a sequence of [let]s inside
    [Simulator._prepare_market_state].

    {2 The order is the contract}

    {!Delisted_exit_runner} runs {b first}. A held symbol whose [active_through]
    marker has passed is a {e known} delisting: an expected corporate action,
    exited at its last real close and labelled ["delisted"]. Only what is left
    over reaches {!Stale_exit_runner}, whose ["stale_force_exit"] therefore
    means "this symbol stopped printing bars and nothing in the warehouse
    explains why" — a data defect by definition, and the thing the validator's
    V16 report counts. Reverse the order and every marked delisting is
    mis-reported as a defect, burying the real ones. See
    [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms".

    Both runners realise their exits directly rather than routing a
    [TriggerExit] order (the {!Margin_runner} pattern), because the symbol has
    {b no bar today} and the engine cannot fill an order against absent market
    data. {!Forced_exit} owns those shared mechanics. *)

open Core

val run :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  active_through_for:(string -> Date.t option) option ->
  stale_config:Stale_hold.config ->
  commission:Trading_engine.Types.commission_config ->
  date:Date.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  last_known_price:(symbol:string -> float option) ->
  on_transitions:(Trading_strategy.Position.transition list -> unit) option ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Trading_strategy.Position.t String.Map.t ->
  unit ->
  Trading_portfolio.Portfolio.t
  * Trading_strategy.Position.t String.Map.t
  * Trading_base.Types.trade list
(** Run both exits in order and return the post-exit
    [(portfolio, positions, trades)], with [trades] chronological and ready to
    merge into the step's trade list.

    [active_through_for] is [None] when the caller supplies no delisting-marker
    lookup, which skips the delisted runner entirely. Note it is also a no-op
    with a lookup present but every marker [None] — which is every warehouse
    built to date, since none populates [active_through].

    [on_transitions] is invoked with the [TriggerExit; ExitFill; ExitComplete]
    triple of every applied exit — the path by which the labels reach
    [trades.csv] via [Backtest.Stop_log.record_transitions] (#2687). It is
    {b not} called when nothing was exited: forced exits are rare, and skipping
    the empty call keeps the observer's per-step call count identical to what it
    was before #2687 on every other step. Both runners are no-ops when
    [today_bars] is empty (a weekend / holiday must not trip an exit), so this
    whole phase is inert on a bar-less day. *)
