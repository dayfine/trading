(** Load universe / AD bars / sector map, build a fresh Weinstein strategy, run
    the simulator, and return a [result] holding the summary plus the
    post-filter steps and trades. Pure orchestration — no output is written. *)

open Core

val warmup_days_for : Strategy_choice.t -> int
(** Number of calendar days the runner prepends before a scenario's [start_date]
    when it runs [strategy] — i.e.
    [warmup_start = start_date - warmup_days_for strategy]. The Weinstein /
    SPY-only stage classifier needs ~30 weeks (210 days) of bar history;
    sector-rotation needs ~52 weeks (364 days) for its RS window; the stateless
    Buy-and-Hold benchmark needs none (0). Exposed (#882-dispatched) so
    snapshot-warehouse tooling derives the same warmup window the runner uses,
    rather than copying the magic numbers. *)

val primary_index_symbol : string
(** The primary index ([GSPC.INDX]) every run loads bars for and feeds into the
    macro / relative-strength pipeline. Exposed so warehouse-building tooling
    stages the same benchmark symbol the runner reads, instead of hardcoding it.
*)

val all_snapshot_symbols : universe:string list -> string list
(** [all_snapshot_symbols ~universe] is the deduped, sorted union of every
    symbol a default [Weinstein] run stages bars for over [universe]: the
    universe itself, {!primary_index_symbol}, every SPDR sector ETF
    ({!Weinstein_strategy.Macro_inputs.spdr_sector_etfs}), and every global
    macro index ({!Weinstein_strategy.Macro_inputs.default_global_indices}).
    Reuses the exact assembly the runner builds its internal [all_symbols] from
    (with the hypothesis-testing skip toggles at their defaults), so a snapshot
    warehouse built over this set carries every macro / RS column the runner
    reads. Omitting these auxiliary symbols leaves those columns degenerate and
    the strategy produces zero trades. *)

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
          meaningful mark-to-market portfolio value per row. Each step carries a
          {!Trading_simulation_types.Portfolio_summary.t} projection rather than
          the full portfolio — see [final_portfolio] for the full end-of-run
          state. *)
  final_portfolio : Trading_portfolio.Portfolio.t;
      (** The full {!Trading_portfolio.Portfolio.t} as of the simulator's last
          step (i.e. the end of [warmup_start..end_date]). Carries lots,
          accounting method, and full trade history — the canonical source of
          truth for end-of-run reconciler artefacts ([open_positions.csv],
          [final_prices.csv]). Per-step [step_result.portfolio] is a skinny
          {!Portfolio_summary.t} projection that omits these details to keep
          [step_history] memory bounded; reconciler consumers must read this
          field instead. *)
  n_stop_eligible_positions : int;
      (** Count of strategy positions still under active stop evaluation (in the
          [Holding] state) at the end of the run, threaded straight through from
          {!Trading_simulation_types.Simulator_types.run_result}. Paired with
          the open-position count of [final_portfolio] by {!divergence_findings}
          to surface the portfolio↔strategy divergence the stuck-[Exiting]
          zombie produces (#1553). In a healthy run this equals the
          open-position count and the divergence check is silent. *)
  overrides : Sexp.t list;
      (** The override sexps used for this run, echoed into params.sexp *)
  stop_infos : Stop_log.stop_info list;
      (** Per-position stop info captured from strategy transitions. Each entry
          records the initial stop level, the stop level at exit, and the exit
          trigger (stop-loss, take-profit, etc.). Keyed by position_id; joinable
          with [round_trips] via symbol + entry_date. *)
  audit : Trade_audit.audit_record list;
      (** Per-trade decision-trail records captured by the strategy. Empty until
          PR-2 of the trade-audit plan wires capture sites in [_run_screen] /
          [entries_from_candidates] / the exit path. When non-empty,
          [Result_writer.write] persists it as [trade_audit.sexp]. *)
  cascade_summaries : Trade_audit.cascade_summary list;
      (** Per-Friday cascade-rejection counts captured by the strategy at the
          end of every screen call. Complements [audit] — where [audit] only
          covers candidates that were ENTERED (plus immediate rivals), this
          field records the per-cascade-phase activity for every Friday,
          including those where the cascade filtered everything. Persisted
          alongside [audit] in [trade_audit.sexp] when either is non-empty. *)
  force_liquidations : Portfolio_risk.Force_liquidation.event list;
      (** Per-position force-liquidation events recorded by the strategy (G4 —
          see [dev/notes/short-side-gaps-2026-04-29.md]). Empty when no forced
          close fired during the run. When non-empty, [Result_writer.write]
          persists it as [force_liquidations.sexp]. Each event is evidence the
          primary stop machinery failed to protect a trade — non-zero counts on
          a release run flag a regression. *)
  stale_holds : Trading_simulation.Stale_hold.event list;
      (** Per-step records of held positions whose underlying bars stopped
          arriving (typical signature of a corporate action — cash merger, stock
          merger, bankruptcy delisting, suspension — the strategy did not
          anticipate). One event per (held position, step) pair while the
          position remains stale. Filtered to events whose [date >= start_date].
          Persisted to [stale_holds.sexp] by [Result_writer.write] when
          non-empty. The detector is a recorder, not a force-closer; the
          position continues to be valued via forward-fill of the last-known
          close in {!Trading_simulation.Simulator}'s portfolio-value
          computation. *)
  final_prices : (string * float) list;
      (** Snapshot of close prices on the run's final calendar day, keyed by
          symbol. Populated by [Panel_runner.run] from the snapshot's [Close]
          field at [end_date] for every symbol still held in
          [final_portfolio.positions]; empty when the simulation never reached
          the final calendar day or no positions were held at end. Consumed by
          [Result_writer] to emit [final_prices.csv] for the external
          [trading-reconciler] tool — see
          [~/Projects/trading-reconciler/PHASE_1_SPEC.md] §3.3. *)
  universe : string list;
      (** Post-cap, sorted list of symbols the simulator actually traded over
          (excludes the primary index and sector ETFs). Persisted to
          [universe.txt] by [Result_writer.write] so downstream counterfactual
          tooling — [optimal_strategy] in particular — can scope its analysis to
          the same universe rather than reloading [data/sectors.csv] (the full
          ~10k-symbol set, which over-states what the strategy could have
          picked). *)
}

