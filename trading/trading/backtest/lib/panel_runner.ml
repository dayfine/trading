(** Panel-loader execution path — see [panel_runner.mli]. *)

open Core
open Trading_simulation
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Bar_panels = Data_panel.Bar_panels
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

(* LRU cap for the snapshot cache. Sized so a tier-3 sp500 run at a long
   horizon fits resident; tier-4 release gates plumb this through
   [Runner.config] when they land. Memory budget is best-effort — a single
   oversized symbol stays resident even when its bytes exceed the cap. *)
let _snapshot_cache_mb = 1024

let _build_strategy (input : input) ~bar_reader ~audit_recorder =
  Weinstein_strategy.make ~ad_bars:input.ad_bars
    ~ticker_sectors:input.ticker_sectors ~bar_reader ~audit_recorder
    input.config

let _build_market_data_adapter ~data_dir ~bar_data_source =
  match
    Bar_data_source.build_adapter bar_data_source ~data_dir
      ~max_cache_mb:_snapshot_cache_mb
  with
  | Ok adapter -> adapter
  | Error err ->
      failwithf "Panel_runner: Bar_data_source.build_adapter failed: %s"
        (Status.show err) ()

let _make_simulator (input : input) ~stop_log ~start_date ~end_date ~warmup_days
    ~initial_cash ~commission ~strategy ~market_data_adapter =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let strategy = Strategy_wrapper.wrap ~stop_log strategy in
  let sim_deps =
    Simulator.create_deps ~symbols:input.all_symbols
      ~data_dir:input.data_dir_fpath ~strategy ~commission
      ~metric_suite:(Metric_computers.default_metric_suite ~initial_cash ())
      ~market_data_adapter ()
  in
  let sim_config =
    Simulator.
      {
        start_date = warmup_start;
        end_date;
        initial_cash;
        commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  match Simulator.create ~config:sim_config ~deps:sim_deps with
  | Ok s -> s
  | Error e ->
      failwith
        (sprintf "Backtest.Panel_runner: failed to create simulator: %s"
           (Status.show e))

(** Phase label for one step boundary. The date is the step-about-to-execute's
    date so a CSV consumer can pair [_before] and [_after] rows on it. *)
let _step_phase ~date ~boundary =
  sprintf "step_%s_%s" (Date.to_string date) boundary

(** One step iteration: snapshot [_before], call [Simulator.step], snapshot
    [_after], return either the final result or the next simulator state. *)
let _step_with_gc_trace ?gc_trace ~date sim =
  Gc_trace.record ?trace:gc_trace
    ~phase:(_step_phase ~date ~boundary:"before")
    ();
  let outcome = Simulator.step sim in
  Gc_trace.record ?trace:gc_trace
    ~phase:(_step_phase ~date ~boundary:"after")
    ();
  outcome

let _step_failed e =
  failwith
    (sprintf "Backtest.Panel_runner: simulation failed: %s" (Status.show e))

(** One iteration of the step loop: snapshot before/after, dispatch on the
    outcome. Returns [`Done r] when the simulator completes, or
    [`Continue (sim', step_result)] with the next simulator state plus the
    per-step result (used to advance progress counters). *)
let _step_loop_iter ?gc_trace ~date sim =
  match _step_with_gc_trace ?gc_trace ~date sim with
  | Error e -> _step_failed e
  | Ok (Simulator.Completed result) -> `Done result
  | Ok (Simulator.Stepped (sim', step_result)) -> `Continue (sim', step_result)

(** Build a progress accumulator from the optional emitter. Extracted so the
    [run] entry-point keeps low nesting. *)
let _build_progress_acc ~progress_emitter ~warmup_start ~end_date =
  match progress_emitter with
  | None -> None
  | Some emitter ->
      let cycles_total =
        Backtest_progress.count_fridays_in_range ~start_date:warmup_start
          ~end_date
      in
      Some (Backtest_progress.create_accumulator ~cycles_total ~emitter ())

(** Forward a completed step into [progress_acc]. Pulled out of the step loop so
    the recursive [loop] body keeps low nesting. *)
let _record_step_into_progress ~progress_acc ~date
    ~(step_result : Trading_simulation_types.Simulator_types.step_result) =
  match progress_acc with
  | None -> ()
  | Some acc ->
      Backtest_progress.record_step acc ~date
        ~trades_added:(List.length step_result.trades)
        ~portfolio_value:step_result.portfolio_value

(** Step-loop replacement for [Simulator.run] that snapshots [Gc.stat] before
    and after each [Simulator.step] call. [pending_date] is tracked locally in
    lockstep with the simulator's internal [current_date] so the [_before]
    snapshot is labeled with the step's date *before* [Simulator.step] is
    invoked. [progress_acc], when passed, has [Backtest_progress.record_step]
    invoked after every completed step; the caller is responsible for the final
    {!Backtest_progress.emit_final} call after the loop returns. *)
let _run_simulator_with_gc_trace ?gc_trace ?progress_acc ~stop_log sim =
  let start_date = (Simulator.get_config sim).start_date in
  let rec loop sim ~pending_date =
    Stop_log.set_current_date stop_log pending_date;
    match _step_loop_iter ?gc_trace ~date:pending_date sim with
    | `Done result -> result
    | `Continue (sim', step_result) ->
        _record_step_into_progress ~progress_acc ~date:pending_date ~step_result;
        loop sim' ~pending_date:(Date.add_days pending_date 1)
  in
  loop sim ~pending_date:start_date

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

(* Resolve the [(snapshot_dir, manifest)] pair the simulator will read through
   for per-tick price reads + final-close lookups. CSV mode delegates to
   [Csv_snapshot_builder.build]; Snapshot mode reuses the caller-provided
   directory. The strategy's bar reads do NOT flow through this snapshot —
   see [_build_panel_bar_reader] for the panel-backed strategy reader. *)
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
   panel cells stay NaN on holidays. Used for the strategy's [Bar_panels.t]
   build. *)
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

(* Build OHLCV panels from CSV using the calendar-aware loader. The universe is
   exactly [input.all_symbols] so the panel covers every symbol the simulator
   will fetch bars for (universe + index + sector ETFs + global indices). This
   is the strategy's bar source; the simulator's per-tick reads still flow
   through the snapshot adapter. See module-doc for the partial-revert
   rationale. *)
let _build_ohlcv ~(input : input) ~calendar =
  let symbol_index =
    match Symbol_index.create ~universe:input.all_symbols with
    | Ok t -> t
    | Error err ->
        failwithf "Panel_runner: Symbol_index.create failed: %s"
          err.Status.message ()
  in
  match
    Ohlcv_panels.load_from_csv_calendar symbol_index
      ~data_dir:input.data_dir_fpath ~calendar
  with
  | Ok t -> t
  | Error err ->
      failwithf "Panel_runner: Ohlcv_panels.load_from_csv_calendar failed: %s"
        (Status.show err) ()

(* Build a panel-backed [Bar_reader.t] for the strategy: load OHLCV from CSV
   on [calendar], wrap in a [Bar_panels.t], wrap in a [Bar_reader]. This is
   the partial-revert path; the strategy's reads route through the panel
   backing rather than [Snapshot_callbacks] until the forward fix lands. *)
let _build_panel_bar_reader (input : input) ~warmup_start ~end_date =
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  let ohlcv = _build_ohlcv ~input ~calendar in
  let bar_panels =
    match Bar_panels.create ~ohlcv ~calendar with
    | Ok p -> p
    | Error err ->
        failwithf "Panel_runner: Bar_panels.create failed: %s" (Status.show err)
          ()
  in
  eprintf "Panel_runner: panels built (%d symbols × %d days) for strategy\n%!"
    (Ohlcv_panels.n ohlcv) (Array.length calendar);
  Weinstein_strategy.Bar_reader.of_panels bar_panels

(* Hybrid setup: panel-backed strategy bar reader, snapshot-backed simulator
   adapter, snapshot-backed final-close lookup. See module-doc. *)
let _setup_hybrid (input : input) ~snapshot_dir ~manifest ~warmup_start
    ~end_date ~audit_recorder =
  let daily_panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest
        ~max_cache_mb:_snapshot_cache_mb
    with
    | Ok p -> p
    | Error err ->
        failwithf "Panel_runner: Daily_panels.create failed: %s"
          (Status.show err) ()
  in
  let bar_reader = _build_panel_bar_reader input ~warmup_start ~end_date in
  let strategy = _build_strategy input ~bar_reader ~audit_recorder in
  let adapter =
    _build_market_data_adapter ~data_dir:input.data_dir_fpath
      ~bar_data_source:(Bar_data_source.Snapshot { snapshot_dir; manifest })
  in
  let final_close_prices () =
    _final_close_prices ~daily_panels ~symbols:input.all_symbols ~end_date
  in
  (strategy, adapter, final_close_prices)

let run ~(input : input) ~start_date ~end_date ~warmup_days ~initial_cash
    ~commission ?trace ?gc_trace ?bar_data_source ?progress_emitter () =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf "Panel_runner: simulator window %s..%s (warmup %d days)\n%!"
    (Date.to_string warmup_start)
    (Date.to_string end_date) warmup_days;
  let stop_log = Stop_log.create () in
  let trade_audit = Trade_audit.create () in
  let force_liquidation_log = Force_liquidation_log.create () in
  let audit_recorder =
    Trade_audit_recorder.of_collector ~trade_audit ~force_liquidation_log
  in
  let n_all_symbols = List.length input.all_symbols in
  let snapshot_dir, manifest =
    _resolve_snapshot_source input ~warmup_start ~end_date ~bar_data_source
  in
  let strategy, market_data_adapter, final_close_prices_thunk =
    _setup_hybrid input ~snapshot_dir ~manifest ~warmup_start ~end_date
      ~audit_recorder
  in
  let sim =
    _make_simulator input ~stop_log ~start_date ~end_date ~warmup_days
      ~initial_cash ~commission ~strategy ~market_data_adapter
  in
  let progress_acc =
    _build_progress_acc ~progress_emitter ~warmup_start ~end_date
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        _run_simulator_with_gc_trace ?gc_trace ?progress_acc ~stop_log sim)
  in
  Option.iter progress_acc ~f:Backtest_progress.emit_final;
  let final_close_prices = final_close_prices_thunk () in
  (sim_result, stop_log, trade_audit, force_liquidation_log, final_close_prices)
