open Core
open Trading_simulation

(* ------------------------------------------------------------------ *)
(* Configuration constants                                             *)
(* ------------------------------------------------------------------ *)

let index_symbol = "GSPC.INDX"
let initial_cash = 1_000_000.0
let commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Number of calendar days to prepend for 30-week MA warmup. *)
let warmup_days = 210

(* ------------------------------------------------------------------ *)
(* Public types                                                        *)
(* ------------------------------------------------------------------ *)

type result = {
  summary_sexp : Sexp.t;
  round_trips : Metrics.trade_metrics list;
  metrics : Trading_simulation_types.Metric_types.metric_set;
  final_value : float;
  steps : Trading_simulation_types.Simulator_types.step_result list;
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
}

(* ------------------------------------------------------------------ *)
(* Sexp helpers                                                        *)
(* ------------------------------------------------------------------ *)

let _sexp_of_pair k v = Sexp.List [ Sexp.Atom k; v ]
let _sexp_of_float f = Sexp.Atom (sprintf "%.2f" f)
let _sexp_of_int i = Sexp.Atom (Int.to_string i)
let _sexp_of_string s = Sexp.Atom s

let _code_version () =
  try
    let ic = Core_unix.open_process_in "git rev-parse HEAD" in
    let line = In_channel.input_line ic in
    let _ = Core_unix.close_process_in ic in
    Option.value line ~default:"unknown"
  with _ -> "unknown"

(* ------------------------------------------------------------------ *)
(* Trading-day filter                                                  *)
(* ------------------------------------------------------------------ *)

(** True if [step] represents a real trading day. On non-trading days (weekends,
    holidays) the simulator has no price bars and reports
    [portfolio_value = cash] even when positions are open. *)
let _is_trading_day
    (step : Trading_simulation_types.Simulator_types.step_result) =
  let has_positions =
    not (List.is_empty step.portfolio.Trading_portfolio.Portfolio.positions)
  in
  if has_positions then
    let cash = step.portfolio.Trading_portfolio.Portfolio.current_cash in
    Float.(abs (step.portfolio_value -. cash) > 1e-2)
  else true

(* ------------------------------------------------------------------ *)
(* Config overrides via sexp deep-merge                                *)
(* ------------------------------------------------------------------ *)

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

(* ------------------------------------------------------------------ *)
(* Dependency loading                                                  *)
(* ------------------------------------------------------------------ *)

type _deps = {
  data_dir_fpath : Fpath.t;
  data_dir : string;
  ticker_sectors : (string, string) Hashtbl.t;
  universe_size : int;
  ad_bars : Macro.ad_bar list;
  config : Weinstein_strategy.config;
  all_symbols : string list;
}

let _load_deps ~overrides =
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
  let config = _apply_overrides config overrides in
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

(* ------------------------------------------------------------------ *)
(* Simulation                                                          *)
(* ------------------------------------------------------------------ *)

let _make_simulator deps ~start_date ~end_date =
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
  match Simulator.create ~config:sim_config ~deps:sim_deps with
  | Ok s -> s
  | Error e ->
      failwith
        (sprintf "Backtest_runner_lib: failed to create simulator: %s"
           (Status.show e))

let _run_simulator sim =
  match Simulator.run sim with
  | Ok r -> r
  | Error e ->
      failwith
        (sprintf "Backtest_runner_lib: simulation failed: %s" (Status.show e))

(* ------------------------------------------------------------------ *)
(* Summary sexp                                                        *)
(* ------------------------------------------------------------------ *)

let _build_summary_sexp ~metrics ~final_value ~start_date ~end_date
    ~universe_size ~n_steps ~n_round_trips =
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

(* ------------------------------------------------------------------ *)
(* run_backtest                                                        *)
(* ------------------------------------------------------------------ *)

let run_backtest ~start_date ~end_date ?(overrides = []) () =
  let deps = _load_deps ~overrides in
  eprintf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length deps.all_symbols);
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf "Running backtest (%s to %s, warmup from %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date)
    (Date.to_string warmup_start);
  let sim = _make_simulator deps ~start_date ~end_date in
  let sim_result = _run_simulator sim in
  let steps =
    List.filter sim_result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date && _is_trading_day s)
  in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips steps in
  let summary_sexp =
    _build_summary_sexp ~metrics:sim_result.metrics ~final_value ~start_date
      ~end_date ~universe_size:deps.universe_size ~n_steps:(List.length steps)
      ~n_round_trips:(List.length round_trips)
  in
  {
    summary_sexp;
    round_trips;
    metrics = sim_result.metrics;
    final_value;
    steps;
    start_date;
    end_date;
    universe_size = deps.universe_size;
  }

(* ------------------------------------------------------------------ *)
(* Output writers                                                      *)
(* ------------------------------------------------------------------ *)

let _commission_sexp () =
  Sexp.List
    [
      _sexp_of_pair "per_share" (_sexp_of_float commission.per_share);
      _sexp_of_pair "minimum" (_sexp_of_float commission.minimum);
    ]

let _write_params ~output_dir ~start_date ~end_date ~universe_size =
  let data_dir = Fpath.to_string (Data_path.default_data_dir ()) in
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

let write_output_dir ~output_dir (result : result) =
  _write_params ~output_dir ~start_date:result.start_date
    ~end_date:result.end_date ~universe_size:result.universe_size;
  Sexp.save_hum (output_dir ^ "/summary.sexp") result.summary_sexp;
  _write_trades ~output_dir ~round_trips:result.round_trips
