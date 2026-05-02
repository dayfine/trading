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

let _build_strategy (input : input) ~bar_panels ~ohlcv ~indicators ~calendar
    ~audit_recorder =
  (* The inner Weinstein strategy reads OHLCV bars from
     {!Data_panel.Bar_panels} (populated up-front from CSV at runner start).
     Stage 3 PR-C deleted the Tiered tier system + parallel [Bar_history]
     cache; the strategy is wrapped only by [Panel_strategy_wrapper], which
     advances the indicator panels per tick and substitutes a panel-backed
     [get_indicator_fn]. *)
  let inner_strategy =
    Weinstein_strategy.make ~ad_bars:input.ad_bars
      ~ticker_sectors:input.ticker_sectors ~bar_panels ~audit_recorder
      input.config
  in
  let panel_config : Panel_strategy_wrapper.config =
    {
      ohlcv;
      indicators;
      calendar;
      primary_index = input.config.indices.primary;
    }
  in
  Panel_strategy_wrapper.wrap ~config:panel_config inner_strategy

(* LRU cap for the snapshot cache. Generous for the typical small-universe
   parity test (a few symbols × a few hundred days = handful of MB) and roomy
   for a five-year sp500 golden (universe size in the hundreds × ~1.3K days
   ≈ tens of MB). Tier-4 spike scenarios (large universes) will need a larger
   cap when Phase E lands; for Phase D this is hard-coded since the only
   consumer is the parity gate. *)
let _snapshot_cache_mb = 256

let _build_market_data_adapter ~data_dir ?bar_data_source () =
  let source = Option.value bar_data_source ~default:Bar_data_source.Csv in
  match
    Bar_data_source.build_adapter source ~data_dir
      ~max_cache_mb:_snapshot_cache_mb
  with
  | Ok adapter -> adapter
  | Error err ->
      failwithf "Panel_runner: Bar_data_source.build_adapter failed: %s"
        (Status.show err) ()

let _make_simulator (input : input) ~stop_log ~audit_recorder ~start_date
    ~end_date ~warmup_days ~initial_cash ~commission ~ohlcv ~indicators
    ~calendar ~bar_panels ~market_data_adapter =
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let strategy =
    _build_strategy input ~bar_panels ~ohlcv ~indicators ~calendar
      ~audit_recorder
  in
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
    outcome. Returns [`Done r] when the simulator completes, or [`Continue sim']
    with the next simulator state. *)
let _step_loop_iter ?gc_trace ~date sim =
  match _step_with_gc_trace ?gc_trace ~date sim with
  | Error e -> _step_failed e
  | Ok (Simulator.Completed result) -> `Done result
  | Ok (Simulator.Stepped (sim', _step_result)) -> `Continue sim'

(** Step-loop replacement for [Simulator.run] that snapshots [Gc.stat] before
    and after each [Simulator.step] call. One step = one calendar day in the
    [Daily] cadence used by the panel runner = one [Engine.update_market] call
    (the dominant per-tick allocator per the post-PR-A memtrace).

    When [gc_trace = None] the loop is functionally identical to [Simulator.run]
    modulo one [Option.is_some] check per step.

    [pending_date] is tracked locally in lockstep with the simulator's internal
    [current_date] so the [_before] snapshot can be labeled with the step's date
    *before* [Simulator.step] is invoked. *)
let _run_simulator_with_gc_trace ?gc_trace ~stop_log sim =
  let start_date = (Simulator.get_config sim).start_date in
  let rec loop sim ~pending_date =
    (* Stamp [pending_date] on [stop_log] so any [EntryComplete] transition
       observed by the strategy wrapper during this step records the correct
       entry_date. The runner reads this back at teardown to drop stop_infos
       for positions opened during the warmup window. *)
    Stop_log.set_current_date stop_log pending_date;
    match _step_loop_iter ?gc_trace ~date:pending_date sim with
    | `Done result -> result
    | `Continue sim' -> loop sim' ~pending_date:(Date.add_days pending_date 1)
  in
  loop sim ~pending_date:start_date

(** Snapshot of close prices on the final calendar column. Iterates the universe
    via [Symbol_index.symbols] and reads cell [(row, n_days - 1)] of
    [Ohlcv_panels.close]. Symbols whose final cell is NaN (no bar that day —
    weekend, holiday, suspended, or pre-IPO) are dropped. Empty result when
    [n_days = 0]. The runner filters this alist to held symbols when populating
    [Runner.result.final_prices]. *)
let _final_close_prices ~ohlcv =
  let n_days = Ohlcv_panels.n_days ohlcv in
  if n_days <= 0 then []
  else
    let last_col = n_days - 1 in
    let close_panel = Ohlcv_panels.close ohlcv in
    let symbol_index = Ohlcv_panels.symbol_index ohlcv in
    let symbols = Symbol_index.symbols symbol_index in
    List.filter_mapi symbols ~f:(fun row symbol ->
        let v = close_panel.{row, last_col} in
        if Float.is_nan v then None else Some (symbol, v))

let run ~(input : input) ~start_date ~end_date ~warmup_days ~initial_cash
    ~commission ?trace ?gc_trace ?bar_data_source () =
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
  let trade_audit = Trade_audit.create () in
  let force_liquidation_log = Force_liquidation_log.create () in
  let audit_recorder =
    Trade_audit_recorder.of_collector ~trade_audit ~force_liquidation_log
  in
  let n_all_symbols = List.length input.all_symbols in
  let market_data_adapter =
    _build_market_data_adapter ~data_dir:input.data_dir_fpath ?bar_data_source
      ()
  in
  let sim =
    _make_simulator input ~stop_log ~audit_recorder ~start_date ~end_date
      ~warmup_days ~initial_cash ~commission ~ohlcv ~indicators ~calendar
      ~bar_panels ~market_data_adapter
  in
  let sim_result =
    Trace.record ?trace ~symbols_in:n_all_symbols Trace.Phase.Fill (fun () ->
        _run_simulator_with_gc_trace ?gc_trace ~stop_log sim)
  in
  let final_close_prices = _final_close_prices ~ohlcv in
  (sim_result, stop_log, trade_audit, force_liquidation_log, final_close_prices)
