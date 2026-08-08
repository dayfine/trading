(** Fix #1 next-bar-open fill gate for Market ENTRY orders (default-off
    [sim_entry_fill_next_open]; dev/plans/fill-model-faithfulness-2026-08-07.md
    Workstream C). *)

open Core

val make :
  positions:Trading_strategy.Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  Trading_orders.Types.order ->
  bool
(** [make ~positions ~today_bars] is the [?can_fill] predicate passed to
    {!Trading_engine.Engine.process_orders}. It returns [false] (holding the
    order back for this step) only for a Market order that would open
    ([Entering]) a position in [positions] whose symbol has no fresh bar in
    [today_bars]; such an order stays active and fills at the next fresh trading
    bar's open — the earliest tradeable price after the signal-close decision.

    Every other order passes: exits, stops, [StopLimit] entries, and Market
    orders on a symbol that has a fresh bar this step (routed by (symbol,
    entry-side) against the [Entering] positions, mirroring {!Fill_router}). The
    caller applies this predicate only when [sim_entry_fill_next_open] is on;
    with it off, no [?can_fill] is supplied and fills are bit-identical to
    before. *)
