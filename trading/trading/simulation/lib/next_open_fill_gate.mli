(** Next-bar-open fill gate for Market ENTRY orders (Fix #1, default-off
    [sim_entry_fill_next_open]), Market EXIT orders (Fix #1b, default-on
    [sim_exit_fill_next_open]) and StopLimit ENTRY tickets (default-off
    [sim_entry_stoplimit_fresh_bar_only]);
    dev/plans/fill-model-faithfulness-2026-08-07.md Workstream C. *)

open Core

val make :
  defer_entries:bool ->
  defer_exits:bool ->
  ?defer_stoplimit_entries:bool ->
  positions:Trading_strategy.Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  Trading_orders.Types.order ->
  bool
(** [make ~defer_entries ~defer_exits ?defer_stoplimit_entries ~positions
     ~today_bars] is the [?can_fill] predicate passed to
    {!Trading_engine.Engine.process_orders}. It returns [false] (holding the
    order back for this step) only for an order in an {b armed} class whose
    symbol has no fresh bar in [today_bars]; such an order stays active and
    fills at the next fresh trading bar's open — the earliest tradeable price
    after the signal-close decision.

    The three classes are armed independently:

    - [defer_entries] ([sim_entry_fill_next_open]) covers a Market order that
      would OPEN an [Entering] position in [positions];
    - [defer_exits] ([sim_exit_fill_next_open]) covers a Market order that would
      CLOSE an [Exiting] position (a full exit or a partial trim alike — both
      leave the position in [Exiting] with one resting Market order);
    - [defer_stoplimit_entries] ([sim_entry_stoplimit_fresh_bar_only], default
      [false]) covers a [StopLimit] order that would OPEN an [Entering]
      position. A ticket placed at a Friday close is otherwise checked on the
      Saturday step against the retained Friday bar and fills inside a range
      that traded before the ticket existed (99 of 100 Saturday-dated entries on
      the 26y PIT record sit inside Friday's own bar). Held, it is first checked
      against the next fresh bar.

    Every class routes by (symbol, side) against the matching position state,
    mirroring {!Fill_router}: [Fill_router.entry_trade_side] for entries,
    [Fill_router.exit_trade_side] for exits. State alone would misclassify a
    Sell when a scale-in add is [Entering] while the original position is
    [Exiting] on the same symbol.

    Every other order passes: an unarmed class, any order on a symbol that has a
    fresh bar this step, and every order type other than Market and [StopLimit]
    entries. {!Order_generator} emits exits only as Market orders
    ([_exit_order_for_position] takes [_create_order]'s default [order_type]),
    so no exit reaches this gate as another type.

    An earlier version of this comment exempted [StopLimit] entries on the
    grounds that their own trigger/limit prices stop a stale bar from filling
    them at a look-back price. That does not hold for a ticket created AFTER the
    bar it is checked against: the trigger is tested against a range the ticket
    never saw. [defer_stoplimit_entries] closes that case; unarmed (the default)
    the old behaviour is kept bit-for-bit (R1).

    The caller supplies this predicate only when at least one flag is on; with
    all off, no [?can_fill] is supplied at all and fills are bit-identical to
    before (R1). *)

type flags = {
  defer_entries : bool;  (** Market entries; see [make]. *)
  defer_exits : bool;  (** Market exits; see [make]. *)
  defer_stoplimit_entries : bool;  (** StopLimit entry tickets; see [make]. *)
}
(** The three independently armed classes, as the simulator carries them. *)

val gate :
  flags ->
  positions:Trading_strategy.Position.t String.Map.t ->
  today_bars:Trading_engine.Types.price_bar list ->
  (Trading_orders.Types.order -> bool) option
(** [gate flags ~positions ~today_bars] is [Some (make ...)] when any class is
    armed and [None] when none is — so the engine receives no [?can_fill] at all
    and fills are bit-identical to the pre-gate simulator (R1). *)
