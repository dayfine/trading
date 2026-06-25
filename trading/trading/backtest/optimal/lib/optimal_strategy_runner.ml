open Core
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Helpers = Optimal_strategy_runner_helpers
module Scanner = Stage_transition_scanner
module Scorer = Outcome_scorer
module Filler = Optimal_portfolio_filler
module Summary_agg = Optimal_summary
module Report = Optimal_strategy_report
module OT = Optimal_types

(* ---------------------------------------------------------------- *)
(* Constants                                                          *)
(* ---------------------------------------------------------------- *)

let _warmup_days = 210

(** LRU cache cap for the [Daily_panels.t] backing the strategy bar reads. Reads
    [SNAPSHOT_CACHE_MB] (default 256, sized for the sp500 ≈ 500-symbol working
    set); bump it for broad top-3000 runs to avoid cache thrash. *)
let _snapshot_cache_mb = Backtest.Snapshot_world.default_cache_mb ()

(* ---------------------------------------------------------------- *)
(* Forward-walk outlooks for the scorer                               *)
(* ---------------------------------------------------------------- *)

type forward_table = (string, Scorer.weekly_outlook list) Hashtbl.t
(** Per-symbol chronologically-ordered [weekly_outlook list] across the run's
    full Friday calendar. Built once per run (PR-1: optimal-strategy
    improvements 2026-05-01) so per-candidate scoring becomes a list slice
    rather than a fresh 130-week stage re-classification.

    Key: symbol. Value: outlooks sorted ascending by [date], with one entry per
    Friday for which the symbol has enough bars to classify a stage. Fridays
    with insufficient history are simply absent from the list. *)

(** Slice the memoized per-symbol outlook list to keep only Fridays strictly
    after [entry_friday]. Replaces the per-candidate Stage-classification loop
    in the original [_forward_outlooks]. Returns [[]] for symbols absent from
    the table (degenerate case — caller drops the candidate). *)
let forward_outlooks_for ~forward_table ~symbol ~entry_friday :
    Scorer.weekly_outlook list =
  match Hashtbl.find forward_table symbol with
  | None -> []
  | Some outlooks ->
      List.drop_while outlooks ~f:(fun (o : Scorer.weekly_outlook) ->
          Date.( <= ) o.date entry_friday)

(* ---------------------------------------------------------------- *)
(* Macro-trend persistence (read side)                                *)
(* ---------------------------------------------------------------- *)

