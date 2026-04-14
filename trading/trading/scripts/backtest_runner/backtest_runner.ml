(** Backtest runner CLI — runs the Weinstein strategy over the full universe and
    writes structured output (params, summary, trades, equity curve).

    Usage: backtest_runner <start_date> [end_date]
    - start_date: required (e.g. 2018-01-02)
    - end_date: optional, defaults to today *)

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
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

(* ------------------------------------------------------------------ *)
(* Config overrides                                                    *)
(* ------------------------------------------------------------------ *)

let _parse_override_pair kv =
  match String.lsplit2 kv ~on:'=' with
  | Some (k, v) -> (k, v)
  | None ->
      eprintf "Error: --override requires key=value, got: %s\n" kv;
      Stdlib.exit 1

let _extract_overrides argv =
  let n = Array.length argv in
  let overrides = ref [] in
  let positional = ref [] in
  let i = ref 1 in
  while !i < n do
    if String.equal argv.(!i) "--override" && !i + 1 < n then (
      overrides := _parse_override_pair argv.(!i + 1) :: !overrides;
      i := !i + 2)
    else (
      positional := argv.(!i) :: !positional;
      incr i)
  done;
  (List.rev !positional, List.rev !overrides)

(* ------------------------------------------------------------------ *)
(* Generic sexp-based config override                                  *)
(* ------------------------------------------------------------------ *)

(** Replace the [key]-valued field in a sexp record with [new_value]. Records
    are encoded by [@@deriving sexp] as [List [ List [Atom "key"; v]; ... ]]. If
    the key is not found the sexp is returned unchanged. *)
let _replace_field sexp key new_value =
  match sexp with
  | Sexp.List fields ->
      Sexp.List
        (List.map fields ~f:(function
          | Sexp.List [ Sexp.Atom k; _ ] when String.equal k key ->
              Sexp.List [ Sexp.Atom k; new_value ]
          | other -> other))
  | other -> other

let _find_field sexp key =
  match sexp with
  | Sexp.List fields ->
      List.find_map fields ~f:(function
        | Sexp.List [ Sexp.Atom k; v ] when String.equal k key -> Some v
        | _ -> None)
  | _ -> None

(** Navigate a sexp tree by a dotted key path and replace the leaf value. *)
let rec _merge_at_path sexp keys value =
  match keys with
  | [] -> Sexp.Atom value
  | [ key ] -> _replace_field sexp key (Sexp.Atom value)
  | key :: rest -> (
      match _find_field sexp key with
      | None ->
          eprintf "Warning: override key path not found: %s\n" key;
          sexp
      | Some child ->
          let updated = _merge_at_path child rest value in
          _replace_field sexp key updated)

let _apply_overrides (config : Weinstein_strategy.config) overrides =
  let sexp = Weinstein_strategy.sexp_of_config config in
  let merged =
    List.fold overrides ~init:sexp ~f:(fun sexp (key, value) ->
        let keys = String.split key ~on:'.' in
        _merge_at_path sexp keys value)
  in
  Weinstein_strategy.config_of_sexp merged

(* ------------------------------------------------------------------ *)
(* CLI parsing                                                         *)
(* ------------------------------------------------------------------ *)

let _parse_args () =
  let argv = Sys.get_argv () in
  let positional, overrides = _extract_overrides argv in
  (match positional with
  | [] ->
      eprintf
        "Usage: backtest_runner <start_date> [end_date] [--override k=v ...]\n";
      Stdlib.exit 1
  | _ -> ());
  let start_date = Date.of_string (List.hd_exn positional) in
  let end_date =
    match List.nth positional 1 with
    | Some s -> Date.of_string s
    | None -> Date.today ~zone:Time_float.Zone.utc
  in
  (start_date, end_date, overrides)

let _code_version () =
  try
    let ic = Core_unix.open_process_in "git rev-parse HEAD" in
    let line = In_channel.input_line ic in
    let _ = Core_unix.close_process_in ic in
    Option.value line ~default:"unknown"
  with _ -> "unknown"

(** True if [step] represents a real trading day. On non-trading days (weekends,
    holidays) the simulator has no price bars, so [_compute_portfolio_value]
    falls back to [current_cash] even when the portfolio holds positions —
    causing a spurious near-zero portfolio value.

    Detection: if the portfolio has open positions yet [portfolio_value] equals
    [current_cash], position market values were not included, so this is not a
    real trading day. When the portfolio is all-cash the value is correct on any
    day, so those steps always pass through. *)
let _is_trading_day
    (step : Trading_simulation_types.Simulator_types.step_result) =
  let has_positions =
    not (List.is_empty step.portfolio.Trading_portfolio.Portfolio.positions)
  in
  if has_positions then
    let cash = step.portfolio.Trading_portfolio.Portfolio.current_cash in
    Float.(abs (step.portfolio_value -. cash) > 1e-2)
  else true

