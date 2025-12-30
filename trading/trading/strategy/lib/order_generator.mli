(** Generate trading orders from position transitions

    This module converts position state transitions (e.g., EntryFill, ExitFill)
    into executable trading orders (buy/sell). It separates strategy decision-making
    from order execution details.

    {1 Design}

    Strategies produce transitions that describe WHAT changed:
    - [EntryFill]: 100 shares filled at $150
    - [ExitFill]: 100 shares filled at $145

    This module converts those into HOW to execute in the market:
    - Buy 100 shares at limit $150
    - Sell 100 shares at limit $145

    {1 Usage}

    {[
      (* After strategy execution *)
      let transitions = strategy_output.transitions in
      let positions = strategy_state.positions in

      (* Generate orders from transitions *)
      let orders = Order_generator.from_transitions ~positions ~transitions in
    ]} *)

val from_transitions :
  positions:Position.t Core.String.Map.t ->
  transitions:Position.transition list ->
  Trading_orders.Types.order list Status.status_or
(** Generate orders from position transitions

    Only [EntryFill] and [ExitFill] transitions generate orders:
    - [EntryFill] → Buy order (limit at fill price)
    - [ExitFill] → Sell order (limit at fill price)
    - All other transitions → No orders

    @param positions Position map to look up symbols from position IDs
    @param transitions List of transitions to convert
    @return List of orders to execute, or error if position not found *)
