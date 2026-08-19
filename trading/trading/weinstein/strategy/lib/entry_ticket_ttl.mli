(** F2 — resting entry-ticket lifecycle: re-screen cancel (primary) + clock TTL
    (backstop). Plan [dev/plans/entry-ticket-async-v2-2026-08-10.md] §2-M2 /
    §3-F2.

    {b The gap it closes.} Under the StopLimit entry family an unfilled entry
    order rests indefinitely — pinned by
    [trading/simulation/test/test_gtc_entry_persistence.ml], which shows the
    order surviving every later step until a bar trades through [E]. That is
    Good-Till-{i Cancelled} with no cancel authority anywhere in the system, so
    the "Cancelled" half of the book's own contract is missing: §4.7 says the
    order stands "until you either cancel the orders or they are actually
    executed", and §7's weekend homework is the loop at which that cancel
    decision is taken. A ticket written against a base that has since broken
    down is a setup that no longer exists; today it still fills.

    {b What this module decides.} Given the strategy's positions on a weekly
    review tick, which {b unfilled} [Entering] positions should be cancelled:

    - {b Primary — re-screen cancel.} The symbol fails the next weekly
      re-screen: it no longer classifies into the stage its side requires (base
      broken down / MA rolled over), its sector rating flipped against it, or
      the macro gate flipped. The caller supplies this as [still_qualifies];
      {!Weinstein_strategy_screening} builds it from the same Phase-1 stage
      filter, sector pre-filter, and {!Screener.longs_admitted_by_macro} /
      {!Screener.shorts_admitted_by_macro} gates the cascade itself uses, so
      re-screen and screen cannot drift.
    - {b Backstop — clock TTL.} The ticket has rested strictly longer than
      [max_rest_weeks] weekly reviews without filling. The book grants cancel
      authority but names no number, so this is a {b BOOK-NEUTRAL dial}.

    {b The two are independently armed} ([rescreen] / [max_rest_weeks]) as of
    2026-08-16, defect C of [dev/plans/entry-anchor-and-ttl-2026-08-15.md]. They
    used to share one [ttl_weeks] knob that returned [[]] at [0] without even
    consulting the re-screen predicate, so the book-supported half was
    unreachable without the invented one. That conflation is also why the
    ladder-v4 finding — ttl4 and ttl8 indistinguishable against a 132.5pp null,
    i.e. the re-screen doing the work and the number being free — could not be
    stated as a config fact before now.

    Cancellation emits a [Position.CancelEntry] transition. The strategy is the
    only decider; the simulator's matching order-cancel path lives in
    {!Trading_simulation.Cancel_handler.cancel_resting_entry_orders} (without it
    a "cancelled" ticket would still fill).

    {b The no-op configuration.} [rescreen = false] with [max_rest_weeks = 0]
    returns [[]] unconditionally and never touches the pin table — no clock
    cancel, no re-screen cancel, weekly re-issue and GTC-forever persistence
    exactly as before, i.e. the old [ttl_weeks = 0]. This {b extends} the
    persistence contract; it does not weaken it.

    Note this is no longer what the {i config defaults} produce: since
    2026-08-18 [Weinstein_strategy_config.entry_order_max_rest_weeks] ships at
    {b 26}, so the default path arms the clock. This function's contract is
    unchanged — only which arguments the shipped config passes it. *)

open Core
module Position = Trading_strategy.Position

val cancellations :
  rescreen:bool ->
  max_rest_weeks:int ->
  positions:Position.t String.Map.t ->
  still_qualifies:(symbol:string -> side:Position.position_side -> bool) ->
  current_date:Date.t ->
  Position.transition list
(** [cancellations ~rescreen ~max_rest_weeks ~positions ~still_qualifies
     ~current_date] returns one [CancelEntry] transition per resting ticket that
    should be cancelled, in [positions] key order.

    A position is considered only when it is [Entering] with
    [filled_quantity = 0.0]. Partially-filled entries are deliberately skipped:
    [CancelEntry] closes the position outright, which would strand the already
    booked shares (the same discipline
    {!Trading_simulation.Cancel_handler.revert_rejected_exits} applies on the
    exit side, and which [Position]'s own [CancelEntry] validator enforces).
    [Holding] / [Exiting] / [Closed] positions are never touched — this is an
    order-lifecycle rule, not an exit rule.

    A qualifying ticket is cancelled when either:
    - [rescreen] is [true] and [still_qualifies ~symbol ~side] is [false]
      (primary), or
    - [max_rest_weeks > 0] and it has rested more than that many whole weeks
      (backstop). Age is [Date.diff current_date created_date / 7] against the
      [Entering] state's [created_date], so a ticket placed on review week 0
      survives review week [max_rest_weeks] and is cancelled at review week
      [max_rest_weeks + 1]. [max_rest_weeks <= 0] means {b unbounded}, not "off"
      — the re-screen still runs when [rescreen] is set.

    The re-screen is evaluated first, so its reason wins when both would fire.

    Returns [[]] when neither is armed — [still_qualifies] is not even consulted
    (R1). *)

val run :
  rescreen:bool ->
  max_rest_weeks:int ->
  pending_entry_e:Entry_freeze.t ->
  positions:Position.t String.Map.t ->
  still_qualifies:(symbol:string -> side:Position.position_side -> bool) ->
  current_date:Date.t ->
  Position.transition list
(** {!cancellations} plus the pin-lifecycle side effect: every cancelled
    symbol's frozen entry [E] is released via {!Entry_freeze.release}, so the
    symbol may re-qualify later at a fresh [E] rather than at the level its
    expired ticket was written against.

    Releasing here is load-bearing (plan §6 "TTL × freeze"): on the cancelling
    tick the symbol is still held, and after a clock-TTL cancel it may still be
    qualifying, so {!Entry_freeze.apply}'s stale-release rule would keep the
    stale pin under both. The complementary half — that a ticket which is
    {b still} resting does not ratchet [E] upward week over week — is
    {!Entry_freeze.apply}'s existing behaviour and is unchanged.

    Releasing an unpinned symbol (i.e. [freeze_entry_at_first_breakout = false],
    where the table is never populated) is a no-op, so this is safe to call
    unconditionally. *)