(** Read [<output_dir>/macro_trend.sexp] and index its entries by Friday for
    O(1) lookup inside [_scan_and_score]. The file is emitted by
    [Backtest.Macro_trend_writer] on every run (PR #671). Missing file or
    malformed sexp ⇒ empty table + stderr warning; the runner's lookup fallback
    is [Weinstein_types.Neutral], so the pipeline still completes. *)
let load_macro_trend ~output_dir :
    (Date.t, Weinstein_types.market_trend) Hashtbl.t =
  let path = Filename.concat output_dir "macro_trend.sexp" in
  let tbl = Hashtbl.create (module Date) in
  if not (Sys_unix.file_exists_exn path) then (
    eprintf
      "optimal_strategy: macro_trend.sexp absent at %s; falling back to \
       Neutral for every Friday\n\
       %!"
      path;
    tbl)
  else
    try
      let entries =
        Backtest.Macro_trend_writer.t_of_sexp (Sexp.load_sexp path)
      in
      List.iter entries ~f:(fun (e : Backtest.Macro_trend_writer.per_friday) ->
          Hashtbl.set tbl ~key:e.date ~data:e.trend);
      tbl
    with exn ->
      eprintf
        "optimal_strategy: failed to read macro_trend.sexp (%s); falling back \
         to Neutral for every Friday\n\
         %!"
        (Exn.to_string exn);
      tbl

(* ---------------------------------------------------------------- *)
(* Scanning + scoring all candidates                                  *)
(* ---------------------------------------------------------------- *)

(** Score each candidate by forward-walking the panel. Drops candidates with no
    forward bars (degenerate end-of-run). Uses the precomputed [forward_table]
    so each candidate's forward outlooks are an O(N_fridays) slice of the
    per-symbol memoized list rather than a fresh Stage-classification sweep. *)
let _score_all_candidates ~forward_table ~scorer_config
    (candidates : OT.candidate_entry list) : OT.scored_candidate list =
  List.filter_map candidates ~f:(fun (c : OT.candidate_entry) ->
      let forward =
        forward_outlooks_for ~forward_table ~symbol:c.symbol
          ~entry_friday:c.entry_week
      in
      Scorer.score ~config:scorer_config ~candidate:c ~forward)

(* ---------------------------------------------------------------- *)
(* Variant build-out                                                  *)
(* ---------------------------------------------------------------- *)

let _build_variant ~filler_config ~variant ~scored ~starting_cash :
    Report.variant_pack =
  let round_trips =
    Filler.fill ~config:filler_config { candidates = scored; variant }
  in
  let summary = Summary_agg.summarize ~starting_cash ~variant round_trips in
  { Report.round_trips; summary }

(* ---------------------------------------------------------------- *)
(* Pipeline phases                                                    *)
(* ---------------------------------------------------------------- *)

let _build_actual_run (inputs : Optimal_run_artefacts.actual_run_inputs) :
    Report.actual_run =
  {
    scenario_name = inputs.scenario_name;
    start_date = inputs.start_date;
    end_date = inputs.end_date;
    universe_size = inputs.universe_size;
    initial_cash = inputs.initial_cash;
    final_portfolio_value = inputs.final_portfolio_value;
    round_trips = inputs.trades;
    win_rate_pct = inputs.win_rate_pct;
    sharpe_ratio = inputs.sharpe_ratio;
    max_drawdown_pct = inputs.max_drawdown_pct;
    profit_factor = Float.nan;
    cascade_rejections = inputs.cascade_rejections;
  }

type _world = {
  snapshot_callbacks : Snapshot_callbacks.t;
  sector_ctx_map : (string, Screener.sector_context) Hashtbl.t;
  fridays : Date.t list;
  universe : string list;
  macro_trend_table : (Date.t, Weinstein_types.market_trend) Hashtbl.t;
      (** Per-Friday macro reading loaded from [macro_trend.sexp]. Populated by
          {!load_macro_trend}; missing entries fall back to [Neutral] inside
          [_scan_and_score]. *)
}
(** Loaded snapshot callbacks + per-symbol sector context + Friday calendar +
    per-Friday macro trends over the run window. Built once per invocation,
    consumed by scan + score. *)

(** Build the snapshot-and-context world.

    The [universe] used here MUST match the actual run's universe (loaded from
    [universe.txt] in [Optimal_run_artefacts.load]). Earlier revisions sourced
    [universe] from [Sector_map.load] (the full ~10k-symbol [data/sectors.csv]
    set), which let the counterfactual cherry-pick trades from symbols the
    actual sp500-2019-2023 backtest never saw — yielding a meaningless ~1997%
    optimal return. The sector_map is still loaded for
    [Helpers.build_sector_context_map], but its keys are no longer the universe
    source. *)
let _build_world ~warehouse_dir ~output_dir ~(actual_run : Report.actual_run)
    ~(universe : string list) : _world =
  let data_dir_fpath = Data_path.default_data_dir () in
  let sectors_tbl = Sector_map.load ~data_dir:data_dir_fpath in
  let warmup_start = Date.add_days actual_run.start_date (-_warmup_days) in
  eprintf "optimal_strategy: building snapshot (%d symbols, %s..%s)\n%!"
    (List.length universe + 1)
    (Date.to_string warmup_start)
    (Date.to_string actual_run.end_date);
  let snapshot_callbacks =
    Backtest.Snapshot_world.build_callbacks ~warehouse_dir
      ~data_dir:data_dir_fpath ~index_symbol:Helpers.index_symbol ~universe
      ~start:warmup_start ~end_:actual_run.end_date
      ~max_cache_mb:_snapshot_cache_mb
  in
  let sector_ctx_map = Helpers.build_sector_context_map sectors_tbl in
  let fridays =
    Helpers.fridays_in_range ~start:actual_run.start_date
      ~end_:actual_run.end_date
  in
  let macro_trend_table = load_macro_trend ~output_dir in
  eprintf "optimal_strategy: macro_trend.sexp loaded (%d Friday entries)\n%!"
    (Hashtbl.length macro_trend_table);
  { snapshot_callbacks; sector_ctx_map; fridays; universe; macro_trend_table }

