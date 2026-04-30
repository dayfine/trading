(** Force-liquidation policy applied to held positions.

    Runs at end of {!Weinstein_strategy._on_market_close}, AFTER
    {!Stops_runner.update}. Responsibilities:

    1. Build {!Portfolio_risk.Force_liquidation.position_input}s from the
    portfolio's [Holding] positions + current bar prices. 2. Compute current
    [portfolio_value] and call {!Portfolio_risk.Force_liquidation.check} — which
    updates the peak-tracker and returns the events to fire. 3. For each event,
    emit a [TriggerExit] transition (kind:
    {!Trading_strategy.Position.StopLoss}) and a parallel
    [record_force_liquidation] audit event.

    The strategy state machine sees a regular [TriggerExit]; the audit channel
    is what distinguishes a forced close from a regular stop-out. The [Halted]
    state in the [peak_tracker] is consulted by the strategy to suppress new
    entries until macro flips off Bearish.

    Pure function over its inputs — no global state. Reads [peak_tracker]
    (mutates it via [Force_liquidation.check]) and [audit_recorder] (invokes the
    [record_force_liquidation] callback). *)

open Core
open Trading_strategy

val update :
  config:Portfolio_risk.Force_liquidation.config ->
  positions:Position.t Map.M(String).t ->
  get_price:Strategy_interface.get_price_fn ->
  cash:float ->
  current_date:Date.t ->
  peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.t ->
  audit_recorder:Audit_recorder.t ->
  Position.transition list
(** Run the force-liquidation policy and return TriggerExit transitions.

    [positions] is used both for the per-position
    [Force_liquidation.position_input]s and for the
    [Portfolio_view.portfolio_value] computation that drives the [peak_tracker].
    Callers that have already filtered out stop-exited-this-tick positions for
    double-exit avoidance MUST still pass the unfiltered set here — see
    {!Weinstein_strategy._on_market_close} for the safe pattern.

    G12 (2026-04-30): the strategy previously called this with a filtered
    position map ([live_positions]) but the unfiltered [cash] from the portfolio
    view. That mixed pre-tick cash with post-stop-filter positions, causing
    [Portfolio_view.portfolio_value] to phantom-spike whenever a short stop
    fired (the short's negative contribution disappeared from the sum, but its
    buy-back debit had not yet been applied to cash). Each spike permanently
    inflated [peak_tracker.peak], and on subsequent days the post-buyback cash
    fell below the inflated [0.4 * peak] floor — triggering mass
    [Portfolio_floor] events on still-profitable shorts. Per-position
    double-exit avoidance now happens at the strategy layer (filter the returned
    transitions), not by passing a filtered position map here.

    Side effects:
    - [peak_tracker] observe + halt-state update via
      {!Portfolio_risk.Force_liquidation.check}.
    - [audit_recorder.record_force_liquidation] called once per event.

    Empty list when no events fire — the common case. *)
