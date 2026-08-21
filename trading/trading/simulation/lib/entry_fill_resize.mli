(** G2b — fill a portfolio-refused entry at a size the book {e can} afford,
    instead of destroying the ticket ([dev/plans/ticket-funding-2026-08-16.md]
    §G2b).

    {b The failure.} {!Trading_engine.Engine} marks a resting entry order
    [Filled] the moment the fill function returns a trade, {i before}
    {!Cancel_handler.apply_trades_best_effort} asks the portfolio to book it.
    When the portfolio refuses — almost always insufficient cash —
    {!Cancel_handler.transitions_for_rejected_trades} emits a [CancelEntry] and
    the [Entering] position is deleted. Order and ticket are both gone, so
    {b one cash-tight instant permanently destroys a ticket} that may have
    rested for months. Measured over 3,530 rejections the median shortfall is
    {b 52%} of the ticket's cost — but 5.1% are within 5% of fundable, and one
    diagnostic ticket ([PRGS]) missed by {b 0.3%}.

    {b What this module does.} It {e claims} such a refusal: the quantity is
    clamped to what the book can fund, the clamped trade is booked at the
    {b price the ticket triggered at}, and the trade is handed back as an
    accepted fill. It therefore pays none of the timing tax that G2a's retry
    ({!Entry_fill_retry}) does — the entry happens now, at the triggered price,
    just smaller.

    {b Why a minimum size.} A resize silently breaks fixed-risk sizing: the
    position no longer carries [risk_per_trade_pct] of the book, and a
    systematically undersized entry into the largest winners is its own tail tax
    ([project_edge_is_the_fat_tail]). [min_size_fraction] is the guard, and it
    is the knob the plan calls "the thing to sweep": a clamp below that fraction
    of the designed quantity is refused outright and the ticket takes the
    unchanged destroy path.

    {b Default-off (R1).} At [enabled = false] {!claim} returns its three inputs
    unchanged — no portfolio call, no allocation the pre-G2b path did not make —
    so the simulator is bit-identical to every existing baseline. No ledger
    verdict exists for this mechanism; it ships off. *)

open Core
module Position = Trading_strategy.Position

type t
(** The run's resize policy: whether resizing is armed, and the minimum fraction
    of the designed quantity a clamp must reach. Immutable and stateless —
    unlike {!Entry_fill_retry.t} there is no per-ticket budget to track, because
    a resize either happens once or does not happen at all. *)

val create : enabled:bool -> min_size_fraction:float -> t
(** [create ~enabled ~min_size_fraction] is the policy the simulator threads
    from [Weinstein_strategy_config.entry_fill_size_to_available] and
    [Weinstein_strategy_config.entry_fill_min_size_fraction]. At
    [enabled = false] (the default) [min_size_fraction] is inert. *)

val disabled : t
(** The no-op policy — [create ~enabled:false]. The default of
    {!Simulator.create_deps}'s [?entry_fill_resize], so a caller that has never
    heard of G2b gets exactly the pre-G2b simulator. *)

val affordable_quantity :
  portfolio:Trading_portfolio.Portfolio.t ->
  trade:Trading_base.Types.trade ->
  float