let _make_output_dir ~data_dir_fpath =
  let repo_root = Fpath.parent data_dir_fpath |> Fpath.to_string in
  let now = Core_unix.gettimeofday () in
  let tm = Core_unix.localtime now in
  let dirname =
    sprintf "%04d-%02d-%02d-%02d%02d%02d" (tm.tm_year + 1900) (tm.tm_mon + 1)
      tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec
  in
  let path = repo_root ^ "dev/backtest/" ^ dirname in
  Core_unix.mkdir_p path;
  path

(* ------------------------------------------------------------------ *)
(* Sexp output helpers                                                 *)
(* ------------------------------------------------------------------ *)

let _sexp_of_pair k v = Sexp.List [ Sexp.Atom k; v ]
let _sexp_of_float f = Sexp.Atom (sprintf "%.2f" f)
let _sexp_of_int i = Sexp.Atom (Int.to_string i)
let _sexp_of_string s = Sexp.Atom s

(* ------------------------------------------------------------------ *)
(* Output writers                                                      *)
(* ------------------------------------------------------------------ *)

let _commission_sexp () =
  Sexp.List
    [
      _sexp_of_pair "per_share" (_sexp_of_float commission.per_share);
      _sexp_of_pair "minimum" (_sexp_of_float commission.minimum);
    ]

let _overrides_sexp overrides =
  Sexp.List
    (List.map overrides ~f:(fun (k, v) ->
         Sexp.List [ Sexp.Atom k; Sexp.Atom v ]))

let _write_params ~output_dir ~start_date ~end_date ~universe_size ~data_dir
    ~overrides =
  let base =
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
  let with_overrides =
    if List.is_empty overrides then base
    else base @ [ _sexp_of_pair "overrides" (_overrides_sexp overrides) ]
  in
  Sexp.save_hum (output_dir ^ "/params.sexp") (Sexp.List with_overrides)

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
  let start_date, end_date, overrides = _parse_args () in
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

  eprintf "Building strategy...\n%!";
  let base_config = Weinstein_strategy.default_config ~universe ~index_symbol in
  let config =
    _apply_overrides
      {
        base_config with
        sector_etfs = Weinstein_strategy.Macro_inputs.spdr_sector_etfs;
      }
      overrides
  in
  let strategy = Weinstein_strategy.make ~ad_bars ~ticker_sectors config in

  let sector_etf_symbols =
    List.map config.sector_etfs ~f:(fun (sym, _) -> sym)
  in
  let all_symbols =
    (index_symbol :: universe) @ sector_etf_symbols
    |> List.dedup_and_sort ~compare:String.compare
  in
  eprintf "Total symbols (universe + index + sector ETFs): %d\n%!"
    (List.length all_symbols);

  (* Start simulation early to warm up 30-week MA *)
  let warmup_start = Date.add_days start_date (-warmup_days) in
  eprintf "Running backtest (%s to %s, warmup from %s)...\n%!"
    (Date.to_string start_date)
    (Date.to_string end_date)
    (Date.to_string warmup_start);
  let metric_suite = Metric_computers.default_metric_suite () in
  let deps =
    Simulator.create_deps ~symbols:all_symbols ~data_dir:data_dir_fpath
      ~strategy ~commission ~metric_suite ()
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
    match Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e ->
        eprintf "Failed to create simulator: %s\n" (Status.show e);
        Stdlib.exit 1
  in
  let result =
    match Simulator.run sim with
    | Ok r -> r
    | Error e ->
        eprintf "Simulation failed: %s\n" (Status.show e);
        Stdlib.exit 1
  in

  (* Filter to the user's requested date range and real trading days only.
     Non-trading days (weekends, holidays) have no price bars, so the simulator
     reports portfolio_value = cash, creating spurious drawdowns. *)
  let steps =
    List.filter result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        Date.( >= ) s.date start_date && _is_trading_day s)
  in
  let final_value = (List.last_exn steps).portfolio_value in
  let round_trips = Metrics.extract_round_trips steps in

  let output_dir = _make_output_dir ~data_dir_fpath in
  eprintf "Writing output to %s/\n%!" output_dir;
  let summary_sexp =
    _build_summary_sexp ~metrics:result.metrics ~final_value ~start_date
      ~end_date ~universe_size ~n_steps:(List.length steps)
      ~n_round_trips:(List.length round_trips)
  in
  _write_params ~output_dir ~start_date ~end_date ~universe_size ~data_dir
    ~overrides;
  _write_summary ~output_dir ~summary_sexp;
  _write_trades ~output_dir ~round_trips;
  _write_equity_curve ~output_dir ~steps;
  eprintf "Output written to: %s/\n%!" output_dir;

  (* Print structured summary to stdout *)
  Out_channel.output_string stdout (Sexp.to_string_hum summary_sexp);
  Out_channel.newline stdout
