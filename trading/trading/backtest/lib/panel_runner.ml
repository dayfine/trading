(** Panel-loader execution path — see [panel_runner.mli]. *)

open Core
open Trading_simulation
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Cost_model = Backtest_cost_model.Cost_model

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

(* Wrap the runner's already-constructed [daily_panels] in the simulator's
   callback adapter, sharing the LRU cache with the strategy bar reader.

   The naive path of going through [Bar_data_source.build_adapter (Snapshot
   {...})] would call [Daily_panels.create] a second time and produce a
   parallel ~330 MB LRU at the 15y SP500 window — see
   [dev/notes/15y-memory-cliff-2026-05-08.md] §"Cliff #2". *)
let _build_market_data_adapter ~daily_panels =
  Bar_data_source.build_adapter_from_panels daily_panels

(* Stale-hold policy for the simulator, derived from the resolved strategy
   config. The detector defaults ([enabled]/[stale_after_days]) are carried over
   from [Stale_hold.default_config]; only [stale_exit_after_days] is threaded
   from the strategy config. [None] (the default) keeps every existing backtest
   byte-identical — the detector still records, but no force-exit fires. *)
let _stale_hold_policy (config : Weinstein_strategy.config) : Stale_hold.config
    =
  {
    Stale_hold.default_config with
    stale_exit_after_days = config.stale_exit_after_days;
  }

