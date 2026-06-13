(* @large-module: backtest orchestration covers config-override deep-merge,
   universe + sector-map resolution, AD-breadth + sector-ETF loading (each
   gated by hypothesis-testing toggles in [Weinstein_strategy.config]), and
   the dispatch into the panel-backed runner. The actual simulator
   construction + run-loop lives in [panel_runner.ml]; this module owns
   the dependency-loading orchestration only. *)
open Core
open Trading_simulation

(* Configuration constants *)

let index_symbol = "GSPC.INDX"
let initial_cash = 1_000_000.0
let commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Number of calendar days to prepend before [start_date] when the simulator
    runs. The Weinstein strategy needs 30 weeks (~210 days) of bar history to
    classify stages; the Buy-and-Hold benchmark is stateless and would otherwise
    enter its single position at [warmup_start] instead of [start_date], which
    corrupts the day-1-entry semantics the BAH baseline is pinned against.
    Strategy-dispatched (#882) rather than a single constant. *)
let warmup_days_for : Strategy_choice.t -> int = function
  | Weinstein -> 210
  | Bah_benchmark _ -> 0
  | Spy_only_weinstein _ -> 210
  (* The RS analyzer needs [rs_ma_period] (52wk default) aligned weekly bars to
     compute a ranking score, so the sector-rotation strategy warms up against
     the larger of its 30-week stage MA and the 52-week RS window — ~52 weeks =
     ~364 days. *)
  | Sector_rotation_weinstein _ -> 364

(* Backwards-compatible internal alias kept so the rest of this module reads as
   before; [warmup_days_for] is the exported name (see [runner.mli]). *)
let _warmup_days_for = warmup_days_for

(* Public types *)

type result = {
  summary : Summary.t;
  round_trips : Metrics.trade_metrics list;
  steps : Trading_simulation_types.Simulator_types.step_result list;
  final_portfolio : Trading_portfolio.Portfolio.t;
  n_stop_eligible_positions : int;
  overrides : Sexp.t list;
  stop_infos : Stop_log.stop_info list;
  audit : Trade_audit.audit_record list;
  cascade_summaries : Trade_audit.cascade_summary list;
  force_liquidations : Portfolio_risk.Force_liquidation.event list;
  stale_holds : Trading_simulation.Stale_hold.event list;
      (** Per-step records of held positions whose underlying bars stopped
          arriving (typical signature of a corporate action — cash merger, stock
          merger, bankruptcy delisting, suspension — the strategy did not
          anticipate). One event per (held position, step) pair while the
          position remains stale. Filtered to events whose [date >= start_date]
          (i.e. dropping warmup-window staleness). Persisted to
          [stale_holds.sexp]. See {!Trading_simulation.Stale_hold}. *)
  final_prices : (string * float) list;
  universe : string list;
      (** Post-cap, sorted list of symbols the simulator actually traded over
          (excludes the primary index and sector ETFs). Persisted to
          [universe.txt] by [Result_writer.write] so downstream counterfactual
          tooling — [optimal_strategy] in particular — can scope its analysis to
          the same universe rather than reloading [data/sectors.csv] (the full
          ~10k-symbol set, which over-states what the strategy could have
          picked). *)
}

(* Trading-day filter *)

(** True if [step] represents a real trading day — i.e. the simulator saw at
    least one bar for any symbol on [step.date]. Reads the authoritative
    [step_result.had_market_bars] flag set in {!Trading_simulation.Simulator}
    from the per-tick [today_bars] list.

    Replaces the prior portfolio-value-vs-cash heuristic, which falsely
    classified post-corporate-action days (held symbol with no further bars →
    [Calculations.portfolio_value] errors → caller silently substitutes [cash])
    as non-trading and silently truncated [equity_curve.csv]
    /[summary.final_portfolio_value] at the day before the gap.

    Must NOT be applied to round-trip extraction — round-trips derive from
    position-state transitions (fills) recorded independently of bar presence.
    Applying this filter before [Metrics.extract_round_trips] silently drops
    every trade whose entry *and* exit landed on steps where
    [had_market_bars = false]. *)
let is_trading_day (step : Trading_simulation_types.Simulator_types.step_result)
    =
  step.had_market_bars

(* Config overrides via sexp deep-merge — see {!Overlay_validator} for the
   deep-merge + unknown-key validation. Extracted to a sibling module to keep
   this file under the @large-module size limit. *)

let _apply_overrides = Overlay_validator.apply_overrides

(* Dependency loading *)

type _deps = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  universe : string list;
      (** Post-cap, sorted list of universe symbols (excluding the primary index
          and sector ETFs). Same set the runner trades over and the value
          carried forward into [Runner.result.universe] / [universe.txt]. *)
  universe_size : int;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

let _resolve_ticker_sectors ~data_dir sector_map_override =
  match sector_map_override with
  | Some tbl ->
      eprintf "Using scenario-provided sector map (%d symbols)...\n%!"
        (Hashtbl.length tbl);
      tbl
  | None ->
      eprintf "Loading universe from sectors.csv...\n%!";
      Sector_map.load ~data_dir

(** Apply [config.universe_cap] to the (sorted) universe + sector map.

    [universe_cap = Some n] truncates the universe to the first [n] symbols
    after the existing [String.compare] sort and rebuilds [ticker_sectors] with
    only the kept symbols. Hypothesis-testing field — see [config] doc. [None]
    (default) returns the inputs unchanged. *)
let _apply_universe_cap ~ticker_sectors ~universe ~cap =
  match cap with
  | None -> (ticker_sectors, universe)
  | Some n when n >= List.length universe -> (ticker_sectors, universe)
  | Some n ->
      let kept = List.take universe n in
      let kept_set = String.Set.of_list kept in
      let trimmed = Hashtbl.create (module String) in
      Hashtbl.iteri ticker_sectors ~f:(fun ~key ~data ->
          if Set.mem kept_set key then Hashtbl.set trimmed ~key ~data);
      eprintf
        "universe_cap = Some %d: truncated universe from %d to %d symbols\n%!" n
        (List.length universe) (List.length kept);
      (trimmed, kept)

(** Load AD breadth bars unless [config.skip_ad_breadth = true]. The skip path
    short-circuits to the same [[]] value [Ad_bars.load] returns when the
    underlying CSVs are absent, so downstream macro readers experience the same
    degraded mode. Hypothesis-testing flag — see [config] doc. *)
let _load_ad_bars ?trace ~data_dir ~universe_size
    ~(config : Weinstein_strategy.config) () =
  if config.skip_ad_breadth then (
    eprintf "skip_ad_breadth = true: AD breadth bars NOT loaded (degraded)\n%!";
    [])
  else (
    eprintf "Loading AD breadth bars...\n%!";
    Trace.record ?trace ~symbols_out:universe_size Trace.Phase.Macro (fun () ->
        Weinstein_strategy.Ad_bars.load ~data_dir))

(** Honor [config.skip_sector_etf_load] by clearing [config.sector_etfs] so no
    sector-ETF bars are loaded downstream. Hypothesis-testing flag — see
    [config] doc. *)
let _maybe_clear_sector_etfs (config : Weinstein_strategy.config) =
  if config.skip_sector_etf_load then (
    eprintf "skip_sector_etf_load = true: sector ETFs NOT loaded (degraded)\n%!";
    { config with sector_etfs = [] })
  else config

(** Build the runner's base config: defaults + the canonical macro pipeline
    (full SPDR sector ETF list + global indices). Returns a config that still
    has the C1 hypothesis-testing toggles at their defaults; [_load_deps]
    threads [overrides] through this and then honors any toggles set there. *)
let _runner_base_config ~universe =
  let cfg = Weinstein_strategy.default_config ~universe ~index_symbol in
  {
    cfg with
    indices =
      {
        primary = index_symbol;
        global = Weinstein_strategy.Macro_inputs.default_global_indices;
      };
    sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs;
  }

(** Union of all symbols the runner needs bar data for: primary index, the
    (post-cap) universe, and every sector ETF + global index that survived the
    [skip_sector_etf_load] toggle. Deduped + sorted so callers can rely on a
    stable order. *)
let _all_runner_symbols ~(config : Weinstein_strategy.config) ~universe =
  let sector_etf_symbols =
    List.map config.sector_etfs ~f:(fun (sym, _) -> sym)
  in
  let global_index_symbols =
    List.map config.indices.global ~f:(fun (sym, _) -> sym)
  in
  (index_symbol :: universe) @ sector_etf_symbols @ global_index_symbols
  |> List.dedup_and_sort ~compare:String.compare

(* The primary index symbol every run loads bars for and feeds the macro / RS
   pipeline. Surfaced via [runner.mli] so warehouse-building tooling can stage
   the same benchmark the runner reads, rather than hardcoding it. *)
let primary_index_symbol = index_symbol

(* All symbols a default [Weinstein] run would stage bars for over [universe]:
   the (post-cap) universe, the primary index, and the full SPDR sector-ETF +
   global-index macro set with the hypothesis-testing skip toggles at their
   defaults (i.e. nothing skipped). Reuses the same [_runner_base_config] +
   [_all_runner_symbols] the runner builds [_deps.all_symbols] from, so the two
   agree by construction. See [runner.mli]. *)
let all_snapshot_symbols ~universe =
  _all_runner_symbols ~config:(_runner_base_config ~universe) ~universe

let _load_deps ?trace ?gc_trace ~overrides ~sector_map_override () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let data_dir = Fpath.to_string data_dir_fpath in
  let ticker_sectors =
    Trace.record ?trace Trace.Phase.Load_universe (fun () ->
        _resolve_ticker_sectors ~data_dir:data_dir_fpath sector_map_override)
  in
  Gc_trace.record ?trace:gc_trace ~phase:"load_universe_done" ();
  let universe =
    Hashtbl.keys ticker_sectors |> List.sort ~compare:String.compare
  in
  (* Build the base config + apply overrides FIRST so the hypothesis-testing
     toggles are populated before we use them to gate AD-breadth +
     sector-ETF loads and to apply the universe cap. *)
  let config = _apply_overrides (_runner_base_config ~universe) overrides in
  let ticker_sectors, universe =
    _apply_universe_cap ~ticker_sectors ~universe ~cap:config.universe_cap
  in
  let universe_size = List.length universe in
  eprintf "Universe: %d stocks\n%!" universe_size;
  let config = _maybe_clear_sector_etfs { config with universe } in
  let ad_bars = _load_ad_bars ?trace ~data_dir ~universe_size ~config () in
  Gc_trace.record ?trace:gc_trace ~phase:"macro_done" ();
  let all_symbols = _all_runner_symbols ~config ~universe in
  {
    data_dir_fpath;
    ticker_sectors;
    universe;
    universe_size;
    ad_bars;
    config;
    all_symbols;
  }

(* Simulation *)

(** Build the [Panel_runner.input] view of the loaded deps — the only fields the
    panel-backed runner needs. *)
let _panel_input_of_deps (deps : _deps) : Panel_runner.input =
  {
    data_dir_fpath = deps.data_dir_fpath;
    ticker_sectors = deps.ticker_sectors;
    ad_bars = deps.ad_bars;
    config = deps.config;
    all_symbols = deps.all_symbols;
  }

let _run_panel_backtest ~deps ~start_date ~end_date ~warmup_days
    ?strategy_choice ?trace ?gc_trace ?bar_data_source ?shared_panels
    ?progress_emitter ?slippage_bps ?cost_model () =
  Panel_runner.run
    ~input:(_panel_input_of_deps deps)
    ~start_date ~end_date ~warmup_days ~initial_cash ~commission
    ?strategy_choice ?trace ?gc_trace ?bar_data_source ?shared_panels
    ?progress_emitter ?slippage_bps ?cost_model ()

(** Drop simulator-side [stop_info]s whose [entry_date] is before [start_date] —
    i.e. positions opened during the warmup window. The simulator runs from
    [warmup_start] so [Stop_log] observes [EntryComplete] transitions for
    positions opened during warmup, then [Result_writer._pop_stop_info] pops by
    symbol-FIFO when rendering [trades.csv]. When the same symbol re-trades
    across the [start_date] boundary (warmup-window stop_info comes first by
    [position_id] sort), the warmup stop_info gets attached to the in-window
    round-trip's row, corrupting [entry_stop] / [exit_stop] / [exit_trigger]
    columns.

    Round-trips from [extract_round_trips steps_in_range] are already filtered
    by construction (the steps list starts at [start_date]), so this filter is
    only needed for the [stop_log] surface which has no date-driven extraction
    API.

    Stop_infos with [entry_date = None] are kept (test fixtures that don't drive
    {!Stop_log.set_current_date}). *)
let filter_stop_infos_in_window stop_infos ~start_date =
  List.filter stop_infos ~f:(fun (info : Stop_log.stop_info) ->
      match info.entry_date with
      | Some d -> Date.( >= ) d start_date
      | None -> true)

(** Drop force-liquidation events whose [date] is before [start_date] — i.e.
    events that fired during the warmup window. The simulator runs from
    [warmup_start] so [Force_liquidation_log] observes events from days before
    [start_date]; without this filter, warmup-window force-liqs appear in
    [force_liquidations.sexp] and the [_build_force_liq_index] layer in
    [Result_writer] inflates the visible force-liq count for release-gate
    consumers. Round-trip rows in [trades.csv] would not directly attach these
    events (the index keys on [(symbol, exit_date)] which is in the warmup
    window for warmup events), but downstream tooling that loads
    [force_liquidations.sexp] independently still over-counts. *)
let filter_force_liquidations_in_window events ~start_date =
  List.filter events ~f:(fun (e : Portfolio_risk.Force_liquidation.event) ->
      Date.( >= ) e.date start_date)

(** Drop trade-audit records whose entry-decision date is before [start_date] —
    i.e. positions whose entry decision was made during the warmup window. The
    strategy's audit recorder is wired from [warmup_start], so without this
    filter [trade_audit.sexp] picks up entry/exit decision pairs whose
    round-trips were never reported to [trades.csv]. *)
let filter_audit_records_in_window records ~start_date =
  List.filter records ~f:(fun (r : Trade_audit.audit_record) ->
      Date.( >= ) r.entry.entry_date start_date)

(** Drop cascade-summary rows whose Friday [date] is before [start_date] — i.e.
    cascade evaluations that ran during the warmup window. The strategy's audit
    recorder calls [record_cascade_summary] every Friday from [warmup_start], so
    without this filter [trade_audit.sexp] reports activity counts that include
    warmup-window screen calls (no candidates of which were ever entered into
    [trades.csv]). *)
let filter_cascade_summaries_in_window summaries ~start_date =
  List.filter summaries ~f:(fun (s : Trade_audit.cascade_summary) ->
      Date.( >= ) s.date start_date)

let _make_summary ~start_date ~end_date ~deps ~steps_in_range ~steps
    ~final_value ~round_trips ~sim_result ~stale_holds : Summary.t =
  let stale_held_symbols =
    stale_holds
    |> List.map ~f:(fun (e : Trading_simulation.Stale_hold.event) -> e.symbol)
    |> List.dedup_and_sort ~compare:String.compare
  in
  {
    start_date;
    end_date;
    universe_size = deps.universe_size;
    n_steps = List.length steps;
    initial_cash;
    final_portfolio_value = final_value;
    n_round_trips = List.length round_trips;
    stale_held_symbols;
    metrics =
      Runner_metrics.align_summary_metrics ~sim_result ~round_trips
        ~steps_in_range ~start_date ~end_date;
  }

(** Symbol accessor for [portfolio_position]. *)
let _position_symbol (p : Trading_portfolio.Types.portfolio_position) = p.symbol

(** Filter [final_close_prices] to symbols that are still held in the run's
    [final_portfolio]. Empty result when no positions are open at end of run.
    The reconciler only references [final_prices.csv] via the join key against
    [open_positions.csv], so prices for never-held or already-closed symbols are
    not needed and would just bloat the artefact. *)
let _final_prices_for_held_symbols
    ~(final_portfolio : Trading_portfolio.Portfolio.t) ~final_close_prices =
  let held =
    final_portfolio.positions
    |> List.map ~f:_position_symbol
    |> String.Set.of_list
  in
  List.filter final_close_prices ~f:(fun (sym, _) -> Set.mem held sym)

(** Split [sim_result.steps] into two views over [start_date..end_date]:
    [steps_in_range] includes every calendar day (needed for round-trip
    extraction) and [steps] keeps only real trading days (needed for
    mark-to-market consumers such as the equity curve). *)
let _filter_steps ~sim_result ~start_date =
  (* Steps in the requested date range, all days included. Round-trip
     extraction derives trades from position-state transitions recorded on
     these steps, so it must see *every* step where a trade fill happened —
     including days the [is_trading_day] mark-to-market heuristic would
     otherwise discard. *)
  let steps_in_range =
    List.filter sim_result.Trading_simulation_types.Simulator_types.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date)
  in
  (* Steps on real trading days only — used for [OpenPositionsValue] /
     [UnrealizedPnl] consumers and anything else that needs a meaningful
     mark-to-market portfolio value. Simulator reports [portfolio_value = cash]
     on weekends/holidays even when positions are open, so filter them out
     before mark-to-market consumers use the series. *)
  let steps = List.filter steps_in_range ~f:is_trading_day in
  (steps_in_range, steps)

