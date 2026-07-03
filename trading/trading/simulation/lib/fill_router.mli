(** Side-aware routing of fill trades onto position lifecycles.

    Extracted from [Simulator] so the routing contract is independently
    testable. Each fill trade routes to a position whose state {e and} side
    expect that trade side:

    - Long [Entering] ← Buy, Long [Exiting] ← Sell
    - Short [Entering] ← Sell (sell-to-open), Short [Exiting] ← Buy
      (buy-to-cover)

    The side check keeps routing correct when an entry and an exit order coexist
    on one symbol — two sibling positions, e.g. a scale-in add entering while
    the original position exits. State-only routing (the historical behaviour,
    safe under the one-position-per-symbol invariant) would route a Sell fill to
    the Entering position and book it as an entry fill. A trade whose side
    matches no open order on its symbol is ignored. *)

val update_positions_from_trades :
  ?order_links:string Core.String.Table.t ->
  date:Core.Date.t ->
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  trades:Trading_base.Types.trade list ->
  unit ->
  Trading_strategy.Position.t Core.String.Map.t Status.status_or
(** [update_positions_from_trades ?order_links ~date ~positions ~trades ()]
    folds [trades] over [positions]: each trade routes to its target position,
    the fill + completion transitions are applied, and the updated position is
    installed — or removed when the fill closes it (Closed positions are
    strategy-invisible; audit trails live elsewhere). Entry fills complete with
    empty risk params (the strategy installs stops via [UpdateRiskParams]).
    Returns an error if a routed transition is invalid for the target's state.

    Routing precedence:

    + {b Exact} — when [order_links] maps the trade's [order_id] to a position
      id (recorded at order-generation time, {!Order_generator}) and that
      position is currently fillable ([Entering] ← entry fill, [Exiting] ← exit
      fill), the fill goes to exactly that position. This is required whenever
      two same-symbol positions are in the {e same} state+side — e.g. both
      scale-in siblings exiting on their shared stop in one tick: the
      symbol+state+side heuristic would route the first (id-ordered) match and
      overflow its target.
    + {b Heuristic fallback} — (symbol, state, side) first-match, as before.
      Covers trades with no recorded link. A trade whose side matches no open
      order on its symbol is ignored. *)

val set_or_drop_if_closed :
  Trading_strategy.Position.t Core.String.Map.t ->
  key:string ->
  data:Trading_strategy.Position.t ->
  Trading_strategy.Position.t Core.String.Map.t
(** Install [data] under [key], or remove [key] when [data] is Closed. Shared
    with [Simulator]'s strategy-transition application path so both sites treat
    Closed positions identically. *)
