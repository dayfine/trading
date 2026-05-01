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

(** Number of calendar days to prepend for 30-week MA warmup. *)
let warmup_days = 210

(* Public types *)

type result = {
  summary : Summary.t;
  round_trips : Metrics.trade_metrics list;
  steps : Trading_simulation_types.Simulator_types.step_result list;
  overrides : Sexp.t list;
  stop_infos : Stop_log.stop_info list;
  audit : Trade_audit.audit_record list;
  cascade_summaries : Trade_audit.cascade_summary list;
  force_liquidations : Portfolio_risk.Force_liquidation.event list;
  final_prices : (string * float) list;
}

(* Trading-day filter *)

(** True if [step] represents a real trading day. On non-trading days (weekends,
    holidays) the simulator has no price bars and reports
    [portfolio_value = cash] even when positions are open.

    Important: this heuristic exists only for mark-to-market aware consumers
    such as [OpenPositionsValue] / [UnrealizedPnl]. It must NOT be applied to
    round-trip extraction — round-trips are derived from position-state
    transitions (fills), which are recorded independently of whether the
    portfolio's mark-to-market view is populated that day. Applying this filter
    before [Metrics.extract_round_trips] silently drops every trade whose entry
    *and* exit landed on steps where [portfolio_value ~ cash], which happens for
    instance when the only non-[Holding] positions are [Entering]/[Closed] (they
    contribute 0.0 to [Portfolio_view.portfolio_value]). *)
let is_trading_day (step : Trading_simulation_types.Simulator_types.step_result)
    =
  let has_positions =
    not (List.is_empty step.portfolio.Trading_portfolio.Portfolio.positions)
  in
  if has_positions then
    let cash = step.portfolio.Trading_portfolio.Portfolio.current_cash in
    Float.(abs (step.portfolio_value -. cash) > 1e-2)
  else true

(* Config overrides via sexp deep-merge *)

let _is_record fields =
  List.for_all fields ~f:(function
    | Sexp.List [ Sexp.Atom _; _ ] -> true
    | _ -> false)

let rec _merge_sexp base overlay =
  match (base, overlay) with
  | Sexp.List base_fields, Sexp.List overlay_fields
    when _is_record base_fields && _is_record overlay_fields ->
      _merge_records base_fields overlay_fields
  | _, _ -> overlay

and _merge_records base_fields overlay_fields =
  let overlay_map =
    List.filter_map overlay_fields ~f:(function
      | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
      | _ -> None)
    |> String.Map.of_alist_exn
  in
  Sexp.List
    (List.map base_fields ~f:(function
      | Sexp.List [ Sexp.Atom k; v ] as pair -> (
          match Map.find overlay_map k with
          | Some overlay_v -> Sexp.List [ Sexp.Atom k; _merge_sexp v overlay_v ]
          | None -> pair)
      | other -> other))

let _apply_overrides (config : Weinstein_strategy.config) overrides =
  match overrides with
  | [] -> config
  | _ ->
      let base = Weinstein_strategy.sexp_of_config config in
      let merged = List.fold overrides ~init:base ~f:_merge_sexp in
      Weinstein_strategy.config_of_sexp merged

(* Dependency loading *)

type _deps = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
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

let _run_panel_backtest ~deps ~start_date ~end_date ?trace ?gc_trace () =
  Panel_runner.run
    ~input:(_panel_input_of_deps deps)
    ~start_date ~end_date ~warmup_days ~initial_cash ~commission ?trace
    ?gc_trace ()

