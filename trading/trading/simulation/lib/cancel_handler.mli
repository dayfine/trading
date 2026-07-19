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

val revert_rejected_exits :
  date:Date.t ->
  positions:Position.t String.Map.t ->
  rejected_trades:Trading_base.Types.trade list ->
  Position.t String.Map.t
(** [revert_rejected_exits ~date ~positions ~rejected_trades] reverts each
    [Exiting] position whose exit fill was rejected back to [Holding], so the
    stop machinery re-evaluates it next cycle and re-triggers the exit (issue
    #1553). For each rejected trade it finds the first [Exiting] position
    matching the trade's symbol {e with [filled_quantity = 0.0]} and reverts it
    to [Holding] — carrying the [Exiting] state's fields (quantity, entry
    price/date, risk params), with [last_updated] set to [date].

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
