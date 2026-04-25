(** Panel-loader execution path — see [panel_runner.mli]. *)

open Core
open Trading_simulation
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Indicator_panels = Data_panel.Indicator_panels
module Indicator_spec = Data_panel.Indicator_spec
module Bar_history = Weinstein_strategy.Bar_history

(* Stage 1 default indicator specs. Daily cadence only; weekly cadence and
   additional indicators (Stage, Volume, Resistance, RS) land in Stage 4. *)
let _default_specs : Indicator_spec.t list =
  [
    { name = "EMA"; period = 50; cadence = Daily };
    { name = "SMA"; period = 50; cadence = Daily };
    { name = "ATR"; period = 14; cadence = Daily };
    { name = "RSI"; period = 14; cadence = Daily };
  ]

(* Generate the trading-day calendar: every weekday (Mon–Fri) in the inclusive
   range [start..end_]. Holidays are not removed — the simulator already
   tolerates "no bar on this day" via the [is_trading_day] filter, and the
   panel cells stay NaN on holidays. *)
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
   will fetch bars for (universe + index + sector ETFs + global indices). *)
let _build_ohlcv ~(input : Tiered_runner.input) ~calendar =
  let symbols = input.all_symbols in
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
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

let _build_indicators ~ohlcv ~n_days =
  let symbol_index = Ohlcv_panels.symbol_index ohlcv in
  Indicator_panels.create ~symbol_index ~n_days ~specs:_default_specs

let _build_strategy (input : Tiered_runner.input) ~loader ~stop_log ~bar_history
    ~warmup_start ~ohlcv ~indicators ~calendar =
  let inner_strategy =
    Weinstein_strategy.make ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors ~bar_history input.config
  in
  let always_loaded =
    String.Set.of_list
      ((input.config.indices.primary :: List.map input.config.sector_etfs ~f:fst)
      @ List.map input.config.indices.global ~f:fst)
  in
  let tiered_config : Tiered_strategy_wrapper.config =
    {
      bar_loader = loader;
      bar_history;
      universe = input.all_symbols;
      always_loaded_symbols = always_loaded;
      seed_warmup_start = warmup_start;
      stop_log;
      primary_index = input.config.indices.primary;
    }
  in
  let tiered_strategy =
    Tiered_strategy_wrapper.wrap ~config:tiered_config inner_strategy
  in
  let panel_config : Panel_strategy_wrapper.config =
    {
      ohlcv;
      indicators;
      calendar;
      primary_index = input.config.indices.primary;
      universe = input.all_symbols;
    }
  in
  Panel_strategy_wrapper.wrap ~config:panel_config tiered_strategy

let _make_simulator (input : Tiered_runner.input) ~loader ~stop_log ~start_date
    ~end_date ~warmup_days ~initial_cash ~commission ~ohlcv ~indicators
    ~calendar =
  let bar_history = Bar_history.create () in
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let strategy =
    _build_strategy input ~loader ~stop_log ~bar_history ~warmup_start ~ohlcv
      ~indicators ~calendar
  in
  let sim_deps =
    Simulator.create_deps ~symbols:input.all_symbols
      ~data_dir:input.data_dir_fpath ~strategy ~commission
      ~metric_suite:(Metric_computers.default_metric_suite ())
      ()
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

let _run_simulator sim =
  match Simulator.run sim with
  | Ok r -> r
  | Error e ->
      failwith
        (sprintf "Backtest.Panel_runner: simulation failed: %s" (Status.show e))

(* Bar_loader creation mirrors [Tiered_runner._create_bar_loader] (which is
   private). Inlined here to avoid widening Tiered_runner's surface. The
   trace_hook is omitted in this stage — Panel mode does not yet emit
   Promote_summary / Promote_full / Demote phase records (the Tiered wrapper
   does, via [Bar_loader.create ~trace_hook]). When trace fidelity becomes
   a concern, factor [_create_bar_loader] out into a shared helper. *)
let _create_loader (input : Tiered_runner.input) =
  let full_config =
    match input.config.full_compute_tail_days with
    | None -> Bar_loader.Full_compute.default_config
    | Some n -> { Bar_loader.Full_compute.tail_days = n }
  in
  Bar_loader.create ~data_dir:input.data_dir_fpath
    ~sector_map:input.ticker_sectors ~universe:input.all_symbols
    ~benchmark_symbol:input.config.indices.primary ~full_config ()

let run ~(input : Tiered_runner.input) ~start_date ~end_date ~warmup_days
    ~initial_cash ~commission ?trace () =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  let n_days = Array.length calendar in
  eprintf "Panel_runner: calendar has %d trading days (%s..%s)\n%!" n_days
    (Date.to_string warmup_start)
    (Date.to_string end_date);
  let ohlcv = _build_ohlcv ~input ~calendar in
  let indicators = _build_indicators ~ohlcv ~n_days in
  eprintf
    "Panel_runner: panels built (%d symbols × %d days, %d indicator specs)\n%!"
    (Ohlcv_panels.n ohlcv) n_days
    (List.length _default_specs);
  let loader = _create_loader input in
  let as_of = end_date in
  let n_all_symbols = List.length input.all_symbols in
  Tiered_runner.promote_universe_metadata ?trace loader input ~as_of;
  let stop_log = Stop_log.create () in
  let sim =
    _make_simulator input ~loader ~stop_log ~start_date ~end_date ~warmup_days
      ~initial_cash ~commission ~ohlcv ~indicators ~calendar
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        _run_simulator sim)
  in
  (sim_result, stop_log)
