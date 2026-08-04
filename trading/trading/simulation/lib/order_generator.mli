(** Order generator - converts strategy transitions to trading orders

    This module bridges the strategy layer (which produces transitions) with the
    order management layer (which executes orders). It examines each transition
    and generates appropriate orders:

    - [CreateEntering] -> Market Buy order for the target quantity
    - [TriggerExit] -> Market Sell order for the position quantity

    Other transitions (fills, completions, risk updates) don't generate orders
    as they represent responses to already-executed trades or state updates.

    Entry fill model (#2158 Phase 2): entries default to Market orders — the
    historical fill model every existing baseline is pinned on. When
    [entry_extension_max_pct] is supplied, [CreateEntering] instead emits
    [StopLimit (entry_price, cap)] with the do-not-chase cap
    [entry_price * (1 + pct/100)] for longs, mirrored to
    [entry_price * (1 - pct/100)] for shorts — the same percentage-point units
    and cap arithmetic as [Entry_reconciliation] classifies against and
    [Weinstein_order_gen._entry_cap] installs live (#2158's "one cap, three
    layers"). The engine's stop-limit execution then fills iff the observed path
    trades through the entry without exceeding the cap; a gap past the cap is a
    no-fill and the candidate is re-evaluated at the next strategy call. Exit
    orders are unaffected (always Market). *)

val transitions_to_orders :
  current_date:Core.Date.t ->
  positions:Trading_strategy.Position.t Core.String.Map.t ->
  ?entry_extension_max_pct:float ->
  Trading_strategy.Position.transition list ->
  (Trading_orders.Types.order list * (string * string) list) Status.status_or
(** Convert strategy transitions to trading orders. Returns the orders plus one
    [(order_id, position_id)] link per order produced — the caller feeds the
    links to {!Fill_router.update_positions_from_trades} so a fill routes to
    exactly the position whose transition created its order (required when
    sibling positions put two same-side orders on one symbol; see
    {!Fill_router}).

    For each transition in the list:
    - [CreateEntering]: Creates a Buy order with target_quantity — Market by
      default, [StopLimit (entry, cap)] when [entry_extension_max_pct] is
      supplied (see the module doc)
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
    @param entry_extension_max_pct
      do-not-chase cap in percentage points of the entry price (same units as
      the [Weinstein_strategy.config.entry_extension_max_pct] field). Absent
      (the default) = Market entries, bit-identical to every pre-#2158 baseline.
      Callers arm it only when the strategy config's
      [enable_sim_entry_stoplimit] flag is on AND [entry_extension_max_pct > 0].
    @return Ok list of orders, or Error if order creation fails. *)
