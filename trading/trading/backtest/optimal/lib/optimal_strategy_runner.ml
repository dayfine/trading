open Core
module Bar_panels = Data_panel.Bar_panels
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Symbol_index = Data_panel.Symbol_index
module Scanner = Stage_transition_scanner
module Scorer = Outcome_scorer
module Filler = Optimal_portfolio_filler
module Summary_agg = Optimal_summary
module Report = Optimal_strategy_report
module OT = Optimal_types

(* ---------------------------------------------------------------- *)
(* Constants                                                          *)
(* ---------------------------------------------------------------- *)

let _index_symbol = "GSPC.INDX"
let _warmup_days = 210

(** Weekly-bar lookback per per-Friday analysis. Large enough to cover the
    30-week MA + breakout-base lookback in [Stock_analysis.default_config]. *)
let _bar_lookback_weeks = 90

(* ---------------------------------------------------------------- *)
(* Calendar + panel construction                                      *)
(* ---------------------------------------------------------------- *)

(** Build the trading-day calendar (weekdays only, holidays kept) over
    [start..end_]. Same shape [Panel_runner] uses. *)
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

(** Build a [Bar_panels.t] over [universe ∪ {primary_index}] for the calendar.
*)
let _build_bar_panels ~data_dir_fpath ~universe ~calendar : Bar_panels.t =
  let symbols =
    _index_symbol :: universe |> List.dedup_and_sort ~compare:String.compare
  in
  let symbol_index =
    match Symbol_index.create ~universe:symbols with
    | Ok t -> t
    | Error err ->
        failwithf "Symbol_index.create failed: %s" err.Status.message ()
  in
  let ohlcv =
    match
      Ohlcv_panels.load_from_csv_calendar symbol_index ~data_dir:data_dir_fpath
        ~calendar
    with
    | Ok t -> t
    | Error err ->
        failwithf "Ohlcv_panels.load_from_csv_calendar failed: %s"
          (Status.show err) ()
  in
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwithf "Bar_panels.create failed: %s" (Status.show err) ()

(* ---------------------------------------------------------------- *)
(* Friday calendar                                                    *)
(* ---------------------------------------------------------------- *)

(** Resolve the most recent Friday on or before [d]. *)
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

(** All Fridays in [start, end_], inclusive on each end where a Friday lies in
    range. Drives the per-week scan loop. *)
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
(* Per-Friday analysis                                                *)
(* ---------------------------------------------------------------- *)

(** Run [Stock_analysis.analyze] for one symbol on one Friday. Returns [None]
    when there are not enough bars for the analysis (e.g. early in the run). *)
let _analyze_symbol_on_friday ~bar_panels ~friday ~stock_config ~bar_lookback
    (symbol : string) : Stock_analysis.t option =
  match Bar_panels.column_of_date bar_panels friday with
  | None -> None
  | Some as_of_day -> (
      let weekly =
        Bar_panels.weekly_bars_for bar_panels ~symbol ~n:bar_lookback ~as_of_day
      in
      let benchmark =
        Bar_panels.weekly_bars_for bar_panels ~symbol:_index_symbol
          ~n:bar_lookback ~as_of_day
      in
      match (weekly, benchmark) with
      | [], _ | _, [] -> None
      | _ ->
          Some
            (Stock_analysis.analyze ~config:stock_config ~ticker:symbol
               ~bars:weekly ~benchmark_bars:benchmark ~prior_stage:None
               ~as_of_date:friday))

