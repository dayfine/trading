(** Weinstein order generator.

    Translates [Position.transition list] from a strategy's [on_market_close]
    call into broker order suggestions for the live runner.

    This module is strategy-agnostic: any strategy that emits
    [Position.transition] values gets formatted order suggestions for free. No
    sizing decisions are made here — those are already encoded in the
    transitions by the strategy.

    {1 Mapping}

    - [CreateEntering { side=Long; entry_price; target_quantity }] → [StopLimit]
      buy [shares] triggering at [entry_price], with the limit capped one
      [entry_extension_max_pct] above it (the do-not-chase ceiling — issue
      #2158). The old degenerate [StopLimit (E, E)] never filled once price ran
      through the breakout; [StopLimit (E, E x (1 + pct/100))] fills anywhere
      between the trigger and the cap, and refuses to chase past it.
    - [CreateEntering { side=Short; entry_price; target_quantity }] →
      [StopLimit] sell short [shares] triggering at [entry_price], limit capped
      one [entry_extension_max_pct] {e below} it (the short mirror).
    - [UpdateRiskParams { new_risk_params = { stop_loss_price = Some p } }] →
      [Stop] order at [p] for the existing position quantity
    - [TriggerExit] → ignored. The broker [Stop] order (from [UpdateRiskParams]
      or the stop sync below) is already working at the broker as a GTC order;
      it executes automatically when price hits the stop. [TriggerExit] is
      internal accounting for the strategy — no additional broker order is
      needed.
    - All other transition kinds (EntryFill, CancelEntry, etc.) → no order of
      their own (simulator-internal). [EntryFill] / [EntryComplete] do drive the
      stop sync below.

    {1 Where broker stops come from}

    [UpdateRiskParams] alone does {b not} keep the broker protected (issue
    #2984): a freshly filled position carries no stop transition until its
    trailing stop first rises, and stop-state moves that emit no transition (a
    tightening, a split rescale) never reach the broker at all. The enforced
    stop lives in the strategy's stop state, not in [risk_params].

    Passing [~stop_sync] closes that gap. It carries the installed stop level
    per ticker {e before} and {e after} the tick (for the Weinstein strategy:
    [Map.find stop_states ticker |> Option.map
     ~f:Weinstein_stops.get_stop_level] on the two snapshots) plus the positions
    to protect, and emits one [Stop] order at the {e after} level for each
    protectable position (see {!stop_sync}) that
    - (a) received an [EntryFill] or [EntryComplete] this tick — the initial
      stop at its installed level, sized to the shares now filled; or
    - (b) has an [UpdateRiskParams] with a stop price this tick; or
    - (c) has an {e after} level different from its {e before} level (a raise, a
      tightening, a split rescale — including a {e lower} level after a split;
      this module forwards the level and does not enforce direction, the
      never-lower invariant lives upstream in the stop state machine).

    {b The installed level wins.} For a position the sync covers (protectable
    and with an {e after} level), the [Stop] that its [UpdateRiskParams] would
    have produced is dropped and only the sync order, at the {e after} level, is
    emitted — one protective stop per position per tick, whatever price the
    transition carried. [UpdateRiskParams] for positions the sync does not cover
    keep the transition mapping above. A ticker with no {e after} level yields
    no sync order. Without [~stop_sync] the output is exactly the transition
    mapping above (pre-#2984 behaviour).

    A [Stop] order means {e set / replace this position's protective stop} at
    the broker (modify the working GTC stop, or place it if none exists) — never
    an additional stop alongside the working one.

    The module stays strategy-agnostic: the levels arrive as plain lookups, so
    it takes no dependency on the Weinstein stop library.

    {1 Location}

    Lives in [trading/weinstein/order_gen/] because it depends on
    [Trading_strategy.Position] and must stay in the [trading/] layer. *)

type suggested_order = {
  ticker : string;  (** Trading symbol *)
  side : Trading_base.Types.side;
      (** [Buy] for long entries and exits; [Sell] for short entries *)
  order_type : Trading_base.Types.order_type;
      (** [Market], [Stop], or [StopLimit] *)
  shares : int;  (** Share count (rounded from float target_quantity) *)
  rationale : string;
      (** Human-readable description of why this order was generated *)
}
[@@deriving show, eq]
(** A single suggested broker order for human review before placement. *)

type stop_sync = {
  positions : Trading_strategy.Position.t list;
      (** Candidate positions to protect. Only a [Holding] position, or an
          [Entering] position with a non-zero [filled_quantity], gets a sync
          order; its share count is the held (resp. filled) quantity. [Exiting]
          and [Closed] positions never get one (a protective stop on a position
          already being sold would risk a double exit at the broker). The
          protective stop is a [Sell] stop for a long and a [Buy] stop (above
          price) for a short.

          Must be the {b post-transition} state — the positions as they stand
          after this tick's transitions (fills) were applied — so a just-filled
          entry is [Holding] (or partially-filled [Entering]) here. *)
  stop_level_before : string -> float option;
      (** Installed stop level by ticker at the start of the tick. *)
  stop_level_after : string -> float option;
      (** Installed stop level by ticker after the tick — the level the next bar
          enforces. *)
}
(** Stop-level snapshots that drive the broker stop sync (issue #2984). See the
    module doc, "Where broker stops come from". *)

val from_transitions :
  ?entry_extension_max_pct:float ->
  ?stop_sync:stop_sync ->
  transitions:Trading_strategy.Position.transition list ->
  get_position:(string -> Trading_strategy.Position.t option) ->
  unit ->
  suggested_order list
(** Translate strategy output into broker order suggestions.

    Iterates over [transitions] and emits one [suggested_order] per
    strategy-triggered transition that maps to a broker action.

    @param entry_extension_max_pct
      Percentage-point cap on how far past the breakout an entry order may fill
      — the limit leg of the [StopLimit] for a [CreateEntering] transition sits
      one such fraction past the trigger ([E x (1 + pct/100)] long, mirrored
      short). Defaults to [0.0], which collapses the limit onto the trigger
      ([StopLimit (E, E)]) — the exact order the generator emitted before issue
      #2158, so an unarmed live run is byte-identical
      (experiment-flag-discipline R1). Pass the strategy's
      [entry_extension_max_pct] to arm the cap; it is the {e same} knob
      {!Entry_reconciliation} classifies the weekly report's tickets against, so
      live orders and the report share one ceiling.

    @param stop_sync
      Opt-in broker stop sync (issue #2984). Omitted, only the transition
      mapping runs. Given, the sync orders are appended after the
      transition-derived orders, in [positions] order, and the sync replaces the
      [UpdateRiskParams] stop of every position it covers (installed level
      wins).

    @param transitions
      The [Position.transition list] returned by [Strategy.on_market_close].
      Contains both strategy-triggered and simulator-triggered transitions; only
      the former are relevant.

    @param get_position
      Look up a [Position.t] by its [position_id]. Required to determine share
      count for stop-update and exit orders (the transition itself does not
      repeat the quantity). Returns [None] if the position is unknown
      (transition is skipped with a warning tag in rationale).

    @return
      Suggested orders in the same order as the input transitions. Transitions
      that do not map to a broker action produce no output. *)
