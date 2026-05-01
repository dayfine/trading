(** Order generator - converts strategy transitions to trading orders

    This module bridges the strategy layer (which produces transitions) with the
    order management layer (which executes orders). It examines each transition
    and generates appropriate orders:

    - [CreateEntering] -> Market Buy order for the target quantity
    - [TriggerExit] -> Market Sell order for the position quantity

    Other transitions (fills, completions, risk updates) don't generate orders
    as they represent responses to already-executed trades or state updates.

    TODO(simulation/stoplimit-orders): Orders should be StopLimit orders instead
    of Market orders. This will require passing entry_price/exit_price from
    transitions and determining appropriate limit prices. *)

val transitions_to_orders :
  current_date:Core.Date.t ->
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  Trading_strategy.Position.transition list ->
  Trading_orders.Types.order list Status.status_or
(** Convert strategy transitions to trading orders.

    For each transition in the list:
    - [CreateEntering]: Creates a Market Buy order with target_quantity
    - [TriggerExit]: Creates a Market Sell order with position quantity (looks
      up position in the provided map)

    Other transition types are ignored (they don't generate orders).

    Order IDs are minted deterministically from [current_date] and the
    transition's index in the list (e.g. ["2024-03-15-007"]). This is the G6
    fix: order IDs were previously derived from [Time_ns_unix.now ()] and
    [Random.int], producing different IDs across forks. Because the IDs are
    hashtable keys in [Trading_orders.Manager.orders], unstable IDs led to
    unstable [list_orders] iteration order -> unstable fill order -> metric
    drift on long-horizon backtests. See
    dev/notes/g6-decade-nondeterminism-investigation-2026-04-30.md.

    @param current_date
      date of the simulation step generating these orders; used to seed
      deterministic IDs.
    @param positions Current positions map for looking up quantities.
    @return Ok list of orders, or Error if order creation fails. *)
