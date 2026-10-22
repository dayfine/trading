(** All-eligible runner — see [all_eligible_runner.mli] for the API contract. *)

open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_bar_views = Snapshot_runtime.Snapshot_bar_views
module Scanner = Backtest_optimal.Stage_transition_scanner
module Scorer = Backtest_optimal.Outcome_scorer
module OT = Backtest_optimal.Optimal_types

(* ---------------------------------------------------------------- *)
(* Constants                                                          *)
(* ---------------------------------------------------------------- *)

let _index_symbol = "GSPC.INDX"
let _warmup_days = Backtest.Runner.warmup_days_for Weinstein
let _bar_lookback_weeks = 90
let _snapshot_cache_mb = Backtest.Snapshot_world.default_cache_mb ()

type cli_args = All_eligible_cli.cli_args = {
  scenario_path : string;
  out_dir : string option;
  entry_dollars : float option;
  return_buckets : float list option;
  min_grade : Weinstein_types.grade option;
  grade_sweep : bool;
  config_overrides : Sexp.t list;
  warehouse_dir : string option;
}

let parse_argv = All_eligible_cli.parse_argv
let resolve_out_dir = All_eligible_cli.resolve_out_dir
let resolve_config = All_eligible_cli.resolve_config

(* ---------------------------------------------------------------- *)
(* Friday calendar                                                    *)
(* ---------------------------------------------------------------- *)

let _friday_on_or_before (d : Date.t) : Date.t =
  let dow = Date.day_of_week d in
  let offset =
    match dow with
    | Day_of_week.Mon -> 3
    | Day_of_week.Tue -> 4
    | Day_of_week.Wed -> 5
    | Day_of_week.Thu -> 6
    | Day_of_week.Fri -> 0
    | Day_of_week.Sat -> 1
    | Day_of_week.Sun -> 2
  in
  Date.add_days d (-offset)

let _fridays_in_range ~start ~end_ : Date.t list =
  let first_fri =
    let f = _friday_on_or_before start in
    if Date.( < ) f start then Date.add_days f 7 else f
  in
  let rec loop d acc =
    if Date.( > ) d end_ then List.rev acc
    else loop (Date.add_days d 7) (d :: acc)
  in
  loop first_fri []

(* ---------------------------------------------------------------- *)
(* Per-Friday analysis + scan                                         *)
(* ---------------------------------------------------------------- *)

let _analyze_symbol_on_friday ~snapshot_callbacks ~friday ~stock_config
    ~bar_lookback (symbol : string) : Stock_analysis.t option =
  let weekly =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol
      ~n:bar_lookback ~as_of:friday
  in
  let benchmark =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol:_index_symbol
      ~n:bar_lookback ~as_of:friday
  in
  match (weekly, benchmark) with
  | [], _ | _, [] -> None
  | _ ->
      Some
        (Stock_analysis.analyze ~config:stock_config ~ticker:symbol ~bars:weekly
           ~benchmark_bars:benchmark ~prior_stage:None ~as_of_date:friday)

let _make_sector_context (sector_name : string) : Screener.sector_context =
  {
    sector_name;
    rating = Screener.Neutral;
    stage = Stage2 { weeks_advancing = 4; late = false };
  }

let _build_sector_context_map (sectors : (string, string) Hashtbl.t) :
    (string, Screener.sector_context) Hashtbl.t =
  let out = Hashtbl.create (module String) in
  Hashtbl.iteri sectors ~f:(fun ~key ~data ->
      Hashtbl.set out ~key ~data:(_make_sector_context data));
  out

let _scan_one_friday ~snapshot_callbacks ~universe ~sector_map ~stock_config
    ~scanner_config ~bar_lookback (friday : Date.t) : OT.candidate_entry list =
  let analyses =
    List.filter_map universe ~f:(fun sym ->
        _analyze_symbol_on_friday ~snapshot_callbacks ~friday ~stock_config
          ~bar_lookback sym)
  in
  let week : Scanner.week_input =
    {
      date = friday;
      macro_trend = Weinstein_types.Neutral;
      analyses;
      sector_map;
    }
  in
  Scanner.scan_week ~config:scanner_config week

