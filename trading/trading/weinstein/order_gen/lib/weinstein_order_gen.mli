(** Weinstein order generator.

    Translates [Position.transition list] from a strategy's [on_market_close]
    call into broker order suggestions for the live runner.

    This module is strategy-agnostic: any strategy that emits
    [Position.transition] values gets formatted order suggestions for free. No
    sizing decisions are made here — those are already encoded in the
    transitions by the strategy.

    {1 Mapping}

    - [CreateEntering { side=Long; entry_price; target_quantity }] → [StopLimit]
      buy [shares] at [entry_price] (breakout entry)
    - [CreateEntering { side=Short; entry_price; target_quantity }] →
      [StopLimit] sell short [shares] at [entry_price]
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
  transitions:Trading_strategy.Position.transition list ->
  get_position:(string -> Trading_strategy.Position.t option) ->
  suggested_order list
(** Translate strategy output into broker order suggestions.

    Iterates over [transitions] and emits one [suggested_order] per
    strategy-triggered transition that maps to a broker action.

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
