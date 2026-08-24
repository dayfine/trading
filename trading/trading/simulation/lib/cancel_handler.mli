(** Cancel/revert transition builder + applier — extracted from the simulator so
    the file stays under its declared-large size limit.

    Handles the two ways a portfolio-rejected fill can strand a strategy
    position:

    {b Entry side ([transitions_for_rejected_trades] + [apply_to_positions]).}
    When an {e entry} fill is rejected by [Portfolio.apply_single_trade]
    (typically on insufficient cash from a next-day-open gap-up that exceeds the
    strategy's sizing headroom), the corresponding [Entering] position stays
    stuck with 0 fills. Strategies whose entry-idempotency check excludes only
    [Closed] (e.g. BAH's [_has_position_for_symbol]) then never retry. The
    simulator works around that by emitting a [CancelEntry] transition for each
    rejected trade so the position transitions to [Closed] and the strategy can
    retry from a clean slate on the next market close. See PR #1172 follow-up
    §"Option B".

    {b Exit side ([revert_rejected_exits]).} The exit-side mirror, added for
    issue #1553. When an {e exit} (cover/sell) fill is rejected by the portfolio
    (the same cash floor can reject a short cover in a bear market — NAV with
    heavy paper losses leaves effective cash below the cover cost), the position
    is left stranded in [Exiting] forever: the stop machinery only re-evaluates
    [Holding] positions, so the exit never re-fires and the (often short)
    position rides the adverse move unbounded. [revert_rejected_exits] reverts
    each such [Exiting] position back to [Holding], so the stop re-evaluates
    next cycle and re-triggers the exit — a natural retry loop. *)

open Core
module Position = Trading_strategy.Position

val portfolio_rejection_reason : string
(** The reason token stamped on every [CancelEntry] this module builds:
    ["entry_fill_rejected_by_portfolio"]. Exposed so a reader (and the tests)
    can group ticket deaths by cause without matching prose. It sits in the same
    namespace as {!Weinstein_strategy.Entry_ticket_ttl}'s
    [entry_ticket_ttl_expired] / [entry_ticket_requalification_failed], which
    are the only other ways a resting entry ticket dies. *)

val transitions_for_rejected_trades :
  date:Date.t ->
  positions:Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Position.transition list
(** [transitions_for_rejected_trades ~date ~positions ~rejected_trades] emits
    one [CancelEntry] transition per rejected trade, matched by symbol against
    the [Entering] positions in [positions]. Rejected trades whose symbol has no
    [Entering] match are silently skipped (defensive — should not happen given
    the strategy invariant). *)

val cancel_resting_entry_orders :
  order_manager:Trading_orders.Manager.order_manager ->
  positions:Position.t String.Map.t ->
  transitions:Position.transition list ->
  Trading_orders.Types.order_id list
(** [cancel_resting_entry_orders ~order_manager ~positions ~transitions] cancels
    the still-active, wholly-unfilled entry orders belonging to the
    [CancelEntry] transitions in [transitions], returning the cancelled order
    ids.

    {b Why this exists.} [CancelEntry] closes the strategy-side [Entering]
    position, but the order it created lives in the order manager and — per the
    GTC persistence contract pinned by [test_gtc_entry_persistence.ml] — would
    otherwise stay [Pending] and still fill on a later bar. A "cancelled" ticket
    that fills anyway is worse than no cancel at all, so the strategy's F2
    decision ({!Weinstein_strategy.Entry_ticket_ttl}) is only real once the
    order is retired too.

    [positions] must be the map {e before} the transitions are applied — that is
    where the cancelled position is still [Entering] and still carries its
    symbol and side. Orders are matched on (symbol, entry order side: [Buy] for
    a long, [Sell] for a short) and must be active with [filled_quantity = 0.0].
    That is the same (symbol, side) heuristic {!Fill_router} already relies on:
    the per-step [order_links] table is cleared on every generation pass, so an
    order placed on an earlier step cannot be identified by position id. A
    partially-filled order is left alone — its shares are booked, and
    {!Weinstein_strategy.Entry_ticket_ttl} will not have emitted a [CancelEntry]
    for it.

    Returns [[]] — touching neither the manager nor its order list — when
    [transitions] contains no [CancelEntry] whose position is a resting
    [Entering]. Today only F2 emits such a transition from a strategy; the
    rejected-fill [CancelEntry]s built by {!transitions_for_rejected_trades}
    describe orders that already filled, so they match nothing here. *)

val apply_to_positions :
  Position.t String.Map.t ->
  Position.transition ->
  Position.t String.Map.t Status.status_or
(** [apply_to_positions positions trans] applies a transition (a [CancelEntry]
    on the entry side, or a [CancelExit] on the exit side) to [positions] via
    [Position.apply_transition]. Drops the position from the map when it reaches
    the terminal [Closed] state — same convention used by the simulator for
    [TriggerExit] under [_set_or_drop_if_closed]. (A [CancelExit] reverts to
    [Holding], not [Closed], so the position is retained, updated in place.)

    Returns the original map unchanged when the transition's position_id has no
    entry in [positions] (defensive — same shape as the simulator's
    [_apply_trigger_exit]). *)

val apply_trades_best_effort :
  ?on_trade_fill:(Trading_base.Types.trade -> Trading_base.Types.trade) ->
  ?initial_long_margin_req:float ->
  Trading_portfolio.Portfolio.t ->
  Trading_base.Types.trade list ->
  Trading_portfolio.Portfolio.t
  * Trading_base.Types.trade list
  * Trading_base.Types.trade list
(** [apply_trades_best_effort ?on_trade_fill ?initial_long_margin_req portfolio
     trades] applies each trade to [portfolio] via
    {!Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin},
    returning the resulting [(portfolio, accepted, rejected)] triple (both lists
    in input order). A portfolio-rejected fill is dropped from the portfolio and
    bucketed into [rejected] — and a loud per-trade [WARN] (symbol / side / qty
    / price / reason) is printed to stderr so the rejection is never silent
    (#1553). The optional [on_trade_fill] hook transforms each trade before it
    is applied (e.g. fill-date stamping). The caller routes [rejected] through
    {!transitions_for_rejected_trades} (entry side) and {!revert_rejected_exits}
    (exit side) to keep stranded positions from sticking.

    [initial_long_margin_req] (default [1.0], a cash account) is the long-side
    leverage dial (margin M1b-2): when [< 1.0] a levered long BUY funds its cash
    shortfall into [Portfolio.long_margin_debit] instead of being
    floor-rejected. At the default the apply is bit-equal to
    [Portfolio.apply_single_trade]. *)

val apply_transitions :
  positions:Position.t String.Map.t ->
  transitions:Position.transition list ->
  Position.t String.Map.t Status.status_or
(** [apply_transitions ~positions ~transitions] folds [transitions] over
    [positions] in list order, stopping at the first invalid transition.
    [CreateEntering] installs a fresh [Entering]; [TriggerExit] /
    [TriggerPartialExit] move a position toward [Exiting] and drop it if the
    transition closes it; [CancelEntry] routes through {!apply_to_positions};
    every other kind (fills, [UpdateRiskParams], …) is a no-op here because it
    is applied elsewhere — {!Fill_router} owns fills.

    Lives beside the cancel builders because [CancelEntry] application is its
    only non-trivial case and this module is where {!Simulator} keeps the
    transition-application half of its pipeline. *)

val revert_rejected_exits :
  date:Date.t ->
  positions:Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Position.t String.Map.t
(** [revert_rejected_exits ~date ~positions ~rejected_trades] reverts each
    [Exiting] position whose exit fill was rejected back to [Holding], so the
    stop machinery re-evaluates it next cycle and re-triggers the exit (issue
    #1553). For each rejected trade it finds the first [Exiting] position that
    trade could be the exit fill of — same symbol, [filled_quantity = 0.0], and
    a trade side that {e closes} a position of that side
    ({!Fill_router.exit_trade_side}: a long is closed by a Sell, a short by a
    Buy) — and reverts it to [Holding], carrying the [Exiting] state's fields
    (quantity, entry price/date, risk params), with [last_updated] set to
    [date].

    {b The side check is a guard, not a behaviour change (#2466).} The caller
    hands this function the {e whole} rejected-trade list, entries included, so
    on symbol-and-state matching alone a rejected {e entry} Buy would revert an
    unrelated [Exiting] sibling on that symbol back to [Holding] — cancelling a
    stop-out the portfolio never refused. That pairing (an [Entering] and an
    [Exiting] on one symbol) is unreachable under the shipped Weinstein
    strategy, which counts [Exiting] as held and writes no entry ticket for such
    a symbol, so every current run is bit-identical with and without the check.
    It is enforced here anyway because this module is strategy-agnostic and
    {!Fill_router} already applies exactly this check when routing the accepted
    fills — see its header on sibling positions.

    A {e partially} filled [Exiting] position is deliberately left untouched:
    reverting it would resurrect a [Holding] at the full pre-exit quantity while
    the portfolio already booked the partial cover, desyncing strategy and
    portfolio. Rejected trades with no matching unfilled-[Exiting] position are
    silently skipped (defensive — covers the case where the same symbol's
    [Entering] rejection is handled by [transitions_for_rejected_trades]).

    The revert routes through the core [Position.CancelExit] transition (the
    exit-side mirror of [CancelEntry]) via [apply_to_positions], so exit
    reversion and entry cancellation share the same state-machine path. The
    [CancelExit] validator independently rejects a partially-filled [Exiting], a
    backstop to the [filled_quantity = 0.0] match guard above. *)
