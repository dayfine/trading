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
let _warmup_days = 210
let _bar_lookback_weeks = 90
let _snapshot_cache_mb = 256

(* ---------------------------------------------------------------- *)
(* CLI args                                                           *)
(* ---------------------------------------------------------------- *)

type cli_args = {
  scenario_path : string;
  out_dir : string option;
  entry_dollars : float option;
  return_buckets : float list option;
  config_overrides : Sexp.t list;
}

let _usage () =
  String.concat ~sep:"\n"
    [
      "Usage: all_eligible_runner --scenario <path> [options]";
      "  --scenario <path>            Path to scenario sexp (required).";
      "  --out-dir <path>             Output dir (default: \
       dev/all_eligible/<name>/<UTC>/).";
      "  --entry-dollars <float>      Override entry-dollar sizing.";
      "  --return-buckets <csv>       Override return-bucket boundaries (e.g. \
       -0.5,0.0,0.5).";
      "  --config-overrides <sexp>    Extra config overrides (sexp list, \
       passthrough).";
    ]

let _fail_usage msg = failwith (msg ^ "\n" ^ _usage ())

let _parse_buckets s : float list =
  String.split s ~on:',' |> List.map ~f:String.strip
  |> List.filter ~f:(fun cell -> not (String.is_empty cell))
  |> List.map ~f:Float.of_string

let _parse_overrides s : Sexp.t list =
  match Sexp.of_string s with
  | List items -> items
  | Atom _ ->
      _fail_usage
        "--config-overrides expects a sexp list, e.g. '((entry_dollars \
         5000.0))'"

let parse_argv argv =
  let init =
    {
      scenario_path = "";
      out_dir = None;
      entry_dollars = None;
      return_buckets = None;
      config_overrides = [];
    }
  in
  let rec loop acc = function
    | [] -> acc
    | "--scenario" :: v :: rest -> loop { acc with scenario_path = v } rest
    | "--out-dir" :: v :: rest -> loop { acc with out_dir = Some v } rest
    | "--entry-dollars" :: v :: rest ->
        loop { acc with entry_dollars = Some (Float.of_string v) } rest
    | "--return-buckets" :: v :: rest ->
        loop { acc with return_buckets = Some (_parse_buckets v) } rest
    | "--config-overrides" :: v :: rest ->
        loop { acc with config_overrides = _parse_overrides v } rest
    | flag :: _ -> _fail_usage (Printf.sprintf "Unknown flag: %s" flag)
  in
  let args = Array.to_list argv |> List.tl |> Option.value ~default:[] in
  let parsed = loop init args in
  if String.is_empty parsed.scenario_path then
    _fail_usage "Missing required flag: --scenario"
  else parsed

(* ---------------------------------------------------------------- *)
(* Out-dir / config resolution                                        *)
(* ---------------------------------------------------------------- *)

(** Render [now] as a filesystem-safe UTC ISO timestamp, e.g.
    [2026-05-06T20-13-44Z]. Replaces colons (illegal on some filesystems) with
    hyphens. *)
let _utc_timestamp () : string =
  let now = Time_ns.now () in
  let s = Time_ns.to_string_iso8601_basic now ~zone:Time_float.Zone.utc in
  String.tr s ~target:':' ~replacement:'-'

let resolve_out_dir ~scenario_name (args : cli_args) : string =
  match args.out_dir with
  | Some d -> d
  | None ->
      let ts = _utc_timestamp () in
      Filename.concat (Filename.concat "dev/all_eligible" scenario_name) ts

let resolve_config (args : cli_args) : All_eligible.config =
  let base = All_eligible.default_config in
  let entry_dollars =
    Option.value args.entry_dollars ~default:base.entry_dollars
  in
  let return_buckets =
    Option.value args.return_buckets ~default:base.return_buckets
  in
  { entry_dollars; return_buckets }