let _scan_all_fridays ~snapshot_callbacks ~fridays ~universe ~sector_map
    ~stock_config ~scanner_config ~bar_lookback : OT.candidate_entry list =
  List.concat_map fridays
    ~f:
      (_scan_one_friday ~snapshot_callbacks ~universe ~sector_map ~stock_config
         ~scanner_config ~bar_lookback)

(* ---------------------------------------------------------------- *)
(* Forward-walk outlooks for the scorer                                *)
(* ---------------------------------------------------------------- *)

let _outlook_at ~snapshot_callbacks ~stage_config ~bar_lookback ~symbol ~friday
    : Scorer.weekly_outlook option =
  let weekly =
    Snapshot_bar_views.weekly_bars_for snapshot_callbacks ~symbol
      ~n:bar_lookback ~as_of:friday
  in
  match List.last weekly with
  | None -> None
  | Some bar ->
      let stage_result =
        Stage.classify ~config:stage_config ~bars:weekly ~prior_stage:None
      in
      Some { Scorer.date = friday; bar; stage_result }

let _outlooks_for_symbol ~snapshot_callbacks ~fridays ~stage_config
    ~bar_lookback (symbol : string) : Scorer.weekly_outlook list =
  List.filter_map fridays ~f:(fun friday ->
      _outlook_at ~snapshot_callbacks ~stage_config ~bar_lookback ~symbol
        ~friday)

let _build_forward_table ~snapshot_callbacks ~fridays ~stage_config
    ~bar_lookback ~universe : (string, Scorer.weekly_outlook list) Hashtbl.t =
  let table = Hashtbl.create ~size:(List.length universe) (module String) in
  List.iter universe ~f:(fun symbol ->
      let outlooks =
        _outlooks_for_symbol ~snapshot_callbacks ~fridays ~stage_config
          ~bar_lookback symbol
      in
      Hashtbl.set table ~key:symbol ~data:outlooks);
  table

let _forward_outlooks_for ~forward_table ~symbol ~entry_friday :
    Scorer.weekly_outlook list =
  match Hashtbl.find forward_table symbol with
  | None -> []
  | Some outlooks ->
      List.drop_while outlooks ~f:(fun (o : Scorer.weekly_outlook) ->
          Date.( <= ) o.date entry_friday)

let _score_all_candidates ~forward_table ~scorer_config
    (candidates : OT.candidate_entry list) : OT.scored_candidate list =
  List.filter_map candidates ~f:(fun (c : OT.candidate_entry) ->
      let forward =
        _forward_outlooks_for ~forward_table ~symbol:c.symbol
          ~entry_friday:c.entry_week
      in
      Scorer.score ~config:scorer_config ~candidate:c ~forward)

(* ---------------------------------------------------------------- *)
(* Universe resolution                                                *)
(* ---------------------------------------------------------------- *)

(** Resolve [scenario.universe_path] into [(universe, sector_table)], the
    symbol→sector hashtable driving [_build_sector_context_map]. Pinned: exactly
    the listed symbols + sectors. Full_sector_map: fall back to
    [Sector_map.load] over [data/sectors.csv]. A [universe_schedule] is rejected
    — dated membership has no implementation here. *)
let _resolve_universe ~fixtures_root (scenario : Scenario_lib.Scenario.t) :
    string list * (string, string) Hashtbl.t =
  match
    Scenario_lib.Universe_schedule.sector_map_of_unscheduled ~fixtures_root
      ~runner_name:"All_eligible_runner" scenario
  with
  | Some tbl ->
      let universe = Hashtbl.keys tbl |> List.sort ~compare:String.compare in
      (universe, tbl)
  | None ->
      let data_dir = Data_path.default_data_dir () in
      let tbl = Sector_map.load ~data_dir in
      let universe = Hashtbl.keys tbl |> List.sort ~compare:String.compare in
      (universe, tbl)

let write_trades_csv = All_eligible_output.write_trades_csv
let format_summary_md = All_eligible_output.format_summary_md

