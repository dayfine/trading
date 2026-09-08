(** The simulator step's forced-exit phase: both exit runners in the one order
    that is correct, the entry-side ticket cancel that closes the same data
    signal on the other half of the book, plus the announcement that makes their
    labels visible.

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
    data. {!Forced_exit} owns those shared mechanics.

    {2 The third action: cancelling resting tickets}

    {!Delisted_ticket_cancel} runs {b last} and is {e not} part of the ordering
    contract above: it selects only wholly-unfilled [Entering] tickets, which
    neither exit runner can reach (both require a non-zero broker quantity), so
    the three act on disjoint halves of the book and their relative order cannot
    change the result. It runs here because it answers the same question from
    the same data — this symbol stopped existing, so nothing of ours may still
    be pointed at it — and because it must precede the step's
    [Engine.process_orders], which is what would otherwise fill the dead ticket.
    Unlike both runners it is {b not} gated on [today_bars]; see its .mli for
    why a bar-less day is exactly when the hole is reachable. *)

open Core

val run :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  order_manager:Trading_orders.Manager.order_manager ->
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
    lookup, which skips both the delisted runner and the ticket cancel entirely.
    Note it is also a no-op with a lookup present but every marker [None] —
    which is every warehouse built before #2691, since none populates
    [active_through].

    [order_manager] is the manager holding the run's resting orders; it is read
    and mutated only by {!Delisted_ticket_cancel}, to retire the order behind a
    ticket it cancels (a "cancelled" ticket whose order still fills is worse
    than no cancel at all).

    [on_transitions] is invoked with the [TriggerExit; ExitFill; ExitComplete]
    triple of every applied exit, followed by one [CancelEntry] per retired
    ticket — the path by which the labels reach [trades.csv] via
    [Backtest.Stop_log.record_transitions] (#2687) and [trade_audit.sexp]. It is
    {b not} called when nothing was exited or cancelled: forced exits are rare,
    and skipping the empty call keeps the observer's per-step call count
    identical to what it was before #2687 on every other step. Both exit runners
    are no-ops when [today_bars] is empty (a weekend / holiday must not trip an
    exit); the ticket cancel is not, so on a bar-less day this phase is inert
    except for tickets whose marker has passed. *)