(* ---------------------------------------------------------------- *)
(* Snapshot construction (mirror of optimal-strategy runner's                *)
(* private helper)                                                            *)
(* ---------------------------------------------------------------- *)

let _build_snapshot_callbacks ~data_dir_fpath ~universe ~start ~end_ :
    Snapshot_callbacks.t =
  let symbols =
    _index_symbol :: universe |> List.dedup_and_sort ~compare:String.compare
  in
  let snapshot_dir, manifest =
    Backtest.Csv_snapshot_builder.build ~data_dir:data_dir_fpath
      ~universe:symbols ~start_date:start ~end_date:end_
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest
        ~max_cache_mb:_snapshot_cache_mb
    with
    | Ok p -> p
    | Error err ->
        failwithf "Daily_panels.create failed: %s" (Status.show err) ()
  in
  Snapshot_callbacks.of_daily_panels panels

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

let _build_sector_context_map (sectors : (string, string) Hashtbl.t) :
    (string, Screener.sector_context) Hashtbl.t =
  let out = Hashtbl.create (module String) in
  Hashtbl.iteri sectors ~f:(fun ~key ~data ->
      let ctx : Screener.sector_context =
        {
          sector_name = data;
          rating = Screener.Neutral;
          stage = Stage2 { weeks_advancing = 4; late = false };
        }
      in
      Hashtbl.set out ~key ~data:ctx);
  out

let _scan_all_fridays ~snapshot_callbacks ~fridays ~universe ~sector_map
    ~stock_config ~scanner_config ~bar_lookback : OT.candidate_entry list =
  List.concat_map fridays ~f:(fun friday ->
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
      Scanner.scan_week ~config:scanner_config week)

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

let _build_forward_table ~snapshot_callbacks ~fridays ~stage_config
    ~bar_lookback ~universe : (string, Scorer.weekly_outlook list) Hashtbl.t =
  let table = Hashtbl.create ~size:(List.length universe) (module String) in
  List.iter universe ~f:(fun symbol ->
      let outlooks =
        List.filter_map fridays ~f:(fun friday ->
            _outlook_at ~snapshot_callbacks ~stage_config ~bar_lookback ~symbol
              ~friday)
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

(** Resolve [scenario.universe_path] against the fixtures root, load the
    universe file, and return [(universe, sector_table)] where [sector_table] is
    the symbol→sector hashtable that drives [_build_sector_context_map].

    Pinned: use exactly the listed symbols + their sectors. Full_sector_map:
    fall back to [Sector_map.load] over [data/sectors.csv]. *)
let _resolve_universe ~fixtures_root (scenario : Scenario_lib.Scenario.t) :
    string list * (string, string) Hashtbl.t =
  let path = Filename.concat fixtures_root scenario.universe_path in
  let uf = Scenario_lib.Universe_file.load path in
  match Scenario_lib.Universe_file.to_sector_map_override uf with
  | Some tbl ->
      let universe = Hashtbl.keys tbl |> List.sort ~compare:String.compare in
      (universe, tbl)
  | None ->
      let data_dir = Data_path.default_data_dir () in
      let tbl = Sector_map.load ~data_dir in
      let universe = Hashtbl.keys tbl |> List.sort ~compare:String.compare in
      (universe, tbl)

(* ---------------------------------------------------------------- *)
(* Output emission                                                    *)
(* ---------------------------------------------------------------- *)

let _csv_header =
  "signal_date,symbol,side,entry_price,exit_date,exit_reason,return_pct,hold_days,entry_dollars,shares,pnl_dollars,cascade_score,passes_macro"

let _side_to_string : Trading_base.Types.position_side -> string = function
  | Long -> "LONG"
  | Short -> "SHORT"

let _exit_reason_to_string : OT.exit_trigger -> string = function
  | Stage3_transition -> "Stage3_transition"
  | Stop_hit -> "Stop_hit"
  | End_of_run -> "End_of_run"

let _trade_to_csv_row (t : All_eligible.trade_record) : string =
  Printf.sprintf "%s,%s,%s,%.4f,%s,%s,%.6f,%d,%.2f,%.6f,%.4f,%d,%b"
    (Date.to_string t.signal_date)
    t.symbol (_side_to_string t.side) t.entry_price
    (Date.to_string t.exit_date)
    (_exit_reason_to_string t.exit_reason)
    t.return_pct t.hold_days t.entry_dollars t.shares t.pnl_dollars
    t.cascade_score t.passes_macro

let write_trades_csv ~path (result : All_eligible.result) : unit =
  let lines = _csv_header :: List.map result.trades ~f:_trade_to_csv_row in
  Out_channel.write_lines path lines

(** Render one row of the bucket histogram. Uses [neg_infinity] / [infinity]
    sentinels for the open ends. *)
let _bucket_row (low, high, count) : string =
  let fmt_low =
    if Float.is_negative low && Float.is_inf low then "-inf"
    else Printf.sprintf "%.2f" low
  in
  let fmt_high =
    if Float.is_inf high then "+inf" else Printf.sprintf "%.2f" high
  in
  Printf.sprintf "| %s | %s | %d |" fmt_low fmt_high count

let format_summary_md ~scenario_name ~start_date ~end_date
    ~(result : All_eligible.result) : string =
  let agg = result.aggregate in
  let bucket_lines =
    "| Low | High | Count |" :: "|---|---|---|"
    :: List.map agg.return_buckets ~f:_bucket_row
  in
  let stats_lines =
    [
      "| Metric | Value |";
      "|---|---|";
      Printf.sprintf "| trade_count | %d |" agg.trade_count;
      Printf.sprintf "| winners | %d |" agg.winners;
      Printf.sprintf "| losers | %d |" agg.losers;
      Printf.sprintf "| win_rate_pct | %.4f |" agg.win_rate_pct;
      Printf.sprintf "| mean_return_pct | %.6f |" agg.mean_return_pct;
      Printf.sprintf "| median_return_pct | %.6f |" agg.median_return_pct;
      Printf.sprintf "| total_pnl_dollars | %.2f |" agg.total_pnl_dollars;
    ]
  in
  let header_lines =
    [
      Printf.sprintf "# All-eligible diagnostic — %s" scenario_name;
      "";
      Printf.sprintf "Period: %s to %s"
        (Date.to_string start_date)
        (Date.to_string end_date);
      "";
      "## Aggregate";
      "";
    ]
  in
  let bucket_header = [ ""; "## Return-bucket histogram"; "" ] in
  String.concat ~sep:"\n"
    (header_lines @ stats_lines @ bucket_header @ bucket_lines @ [ "" ])

let _write_config_sexp ~path (config : All_eligible.config) : unit =
  Sexp.save_hum path (All_eligible.sexp_of_config config)

(* ---------------------------------------------------------------- *)
(* Pipeline                                                            *)
(* ---------------------------------------------------------------- *)

(** Build the snapshot world and Friday calendar for [scenario] given [universe]
    / [sectors_tbl]. Mirrors the optimal-strategy runner's private
    [_build_world] but without the macro-trend table (this diagnostic doesn't
    consume one — every Friday treats macro as [Neutral]). *)
let _build_world ~(scenario : Scenario_lib.Scenario.t) ~universe ~sectors_tbl :
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
    _build_snapshot_callbacks ~data_dir_fpath ~universe ~start:warmup_start
      ~end_:scenario.period.end_date
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

let _emit_artefacts ~out_dir ~scenario ~config ~result : unit =
  let trades_path = Filename.concat out_dir "trades.csv" in
  let summary_path = Filename.concat out_dir "summary.md" in
  let config_path = Filename.concat out_dir "config.sexp" in
  write_trades_csv ~path:trades_path result;
  let md =
    format_summary_md ~scenario_name:scenario.Scenario_lib.Scenario.name
      ~start_date:scenario.period.start_date ~end_date:scenario.period.end_date
      ~result
  in
  Out_channel.write_all summary_path ~data:md;
  _write_config_sexp ~path:config_path config;
  eprintf "all_eligible: wrote %s, %s, %s\n%!" trades_path summary_path
    config_path

let run_with_args (args : cli_args) : unit =
  eprintf "all_eligible: loading scenario %s\n%!" args.scenario_path;
  let scenario = Scenario_lib.Scenario.load args.scenario_path in
  let fixtures_root = Scenario_lib.Fixtures_root.resolve () in
  let universe, sectors_tbl = _resolve_universe ~fixtures_root scenario in
  let out_dir = resolve_out_dir ~scenario_name:scenario.name args in
  Core_unix.mkdir_p out_dir;
  let config = resolve_config args in
  let snapshot_callbacks, sector_ctx_map, fridays =
    _build_world ~scenario ~universe ~sectors_tbl
  in
  let scored =
    _scan_and_score ~snapshot_callbacks ~sector_ctx_map ~fridays ~universe
  in
  eprintf "all_eligible: %d scored candidates pre-dedup; deduping...\n%!"
    (List.length scored);
  let deduped = All_eligible.dedup_first_admission scored in
  eprintf "all_eligible: %d candidates post-dedup; grading...\n%!"
    (List.length deduped);
  let result = All_eligible.grade ~config ~scored:deduped in
  _emit_artefacts ~out_dir ~scenario ~config ~result
