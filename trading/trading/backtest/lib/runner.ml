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
}

(* Trading-day filter *)

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
      indices =
        {
          primary = index_symbol;
          global = Weinstein_strategy.Macro_inputs.default_global_indices;
        };
      sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs;
    }
  in
  let config = _apply_overrides config overrides in
  let sector_etf_symbols =
    List.map config.sector_etfs ~f:(fun (sym, _) -> sym)
  in
  let global_index_symbols =
    List.map config.indices.global ~f:(fun (sym, _) -> sym)
  in
  let all_symbols =
    (index_symbol :: universe) @ sector_etf_symbols @ global_index_symbols
    |> List.dedup_and_sort ~compare:String.compare
  in
  {
    data_dir_fpath;
    ticker_sectors;
    universe_size;
    ad_bars;
    config;
    all_symbols;
  }

(* Simulation *)

let _make_simulator deps ~stop_log ~start_date ~end_date =
  let strategy =
    Weinstein_strategy.make ~ad_bars:deps.ad_bars
      ~ticker_sectors:deps.ticker_sectors deps.config
  in
  let strategy = Strategy_wrapper.wrap ~stop_log strategy in
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
        (sprintf "Backtest.Runner: failed to create simulator: %s"
           (Status.show e))

let _run_simulator sim =
  match Simulator.run sim with
  | Ok r -> r
  | Error e ->
      failwith
        (sprintf "Backtest.Runner: simulation failed: %s" (Status.show e))

let run_backtest ~start_date ~end_date ?(overrides = []) () =
  let deps = _load_deps ~overrides in
  eprintf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length deps.all_symbols);
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf "Running backtest (%s to %s, warmup from %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date)
    (Date.to_string warmup_start);
  let stop_log = Stop_log.create () in
  let sim = _make_simulator deps ~stop_log ~start_date ~end_date in
  let sim_result = _run_simulator sim in
  let steps =
    List.filter sim_result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date && _is_trading_day s)
  in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips steps in
  let stop_infos = Stop_log.get_stop_infos stop_log in
  let summary : Summary.t =
    {
      start_date;
      end_date;
      universe_size = deps.universe_size;
      n_steps = List.length steps;
      initial_cash;
      final_portfolio_value = final_value;
      n_round_trips = List.length round_trips;
      metrics = sim_result.metrics;
    }
  in
  { summary; round_trips; steps; overrides; stop_infos }