(** Re-run the step-based metric computers ([SharpeRatio], [MaxDrawdown],
    [CAGR]) on the in-window step list with a config whose [start_date] is the
    actual run start (not the warmup_start the simulator was created with). The
    simulator computed these metrics across [warmup_start..end_date], which
    folds the warmup window's drawdown, return volatility, and total return into
    the published values; this overlay restores the metrics' values to "what
    happened during the measurement window only". *)
let _recompute_in_window_step_metrics ~steps_in_range ~start_date ~end_date =
  let config : Trading_simulation_types.Simulator_types.config =
    {
      start_date;
      end_date;
      initial_cash;
      commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let computers =
    [
      Metric_computers.sharpe_ratio_computer ();
      Metric_computers.max_drawdown_computer ();
      Metric_computers.cagr_computer ();
    ]
  in
  List.fold computers ~init:Trading_simulation_types.Metric_types.empty
    ~f:(fun acc c ->
      Trading_simulation_types.Metric_types.merge acc
        (c.run ~config ~steps:steps_in_range))

(** Recompute [CalmarRatio = CAGR / MaxDrawdown] from already-overlaid
    [base_metrics]. The simulator emits [CalmarRatio] from the
    [calmar_ratio_derived] computer using its own warmup-inclusive CAGR /
    MaxDrawdown; once the overlay has replaced those with in-window values, the
    published [CalmarRatio] must follow or the ratio is inconsistent with its
    components. *)
let _recompute_calmar_ratio ~base_metrics =
  let dummy_config : Trading_simulation_types.Simulator_types.config =
    {
      start_date = Date.create_exn ~y:2000 ~m:Month.Jan ~d:1;
      end_date = Date.create_exn ~y:2000 ~m:Month.Jan ~d:1;
      initial_cash;
      commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  Metric_computers.calmar_ratio_derived.compute ~config:dummy_config
    ~base_metrics

(** Three-stage overlay applied to the simulator's metric set:

    1. Replace round-trip-derived metrics ([TotalPnl], [AvgHoldingDays],
    [WinCount], [LossCount], [WinRate], [ProfitFactor]) with values computed
    from the runner's range-filtered [round_trips] — observed empirically on
    [panel-golden-2019-full] (sim says 3 wins; runner round_trips says 2 wins;
    trades.csv shows 2; the overlay aligns the summary to trades.csv).

    2. Replace step-based metrics ([SharpeRatio], [MaxDrawdown], [CAGR]) with
    values recomputed on [steps_in_range] (the in-window step list only) —
    without this, warmup-window drawdown / return / volatility inflate the
    published values vs. what actually happened in the run.

    3. Recompute [CalmarRatio] from the overlaid CAGR / MaxDrawdown so the
    derived metric stays consistent with its components.

    The simulator runs from [warmup_start] (not [start_date]) so all three of
    its metric flavors (round-trip, step-based, and derived) include the warmup
    window. The overlay restores the invariant that the published metrics
    describe the measurement window only. *)
let _align_summary_metrics ~sim_result ~round_trips ~steps_in_range ~start_date
    ~end_date =
  let merge = Trading_simulation_types.Metric_types.merge in
  let after_round_trips =
    merge sim_result.Trading_simulation_types.Simulator_types.metrics
      (Metrics.compute_round_trip_metric_set round_trips)
  in
  let after_step =
    merge after_round_trips
      (_recompute_in_window_step_metrics ~steps_in_range ~start_date ~end_date)
  in
  merge after_step (_recompute_calmar_ratio ~base_metrics:after_step)

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
    ~final_value ~round_trips ~sim_result : Summary.t =
  {
    start_date;
    end_date;
    universe_size = deps.universe_size;
    n_steps = List.length steps;
    initial_cash;
    final_portfolio_value = final_value;
    n_round_trips = List.length round_trips;
    metrics =
      _align_summary_metrics ~sim_result ~round_trips ~steps_in_range
        ~start_date ~end_date;
  }

(** Filter [final_close_prices] to symbols that are still held in the last
    step's portfolio. Empty result when [steps] is empty or no positions are
    open. The reconciler only references [final_prices.csv] via the join key
    against [open_positions.csv], so prices for never-held or already-closed
    symbols are not needed and would just bloat the artefact. *)
let _final_prices_for_held_symbols ~steps ~final_close_prices =
  match List.last steps with
  | None -> []
  | Some last_step ->
      let open Trading_simulation_types.Simulator_types in
      let held =
        last_step.portfolio.Trading_portfolio.Portfolio.positions
        |> List.map ~f:(fun (p : Trading_portfolio.Types.portfolio_position) ->
            p.symbol)
        |> String.Set.of_list
      in
      List.filter final_close_prices ~f:(fun (sym, _) -> Set.mem held sym)

let run_backtest ~start_date ~end_date ?(overrides = []) ?sector_map_override
    ?trace ?gc_trace () =
  let deps = _load_deps ?trace ?gc_trace ~overrides ~sector_map_override () in
  eprintf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length deps.all_symbols);
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf "Running backtest (%s to %s, warmup from %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date)
    (Date.to_string warmup_start);
  let ( sim_result,
        stop_log,
        trade_audit,
        force_liquidation_log,
        final_close_prices ) =
    _run_panel_backtest ~deps ~start_date ~end_date ?trace ?gc_trace ()
  in
  Gc_trace.record ?trace:gc_trace ~phase:"fill_done" ();
  (* Steps in the requested date range, all days included. Round-trip
     extraction derives trades from position-state transitions recorded on
     these steps, so it must see *every* step where a trade fill happened —
     including days the [is_trading_day] mark-to-market heuristic would
     otherwise discard. *)
  let steps_in_range =
    List.filter sim_result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date)
  in
  (* Steps on real trading days only — used for [OpenPositionsValue] /
     [UnrealizedPnl] consumers and
     anything else that needs a meaningful mark-to-market portfolio value.
     Simulator reports [portfolio_value = cash] on weekends/holidays even
     when positions are open, so filter them out before mark-to-market
     consumers use the series. *)
  let steps = List.filter steps_in_range ~f:is_trading_day in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips, stop_infos, audit, cascade_summaries, force_liquidations =
    Trace.record ?trace Trace.Phase.Teardown (fun () ->
        ( Metrics.extract_round_trips steps_in_range,
          filter_stop_infos_in_window
            (Stop_log.get_stop_infos stop_log)
            ~start_date,
          filter_audit_records_in_window
            (Trade_audit.get_audit_records trade_audit)
            ~start_date,
          filter_cascade_summaries_in_window
            (Trade_audit.get_cascade_summaries trade_audit)
            ~start_date,
          filter_force_liquidations_in_window
            (Force_liquidation_log.events force_liquidation_log)
            ~start_date ))
  in
  Gc_trace.record ?trace:gc_trace ~phase:"teardown_done" ();
  let summary =
    _make_summary ~start_date ~end_date ~deps ~steps_in_range ~steps
      ~final_value ~round_trips ~sim_result
  in
  let final_prices =
    _final_prices_for_held_symbols ~steps ~final_close_prices
  in
  {
    summary;
    round_trips;
    steps;
    overrides;
    stop_infos;
    audit;
    cascade_summaries;
    force_liquidations;
    final_prices;
  }