(** Collect all in-window teardown artefacts (round trips, stop infos, audit
    records, cascade summaries, force liquidations) from the simulation logs.
    Called inside a [Trace.Teardown] span by [_extract_filtered_logs]. *)
let _collect_teardown_artefacts ~stop_log ~trade_audit ~force_liquidation_log
    ~steps_in_range ~start_date =
  ( Metrics.extract_round_trips steps_in_range,
    filter_stop_infos_in_window (Stop_log.get_stop_infos stop_log) ~start_date,
    filter_audit_records_in_window
      (Trade_audit.get_audit_records trade_audit)
      ~start_date,
    filter_cascade_summaries_in_window
      (Trade_audit.get_cascade_summaries trade_audit)
      ~start_date,
    filter_force_liquidations_in_window
      (Force_liquidation_log.events force_liquidation_log)
      ~start_date )

(** Filter stale-hold events to those at or after [start_date]. *)
let _filter_stale_holds ~stale_hold_log ~start_date =
  Trading_simulation.Stale_hold.Log.events stale_hold_log
  |> List.filter ~f:(fun (e : Trading_simulation.Stale_hold.event) ->
      Date.( >= ) e.date start_date)

(** Extract and in-window-filter all post-simulation artefacts: round trips,
    stop infos, audit records, cascade summaries, force liquidations, and stale
    holds. Wrapped in a [Trace.Teardown] span. *)
