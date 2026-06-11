open Core
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Metric_types = Trading_simulation_types.Metric_types
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

let enumerate_starts ~scenario_start ~end_date ~stride_days =
  if stride_days <= 0 then
    invalid_arg
      (sprintf "enumerate_starts: stride_days must be positive, got %d"
         stride_days);
  let rec loop acc d =
    if Date.( >= ) d end_date then List.rev acc
    else loop (d :: acc) (Date.add_days d stride_days)
  in
  loop [] scenario_start

let enumerate_starts_jittered ~scenario_start ~end_date ~stride_days
    ~jitter_seed =
  let base = enumerate_starts ~scenario_start ~end_date ~stride_days in
  let rng = Stdlib.Random.State.make [| jitter_seed |] in
  (* Consume one uniform draw per non-first base point, in ascending order, so
     the output is a pure function of (inputs, seed). The first point is pinned
     to scenario_start; a jittered point that crosses end_date is dropped. *)
  List.filter_mapi base ~f:(fun i d ->
      if i = 0 then Some d
      else
        let offset = Stdlib.Random.State.int rng stride_days in
        let jittered = Date.add_days d offset in
        if Date.( >= ) jittered end_date then None else Some jittered)

(** Inclusive calendar-day count of [start_date .. end_date]. *)
let _inclusive_days ~start_date ~end_date = Date.diff end_date start_date + 1

let bah_cagr_pct ~start_date ~end_date ~close_series =
  (* Entry = first close on/after start_date; exit = last close on/before
     end_date. Both selected by date, so an unsorted series still works. *)
  let entry =
    List.filter close_series ~f:(fun (d, _) -> Date.( >= ) d start_date)
    |> List.min_elt ~compare:(fun (a, _) (b, _) -> Date.compare a b)
  in
  let exit =
    List.filter close_series ~f:(fun (d, _) -> Date.( <= ) d end_date)
    |> List.max_elt ~compare:(fun (a, _) (b, _) -> Date.compare a b)
  in
  match (entry, exit) with
  | Some (entry_date, entry_close), Some (exit_date, exit_close)
    when Float.( > ) entry_close 0.0 && Date.( < ) entry_date exit_date ->
      let total_return_pct =
        (exit_close -. entry_close) /. entry_close *. 100.0
      in
      let test_days = _inclusive_days ~start_date ~end_date in
      Walk_forward.Walk_forward_runner.cagr_pct ~test_days ~total_return_pct
  | _ -> Float.nan

(* Realized-basis return: strip the terminal unrealized mark on open positions
   so a single big paper winner cannot flatter the row. nan only when initial
   cash is non-positive (degenerate). *)
let _realized_return_pct ~initial_cash ~final_value ~unrealized_pnl =
  if Float.( <= ) initial_cash 0.0 then Float.nan
  else (final_value -. unrealized_pnl -. initial_cash) /. initial_cash *. 100.0

let per_start_of_summary ?(benchmark_cagr_pct = Float.nan) ?(equity_curve = [])
    ~start_date ~end_date (summary : Backtest.Summary.t) :
    Rolling_start_types.per_start =
  let get k = Map.find summary.metrics k |> Option.value ~default:Float.nan in
  let total_return_pct =
    (summary.final_portfolio_value -. summary.initial_cash)
    /. summary.initial_cash *. 100.0
  in
  let test_days = _inclusive_days ~start_date ~end_date in
  let cagr_pct =
    Walk_forward.Walk_forward_runner.cagr_pct ~test_days ~total_return_pct
  in
  let unrealized_pnl =
    Map.find summary.metrics Metric_types.UnrealizedPnl
    |> Option.value ~default:0.0
  in
  {
    Rolling_start_types.start_date;
    cagr_pct;
    max_underwater_vs_initial_pct = get Metric_types.MaxUnderwaterVsInitialPct;
    max_drawdown_pct = get Metric_types.MaxDrawdown;
    benchmark_cagr_pct;
    edge_pct = cagr_pct -. benchmark_cagr_pct;
    sharpe = get Metric_types.SharpeRatio;
    time_underwater_pct = Convexity_stats.time_underwater_pct equity_curve;
    realized_return_pct =
      _realized_return_pct ~initial_cash:summary.initial_cash
        ~final_value:summary.final_portfolio_value ~unrealized_pnl;
  }

type config = {
  scenario : Scenario.t;
  end_date : Date.t;
  stride_days : int;
  jitter_seed : int option;
  benchmark_symbol : string option;
  parallel : int;
  fixtures_root : string;
  bar_data_source : Backtest.Bar_data_source.t option;
}

