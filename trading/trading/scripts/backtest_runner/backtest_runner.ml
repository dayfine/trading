(** Backtest runner CLI — runs the Weinstein strategy over the full universe and
    writes structured output (params, summary, trades, equity curve).

    Usage:
    - backtest_runner <start_date> [end_date]
    - backtest_runner --smoke
    - backtest_runner --scenarios <path> *)

open Core
open Trading_simulation

(* ------------------------------------------------------------------ *)
(* Configuration constants                                             *)
(* ------------------------------------------------------------------ *)

let index_symbol = "GSPC.INDX"
let initial_cash = 1_000_000.0
let commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
let warmup_days = 210

(* ------------------------------------------------------------------ *)
(* Scenario parsing                                                    *)
(* ------------------------------------------------------------------ *)

type scenario = { name : string; start_date : Date.t; end_date : Date.t }

let _find_field fields key =
  List.find_map fields ~f:(function
    | Sexp.List [ Sexp.Atom k; Sexp.Atom v ] when String.equal k key -> Some v
    | _ -> None)

let _build_scenario ~name ~sd ~ed =
  { name; start_date = Date.of_string sd; end_date = Date.of_string ed }

let _parse_scenario_fields fields =
  match
    ( _find_field fields "name",
      _find_field fields "start_date",
      _find_field fields "end_date" )
  with
  | Some name, Some sd, Some ed -> Some (_build_scenario ~name ~sd ~ed)
  | _ -> None

let _parse_scenario = function
  | Sexp.List fields -> _parse_scenario_fields fields
  | _ -> None

let _load_scenarios path =
  let sexp = Sexp.load_sexp path in
  match sexp with
  | Sexp.List [ Sexp.List (Sexp.Atom "scenarios" :: scenario_sexps) ] ->
      List.filter_map scenario_sexps ~f:_parse_scenario
  | _ -> failwith ("Cannot parse scenarios file: " ^ path)

let _default_scenarios_path data_dir_fpath =
  Fpath.parent data_dir_fpath |> Fpath.to_string |> fun root ->
  root ^ "dev/backtest/smoke-scenarios.sexp"

(* ------------------------------------------------------------------ *)
(* CLI parsing                                                         *)
(* ------------------------------------------------------------------ *)

type run_mode =
  | Single of { start_date : Date.t; end_date : Date.t }
  | Scenarios of string

let _parse_args () =
  let argv = Sys.get_argv () in
  if Array.length argv < 2 then (
    eprintf "Usage: backtest_runner <start_date> [end_date]\n";
    eprintf "       backtest_runner --smoke\n";
    eprintf "       backtest_runner --scenarios <path>\n";
    Stdlib.exit 1);
  match argv.(1) with
  | "--smoke" -> Scenarios "smoke"
  | "--scenarios" ->
      if Array.length argv < 3 then (
        eprintf "Error: --scenarios requires a path\n";
        Stdlib.exit 1);
      Scenarios argv.(2)
  | start_str ->
      let start_date = Date.of_string start_str in
      let end_date =
        if Array.length argv > 2 then Date.of_string argv.(2)
        else Date.today ~zone:Time_float.Zone.utc
      in
      Single { start_date; end_date }

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

let _code_version () =
  try
    let ic = Core_unix.open_process_in "git rev-parse HEAD" in
    let line = In_channel.input_line ic in
    let _ = Core_unix.close_process_in ic in
    Option.value line ~default:"unknown"
  with _ -> "unknown"

let _is_trading_day
    (step : Trading_simulation_types.Simulator_types.step_result) =
  let has_positions =
    not (List.is_empty step.portfolio.Trading_portfolio.Portfolio.positions)
  in
  if has_positions then
    let cash = step.portfolio.Trading_portfolio.Portfolio.current_cash in
    Float.(abs (step.portfolio_value -. cash) > 1e-2)
  else true

let _make_output_dir ~data_dir_fpath ~subdir =
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let ts =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let path = repo_root ^ "dev/backtest/" ^ subdir ^ ts in
  Core_unix.mkdir_p path;
  path

(* ------------------------------------------------------------------ *)
(* Sexp output helpers                                                 *)
(* ------------------------------------------------------------------ *)

let _sexp_of_pair k v = Sexp.List [ Sexp.Atom k; v ]
let _sexp_of_float f = Sexp.Atom (sprintf "%.2f" f)
let _sexp_of_int i = Sexp.Atom (Int.to_string i)
let _sexp_of_string s = Sexp.Atom s

let _commission_sexp () =
  Sexp.List
    [
      _sexp_of_pair "per_share" (_sexp_of_float commission.per_share);
      _sexp_of_pair "minimum" (_sexp_of_float commission.minimum);
    ]