let _make_simulator (input : input) ~stop_log ~stale_hold_log ~start_date
    ~warmup_start ~end_date ~initial_cash ~commission ?slippage_bps
    ?on_trade_fill ~strategy ~market_data_adapter () =
  (* Default-off [Warmup_trade_gate] (#1549 A2); identity unless the flag is on. *)
  let strategy =
    Strategy_wrapper.wrap ~stop_log strategy
    |> Warmup_trade_gate.wrap_strategy
         ~suppress:input.config.suppress_warmup_trading ~start_date
  in
  let sim_deps =
    Simulator.create_deps ~symbols:input.all_symbols
      ~data_dir:input.data_dir_fpath ~strategy ~commission
      ~metric_suite:(Metric_computers.default_metric_suite ~initial_cash ())
      ~market_data_adapter ~stale_hold_log ?slippage_bps
      ~stale_hold_policy:(_stale_hold_policy input.config)
      ~margin_config:input.config.margin_config ?on_trade_fill ()
  in
  let config =
    Simulator.
      {
        start_date = warmup_start;
        end_date;
        initial_cash;
        commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  Simulator.create ~config ~deps:sim_deps
  |> Result.map_error ~f:(fun e ->
      "Backtest.Panel_runner: failed to create simulator: " ^ Status.show e)
  |> Result.ok_or_failwith

(* Read one symbol's close on [date]. Returns [None] when the symbol is not
   present in the snapshot, the read errors, or the close is NaN. *)
let _read_close ~daily_panels ~close_col ~date symbol =
  match Daily_panels.read_today daily_panels ~symbol ~date with
  | Error _ -> None
  | Ok snap ->
      let v = snap.values.(close_col) in
      if Float.is_nan v then None else Some (symbol, v)

(** Close prices on [end_date] for every universe symbol, read from the snapshot
    via [Daily_panels.read_today]. Missing / NaN entries are dropped; the runner
    filters to held symbols when populating [Runner.result.final_prices]. *)
let _final_close_prices ~daily_panels ~symbols ~end_date =
  let schema = Daily_panels.schema daily_panels in
  match Snapshot_schema.index_of schema Snapshot_schema.Close with
  | None -> []
  | Some close_col ->
      List.filter_map symbols
        ~f:(_read_close ~daily_panels ~close_col ~date:end_date)

(* Resolve the [(snapshot_dir, manifest)] pair the runner reads through for
   the strategy's bar reads (via [_build_snapshot_bar_reader]), the
   simulator's per-tick price reads, and final-close lookups. CSV mode
   delegates to [Csv_snapshot_builder.build]; Snapshot mode reuses the
   caller-provided directory. *)
let _resolve_snapshot_source (input : input) ~warmup_start ~end_date
    ~bar_data_source =
  match bar_data_source with
  | None | Some Bar_data_source.Csv ->
      let dir, manifest =
        Csv_snapshot_builder.build ~data_dir:input.data_dir_fpath
          ~universe:input.all_symbols ~start_date:warmup_start ~end_date
      in
      eprintf "Panel_runner: in-process snapshot built (%d symbols, %s)\n%!"
        (List.length input.all_symbols)
        dir;
      (dir, manifest)
  | Some (Bar_data_source.Snapshot { snapshot_dir; manifest }) ->
      (snapshot_dir, manifest)

(* Generate the trading-day calendar: every weekday (Mon-Fri) in the inclusive
   range [start..end_]. Holidays are not removed — the simulator already
   tolerates "no bar on this day" via the [is_trading_day] filter, and the
   strategy's snapshot-backed [daily_view_for] walks calendar columns
   deterministically (PR1 of the #848 forward fix; see
   [Bar_reader.of_snapshot_views]). *)
let _build_calendar ~start ~end_ : Date.t array =
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else
      let dow = Date.day_of_week d in
      let is_weekend =
        Day_of_week.equal dow Day_of_week.Sat
        || Day_of_week.equal dow Day_of_week.Sun
      in
      let acc' = if is_weekend then acc else d :: acc in
      loop (Date.add_days d 1) acc'
  in
  Array.of_list (loop start [])

(* Build a snapshot-backed [Bar_reader.t] for the strategy: derive the
   field-accessor [Snapshot_callbacks.t] from the same [Daily_panels.t] the
   simulator + final-close lookup already use, then wrap in a
   [Bar_reader.of_snapshot_views] passing the runner's [calendar]. The
   calendar threads through to [Snapshot_bar_views.daily_view_for] /
   [low_window], which walk calendar columns NaN-passthrough deterministically
   — the same window definition that closes the #848 path-dependent
   regression.

   The snapshot path reuses the LRU-bounded [Daily_panels.t] for both strategy
   bar reads and simulator price reads, so we hold one shared bar store
   resident.

   Refs: closes the regression on Bar_reader.of_snapshot_views (the
   [~calendar] plumbing on the snapshot views that this constructor now
   consumes was introduced in a separate prior PR). *)
let _build_snapshot_bar_reader ~daily_panels ~calendar =
  let callbacks = Snapshot_callbacks.of_daily_panels daily_panels in
  eprintf
    "Panel_runner: snapshot bar reader wired (calendar %d days) for strategy\n\
     %!"
    (Array.length calendar);
  Weinstein_strategy.Bar_reader.of_snapshot_views ~calendar callbacks

let _create_panels ~snapshot_dir ~manifest =
  Daily_panels.create ~snapshot_dir ~manifest
    ~max_cache_mb:(Snapshot_cache_config.resolve_cache_mb ())
  |> Result.map_error ~f:(fun e ->
      "Panel_runner: Daily_panels.create failed: " ^ Status.show e)
  |> Result.ok_or_failwith

(* Resolve the [Daily_panels.t] this run reads through. [Some p]: read through a
   caller-owned cache ([run] does not close it). [None]: a per-run cache [run]
   closes (the prior path). See [shared_panels] in [panel_runner.mli]. *)
let _resolve_panels ~shared_panels ~snapshot_dir ~manifest =
  match shared_panels with
  | Some p -> p
  | None -> _create_panels ~snapshot_dir ~manifest

(* Hybrid setup: snapshot-backed strategy bar reader, snapshot-backed
   simulator adapter, snapshot-backed final-close lookup — all reading
   through one [Daily_panels.t]. See module-doc. *)
let _setup_hybrid (input : input) ~strategy_choice ~snapshot_dir ~manifest
    ~shared_panels ~warmup_start ~end_date ~audit_recorder =
  let daily_panels = _resolve_panels ~shared_panels ~snapshot_dir ~manifest in
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  let bar_reader = _build_snapshot_bar_reader ~daily_panels ~calendar in
  let strategy =
    Panel_strategy_builder.build ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors ~config:input.config ~strategy_choice
      ~bar_reader ~audit_recorder
  in
  let adapter = _build_market_data_adapter ~daily_panels in
  let final_close_prices () =
    _final_close_prices ~daily_panels ~symbols:input.all_symbols ~end_date
  in
  (strategy, adapter, final_close_prices, daily_panels)

(* Bundle of recorder collectors threaded through one backtest. Extracted
   so [run] stays under the 50-line linter cap. *)
type _recorders = {
  stop_log : Stop_log.t;
  trade_audit : Trade_audit.t;
  force_liquidation_log : Force_liquidation_log.t;
  stale_hold_log : Trading_simulation.Stale_hold.Log.t;
  audit_recorder : Weinstein_strategy.Audit_recorder.t;
}

let _create_recorders () : _recorders =
  let stop_log = Stop_log.create () in
  let trade_audit = Trade_audit.create () in
  let force_liquidation_log = Force_liquidation_log.create () in
  let stale_hold_log = Trading_simulation.Stale_hold.Log.create () in
  let audit_recorder =
    Trade_audit_recorder.of_collector ~trade_audit ~force_liquidation_log
  in
  {
    stop_log;
    trade_audit;
    force_liquidation_log;
    stale_hold_log;
    audit_recorder;
  }

(* Build the simulator's per-trade post-fill adjustment from the optional
   [cost_model]. [None] returns [None] — the simulator stays on its
   byte-equal default path. *)
let _on_trade_fill_of_cost_model cost_model =
  Option.map cost_model ~f:Cost_model.apply_per_trade_commission

(* Resolve the effective [(commission, slippage_bps)] pair the simulator
   receives.

   When [cost_model = Some cm], the overlay takes precedence: the engine's
   per-share commission + integer slippage_bps are derived from
   {!Cost_model.to_engine_costs}, fully replacing the runner's default
   commission and the caller's [?slippage_bps]. This is the explicit
   scenario-facing surface — scenarios that declare a [cost_model] expect
   their declared cost regime to be exactly what the engine bills.

   When [cost_model = None], the function returns the runner-side defaults
   unchanged: the [~default_commission] passed by the runner constants
   table and the caller's [?default_slippage_bps] (typically [None] →
   engine's own slippage default). Byte-equal to pre-#1260 baselines. *)
let engine_costs_with_overlay ~default_commission ?default_slippage_bps
    ?cost_model () =
  match cost_model with
  | None -> (default_commission, default_slippage_bps)
  | Some cm ->
      let commission, slip_bps = Cost_model.to_engine_costs cm in
      (commission, Some slip_bps)

(* Emit the cache-thrash diagnostic and drop the LRU before returning (see
   dev/notes/bayesian-int-rounding-bug-2026-05-19.md §"Third failure"). When
   [shared_panels = Some _] the caller owns the cache lifecycle, so we must NOT
   close it here — the owning caller (the walk-forward executor) closes it once
   after the grid. *)
let _finish_panels ~daily_panels ~n_all_symbols ~shared_panels =
  Snapshot_cache_config.log_cache_stats ~daily_panels ~n_symbols:n_all_symbols;
  if Option.is_none shared_panels then Daily_panels.close daily_panels

let run ~(input : input) ~start_date ~end_date ~warmup_days ~initial_cash
    ~commission ?(strategy_choice = Strategy_choice.default) ?trace ?gc_trace
    ?bar_data_source ?shared_panels ?progress_emitter ?slippage_bps ?cost_model
    () =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf
    "Panel_runner: simulator window %s..%s (warmup %d days, strategy %s)\n%!"
    (Date.to_string warmup_start)
    (Date.to_string end_date) warmup_days
    (Strategy_choice.name strategy_choice);
  let r = _create_recorders () in
  let n_all_symbols = List.length input.all_symbols in
  let snapshot_dir, manifest =
    _resolve_snapshot_source input ~warmup_start ~end_date ~bar_data_source
  in
  let strategy, market_data_adapter, final_close_prices_thunk, daily_panels =
    _setup_hybrid input ~strategy_choice ~snapshot_dir ~manifest ~shared_panels
      ~warmup_start ~end_date ~audit_recorder:r.audit_recorder
  in
  let on_trade_fill = _on_trade_fill_of_cost_model cost_model in
  let effective_commission, effective_slippage_bps =
    engine_costs_with_overlay ~default_commission:commission
      ?default_slippage_bps:slippage_bps ?cost_model ()
  in
  let sim =
    _make_simulator input ~stop_log:r.stop_log ~stale_hold_log:r.stale_hold_log
      ~start_date ~warmup_start ~end_date ~initial_cash
      ~commission:effective_commission ?slippage_bps:effective_slippage_bps
      ?on_trade_fill ~strategy ~market_data_adapter ()
  in
  let progress_acc =
    Panel_step_loop.build_progress_acc ~progress_emitter ~warmup_start ~end_date
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        Panel_step_loop.run_simulator_with_gc_trace ?gc_trace ?progress_acc
          ~stop_log:r.stop_log sim)
  in
  Option.iter progress_acc ~f:Backtest_progress.emit_final;
  let final_close_prices = final_close_prices_thunk () in
  _finish_panels ~daily_panels ~n_all_symbols ~shared_panels;
  ( sim_result,
    r.stop_log,
    r.trade_audit,
    r.force_liquidation_log,
    r.stale_hold_log,
    final_close_prices )