let _extract_filtered_logs ?trace ?gc_trace ~stop_log ~trade_audit
    ~force_liquidation_log ~stale_hold_log ~steps_in_range ~start_date () =
  let round_trips, stop_infos, audit, cascade_summaries, force_liquidations =
    Trace.record ?trace Trace.Phase.Teardown (fun () ->
        _collect_teardown_artefacts ~stop_log ~trade_audit
          ~force_liquidation_log ~steps_in_range ~start_date)
  in
  Gc_trace.record ?trace:gc_trace ~phase:"teardown_done" ();
  let stale_holds = _filter_stale_holds ~stale_hold_log ~start_date in
  ( round_trips,
    stop_infos,
    audit,
    cascade_summaries,
    force_liquidations,
    stale_holds )

let _log_backtest_window ~start_date ~end_date ~warmup_start ~all_symbols =
  eprintf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length all_symbols);
  eprintf "Running backtest (%s to %s, warmup from %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date)
    (Date.to_string warmup_start)

(* Post-simulation assembly: filter steps to the requested window, extract the
   teardown artefacts, and build the [result] record. Split out of
   [run_backtest] to keep that function under the length limit. *)
let _assemble_result ~start_date ~end_date ~deps ~overrides ~sim_result
    ~stop_log ~trade_audit ~force_liquidation_log ~stale_hold_log
    ~final_close_prices ?trace ?gc_trace () =
  let steps_in_range, steps = _filter_steps ~sim_result ~start_date in
  let final_value = (List.last_exn steps).portfolio_value in
  let ( round_trips,
        stop_infos,
        audit,
        cascade_summaries,
        force_liquidations,
        stale_holds ) =
    _extract_filtered_logs ?trace ?gc_trace ~stop_log ~trade_audit
      ~force_liquidation_log ~stale_hold_log ~steps_in_range ~start_date ()
  in
  let summary =
    _make_summary ~start_date ~end_date ~deps ~steps_in_range ~steps
      ~final_value ~round_trips ~sim_result ~stale_holds
  in
  let final_portfolio = sim_result.final_portfolio in
  {
    summary;
    round_trips;
    steps;
    final_portfolio;
    n_stop_eligible_positions = sim_result.n_stop_eligible_positions;
    overrides;
    stop_infos;
    audit;
    cascade_summaries;
    force_liquidations;
    stale_holds;
    final_prices =
      _final_prices_for_held_symbols ~final_portfolio ~final_close_prices;
    universe = deps.universe;
  }