(* ---------------------------------------------------------------- *)
(* Pipeline                                                            *)
(* ---------------------------------------------------------------- *)

(** Build the snapshot world and Friday calendar for [scenario] given [universe]
    / [sectors_tbl]. Mirrors the optimal-strategy runner's private
    [_build_world] but without the macro-trend table (this diagnostic doesn't
    consume one — every Friday treats macro as [Neutral]). *)
let _build_world ~warehouse_dir ~(scenario : Scenario_lib.Scenario.t) ~universe
    ~sectors_tbl :
    Snapshot_callbacks.t
    * (string, Screener.sector_context) Hashtbl.t
    * Date.t list =
  let data_dir_fpath = Data_path.default_data_dir () in
  let warmup_start = Date.add_days scenario.period.start_date (-_warmup_days) in
  eprintf "all_eligible: building snapshot (%d symbols, %s..%s)\n%!"
    (List.length universe + 1)
    (Date.to_string warmup_start)
    (Date.to_string scenario.period.end_date);
  let snapshot_callbacks =
    Backtest.Snapshot_world.build_callbacks ~warehouse_dir
      ~data_dir:data_dir_fpath ~index_symbol:_index_symbol ~universe
      ~start:warmup_start ~end_:scenario.period.end_date
      ~max_cache_mb:_snapshot_cache_mb
  in
  let sector_ctx_map = _build_sector_context_map sectors_tbl in
  let fridays =
    _fridays_in_range ~start:scenario.period.start_date
      ~end_:scenario.period.end_date
  in
  (snapshot_callbacks, sector_ctx_map, fridays)

let _scan_and_score ~snapshot_callbacks ~sector_ctx_map ~fridays ~universe :
    OT.scored_candidate list =
  eprintf "all_eligible: scanning %d Fridays\n%!" (List.length fridays);
  let stock_config = Stock_analysis.default_config in
  let stage_config = stock_config.stage in
  let screener_config = Screener.default_config in
  let scanner_config = Scanner.config_of_screener_config screener_config in
  let scorer_config = Scorer.default_config in
  let candidates =
    _scan_all_fridays ~snapshot_callbacks ~fridays ~universe
      ~sector_map:sector_ctx_map ~stock_config ~scanner_config
      ~bar_lookback:_bar_lookback_weeks
  in
  eprintf "all_eligible: %d candidates emitted; scoring...\n%!"
    (List.length candidates);
  let forward_table =
    _build_forward_table ~snapshot_callbacks ~fridays ~stage_config
      ~bar_lookback:_bar_lookback_weeks ~universe
  in
  _score_all_candidates ~forward_table ~scorer_config candidates

let _build_cell_inputs ~base_config ~scored ~scenario ~out_dir :
    Grade_sweep.cell_inputs =
  {
    base_config;
    scored;
    scenario;
    out_dir;
    write_trades_csv;
    format_summary_md;
  }

let run_with_args (args : cli_args) : unit =
  eprintf "all_eligible: loading scenario %s\n%!" args.scenario_path;
  let scenario = Scenario_lib.Scenario.load args.scenario_path in
  let fixtures_root = Scenario_lib.Fixtures_root.resolve () in
  let universe, sectors_tbl = _resolve_universe ~fixtures_root scenario in
  let out_dir = resolve_out_dir ~scenario_name:scenario.name args in
  Core_unix.mkdir_p out_dir;
  let base_config = resolve_config args in
  let snapshot_callbacks, sector_ctx_map, fridays =
    _build_world ~warehouse_dir:args.warehouse_dir ~scenario ~universe
      ~sectors_tbl
  in
  let scored =
    _scan_and_score ~snapshot_callbacks ~sector_ctx_map ~fridays ~universe
  in
  eprintf "all_eligible: %d scored candidates (pre filter+dedup)\n%!"
    (List.length scored);
  let inputs = _build_cell_inputs ~base_config ~scored ~scenario ~out_dir in
  if args.grade_sweep then Grade_sweep.emit_grade_sweep ~inputs
  else Grade_sweep.emit_single_cell ~inputs
