(** Split detection and application — broker portfolio + strategy-side
    {!Trading_strategy.Position.t} map updates. Pure helpers extracted from
    {!Simulator} so the simulator stays under the file-length limit and the
    split-handling logic is independently unit-testable.

    Two-side scaling is required because the simulator threads two parallel
    representations of the same position state: the broker portfolio
    ({!Trading_portfolio.Portfolio.t}) and the strategy-facing
    {!Trading_strategy.Position.t} map. Both must be scaled in lockstep on every
    detected split or the views diverge.

    No behavior change relative to the pre-extraction simulator — the helpers
    were lifted verbatim. *)

open Core

val detect_for_symbol :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  date:Date.t ->
  symbol:string ->
  Trading_portfolio.Split_event.t option
(** Detect a split for [symbol] between the prior trading day's bar and today's
    bar. Returns [Some event] when both bars exist and
    {!Types.Split_detector.detect_split} fires; otherwise [None]. Pure with
    respect to the adapter's cache. *)

val detect_for_held_positions :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  date:Date.t ->
  portfolio:Trading_portfolio.Portfolio.t ->
  Trading_portfolio.Split_event.t list
(** For every symbol currently held in [portfolio], call {!detect_for_symbol}.
    Symbols with no current bar (weekends/holidays) or no prior bar (first
    appearance) yield no event. Order follows [portfolio.positions] (sorted by
    symbol). *)

val apply_events :
  Trading_portfolio.Portfolio.t ->
  Trading_portfolio.Split_event.t list ->
  Trading_portfolio.Portfolio.t
(** Apply each detected split event to [portfolio] in order. Pure: returns the
    updated portfolio with all events folded in. *)

val apply_to_position :
  float -> Trading_strategy.Position.t -> Trading_strategy.Position.t
(** Apply a split [factor] to a strategy-side {!Trading_strategy.Position.t}'s
    share-count and per-share-price fields. Long-only path: [Holding.quantity]
    multiplies by [factor] and [Holding.entry_price] divides by [factor],
    preserving total cost basis. [Exiting] mirrors the same scaling on its
    share-count fields ([quantity], [target_quantity], [filled_quantity]) and
    per-share-price fields ([entry_price], [exit_price]). [Entering] (in-flight
    entry order) and [Closed] (historical) pass through unchanged: an entry
    order spanning a split is exotic and out of scope for the broker-model fix;
    closed positions have no live state to scale.

    Pure: returns a new [Position.t] with [state] replaced. The position's [id],
    [symbol], [side], [entry_reasoning], [exit_reason], [last_updated], and
    [portfolio_lot_ids] are unchanged. *)

val apply_to_positions :
  Trading_strategy.Position.t String.Map.t ->
  Trading_portfolio.Split_event.t list ->
  Trading_strategy.Position.t String.Map.t
(** Apply detected split events to the strategy-side {!Position.t} map. Each
    event matches positions by symbol; multiple positions on the same symbol
    (lots reopened after a prior close) all get scaled. Order matches
    {!apply_events}: events are folded in detection order. Pure. *)