let run_backtest ~start_date ~end_date ?(overrides = []) ?sector_map_override
    ?(strategy_choice = Strategy_choice.default) ?trace ?gc_trace
    ?bar_data_source ?shared_panels ?progress_emitter ?slippage_bps ?cost_model
    () =
  let deps = _load_deps ?trace ?gc_trace ~overrides ~sector_map_override () in
  let warmup_days = _warmup_days_for strategy_choice in
  let warmup_start = Date.add_days start_date (-warmup_days) in
  _log_backtest_window ~start_date ~end_date ~warmup_start
    ~all_symbols:deps.all_symbols;
  let ( sim_result,
        stop_log,
        trade_audit,
        force_liquidation_log,
        stale_hold_log,
        final_close_prices ) =
    _run_panel_backtest ~deps ~start_date ~end_date ~warmup_days
      ~strategy_choice ?trace ?gc_trace ?bar_data_source ?shared_panels
      ?progress_emitter ?slippage_bps ?cost_model ()
  in
  Gc_trace.record ?trace:gc_trace ~phase:"fill_done" ();
  _assemble_result ~start_date ~end_date ~deps ~overrides ~sim_result ~stop_log
    ~trade_audit ~force_liquidation_log ~stale_hold_log ~final_close_prices
    ?trace ?gc_trace ()