(* Read [symbol]'s adjusted-close series over [from .. to_] from the snapshot
   panels, as chronological [(date, adjusted_close)] pairs. Rows missing /
   NaN-valued in the Adjusted_close column are dropped (they cannot price a
   buy-and-hold leg). Returns [] when the symbol is absent or the read fails —
   the caller's [bah_cagr_pct] then yields nan for every start. *)
let _benchmark_close_series ~panels ~symbol ~from ~to_ =
  match Daily_panels.read_history panels ~symbol ~from ~until:to_ with
  | Error _ -> []
  | Ok rows ->
      List.filter_map rows ~f:(fun (s : Snapshot.t) ->
          match Snapshot.get s Snapshot_schema.Adjusted_close with
          | Some v when not (Float.is_nan v) -> Some (s.date, v)
          | _ -> None)

(* Resolve the benchmark's full-window close series once (shared across starts),
   when both a [benchmark_symbol] and a snapshot [bar_data_source] are
   configured. CSV mode has no caller-owned panels handle, so the benchmark
   overlay is snapshot-only; absent either, returns [] -> every start's
   benchmark CAGR is nan (unbenchmarked), which the report renders as blank. *)
let _resolve_benchmark_series ~config ~earliest_start =
  match (config.benchmark_symbol, config.bar_data_source) with
  | Some symbol, Some src -> (
      match Backtest.Bar_data_source.build_shared_panels src with
      | Ok (Some panels) ->
          let series =
            _benchmark_close_series ~panels ~symbol ~from:earliest_start
              ~to_:config.end_date
          in
          Backtest.Bar_data_source.close_shared_panels panels;
          series
      | Ok None | Error _ -> [])
  | _ -> []

(** Resolve the scenario's [universe_path] (relative to [fixtures_root]) into
    the optional sector-map override [Backtest.Runner] uses as its universe.
    Mirrors [scenario_runner._sector_map_of_universe_file]. *)
let _sector_map_override ~fixtures_root (scenario : Scenario.t) =
  let resolved = Filename.concat fixtures_root scenario.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

(** Run one backtest from [start_date] to [config.end_date], threading the
    scenario's overrides / strategy / cost knobs and the shared sector-map
    override + optional snapshot source, and project the terminal summary into a
    {!Rolling_start_types.per_start}. [benchmark_series] is the (once-resolved)
    benchmark close series; this start's benchmark CAGR is projected from it. *)
let _run_one ~config ~sector_map_override ~benchmark_series ~start_date =
  let result =
    Backtest.Runner.run_backtest ~start_date ~end_date:config.end_date
      ~overrides:config.scenario.config_overrides ?sector_map_override
      ~strategy_choice:config.scenario.strategy
      ?slippage_bps:config.scenario.slippage_bps
      ?cost_model:config.scenario.cost_model
      ?bar_data_source:config.bar_data_source ()
  in
  let benchmark_cagr_pct =
    bah_cagr_pct ~start_date ~end_date:config.end_date
      ~close_series:benchmark_series
  in
  (* The run's per-step NAV series, chronological — the equity curve the
     time-underwater metric reads. [result.steps] is already filtered to
     trading days in [start_date .. end_date]. *)
  let equity_curve =
    List.map result.steps
      ~f:(fun (s : Trading_simulation_types.Simulator_types.step_result) ->
        s.portfolio_value)
  in
  per_start_of_summary ~benchmark_cagr_pct ~equity_curve ~start_date
    ~end_date:config.end_date result.summary

(* The start dates to sweep: jittered when [jitter_seed] is set, the fixed grid
   otherwise. Both share the same base grid. *)
let _starts_for config =
  match config.jitter_seed with
  | Some jitter_seed ->
      enumerate_starts_jittered
        ~scenario_start:config.scenario.period.start_date
        ~end_date:config.end_date ~stride_days:config.stride_days ~jitter_seed
  | None ->
      enumerate_starts ~scenario_start:config.scenario.period.start_date
        ~end_date:config.end_date ~stride_days:config.stride_days

let run config =
  let starts = _starts_for config in
  let sector_map_override =
    _sector_map_override ~fixtures_root:config.fixtures_root config.scenario
  in
  let benchmark_series =
    match List.min_elt starts ~compare:Date.compare with
    | Some earliest_start -> _resolve_benchmark_series ~config ~earliest_start
    | None -> []
  in
  (* One job per start. Each job is a self-contained backtest of marshallable
     inputs/outputs (a per_start record of floats + a Date), so it forks
     cleanly. parallel=1 forks each job one-at-a-time (memory-safe broad-universe
     path); parallel>1 keeps up to [parallel] children alive. Result order is
     input order in both cases — see Fork_pool. *)
  let jobs =
    Array.of_list
      (List.map starts ~f:(fun start_date () ->
           _run_one ~config ~sector_map_override ~benchmark_series ~start_date))
  in
  let per_starts =
    (if config.parallel <= 1 then Fork_pool.run_each_forked ~jobs
     else Fork_pool.run_parallel ~parallel:config.parallel ~jobs)
    |> Array.to_list
  in
  Rolling_start_types.build ~end_date:config.end_date per_starts
