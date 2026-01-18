(** Order generator - converts strategy transitions to trading orders

    This module bridges the strategy layer (which produces transitions) with the
    order management layer (which executes orders). It examines each transition
    and generates appropriate orders:

    - [CreateEntering] -> Market Buy order for the target quantity
    - [TriggerExit] -> Market Sell order for the position quantity

    Other transitions (fills, completions, risk updates) don't generate orders
    as they represent responses to already-executed trades or state updates. *)

val transitions_to_orders :
  Trading_strategy.Position.transition list ->
  Trading_orders.Types.order list Status.status_or
(** Convert strategy transitions to trading orders.

    For each transition in the list:
    - [CreateEntering]: Creates a Market Buy order with target_quantity
    - [TriggerExit]: Creates a Market Sell order with position quantity

    Other transition types are ignored (they don't generate orders).

    @return Ok list of orders, or Error if order creation fails *)

val transition_to_order :
  Trading_strategy.Position.transition ->
  Trading_orders.Types.order option Status.status_or
(** Convert a single transition to an order (if applicable).

    @return
      Ok (Some order) if transition generates an order, Ok None if transition
      doesn't generate an order, Error if order creation fails *)
