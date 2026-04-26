(** Load universe / AD bars / sector map, build a fresh Weinstein strategy, run
    the simulator, and return a [result] holding the summary plus the
    post-filter steps and trades. Pure orchestration — no output is written. *)

open Core

type result = {
  summary : Summary.t;
  round_trips : Trading_simulation.Metrics.trade_metrics list;
      (** Completed round-trips derived from *every* step in
          [start_date..end_date] — the [is_trading_day] mark-to-market filter is
          NOT applied here, since trade fills are recorded independently of
          mark-to-market portfolio valuation. *)
  steps : Trading_simulation_types.Simulator_types.step_result list;
      (** Steps filtered to [start_date..end_date] on real trading days only.
          Used for the equity curve and any downstream consumer that needs a
          meaningful mark-to-market portfolio value per row. *)
  overrides : Sexp.t list;
      (** The override sexps used for this run, echoed into params.sexp *)
  stop_infos : Stop_log.stop_info list;
      (** Per-position stop info captured from strategy transitions. Each entry
          records the initial stop level, the stop level at exit, and the exit
          trigger (stop-loss, take-profit, etc.). Keyed by position_id; joinable
          with [round_trips] via symbol + entry_date. *)
}

val is_trading_day :
  Trading_simulation_types.Simulator_types.step_result -> bool
(** True if [step] represents a real trading day — i.e. the portfolio's
    mark-to-market value materially differs from its cash balance when any
    positions are open, or if no positions are open. On non-trading days
    (weekends, holidays) the simulator has no price bars and reports
    [portfolio_value = cash] even when positions exist.

    This filter is appropriate for mark-to-market aware consumers (the equity
    curve, [UnrealizedPnl]) but MUST NOT be applied before round-trip extraction
    — doing so silently drops trades whose entry/exit steps had no
    mark-to-market view. See PR #393 (filter introduction) and the trades.csv
    fix note in [runner.ml]. *)

val run_backtest :
  start_date:Date.t ->
  end_date:Date.t ->
  ?overrides:Sexp.t list ->
  ?sector_map_override:(string, string) Core.Hashtbl.t ->
  ?trace:Trace.t ->
  unit ->
  result
(** Run the simulator from [start_date - warmup] to [end_date], filter to the
    requested range and to trading days only, and return the [result].

    [overrides] are partial config sexps deep-merged into the default config in
    order. Each must be a record sexp with fields matching
    [Weinstein_strategy.config]. Example:
    {[
    [
      Sexp.of_string "((initial_stop_buffer 1.08))";
      Sexp.of_string "((stage_config ((ma_period 40))))";
    ]
    ]}

    [sector_map_override], when passed, replaces the sector-map normally loaded
    from [data/sectors.csv]. The backtest universe becomes exactly the keys of
    this hashtable. This is the wiring point for scenario-level universe
    selection (small / broad tiers). When [None] (the default), the runner falls
    back to [Sector_map.load] — pre-migration behaviour.

    [trace], when passed, instruments the run with per-phase timing and memory
    measurements via {!Trace.record}. Wraps these coarse phases at the runner
    level:
    - [Load_universe] — resolving the sector map
    - [Macro] — loading AD breadth bars
    - [Fill] — running the simulator main loop (all per-bar strategy work)
    - [Teardown] — extracting round-trips and gathering stop infos

    The actual simulator construction + run-loop is delegated to
    {!Panel_runner.run}, which builds [Ohlcv_panels] + [Indicator_panels] over
    the universe and threads a panel-backed [get_indicator_fn] into the
    strategy. Parity is pinned by [test_panel_loader_parity].

    Finer-grained wrap points for the per-bar phases inside [Simulator.run]
    (Sector_rank / Rs_rank / Stage_classify / Screener / Stop_update /
    Order_gen) require strategy-level instrumentation and are tracked as a
    follow-up. When [trace] is omitted, instrumentation is a no-op. *)
