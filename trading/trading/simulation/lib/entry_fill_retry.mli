(** G2a — give a portfolio-refused entry fill another attempt instead of
    destroying the ticket ([dev/plans/ticket-funding-2026-08-16.md] §G2a).

    {b The failure.} {!Trading_engine.Engine} marks a resting entry order
    [Filled] the moment the fill function returns a trade, {i before}
    {!Cancel_handler.apply_trades_best_effort} asks the portfolio to book it.
    When the portfolio refuses — almost always insufficient cash —
    {!Cancel_handler.transitions_for_rejected_trades} emits a [CancelEntry] and
    the [Entering] position is deleted. The order is gone (it is marked filled)
    and the ticket is gone (it is cancelled), so
    {b one cash-tight instant permanently destroys a ticket} that may have
    rested for months. Measured over 3,530 rejections: median shortfall {b 52%}
    of the ticket's cost, but 5.1% are within 5% of fundable and one diagnostic
    ticket missed by {b 0.3%}.

    {b What this module does.} Given the run's retry budget
    ([Weinstein_strategy_config.entry_fill_reject_retries]) it decides, per
    refused trade, whether the ticket is retried or destroyed. A retried ticket
    keeps its [Entering] position untouched — it never filled, so there is
    nothing to unwind — and gets a {e fresh copy} of the refused order
    re-submitted to the order manager, which the engine re-offers on the next
    tick against whatever cash the book has by then. A destroyed ticket is
    handed back to the caller for the unchanged {!Cancel_handler} path.

    {b The retried order is matched by the heuristic, not by [order_links].}
    {!Fill_router} routes a fill with no recorded link by (symbol, state, side)
    — the same fallback every resting entry order already depends on, since the
    in-flight link set is replaced wholesale on each generation pass. This
    module deliberately does not call {!Fill_router.record}: that would replace
    the current pass's links rather than add to them.

    {b Default-off (R1).} At [max_retries = 0] {!handle_rejected_entries}
    returns its input unchanged and touches neither the ledger nor the order
    manager, so the simulator's behaviour is bit-identical to the pre-G2a path.
    No ledger verdict exists for this mechanism; it ships off. *)

open Core
module Position = Trading_strategy.Position

type t
(** Per-run ledger of retries already spent, keyed by position id. Mutable and
    reference-shared, like {!Stale_hold.Log.t}: one value lives in the
    simulator's dependencies for the life of a run. *)

val create : unit -> t
(** An empty ledger — no ticket has been retried yet. *)

val retries_used : t -> position_id:string -> int
(** [retries_used ledger ~position_id] is how many retries the ticket held by
    [position_id] has already consumed; [0] for a ticket that has never been
    refused (or has never been retried). Entries are kept after the ticket is
    finally destroyed, so a post-run reader can still see what a dead ticket
    cost. *)

val handle_rejected_entries :
  t ->
  max_retries:int ->
  order_manager:Trading_orders.Manager.order_manager ->
  positions:Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Trading_base.Types.trade list
(** [handle_rejected_entries ledger ~max_retries ~order_manager ~positions
     ~rejected_trades] re-offers the refused entry orders that still have retry
    budget and returns, {b in input order}, the trades that were {e not} retried
    and must therefore follow the unchanged cancel path
    ({!Cancel_handler.transitions_for_rejected_trades}).

    A trade is retried only when all of the following hold. Any failure falls
    through to the returned list, so the worst case is exactly today's behaviour
    and never a ticket left resting with no order behind it:

    + [max_retries > 0].
    + Some [Entering] position in [positions] carries the trade's symbol. A
      refused {e exit} matches none, so it passes straight through — the exit
      side has its own revert ({!Cancel_handler.revert_rejected_exits}) and must
      keep seeing the full rejected list.
    + That position has spent fewer than [max_retries] retries.
    + The refused order is still known to [order_manager] and the re-submitted
      copy is accepted by it.

    The copy carries the original's symbol, side, order type (including a
    [StopLimit]'s trigger and cap) and quantity, with a derived id, [Pending]
    status and no fills. The ledger is incremented only once the copy has been
    accepted, so a failed re-offer does not silently consume budget.

    {b Note the price the retry gets is not the price the ticket triggered at.}
    That timing cost is the mechanism's main expected failure mode and is argued
    in full on [Weinstein_strategy_config.entry_fill_reject_retries]. *)

val retry_order_id :
  order_id:Trading_orders.Types.order_id ->
  attempt:int ->
  Trading_orders.Types.order_id
(** The id minted for the [attempt]-th (1-based) re-offer of [order_id]:
    ["<base>#retry<attempt>"], where [<base>] is [order_id] with any existing
    ["#retry..."] suffix stripped — so a second retry is ["X#retry2"], not
    ["X#retry1#retry2"].

    Exposed for tests, and because the id is the only trace a re-offered order
    leaves in [trade_audit.sexp]: a reader grouping fills by originating ticket
    needs to know the suffix is not part of the generator's [<date>-<seq>]
    scheme. Derived from the original rather than minted from the clock so that
    two structurally identical runs produce identical ids (the determinism
    constraint {!Order_generator._make_id} exists for). *)
