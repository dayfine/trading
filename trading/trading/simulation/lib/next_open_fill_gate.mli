(** Next-bar-open fill gate for Market ENTRY orders (Fix #1, default-off
    [sim_entry_fill_next_open]) and Market EXIT orders (Fix #1b, default-off
    [sim_exit_fill_next_open]); dev/plans/fill-model-faithfulness-2026-08-07.md
    Workstream C. *)

open Core

val make :
  defer_entries:bool ->
  defer_exits:bool ->
  positions:Trading_strategy.Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  Trading_orders.Types.order ->
  bool
(** [make ~defer_entries ~defer_exits ~positions ~today_bars] is the [?can_fill]
    predicate passed to {!Trading_engine.Engine.process_orders}. It returns
    [false] (holding the order back for this step) only for a Market order in an
    {b armed} class whose symbol has no fresh bar in [today_bars]; such an order
    stays active and fills at the next fresh trading bar's open — the earliest
    tradeable price after the signal-close decision.

    The two classes are armed independently:

    - [defer_entries] ([sim_entry_fill_next_open]) covers a Market order that
      would OPEN an [Entering] position in [positions];
    - [defer_exits] ([sim_exit_fill_next_open]) covers a Market order that would
      CLOSE an [Exiting] position (a full exit or a partial trim alike — both
      leave the position in [Exiting] with one resting Market order).

    Both classes route by (symbol, side) against the matching position state,
    mirroring {!Fill_router}: [Fill_router.entry_trade_side] for entries,
    [Fill_router.exit_trade_side] for exits. State alone would misclassify a
    Sell when a scale-in add is [Entering] while the original position is
    [Exiting] on the same symbol.

    Every other order passes: an unarmed class, a Market order on a symbol that
    has a fresh bar this step, and every {b non-Market} order type. The
    non-Market exemption is deliberate rather than incidental: today
    {!Order_generator} emits exits only as Market orders
    ([_exit_order_for_position] takes [_create_order]'s default [order_type]),
    so no exit reaches this gate as a [StopLimit]; and were one to, it carries
    its own trigger/limit prices, so a retained stale bar cannot fill it at a
    look-back price the way an unconditional Market order can. The [StopLimit]
    entry model (#2158) is exempt for the same reason.

    The caller supplies this predicate only when at least one flag is on; with
    both off, no [?can_fill] is supplied at all and fills are bit-identical to
    before (R1). *)