(** Build a [sector_map] (symbol → [Screener.sector_context]) from a flat
    [sectors : (symbol → sector_name)] table. The screener's sector-context
    expects a [rating] and [stage] per sector; we use [Neutral] / [Stage2] as
    pass-throughs because the counterfactual treats sector caps separately (via
    the filler's [max_sector_concentration]). *)
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

(* ---------------------------------------------------------------- *)
(* Forward-walk outlooks for the scorer                                *)
(* ---------------------------------------------------------------- *)

(** Build a forward [Outcome_scorer.weekly_outlook list] for [symbol] starting
    on the Friday {b after} [entry_friday]. Reads weekly bars + classifies Stage
    at each Friday via [Stage.classify]. Empty list means the run ends at or
    before [entry_friday]. *)
let _forward_outlooks ~bar_panels ~all_fridays ~stage_config ~bar_lookback
    ~symbol ~entry_friday : Scorer.weekly_outlook list =
  let after =
    List.drop_while all_fridays ~f:(fun d -> Date.( <= ) d entry_friday)
  in
  List.filter_map after ~f:(fun friday ->
      match Bar_panels.column_of_date bar_panels friday with
      | None -> None
      | Some as_of_day -> (
          let weekly =
            Bar_panels.weekly_bars_for bar_panels ~symbol ~n:bar_lookback
              ~as_of_day
          in
          match List.last weekly with
          | None -> None
          | Some bar ->
              let stage_result =
                Stage.classify ~config:stage_config ~bars:weekly
                  ~prior_stage:None
              in
              Some { Scorer.date = friday; bar; stage_result }))

(* ---------------------------------------------------------------- *)
(* Macro-trend persistence (read side)                                *)
(* ---------------------------------------------------------------- *)

(** Read [<output_dir>/macro_trend.sexp] and index its entries by Friday for
    O(1) lookup inside [_scan_all_fridays]. The file is emitted by
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

(** Run the scanner over all Fridays in the run and emit candidates. Each week's
    [macro_trend] is sourced from [macro_trend_table] (built from the run's
    [macro_trend.sexp]); Fridays absent from the table fall back to [Neutral].
*)
let _scan_all_fridays ~bar_panels ~fridays ~universe ~sector_map ~stock_config
    ~scanner_config ~bar_lookback ~macro_trend_table : OT.candidate_entry list =
  List.concat_map fridays ~f:(fun friday ->
      let analyses =
        List.filter_map universe ~f:(fun sym ->
            _analyze_symbol_on_friday ~bar_panels ~friday ~stock_config
              ~bar_lookback sym)
      in
      let macro_trend =
        Hashtbl.find macro_trend_table friday
        |> Option.value ~default:Weinstein_types.Neutral
      in
      let week : Scanner.week_input =
        { date = friday; macro_trend; analyses; sector_map }
      in
      Scanner.scan_week ~config:scanner_config week)

(** Score each candidate by forward-walking the panel. Drops candidates with no
    forward bars (degenerate end-of-run). *)
let _score_all_candidates ~bar_panels ~all_fridays ~scorer_config ~stage_config
    ~bar_lookback (candidates : OT.candidate_entry list) :
    OT.scored_candidate list =
  List.filter_map candidates ~f:(fun (c : OT.candidate_entry) ->
      let forward =
        _forward_outlooks ~bar_panels ~all_fridays ~stage_config ~bar_lookback
          ~symbol:c.symbol ~entry_friday:c.entry_week
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
  bar_panels : Bar_panels.t;
  sector_ctx_map : (string, Screener.sector_context) Hashtbl.t;
  fridays : Date.t list;
  universe : string list;
  macro_trend_table : (Date.t, Weinstein_types.market_trend) Hashtbl.t;
      (** Per-Friday macro reading loaded from [macro_trend.sexp]. Populated by
          {!load_macro_trend}; missing entries fall back to [Neutral] inside
          [_scan_all_fridays]. *)
}
(** Loaded panels + per-symbol sector context + Friday calendar + per-Friday
    macro trends over the run window. Built once per invocation, consumed by
    scan + score. *)

(** Build the panels-and-context world.

    The [universe] used here MUST match the actual run's universe (loaded from
    [universe.txt] in [Optimal_run_artefacts.load]). Earlier revisions sourced
    [universe] from [Sector_map.load] (the full ~10k-symbol [data/sectors.csv]
    set), which let the counterfactual cherry-pick trades from symbols the
    actual sp500-2019-2023 backtest never saw — yielding a meaningless ~1997%
    optimal return. The sector_map is still loaded for
    [_build_sector_context_map], but its keys are no longer the universe source.
*)
let _build_world ~output_dir ~(actual_run : Report.actual_run)
    ~(universe : string list) : _world =
  let data_dir_fpath = Data_path.default_data_dir () in
  let sectors_tbl = Sector_map.load ~data_dir:data_dir_fpath in
  let warmup_start = Date.add_days actual_run.start_date (-_warmup_days) in
  let calendar =
    _build_calendar ~start:warmup_start ~end_:actual_run.end_date
  in
  eprintf "optimal_strategy: building panels (%d symbols × %d days)\n%!"
    (List.length universe + 1)
    (Array.length calendar);
  let bar_panels = _build_bar_panels ~data_dir_fpath ~universe ~calendar in
  let sector_ctx_map = _build_sector_context_map sectors_tbl in
  let fridays =
    _fridays_in_range ~start:actual_run.start_date ~end_:actual_run.end_date
  in
  let macro_trend_table = load_macro_trend ~output_dir in
  eprintf "optimal_strategy: macro_trend.sexp loaded (%d Friday entries)\n%!"
    (Hashtbl.length macro_trend_table);
  { bar_panels; sector_ctx_map; fridays; universe; macro_trend_table }

let _scan_and_score ~(world : _world) : OT.scored_candidate list =
  eprintf "optimal_strategy: scanning %d Fridays\n%!"
    (List.length world.fridays);
  let stock_config = Stock_analysis.default_config in
  let stage_config = stock_config.stage in
  let screener_config = Screener.default_config in
  let scanner_config = Scanner.config_of_screener_config screener_config in
  let scorer_config = Scorer.default_config in
  let candidates =
    _scan_all_fridays ~bar_panels:world.bar_panels ~fridays:world.fridays
      ~universe:world.universe ~sector_map:world.sector_ctx_map ~stock_config
      ~scanner_config ~bar_lookback:_bar_lookback_weeks
      ~macro_trend_table:world.macro_trend_table
  in
  eprintf "optimal_strategy: %d candidates emitted; scoring...\n%!"
    (List.length candidates);
  let scored =
    _score_all_candidates ~bar_panels:world.bar_panels
      ~all_fridays:world.fridays ~scorer_config ~stage_config
      ~bar_lookback:_bar_lookback_weeks candidates
  in
  eprintf "optimal_strategy: %d scored candidates; filling variants...\n%!"
    (List.length scored);
  scored

let _emit_report ~output_dir ~(actual_run : Report.actual_run) ~scored : unit =
  let filler_config = Filler.default_config in
  let constrained =
    _build_variant ~filler_config ~variant:OT.Constrained ~scored
      ~starting_cash:actual_run.initial_cash
  in
  let relaxed_macro =
    _build_variant ~filler_config ~variant:OT.Relaxed_macro ~scored
      ~starting_cash:actual_run.initial_cash
  in
  let input : Report.input =
    { actual = actual_run; constrained; relaxed_macro }
  in
  let md = Report.render input in
  let out_path = Filename.concat output_dir "optimal_strategy.md" in
  Out_channel.write_all out_path ~data:md;
  eprintf "optimal_strategy: wrote %s\n%!" out_path;
  Optimal_summary_artefact.write ~output_dir
    { constrained = constrained.summary; relaxed_macro = relaxed_macro.summary }

let run ~output_dir =
  eprintf "optimal_strategy: reading artefacts from %s\n%!" output_dir;
  let inputs = Optimal_run_artefacts.load ~output_dir in
  let actual_run = _build_actual_run inputs in
  eprintf "optimal_strategy: actual run %s..%s, universe=%d\n%!"
    (Date.to_string actual_run.start_date)
    (Date.to_string actual_run.end_date)
    actual_run.universe_size;
  let world = _build_world ~output_dir ~actual_run ~universe:inputs.universe in
  let scored = _scan_and_score ~world in
  _emit_report ~output_dir ~actual_run ~scored
