(** Panel-loader execution path — runner-side seam for the simulator + Weinstein
    strategy.

    Post-#848 forward fix (PR2 of two; PR1 #861 added the [~calendar] plumbing
    on [Snapshot_bar_views] / [Bar_reader.of_snapshot_views]). All three reader
    surfaces fan out from one snapshot directory:

    - The strategy's [Bar_reader] is snapshot-backed:
      [Bar_reader.of_snapshot_views ~calendar] is built over a
      [Snapshot_callbacks.of_daily_panels] shim around the same [Daily_panels.t]
      the simulator and final-close lookup use. The [~calendar] argument is the
      trading-day calendar (Mon–Fri, holidays included) the runner builds for
      the warmup..end_date span; threading it through makes
      [Snapshot_bar_views.daily_view_for] walk calendar columns NaN-passthrough
      deterministically. This is the closing half of #848 — see
      `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md` for
      the cell-by-cell parity surface.
    - The simulator's per-tick price reads flow through a snapshot-backed
      [Market_data_adapter]. CSV mode builds the snapshot directory in-process
      from CSV bars at runner start (via [Csv_snapshot_builder]); Snapshot mode
      reuses a pre-built directory.
    - Final close-price lookups read from the [Snapshot_runtime.Daily_panels]
      via [Daily_panels.read_today].

    The runner holds no parallel panel-backed bar storage — every read fans out
    from the snapshot directory. *)

open Core

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}
(** Minimal subset of {!Runner._deps} that [Panel_runner] needs. Kept as a plain
    record so [Runner] can build it without exporting its private [_deps] type.
*)

val run :
  input:input ->
  start_date:Date.t ->
  end_date:Date.t ->
  warmup_days:int ->
  initial_cash:float ->
  commission:Trading_engine.Types.commission_config ->
  ?strategy_choice:Strategy_choice.t ->
  ?trace:Trace.t ->
  ?gc_trace:Gc_trace.t ->
  ?bar_data_source:Bar_data_source.t ->
  ?shared_panels:Snapshot_runtime.Daily_panels.t ->
  ?progress_emitter:Backtest_progress.emitter ->
  ?slippage_bps:int ->
  ?cost_model:Backtest_cost_model.Cost_model.t ->
  ?prune_universe_by_active_through:bool ->
  unit ->
  Trading_simulation_types.Simulator_types.run_result
  * Stop_log.t
  * Trade_audit.t
  * Force_liquidation_log.t
  * Trading_simulation.Stale_hold.Log.t
  * (string * float) list