let _scan_and_score ~(world : _world) : OT.scored_candidate list =
  eprintf "optimal_strategy: scanning %d Fridays\n%!"
    (List.length world.fridays);
  let stock_config = Stock_analysis.default_config in
  let stage_config = stock_config.stage in
  let screener_config = Screener.default_config in
  let scanner_config = Scanner.config_of_screener_config screener_config in
  let scorer_config = Scorer.default_config in
  let candidates =
    Helpers.scan_all_fridays ~snapshot_callbacks:world.snapshot_callbacks
      ~fridays:world.fridays ~universe:world.universe
      ~sector_map:world.sector_ctx_map ~stock_config ~scanner_config
      ~bar_lookback:Helpers.bar_lookback_weeks
      ~macro_trend_table:world.macro_trend_table
  in
  eprintf "optimal_strategy: %d candidates emitted; scoring...\n%!"
    (List.length candidates);
  let forward_table =
    Helpers.build_forward_table ~snapshot_callbacks:world.snapshot_callbacks
      ~fridays:world.fridays ~stage_config
      ~bar_lookback:Helpers.bar_lookback_weeks ~universe:world.universe
  in
  eprintf "optimal_strategy: forward outlooks memoized (%d symbols)\n%!"
    (Hashtbl.length forward_table);
  let scored = _score_all_candidates ~forward_table ~scorer_config candidates in
  eprintf "optimal_strategy: %d scored candidates; filling variants...\n%!"
    (List.length scored);
  scored

let _emit_report ~output_dir ~(actual_run : Report.actual_run) ~scored : unit =
  let filler_config = Filler.default_config in
  let starting_cash = actual_run.initial_cash in
  let constrained =
    _build_variant ~filler_config ~variant:OT.Constrained ~scored ~starting_cash
  in
  let score_picked =
    _build_variant ~filler_config ~variant:OT.Score_picked ~scored
      ~starting_cash
  in
  let relaxed_macro =
    _build_variant ~filler_config ~variant:OT.Relaxed_macro ~scored
      ~starting_cash
  in
  let input : Report.input =
    { actual = actual_run; constrained; score_picked; relaxed_macro }
  in
  let md = Report.render input in
  let out_path = Filename.concat output_dir "optimal_strategy.md" in
  Out_channel.write_all out_path ~data:md;
  eprintf "optimal_strategy: wrote %s\n%!" out_path;
  Optimal_summary_artefact.write ~output_dir
    {
      constrained = constrained.summary;
      score_picked = score_picked.summary;
      relaxed_macro = relaxed_macro.summary;
    }

let run ?warehouse_dir ~output_dir () =
  eprintf "optimal_strategy: reading artefacts from %s\n%!" output_dir;
  let inputs = Optimal_run_artefacts.load ~output_dir in
  let actual_run = _build_actual_run inputs in
  eprintf "optimal_strategy: actual run %s..%s, universe=%d\n%!"
    (Date.to_string actual_run.start_date)
    (Date.to_string actual_run.end_date)
    actual_run.universe_size;
  let world =
    _build_world ~warehouse_dir ~output_dir ~actual_run
      ~universe:inputs.universe
  in
  let scored = _scan_and_score ~world in
  _emit_report ~output_dir ~actual_run ~scored
