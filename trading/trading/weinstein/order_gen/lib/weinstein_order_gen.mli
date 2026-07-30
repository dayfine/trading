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
    - [TriggerExit] → ignored. The [Stop] order placed via [UpdateRiskParams] is
      already working at the broker as a GTC order; it executes automatically
      when price hits the stop. [TriggerExit] is internal accounting for the
      strategy — no additional broker order is needed.
    - All other transition kinds (EntryFill, CancelEntry, etc.) → ignored
      (simulator-internal; not relevant to the live broker)

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

val from_transitions :
  ?entry_extension_max_pct:float ->
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
