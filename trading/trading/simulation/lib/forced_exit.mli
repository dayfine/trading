(** Applies a simulator-side forced exit: a position closed at a price the
    engine cannot fill an order against, because the symbol has no bar today.

    Extracted from {!Stale_exit_runner} so that module and
    {!Delisted_exit_runner} share one implementation of "realise this position
    at this price, close its strategy [Position.t], and report what happened".
    The two differ only in {b which} held positions they select and {b why} —
    this module owns the mechanics, not the policy.

    The distinction the two callers encode matters and is the point of the split
    (see [dev/plans/delisting-data-fix-2026-09-06.md] §"Principle: fallbacks are
    quality flags, not mechanisms"):

    - {!Delisted_exit_runner} exits on a {b known} delisting marker. That is an
      EXPECTED event and its ["delisted"] label is not a defect signal.
    - {!Stale_exit_runner} exits a symbol that simply stopped printing bars with
      no marker to explain it. That is a {b safety net}, and every
      ["stale_force_exit"] row is a data-quality flag to chase down.

    Strategy-agnostic: it operates on the broker portfolio and the generic
    [Position.t] state machine. *)

open Core

type request = {
  symbol : string;
  signed_quantity : float;
      (** Held quantity, signed: positive for a long (flattened with a Sell),
          negative for a short (flattened with a Buy). A request with quantity
          [0.0] produces no trade. *)
  exit_price : float;
      (** The price to realise at. Callers supply the last {b real} close for
          the symbol — there is no bar today, so this is the only meaningful
          market price. *)
  reason : Trading_strategy.Position.exit_reason;
      (** Stamped on the [TriggerExit] transition, and therefore on the
          [exit_trigger] column of [trades.csv] via
          [Backtest.Stop_log.record_transitions] (#2687). *)
  id_tag : string;
      (** Short slug identifying the exit path in the synthetic trade's [id] /
          [order_id] (e.g. ["stale-exit"], ["delisted-exit"]), so a row in
          [trades.csv] can be traced to the runner that produced it. No engine
          order can produce these ids. *)
}
(** One position to force-exit. Built by the caller from its own selection
    policy. *)

type outcome = {
  portfolio : Trading_portfolio.Portfolio.t;
  positions : Trading_strategy.Position.t String.Map.t;
  trades : Trading_base.Types.trade list;
      (** Realised synthetic trades in request order, ready to merge into the
          step's trade list. *)
  transitions : Trading_strategy.Position.transition list;
      (** The [TriggerExit; ExitFill; ExitComplete] triple per {b applied} exit,
          in request order, ready to hand to
          [Simulator.dependencies.on_transitions]. *)
}
(** The post-exit state plus what was actually done. *)

val apply_all :
  date:Date.t ->
  commission:Trading_engine.Types.commission_config ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Trading_strategy.Position.t String.Map.t ->
  request list ->
  outcome
(** [apply_all ~date ~commission ~portfolio ~positions requests] applies each
    request in order. For each:

    - builds a synthetic market trade at [request.exit_price] (a long is
      flattened with a Sell, a short with a Buy) carrying the engine's
      [max(per_share * qty, minimum)] commission;
    - applies it to [portfolio] ([apply_single_trade]) — realising the P&L and
      freeing cash;
    - drives the matching Holding [Position.t] through Exiting to Closed and
      drops it from [positions].

    A request the portfolio {b rejects} (e.g. the position was already
    flattened) is skipped: it contributes neither a trade nor a transition. So
    is a request with no matching Holding [Position.t] — except that its trade
    still lands, since the portfolio, not the strategy map, is the source of
    truth for realised P&L. An observer is therefore never told about an exit
    that did not happen.

    An empty request list returns the inputs unchanged with both lists empty —
    the byte-identical no-op path both callers take on almost every step. *)
