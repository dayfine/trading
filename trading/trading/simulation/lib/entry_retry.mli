(** G2a of [dev/plans/ticket-funding-2026-08-16.md] — revert-and-retry for entry
    tickets whose fill the {b portfolio} refused.

    {b The failure this arbitrates.} A resting entry ticket triggers,
    {!Trading_engine.Engine.process_orders} marks its order [Filled] and hands
    the trade to the simulator, and only {i then} does
    {!Cancel_handler.apply_trades_best_effort} find the book cannot fund it. The
    trade is dropped, {!Cancel_handler.transitions_for_rejected_trades} emits a
    [CancelEntry], and the ticket is gone — with no order left to re-offer,
    because the engine already retired it. One cash-tight instant permanently
    destroys a ticket that may have rested for months, and it takes ~25% of
    would-be entries ([[project-ticket-dies-on-cash-shortfall]]).

    {b What this module changes.} The order is only {i provisionally} filled:
    the engine's [Filled] stamp is reversed back to [Pending] for any rejected
    entry that still has retry budget, so the same order is matched again on the
    next tick. The strategy-side position needs no repair — {!Fill_router} is
    only ever given the {i accepted} trades, so a rejected entry's position is
    still [Entering] with zero fills. Reversing the order is therefore the whole
    of the "revert to [Entering] with its resting order intact" prerequisite the
    plan names.

    {b Why the reversal is scoped to retried tickets only.} Reinstating an order
    the caller is about to [CancelEntry] would be worse than leaving it: a
    [Filled] order is inert, whereas a [Pending] one fills again next tick, and
    {!Cancel_handler.cancel_resting_entry_orders} does not retire it (it matches
    on the pre-transition position map, and a rejection-[CancelEntry] describes
    an order that has already been through the engine). So the retry decision
    and the reinstatement are one indivisible step — {!withhold_retryable} —
    rather than two the caller could interleave wrongly.

    {b The same order is re-offered} — same type, trigger and limit price. Under
    [enable_sim_entry_stoplimit] that means the do-not-chase cap
    ([entry_extension_max_pct], baked into the order's limit leg at generation)
    still binds on every retry: a ticket whose price has run past the cap does
    not fill and is not chased.

    {b Default off (R1).} At [max_retries = 0] {!withhold_retryable} returns its
    input and touches no order. *)

open Core

type t
(** A retry budget bound to the order manager it reinstates into, plus the
    per-[position_id] ledger of retries already spent. Mutable; the simulator
    creates one per run and reference-shares it across its per-step state
    copies, in the same way as [Simulator.last_known_prices].

    Budget and manager are held here rather than passed per call so a caller
    cannot pair a ledger with the wrong budget, or reinstate into a manager
    other than the one whose orders it is counting. *)

val create :
  max_retries:int -> order_manager:Trading_orders.Manager.order_manager -> t
(** [create ~max_retries ~order_manager] is an unspent ledger allowing each
    entry ticket [max_retries] re-offers. [max_retries <= 0] disables the
    mechanism entirely. *)

val retries_used : t -> position_id:string -> int
(** Retries already spent on [position_id]; [0] for a ticket that has never been
    rejected. Exposed for tests and diagnostics. *)

val withhold_retryable :
  t ->
  positions:Trading_strategy.Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Trading_base.Types.trade list
(** [withhold_retryable t ~positions ~rejected_trades] claims every rejected
    trade that still has retry budget — charging that budget and putting the
    trade's originating order back to [Pending] so
    {!Trading_engine.Engine.process_orders}, which lists [ActiveOnly], matches
    it again next tick — and returns the trades it did {b not} claim, in input
    order.

    The caller passes that remainder to
    {!Cancel_handler.transitions_for_rejected_trades} exactly as it used to pass
    the whole list. So the [CancelEntry] audit trail ([cancel_reason],
    [ticket_age_weeks_at_cancel]) is unchanged for tickets that are ultimately
    destroyed — it just fires once the budget is exhausted rather than on the
    first rejection.

    A trade is claimed only when all of:
    - the ticket has spent fewer than [max_retries] retries so far;
    - some position in [positions] is [Entering] on the trade's symbol with
      [filled_quantity = 0.0] — an unfilled resting ticket. A partially filled
      one has already booked shares, so re-offering its order would double them
      (the entry-side reading of the guard
      {!Cancel_handler.revert_rejected_exits} applies to [Exiting]);
    - the trade's side is the one that {e opens} that position ([Buy] for a
      long, [Sell] for a short). Without this guard a rejected {i exit} on a
      symbol that happens to carry an entering sibling would silently spend the
      entry ticket's budget; such a trade belongs to
      {!Cancel_handler.revert_rejected_exits};
    - its order is still the wholly-unfilled [Filled] order the engine just
      stamped. An order that is missing or in any other state is left alone and
      its trade is not claimed, so it follows the normal cancel path.

    At [max_retries <= 0] this is the identity on [rejected_trades] and the
    ledger is not written. *)