(** Same shape as the Legacy path's per-strategy entry point. The Panel branch
    in [Runner] uses this; callers should not call this directly outside of
    tests.

    Returns a 6-tuple
    [(run_result, stop_log, trade_audit, force_liquidation_log, stale_hold_log,
     final_close_prices)]: the simulator output, the per-position stop log
    accumulated by the strategy wrapper, the per-trade decision-trail audit
    collected at the strategy's entry / exit decision sites, the
    force-liquidation event log, the per-step stale-held-position log (held
    symbols whose underlying bars stopped arriving — typically a
    corporate-action signature; see {!Trading_simulation.Stale_hold}), and an
    alist of [(symbol, close_price)] read from the snapshot's [Close] column for
    [end_date] for every universe symbol with a non-NaN close on that date. The
    consumer ([Runner]) filters [final_close_prices] to symbols still held at
    end of run when populating [Runner.result.final_prices].

    [gc_trace], when passed, snapshots [Gc.stat] before and after every
    simulator step (one step = one calendar day = one [Engine.update_market]
    call). Phase labels are shaped [step_<YYYY-MM-DD>_before] and
    [step_<YYYY-MM-DD>_after] so the per-day delta is recoverable from the CSV
    by pairing labels. Used by PR-1 of the engine-pooling plan
    ([dev/plans/engine-layer-pooling-2026-04-27.md]) to confirm on real data
    that [Engine.update_market] dominates the per-tick allocator profile before
    the buffer-reuse refactors land. When [gc_trace] is omitted, the runner
    takes no per-step snapshots and the cost is one [None] match per step.

    [progress_emitter], when passed, threads a periodic-checkpoint hook into the
    per-step loop. On every [emitter.every_n_fridays]-th Friday the runner
    builds a {!Backtest_progress.t} reflecting cycles done / total / last
    completed date / cumulative trade count / current equity, and invokes
    [emitter.on_progress] with it. The final completed step also fires an
    emission unconditionally so a [progress.sexp] always reflects the run's end
    state. When [None], the runner takes no extra work — same zero-overhead
    contract as the other optional plumbing.

    [strategy_choice], when passed, selects which strategy module the simulator
    runs (#882). Defaults to {!Strategy_choice.Weinstein} —
    {!Weinstein_strategy.make} with the runner's deps-loaded inputs (AD bars,
    sector map, config). {!Strategy_choice.Bah_benchmark} swaps in
    {!Trading_strategy.Bah_benchmark_strategy.make} on the configured symbol;
    the runner's bar_reader / audit_recorder / ad_bars / ticker_sectors / config
    are dropped on that branch (BAH ignores them).

    [bar_data_source], when passed, selects how the snapshot directory is
    sourced. The strategy's bar reader, the simulator adapter, and the
    final-close lookup all read through this same snapshot.

    - Default ({!Bar_data_source.Csv}) builds a snapshot directory in-process
      from the universe's CSV bars at runner start, then routes the simulator
      through it.

    - {!Bar_data_source.Snapshot} reuses a caller-provided pre-built snapshot
      directory + manifest (typically written by [build_snapshots.exe]).

    Both branches use the same wiring (snapshot-backed strategy reader +
    snapshot-backed simulator adapter, fanning out from one [Daily_panels.t]);
    the only difference is whether the snapshot directory was materialised
    in-process or supplied externally. See
    `dev/notes/path-dependent-regression-848-investigation-2026-05-05.md` for
    the path-dependence surface this rewiring closes.

    [shared_panels], when [Some p], makes the run read through a caller-owned
    [Snapshot_runtime.Daily_panels.t] instead of allocating (and closing) a
    fresh one. The caller owns the lifecycle: [run] neither creates nor
    {!Snapshot_runtime.Daily_panels.close}s the cache. An in-process caller that
    issues several [run] calls against the same handle reuses the first run's
    decode instead of re-decoding (pinned by
    [test_shared_panels_reused_across_backtests]). Only valid with
    [bar_data_source = Some (Snapshot {...})] whose [snapshot_dir]/[manifest]
    match the panels.

    The broad-universe walk-forward path (see
    {!Walk_forward.Walk_forward_executor}) passes a parent-owned handle so each
    forked fold reads through it without closing it; on that path the per-fold
    [misses_per_symbol = 1.00] is expected and harmless because each fold runs
    in its OWN child process whose exit resets the [VMAllocationTracker] slab
    and reclaims the heap — the RSS / crash safety comes from that fork
    isolation, not from cross-fold cache reuse. [None] (the default) is
    byte-identical to the prior per-run create/close behaviour — every existing
    caller is unaffected.

    [cost_model], when passed, threads a {!Backtest_cost_model.Cost_model.t}
    overlay through the simulator on two surfaces:

    - {!Cost_model.apply_per_trade_commission} becomes the simulator's
      [on_trade_fill] hook (item 2 of the cost-model wiring plan in
      [dev/status/cost-model.md]).
    - {!Cost_model.to_engine_costs} derives the engine's per-share commission
      and integer slippage_bps, fully replacing both the runner's default
      commission (typically [{ per_share = 0.01; minimum = 1.0 }]) and the
      caller's [?slippage_bps]. This makes [bid_ask_spread_bps] and
      [per_share_commission] material at every fill. See
      {!engine_costs_with_overlay} for the pure helper that performs the
      resolution (exposed for tests).

    [None] (the default) preserves the byte-equal baseline: the runner's default
    commission and the caller's [?slippage_bps] flow through unchanged, and no
    [on_trade_fill] is set. The market-impact component of [cost_model] is not
    yet routed through the runner — it requires ADV plumbing that lives on the
    simulation data layer.

    [prune_universe_by_active_through] is the Win #4 production opt-in (see
    [dev/plans/v7-sweep-speedup-2026-05-26.md] §Win #4). When [true], the run's
    [start_date] becomes a point-in-time cutoff applied on two surfaces, both
    reading the per-symbol [active_through] marker from the run's
    [Snapshot_runtime.Daily_panels.t]:

    - the strategy's per-Friday screener pre-prunes [config.universe] before
      Phase-1 stage classification (via {!Weinstein_strategy.make}'s
      [?fold_start_date], threaded through {!Panel_strategy_builder.build}); and
    - the simulator's per-step bar-fetch loop drops the same symbols (via
      {!Trading_simulation.Simulator.create_deps}'s [?active_through_for]).

    Both drop only symbols whose last active day is strictly before [start_date]
    — symbols genuinely uninvestable AT THE FOLD START. This is NOT survivor
    bias: it never filters on the present date, so symbols delisted later in the
    fold (or still trading today) are kept. The speedup comes from skipping the
    per-symbol cost of names that can never appear in the fold's results (e.g.
    ~1500 of 3015 symbols pre-IPO/already-delisted on a 1998 fold).

    [false] (the default) is byte-identical to the pre-Win-#4 baseline: no
    pruning on either surface, every universe symbol is classified and
    bar-fetched, every golden / snapshot-parity test replays unchanged. Only the
    {!Strategy_choice.Weinstein} strategy consumes the screener-side cutoff; the
    simulator-side bar-fetch prune applies regardless of strategy choice (it
    drops symbols no strategy could use). *)

val fold_start_date_of_opt_in :
  prune_universe_by_active_through:bool -> start_date:Date.t -> Date.t option
(** Pure helper that mirrors the Win #4 opt-in resolution applied inside {!run}:
    [prune_universe_by_active_through = false] (the default) → [None] (no
    point-in-time pruning on either the strategy screener or the simulator
    bar-fetch loop → bit-equal baselines); [true] → [Some start_date], the
    fold's first day used as the [active_through] cutoff on both surfaces.
    Exposed so tests pin the flag→cutoff mapping without spinning up a full
    simulator run. *)

val engine_costs_with_overlay :
  default_commission:Trading_engine.Types.commission_config ->
  ?default_slippage_bps:int ->
  ?cost_model:Backtest_cost_model.Cost_model.t ->
  unit ->
  Trading_engine.Types.commission_config * int option
(** Pure helper that mirrors the overlay rule applied inside {!run}: when
    [cost_model = Some cm], the returned [(commission, slippage_bps)] pair is
    derived from {!Cost_model.to_engine_costs} (fully replacing the runner
    defaults); when [cost_model = None], the runner defaults flow through
    unchanged. Exposed so tests can pin the resolution without spinning up a
    full simulator. *)
