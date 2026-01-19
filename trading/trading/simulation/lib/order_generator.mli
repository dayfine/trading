(** Order generator - converts strategy transitions to trading orders

    This module bridges the strategy layer (which produces transitions) with the
    order management layer (which executes orders). It examines each transition
    and generates appropriate orders:

    - [CreateEntering] -> Market Buy order for the target quantity
    - [TriggerExit] -> Market Sell order for the position quantity

    Other transitions (fills, completions, risk updates) don't generate orders
    as they represent responses to already-executed trades or state updates.

    TODO: Orders should be StopLimit orders instead of Market orders. This will
    require passing entry_price/exit_price from transitions and determining
    appropriate limit prices. *)

val transitions_to_orders :
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  Trading_strategy.Position.transition list ->
  Trading_orders.Types.order list Status.status_or
(** Convert strategy transitions to trading orders.

    For each transition in the list:
    - [CreateEntering]: Creates a Market Buy order with target_quantity
    - [TriggerExit]: Creates a Market Sell order with position quantity (looks
      up position in the provided map)

    Other transition types are ignored (they don't generate orders).

    @param positions Current positions map for looking up quantities
    @return Ok list of orders, or Error if order creation fails *)
