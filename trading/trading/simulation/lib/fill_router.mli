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
  date:Core.Date.t ->
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  trades:Trading_base.Types.trade list ->
  Trading_strategy.Position.t Core.String.Map.t Status.status_or
(** [update_positions_from_trades ~date ~positions ~trades] folds [trades] over
    [positions]: each trade routes to its (symbol, state, side) target, the fill
    \+ completion transitions are applied, and the updated position is installed
    — or removed when the fill closes it (Closed positions are
    strategy-invisible; audit trails live elsewhere). Entry fills complete with
    empty risk params (the strategy installs stops via [UpdateRiskParams]).
    Returns an error if a routed transition is invalid for the target's state.
*)

val set_or_drop_if_closed :
  Trading_strategy.Position.t Core.String.Map.t ->
  key:string ->
  data:Trading_strategy.Position.t ->
  Trading_strategy.Position.t Core.String.Map.t
(** Install [data] under [key], or remove [key] when [data] is Closed. Shared
    with [Simulator]'s strategy-transition application path so both sites treat
    Closed positions identically. *)
