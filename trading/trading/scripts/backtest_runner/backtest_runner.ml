(** Backtest runner CLI — runs the Weinstein strategy over the full universe and
    writes structured output (params, summary, trades, equity curve). *)

open Core
open Trading_simulation

(* ------------------------------------------------------------------ *)
(* Configuration constants                                             *)
(* ------------------------------------------------------------------ *)

let index_symbol = "GSPC.INDX"
let initial_cash = 1_000_000.0
let commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }
let default_start = "2018-01-02"
let default_end = "2023-12-29"

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

(** Parse CLI args: [backtest_runner [start_date] [end_date]]. *)
let _parse_args () =
  let argv = Sys.get_argv () in
  let start_str = if Array.length argv > 1 then argv.(1) else default_start in
  let end_str = if Array.length argv > 2 then argv.(2) else default_end in
  (Date.of_string start_str, Date.of_string end_str)

(** Get git HEAD revision, or "unknown" on failure. *)
let _code_version () =
  try
    let ic = Core_unix.open_process_in "git rev-parse HEAD" in
    let line = In_channel.input_line ic in
    let _ = Core_unix.close_process_in ic in
    Option.value line ~default:"unknown"
  with _ -> "unknown"

(** Create a timestamped output directory under [dev/backtest/]. *)
let _make_output_dir () =
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let dirname =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let base = "dev/backtest" in
  let path = base ^ "/" ^ dirname in
  Core_unix.mkdir_p path;
  path

(* ------------------------------------------------------------------ *)
(* Output writers                                                      *)
(* ------------------------------------------------------------------ *)

(** Write params.json recording inputs for reproducibility. *)
let _write_params ~output_dir ~start_date ~end_date ~universe_size ~data_dir =
  let path = output_dir ^ "/params.json" in
  let oc = Out_channel.create path in
  fprintf oc
    {|{
  "code_version": "%s",
  "start_date": "%s",
  "end_date": "%s",
  "initial_cash": %.1f,
  "universe_size": %d,
  "data_dir": "%s",
  "commission": {"per_share": %.2f, "minimum": %.2f}
}
|}
    (_code_version ())
    (Date.to_string start_date)
    (Date.to_string end_date) initial_cash universe_size data_dir
    commission.per_share commission.minimum;
  Out_channel.close oc

(** Write summary.json with key performance metrics. *)
let _write_summary ~output_dir
    ~(metrics : Trading_simulation_types.Metric_types.metric_set)
    ~(summary : Metrics.summary_stats option) ~final_value =
  let path = output_dir ^ "/summary.json" in
  let oc = Out_channel.create path in
  let open Trading_simulation_types.Metric_types in
  let get key = Map.find metrics key |> Option.value ~default:0.0 in
  let total_pnl = get TotalPnl in
  let win_count = get WinCount in
  let loss_count = get LossCount in
  let win_rate = get WinRate in
  let sharpe = get SharpeRatio in
  let max_dd = get MaxDrawdown in
  let total_trades = Float.to_int win_count + Float.to_int loss_count in
  let avg_hold =
    match summary with Some s -> s.avg_holding_days | None -> 0.0
  in
  fprintf oc
    {|{
  "total_pnl": %.2f,
  "win_count": %d,
  "loss_count": %d,
  "win_rate": %.1f,
  "sharpe_ratio": %.2f,
  "max_drawdown_pct": %.1f,
  "total_trades": %d,
  "avg_holding_days": %.1f,
  "final_portfolio_value": %.2f
}
|}
    total_pnl (Float.to_int win_count) (Float.to_int loss_count) win_rate sharpe
    (Float.abs max_dd *. 100.0)
    total_trades avg_hold final_value;
  Out_channel.close oc

(** Write trades.csv with all round-trip trades. *)
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

(** Write equity_curve.csv with daily portfolio values. *)
let _write_equity_curve ~output_dir
    ~(steps : Trading_simulation_types.Simulator_types.step_result list) =
  let path = output_dir ^ "/equity_curve.csv" in
  let oc = Out_channel.create path in
  fprintf oc "date,portfolio_value\n";
  List.iter steps
    ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
      fprintf oc "%s,%.2f\n" (Date.to_string s.date) s.portfolio_value);
  Out_channel.close oc

(* ------------------------------------------------------------------ *)
(* Main                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  let start_date, end_date = _parse_args () in
  let data_dir_fpath = Data_path.default_data_dir () in
  let data_dir = Fpath.to_string data_dir_fpath in

  printf "Loading universe from sectors.csv...\n%!";
  let ticker_sectors = Sector_map.load ~data_dir:data_dir_fpath in
  let universe = Hashtbl.keys ticker_sectors in
  let universe_size = List.length universe in
  printf "Universe: %d stocks\n%!" universe_size;

  printf "Loading AD breadth bars...\n%!";
  let ad_bars = Weinstein_strategy.Ad_bars.load ~data_dir in

  printf "Building strategy...\n%!";
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    {
      base_config with
      sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs;
    }
  in
  let strategy = Weinstein_strategy.make ~ad_bars ~ticker_sectors config in

  (* All symbols = universe + index + sector ETFs *)
  let sector_etf_symbols =
    List.map config.sector_etfs ~f:(fun (sym, _) -> sym)
  in
  let all_symbols =
    (index_symbol :: universe) @ sector_etf_symbols
    |> List.dedup_and_sort ~compare:String.compare
  in
  printf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length all_symbols);

  printf "Creating simulator (%s to %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date);
  let deps =
    Simulator.create_deps ~symbols:all_symbols ~data_dir:data_dir_fpath
      ~strategy ~commission ()
  in
  let sim_config =
    Simulator.
      {
        start_date;
        end_date;
        initial_cash;
        commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  let sim =
    match Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e ->
        eprintf "Failed to create simulator: %s\n" (Status.show e);
        Stdlib.exit 1
  in

  printf "Running backtest...\n%!";
  let result =
    match Simulator.run sim with
    | Ok r -> r
    | Error e ->
        eprintf "Simulation failed: %s\n" (Status.show e);
        Stdlib.exit 1
  in

  (* Extract results *)
  let steps = result.steps in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips steps in
  let summary = Metrics.compute_summary round_trips in

  (* Write output *)
  let output_dir = _make_output_dir () in
  printf "Writing output to %s/\n%!" output_dir;
  _write_params ~output_dir ~start_date ~end_date ~universe_size ~data_dir;
  _write_summary ~output_dir ~metrics:result.metrics ~summary ~final_value;
  _write_trades ~output_dir ~round_trips;
  _write_equity_curve ~output_dir ~steps;

  (* Print summary to stdout *)
  printf "\n=== Backtest Summary ===\n";
  printf "Period: %s to %s\n"
    (Date.to_string start_date)
    (Date.to_string end_date);
  printf "Universe: %d stocks\n" universe_size;
  printf "Steps: %d\n" (List.length steps);
  printf "Final portfolio value: $%.2f\n" final_value;
  printf "Total P&L: $%.2f\n" (final_value -. initial_cash);
  printf "Round-trip trades: %d\n" (List.length round_trips);
  (match summary with
  | Some s ->
      printf "Win/Loss: %d/%d (%.1f%%)\n" s.win_count s.loss_count s.win_rate;
      printf "Avg holding days: %.1f\n" s.avg_holding_days;
      printf "Total trade P&L: $%.2f\n" s.total_pnl
  | None -> printf "No completed trades.\n");
  printf "Output written to: %s/\n" output_dir
