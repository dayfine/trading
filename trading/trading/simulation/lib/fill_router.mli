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

type links
(** The [(order_id, position_id)] links {!Order_generator} records when it turns
    a transition into an order, held in the two lifetimes a run needs.

    {b In-flight} — the current generation pass's links, which
    {!update_positions_from_trades} routes on. Entry orders are day orders, so
    {!record} replaces this set wholesale on each pass.

    {b Archive} — every link the run has ever produced, never replaced. It is
    what lets a post-run consumer take a fill's [order_id] off a recorded trade
    and recover the strategy position that ordered it, long after the in-flight
    set was recycled — the join
    {!Trading_simulation.Round_trip_pairing.extract_round_trips} needs to stamp
    [position_id] on each round-trip. The simulator snapshots it onto
    [Simulator_types.run_result.order_position_links].

    Mutable and reference-shared: a simulator's per-step state copies alias one
    value. *)

val entry_trade_side :
  Trading_base.Types.position_side -> Trading_base.Types.side
(** The broker side of the trade that {b opens} a position of this side: a long
    is entered by buying, a short by selling to open.

    Exported so the rest of the rejection path can apply the same side check
    this module's routing already does, instead of matching on symbol and state
    alone. {!Cancel_handler} is the consumer. *)

val exit_trade_side :
  Trading_base.Types.position_side -> Trading_base.Types.side
(** The broker side of the trade that {b closes} a position of this side: a long
    is exited by selling, a short by buying to cover. The mirror of
    {!entry_trade_side}; see its note for why both are exported. *)

val create_links : unit -> links
(** Empty links — no orders generated yet. *)

val record : links -> (string * string) list -> unit
(** Install one generation pass's [(order_id, position_id)] pairs, in place:
    replaces the in-flight set, appends to the archive. *)

val archived : links -> string Core.String.Map.t
(** Immutable snapshot of the archive — [order_id -> position_id] for every
    order generated so far, in any pass. *)

val update_positions_from_trades :
  ?order_links:links ->
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

    + {b Exact} — when [order_links]'s in-flight set maps the trade's [order_id]
      to a position id (recorded at order-generation time, {!Order_generator})
      and that position is currently fillable ([Entering] ← entry fill,
      [Exiting] ← exit fill), the fill goes to exactly that position. This is
      required whenever two same-symbol positions are in the {e same} state+side
      — e.g. both scale-in siblings exiting on their shared stop in one tick:
      the symbol+state+side heuristic would route the first (id-ordered) match
      and overflow its target.
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