val open_position_count : Trading_portfolio.Portfolio.t -> int
(** Count of open positions in [portfolio] — the length of
    [portfolio.positions]. Fully-closed positions are already dropped from that
    list by {!Trading_portfolio.Portfolio.apply_trades}, so every element is a
    genuinely-open position (matching the per-row semantics
    {!Reconciler_writer.write_open_positions} uses for [open_positions.csv]).
    Exposed for the divergence check ({!divergence_findings}) and its tests. *)

val divergence_findings :
  config:Fold_health.config -> result -> Fold_health.finding list
(** [divergence_findings ~config result] runs {!Fold_health.check_divergence}
    over [result] — deriving the open-position count from
    [result.final_portfolio] via {!open_position_count} and the stop-eligible
    count from [result.n_stop_eligible_positions]. Returns a singleton
    [Stuck_held_positions] finding when the portfolio holds more open positions
    than the strategy still monitors under stop evaluation (the gap exceeds
    [config.max_stuck_held_positions]), else the empty list (#1553). The
    runner-path bridge the scenario runner unions with the {!Fold_health.check}
    findings; additive and purely diagnostic. *)

val filter_stop_infos_in_window :
  Stop_log.stop_info list -> start_date:Date.t -> Stop_log.stop_info list
(** Drop [stop_info]s whose [entry_date] is before [start_date] — i.e. positions
    opened during the warmup window. Used at runner teardown to keep
    warmup-window stop events from corrupting [trades.csv] columns (FIFO-pop in
    [Result_writer._pop_stop_info] would otherwise attach a warmup-window
    stop_info to an in-window round-trip when the same symbol re-trades across
    the boundary).

    Stop_infos with [entry_date = None] are kept (test fixtures that don't drive
    {!Stop_log.set_current_date}). *)

val filter_force_liquidations_in_window :
  Portfolio_risk.Force_liquidation.event list ->
  start_date:Date.t ->
  Portfolio_risk.Force_liquidation.event list
(** Drop force-liquidation events whose [date] is before [start_date] — i.e.
    events that fired during the warmup window. The simulator runs from
    [warmup_start] so [Force_liquidation_log] observes events from days before
    [start_date]; without this filter, warmup-window force-liqs leak into
    [force_liquidations.sexp] and inflate the visible event count. *)

val filter_audit_records_in_window :
  Trade_audit.audit_record list ->
  start_date:Date.t ->
  Trade_audit.audit_record list
(** Drop audit records whose entry-decision date is before [start_date]. The
    strategy's audit recorder fires from [warmup_start], so without this filter
    [trade_audit.sexp] picks up entries whose round-trips were never reported to
    [trades.csv]. *)

val filter_cascade_summaries_in_window :
  Trade_audit.cascade_summary list ->
  start_date:Date.t ->
  Trade_audit.cascade_summary list
(** Drop cascade-summary rows whose Friday [date] is before [start_date] —
    cascade evaluations that ran during the warmup window. The strategy records
    summaries every Friday from [warmup_start], so without this filter
    [trade_audit.sexp] reports activity counts that include warmup- window
    screen calls. *)

val is_trading_day :
  Trading_simulation_types.Simulator_types.step_result -> bool
(** True if [step] represents a real trading day — i.e. the simulator saw at
    least one bar for any symbol on [step.date]. Reads the authoritative
    [step_result.had_market_bars] flag set in {!Trading_simulation.Simulator}.

    Replaces the prior portfolio-value-vs-cash heuristic, which falsely
    classified post-corporate-action days (held symbol with no further bars) as
    non-trading and silently truncated [equity_curve.csv] /
    [summary.final_portfolio_value] at the day before the gap.

    Must NOT be applied before [Metrics.extract_round_trips] — round-trips
    derive from position-state transitions recorded independently of bar
    presence; filtering on [had_market_bars = false] silently drops trades whose
    entry/exit landed on bar-less days. *)

val run_backtest :
  start_date:Date.t ->
  end_date:Date.t ->
  ?overrides:Sexp.t list ->
  ?sector_map_override:(string, string) Core.Hashtbl.t ->
  ?strategy_choice:Strategy_choice.t ->
  ?trace:Trace.t ->
  ?gc_trace:Gc_trace.t ->
  ?bar_data_source:Bar_data_source.t ->
  ?shared_panels:Snapshot_runtime.Daily_panels.t ->
  ?progress_emitter:Backtest_progress.emitter ->
  ?slippage_bps:int ->
  ?cost_model:Backtest_cost_model.Cost_model.t ->
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
    follow-up. When [trace] is omitted, instrumentation is a no-op.

    [gc_trace], when passed, records [Gc.stat] snapshots at the same coarse
    phase boundaries as [trace] (universe-load done, macro-load done, fill done,
    teardown done). Used by Phase 1 of the hybrid-tier architecture plan to
    discriminate among load-time / per-tick / Friday-cycle residency hypotheses.

    Additionally, the panel runner snapshots [Gc.stat] before and after every
    simulator step (one step = one calendar day in the [Daily] cadence = one
    [Engine.update_market] call). Phase labels are shaped
    [step_<YYYY-MM-DD>_before] / [step_<YYYY-MM-DD>_after] so the per-day delta
    is recoverable from the CSV by pairing labels. Used by PR-1 of the
    engine-pooling plan ([dev/plans/engine-layer-pooling-2026-04-27.md]) to
    confirm on real data that [Engine.update_market] dominates the per-tick
    allocator profile before the buffer-reuse refactors land.

    Independent measurement plane from [trace]'s per-phase wall-time + RSS
    readings; both can be passed in the same run. When [gc_trace] is omitted, no
    snapshots are taken.

    [strategy_choice], when passed, selects which trading strategy the simulator
    runs (#882). Defaults to {!Strategy_choice.Weinstein} — behaviour-preserving
    for every pre-#882 caller. Set to {!Strategy_choice.Bah_benchmark} to swap
    in a Buy-and-Hold benchmark on a single symbol; the runner still loads the
    standard universe / sector-map / AD-bars machinery (wasted work for BAH but
    minimally invasive), and the [Panel_runner] dispatch picks
    {!Trading_strategy.Bah_benchmark_strategy.make} in place of
    {!Weinstein_strategy.make}. The BAH symbol must be present in the resolved
    [sector_map_override] so its CSV gets staged into the snapshot — see
    [universes/spy-only.sexp].

    [bar_data_source], when passed, selects the OHLCV backend for the
    simulator's per-tick price reads. Default is {!Bar_data_source.Csv} (the
    pre-Phase-D behaviour). {!Bar_data_source.Snapshot} switches the simulator
    to read OHLCV from a snapshot directory written by Phase B. See
    {!Bar_data_source.t} and the Phase D plan
    ([dev/plans/snapshot-engine-phase-d-2026-05-02.md]) for the full contract.

    [shared_panels], when [Some p], reuses a caller-owned
    [Snapshot_runtime.Daily_panels.t] for this run's snapshot reads instead of
    allocating + closing a fresh cache. Threaded straight through to
    {!Panel_runner.run}; see its [shared_panels] doc for the contract and the
    walk-forward cache-reuse motivation. [None] (the default) is byte-identical
    to the prior per-run create/close behaviour.

    [progress_emitter], when passed, threads a Friday-cycle checkpoint hook
    through the simulator step loop. See {!Backtest_progress.emitter}. Used by
    [backtest_runner.exe]'s [--progress-every] flag to emit a tail-able
    [progress.sexp] mid-run; tests install a recording emitter to pin emission
    cadence. Resumability is intentionally NOT in this PR — the checkpoint is
    read-only progress information; restartability of the simulator state is a
    follow-up (deferred per the data-pipeline-automation plan, §"Open question
    4").

    [cost_model], when passed, threads a {!Backtest_cost_model.Cost_model.t}
    overlay through the simulator. The runner builds a per-trade post-fill
    adjustment from {!Backtest_cost_model.Cost_model.apply_per_trade_commission}
    and threads it through {!Panel_runner.run} into
    {!Trading_simulation.Simulator.create_deps}. [None] (the default) preserves
    the zero-cost baseline byte-for-byte — every existing scenario file omits
    the field and is unaffected. Item 2 of the four-item cost-model wiring plan
    tracked in [dev/status/cost-model.md]; the per-share-commission,
    bid-ask-spread and market-impact components are not yet routed through the
    runner. *)