(* ------------------------------------------------------------------ *)
(* Output writers                                                      *)
(* ------------------------------------------------------------------ *)

let _write_params ~output_dir ~start_date ~end_date ~universe_size ~data_dir =
  let sexp =
    Sexp.List
      [
        _sexp_of_pair "code_version" (_sexp_of_string (_code_version ()));
        _sexp_of_pair "start_date" (_sexp_of_string (Date.to_string start_date));
        _sexp_of_pair "end_date" (_sexp_of_string (Date.to_string end_date));
        _sexp_of_pair "initial_cash" (_sexp_of_float initial_cash);
        _sexp_of_pair "universe_size" (_sexp_of_int universe_size);
        _sexp_of_pair "data_dir" (_sexp_of_string data_dir);
        _sexp_of_pair "commission" (_commission_sexp ());
      ]
  in
  Sexp.save_hum (output_dir ^ "/params.sexp") sexp

let _build_summary_sexp
    ~(metrics : Trading_simulation_types.Metric_types.metric_set) ~final_value
    ~start_date ~end_date ~universe_size ~n_steps ~n_round_trips =
  let run_info =
    [
      _sexp_of_pair "start_date" (_sexp_of_string (Date.to_string start_date));
      _sexp_of_pair "end_date" (_sexp_of_string (Date.to_string end_date));
      _sexp_of_pair "universe_size" (_sexp_of_int universe_size);
      _sexp_of_pair "steps" (_sexp_of_int n_steps);
      _sexp_of_pair "final_portfolio_value" (_sexp_of_float final_value);
      _sexp_of_pair "round_trips" (_sexp_of_int n_round_trips);
    ]
  in
  let metrics_sexp =
    Trading_simulation_types.Metric_types.metric_set_to_sexp_pairs metrics
  in
  Sexp.List (run_info @ [ _sexp_of_pair "metrics" metrics_sexp ])

let _write_summary ~output_dir ~summary_sexp =
  Sexp.save_hum (output_dir ^ "/summary.sexp") summary_sexp

let _write_trades ~output_dir ~(round_trips : Metrics.trade_metrics list) =
  let path = output_dir ^ "/trades.csv" in
  let oc = Out_channel.create path in
  fprintf oc
    "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent\n";
  List.iter round_trips ~f:(fun (t : Metrics.trade_metrics) ->
      fprintf oc "%s,%s,%s,%d,%.2f,%.2f,%.0f,%.2f,%.2f\n" t.symbol
        (Date.to_string t.entry_date)
        (Date.to_string t.exit_date)
        t.days_held t.entry_price t.exit_price t.quantity t.pnl_dollars
        t.pnl_percent);
  Out_channel.close oc

(* ------------------------------------------------------------------ *)
(* Core run logic                                                      *)
(* ------------------------------------------------------------------ *)

type run_deps = {
  data_dir_fpath : Fpath.t;
  data_dir : string;
  ticker_sectors : (string, string) Hashtbl.t;
  universe_size : int;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

let _load_deps () =
  let data_dir_fpath = Data_path.default_data_dir () in
  let data_dir = Fpath.to_string data_dir_fpath in
  eprintf "Loading universe from sectors.csv...\n%!";
  let ticker_sectors = Sector_map.load ~data_dir:data_dir_fpath in
  let universe =
    Hashtbl.keys ticker_sectors |> List.sort ~compare:String.compare
  in
  let universe_size = List.length universe in
  eprintf "Universe: %d stocks\n%!" universe_size;
  eprintf "Loading AD breadth bars...\n%!";
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    {
      base_config with
      sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs;
    }
  in
  let sector_etf_symbols =
    List.map config.sector_etfs ~f:(fun (sym, _) -> sym)
  in
  let all_symbols =
    (index_symbol :: universe) @ sector_etf_symbols
    |> List.dedup_and_sort ~compare:String.compare
  in
  {
    data_dir_fpath;
    data_dir;
    ticker_sectors;
    universe_size;
    ad_bars;
    config;
    all_symbols;
  }

let _run_single (deps : run_deps) ~start_date ~end_date =
  let strategy =
    Weinstein_strategy.make ~ad_bars:deps.ad_bars
      ~ticker_sectors:deps.ticker_sectors deps.config
  in
  let warmup_start = Date.add_days start_date (-warmup_days) in
  let metric_suite = Metric_computers.default_metric_suite () in
  let sim_deps =
    Simulator.create_deps ~symbols:deps.all_symbols
      ~data_dir:deps.data_dir_fpath ~strategy ~commission ~metric_suite ()
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
  let sim =
    match Simulator.create ~config:sim_config ~deps:sim_deps with
    | Ok s -> s
    | Error e ->
        eprintf "Failed to create simulator: %s\n" (Status.show e);
        Stdlib.exit 1
  in
  match Simulator.run sim with
  | Ok r -> r
  | Error e ->
      eprintf "Simulation failed: %s\n" (Status.show e);
      Stdlib.exit 1

let _collect_results result ~start_date =
  let steps =
    List.filter result.Simulator.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date && _is_trading_day s)
  in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips steps in
  (steps, final_value, round_trips, result.metrics)