(** [affordable_quantity ~portfolio ~trade] is the largest whole-share quantity
    of [trade] that {!Trading_portfolio.Portfolio.apply_single_trade}'s cash
    floor would accept against [portfolio], at [trade]'s own price and
    commission.

    The floor is [current_cash + cash_change + negative_unrealized_pnl >= 0]
    with [cash_change = -.(quantity *. price +. commission)] for a Buy, so the
    solve is
    [floor ((current_cash + negative_unrealized_pnl - commission) / price)],
    where [negative_unrealized_pnl] is the (non-positive) paper-loss drag
    [Portfolio] carries in [unrealized_pnl_per_position]. Whole shares, because
    that is what [Weinstein_portfolio_risk.compute_position_size] produces.

    {b The resized trade keeps the original's commission.} Commission is
    [max (quantity * per_share) minimum] and therefore never {e rises} as
    quantity falls, so charging the original figure is conservative — and it
    makes the solve above exact rather than an implicit equation.

    [0.0] — meaning "no affordable size" — for a Sell, a non-positive price, or
    a non-positive budget. A Sell is excluded on purpose: a short entry's cash
    change is an {e inflow}, so the floor gets {e harder} to satisfy as the
    quantity shrinks, and no clamp can rescue a refused short entry.

    Exposed because it is the load-bearing arithmetic of the mechanism and
    deserves to be pinned directly, not only through {!claim}. *)

val claim :
  t ->
  initial_long_margin_req:float ->
  portfolio:Trading_portfolio.Portfolio.t ->
  positions:Position.t String.Map.t ->
  accepted:Trading_base.Types.trade list ->
  rejected_trades:Trading_base.Types.trade list ->
  Trading_portfolio.Portfolio.t
  * Trading_base.Types.trade list
  * Trading_base.Types.trade list
(** [claim t ~initial_long_margin_req ~portfolio ~positions ~accepted
     ~rejected_trades] walks [rejected_trades] in order and returns
    [(portfolio, accepted, still_rejected)]:

    - [portfolio] carries every clamped fill this call booked;
    - [accepted] is the input [accepted] followed by the clamped fills, in input
      order — the caller passes it to
      {!Fill_router.update_positions_from_trades}, so a clamped fill routes onto
      its [Entering] position and records in [trades.csv] / [trade_audit.sexp]
      exactly as any other fill does;
    - [still_rejected] is the sub-list that was {e not} claimed and must follow
      the unchanged death path ({!Entry_fill_retry.handle_rejected_entries},
      then {!Cancel_handler.transitions_for_rejected_trades}).

    A trade is claimed only when all of the following hold; any failure falls
    through to [still_rejected], so the worst case is exactly today's behaviour:

    + [t] is enabled.
    + Some position in [positions] is [Entering]
      {b on the trade's symbol and expecting the trade's side} (Buy opens a
      long, Sell opens a short) — the same (symbol, state, side) key
      {!Fill_router} routes fills on. Its [target_quantity] is the {e designed}
      quantity.
    + {!affordable_quantity} is positive.
    + The clamped quantity — [min designed affordable] — is at least
      [min_size_fraction] of [designed].
    + {!Trading_portfolio.Portfolio_margin.apply_single_trade_with_long_margin}
      accepts the clamped trade. If a floating-point edge makes the clamp a hair
      too large, the apply refuses and the ticket falls through; a rounding edge
      can never strand a ticket.

    {b The side check is the guard against #2466.}
    {!Cancel_handler.revert_rejected_exits} matches rejected trades on
    {e symbol alone}, so if an entry rejection for symbol [S] reached that scan
    while [S] also had an [Exiting] sibling, the sibling would be wrongly
    reverted to [Holding]. Claiming an entry rejection here removes it from the
    list the caller hands to that scan, and the side check guarantees the
    converse — a rejected {e exit} is never claimed here and always reaches it.

    {b The caps still bind.} The clamp is bounded above by [designed], which is
    [Weinstein_portfolio_risk.compute_position_size]'s output and therefore
    already the minimum of the risk-based size, the side-exposure cap, the
    per-position [max_position_pct] cap and the sizing-cash cap. A resize can
    only ever move {e down} from a capped number, so every cap the original
    sizing respected still holds — and the aggregate exposure after a clamped
    fill is strictly below the exposure the unclamped fill would have produced,
    which today's code already permits.

    {b Precedence over G2a.} The simulator calls this {e before}
    {!Entry_fill_retry.handle_rejected_entries}, so when both mechanisms are
    armed a refusal is offered a resize first and only consumes retry budget if
    the resize is refused. Resizing is the cheaper answer — it enters now, at
    the triggered price — so spending a retry ahead of it would pay the timing
    tax for nothing.

    {b The clamped trade is not re-hooked.} [rejected_trades] have already
    passed [Simulator]'s [on_trade_fill] hook (that is what
    {!Cancel_handler.apply_trades_best_effort} returns), so the clamped copy
    inherits its fill-date stamp rather than being stamped twice.

    [initial_long_margin_req] is the long-side leverage dial, forwarded verbatim
    so a clamped fill books under the same margin rules as the original would
    have. Note {!affordable_quantity} solves the {e cash-account} floor, so
    under leverage the clamp is conservative (it may undersize, never oversize).
*)

val entry_trade_side :
  Trading_base.Types.position_side -> Trading_base.Types.side
(** The trade side that fills a position's {e entry} order: [Buy] for a long,
    [Sell] (sell-to-open) for a short. Exposed so a test can state the
    wrong-side case in the same vocabulary the implementation matches on. *)
