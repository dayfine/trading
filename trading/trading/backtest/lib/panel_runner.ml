(** Panel-loader execution path — see [panel_runner.mli]. *)

open Core
open Trading_simulation
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Bar_panels = Data_panel.Bar_panels
module Indicator_panels = Data_panel.Indicator_panels
module Indicator_spec = Data_panel.Indicator_spec

type input = {
  data_dir_fpath : Fpath.t;
  ticker_sectors : (string, string) Hashtbl.t;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

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
let _build_ohlcv ~(input : input) ~calendar =
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

let _build_strategy (input : input) ~bar_panels ~ohlcv ~indicators ~calendar =
  (* The inner Weinstein strategy reads OHLCV bars from
     {!Data_panel.Bar_panels} (populated up-front from CSV at runner start).
     Stage 3 PR-C deleted the Tiered tier system + parallel [Bar_history]
     cache; the strategy is wrapped only by [Panel_strategy_wrapper], which
     advances the indicator panels per tick and substitutes a panel-backed
     [get_indicator_fn]. *)
  let inner_strategy =
    Weinstein_strategy.make ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors ~bar_panels input.config
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
  Panel_strategy_wrapper.wrap ~config:panel_config inner_strategy

let _make_simulator (input : input) ~stop_log ~start_date ~end_date ~warmup_days
    ~initial_cash ~commission ~ohlcv ~indicators ~calendar ~bar_panels =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let strategy =
    _build_strategy input ~bar_panels ~ohlcv ~indicators ~calendar
  in
  let strategy = Strategy_wrapper.wrap ~stop_log strategy in
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

let run ~(input : input) ~start_date ~end_date ~warmup_days ~initial_cash
    ~commission ?trace () =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let calendar = _build_calendar ~start:warmup_start ~end_:end_date in
  let n_days = Array.length calendar in
  eprintf "Panel_runner: calendar has %d trading days (%s..%s)\n%!" n_days
    (Date.to_string warmup_start)
    (Date.to_string end_date);
  let ohlcv = _build_ohlcv ~input ~calendar in
  let indicators = _build_indicators ~ohlcv ~n_days in
  let bar_panels =
    match Bar_panels.create ~ohlcv ~calendar with
    | Ok p -> p
    | Error err ->
        failwithf "Panel_runner: Bar_panels.create failed: %s" (Status.show err)
          ()
  in
  eprintf
    "Panel_runner: panels built (%d symbols × %d days, %d indicator specs)\n%!"
    (Ohlcv_panels.n ohlcv) n_days
    (List.length _default_specs);
  let stop_log = Stop_log.create () in
  let n_all_symbols = List.length input.all_symbols in
  let sim =
    _make_simulator input ~stop_log ~start_date ~end_date ~warmup_days
      ~initial_cash ~commission ~ohlcv ~indicators ~calendar ~bar_panels
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        _run_simulator sim)
  in
  (sim_result, stop_log)