(* ------------------------------------------------------------------ *)
(* Single run mode                                                     *)
(* ------------------------------------------------------------------ *)

let _run_single_mode deps ~start_date ~end_date =
  eprintf "Running backtest (%s to %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date);
  let result = _run_single deps ~start_date ~end_date in
  let steps, final_value, round_trips, metrics =
    _collect_results result ~start_date
  in
  let output_dir =
    _make_output_dir ~data_dir_fpath:deps.data_dir_fpath ~subdir:""
  in
  eprintf "Writing output to %s/\n%!" output_dir;
  let summary_sexp =
    _build_summary_sexp ~metrics ~final_value ~start_date ~end_date
      ~universe_size:deps.universe_size ~n_steps:(List.length steps)
      ~n_round_trips:(List.length round_trips)
  in
  _write_params ~output_dir ~start_date ~end_date
    ~universe_size:deps.universe_size ~data_dir:deps.data_dir;
  _write_summary ~output_dir ~summary_sexp;
  _write_trades ~output_dir ~round_trips;
  eprintf "Output written to: %s/\n%!" output_dir;
  Out_channel.output_string stdout (Sexp.to_string_hum summary_sexp);
  Out_channel.newline stdout

(* ------------------------------------------------------------------ *)
(* Smoke / scenarios mode                                              *)
(* ------------------------------------------------------------------ *)

let _print_table_header () =
  eprintf "%-12s %12s %7s %6s %8s %7s %7s\n" "Scenario" "Final Value" "Return"
    "Trades" "Win Rate" "Max DD" "Sharpe"

let _print_table_row name final_value trades win_rate max_dd sharpe =
  let ret = (final_value -. initial_cash) /. initial_cash *. 100.0 in
  eprintf "%-12s %12.0f %6.1f%% %6d %7.1f%% %6.1f%% %7.2f\n" name final_value
    ret trades win_rate max_dd sharpe

let _run_scenario deps (scenario : scenario) ~output_dir =
  eprintf "  Running %s (%s to %s)...\n%!" scenario.name
    (Date.to_string scenario.start_date)
    (Date.to_string scenario.end_date);
  let result =
    _run_single deps ~start_date:scenario.start_date ~end_date:scenario.end_date
  in
  let _steps, final_value, round_trips, metrics =
    _collect_results result ~start_date:scenario.start_date
  in
  let open Trading_simulation_types.Metric_types in
  let get k = Map.find metrics k |> Option.value ~default:0.0 in
  let scenario_dir = output_dir ^ "/" ^ scenario.name in
  Core_unix.mkdir_p scenario_dir;
  let summary_sexp =
    _build_summary_sexp ~metrics ~final_value ~start_date:scenario.start_date
      ~end_date:scenario.end_date ~universe_size:deps.universe_size ~n_steps:0
      ~n_round_trips:(List.length round_trips)
  in
  _write_summary ~output_dir:scenario_dir ~summary_sexp;
  _write_trades ~output_dir:scenario_dir ~round_trips;
  _print_table_row scenario.name final_value (List.length round_trips)
    (get WinRate) (get MaxDrawdown) (get SharpeRatio)

let _run_scenarios_mode deps ~scenarios_path =
  let data_dir_fpath = deps.data_dir_fpath in
  let path =
    if String.equal scenarios_path "smoke" then
      _default_scenarios_path data_dir_fpath
    else scenarios_path
  in
  let scenarios = _load_scenarios path in
  eprintf "Running %d scenarios from %s\n%!" (List.length scenarios) path;
  let output_dir = _make_output_dir ~data_dir_fpath ~subdir:"smoke-" in
  _print_table_header ();
  List.iter scenarios ~f:(fun s -> _run_scenario deps s ~output_dir);
  eprintf "Output written to: %s/\n%!" output_dir

(* ------------------------------------------------------------------ *)
(* Main                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  let mode = _parse_args () in
  let deps = _load_deps () in
  match mode with
  | Single { start_date; end_date } ->
      _run_single_mode deps ~start_date ~end_date
  | Scenarios path -> _run_scenarios_mode deps ~scenarios_path:path
