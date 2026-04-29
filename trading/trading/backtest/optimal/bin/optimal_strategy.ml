(** Optimal-strategy counterfactual binary.

    Reads the artefacts written by a prior [scenario_runner.exe] run from
    [--output-dir] and produces [<output_dir>/optimal_strategy.md] — a markdown
    report comparing the actual run's performance against the [Constrained] /
    [Relaxed_macro] counterfactual variants, rendered via
    {!Backtest_optimal.Optimal_strategy_report.render}.

    {1 Pipeline}

    1. Parse [--output-dir] from the CLI. 2. Load [actual.sexp], [summary.sexp],
    [trades.csv] (and optionally [trade_audit.sexp]) to build the renderer's
    [actual_run]. 3. Re-build OHLCV + bar panels over the run's universe +
    period via the same calendar-aware loader [Panel_runner] uses. 4. Walk
    Fridays in [start_date, end_date]:
    - Per symbol: run [Stock_analysis.analyze] via {!Stage_callbacks_from_bars}
      to produce a candidate-eligibility analysis.
    - Build a [Stage_transition_scanner.week_input] and call [scan_week]. 5. For
      each candidate, score forward-weekly outlooks via {!Outcome_scorer.score}
      (walks future Fridays' bar + stage classification). 6. Run
      [Optimal_portfolio_filler.fill] for [Constrained] and [Relaxed_macro];
      summarise each via [Optimal_summary.summarize]. 7. Build the renderer
      input and write [<output_dir>/optimal_strategy.md].

    {1 Macro-trend simplification}

    The actual run records a per-Friday macro trend implicitly — but it is not
    persisted to disk in the run artefacts. The counterfactual bin uses a fixed
    [Neutral] macro trend across all weeks: this makes [passes_macro = true] for
    every candidate (the gate's rule is [macro_trend <> Bearish]), so
    [Constrained] and [Relaxed_macro] tag every candidate the same way. The
    headline comparison still surfaces the cascade-ranking gap; honest
    macro-driven divergence between the two variants is a follow-up that needs
    the macro trend persisted alongside [actual.sexp].

    {1 Outputs}

    - [<output_dir>/optimal_strategy.md] — the markdown report.
    - stderr: progress messages.

    {1 Usage}

    {[
      optimal_strategy.exe --output-dir dev/backtest/scenarios-XYZ/sp500-2019-2023/
    ]} *)

open Core
module Bar_panels = Data_panel.Bar_panels
module Ohlcv_panels = Data_panel.Ohlcv_panels
module Symbol_index = Data_panel.Symbol_index
module Scanner = Backtest_optimal.Stage_transition_scanner
module Scorer = Backtest_optimal.Outcome_scorer
module Filler = Backtest_optimal.Optimal_portfolio_filler
module Summary_agg = Backtest_optimal.Optimal_summary
module Report = Backtest_optimal.Optimal_strategy_report
module OT = Backtest_optimal.Optimal_types

(* ---------------------------------------------------------------- *)
(* CLI parsing                                                       *)
(* ---------------------------------------------------------------- *)

type cli_args = { output_dir : string }
(** Parsed CLI arguments. *)

let _usage_and_exit () =
  eprintf "Usage: optimal_strategy --output-dir <path>\n";
  Stdlib.exit 1

let _parse_args () : cli_args =
  let argv = Sys.get_argv () |> Array.to_list |> List.tl_exn in
  let rec loop output_dir = function
    | [] -> output_dir
    | "--output-dir" :: v :: rest -> loop (Some v) rest
    | _ :: _ -> _usage_and_exit ()
  in
  match loop None argv with
  | Some d -> { output_dir = d }
  | None -> _usage_and_exit ()

(* ---------------------------------------------------------------- *)
(* Loading actual-run artefacts                                       *)
(* ---------------------------------------------------------------- *)

type _actual_sexp_shape = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Mirrors [Backtest.Scenarios.Scenario_runner.actual] — a private record
    written alongside other artefacts. We re-declare the shape locally and parse
    it via the same [@@deriving sexp]. *)

type _summary_sexp_shape = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]
(** Mirrors [Backtest.Summary.t]'s on-disk fields. We use
    [sexp.allow_extra_fields] to tolerate the [metrics] field which we don't
    read here. *)

let _load_actual_sexp ~output_dir : _actual_sexp_shape =
  let path = Filename.concat output_dir "actual.sexp" in
  if not (Sys_unix.file_exists_exn path) then
    failwithf "Missing actual.sexp at %s" path ();
  _actual_sexp_shape_of_sexp (Sexp.load_sexp path)

let _load_summary_sexp ~output_dir : _summary_sexp_shape =
  let path = Filename.concat output_dir "summary.sexp" in
  if not (Sys_unix.file_exists_exn path) then
    failwithf "Missing summary.sexp at %s" path ();
  _summary_sexp_shape_of_sexp (Sexp.load_sexp path)

(* ---------------------------------------------------------------- *)
(* Loading trades.csv                                                 *)
(* ---------------------------------------------------------------- *)

(** Parse one line of trades.csv into a
    [Trading_simulation.Metrics.trade_metrics]. The on-disk format is set by
    [Backtest.Result_writer._write_trade_row]:
    [symbol,entry_date,exit_date,days_held,entry_price,exit_price,
     quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger]. *)
let _parse_trade_row line : Trading_simulation.Metrics.trade_metrics option =
  match String.split line ~on:',' with
  | symbol :: entry_date :: exit_date :: days_held :: entry_price :: exit_price
    :: quantity :: pnl_dollars :: pnl_percent :: _stop_fields -> (
      try
        Some
          {
            symbol;
            entry_date = Date.of_string entry_date;
            exit_date = Date.of_string exit_date;
            days_held = Int.of_string days_held;
            entry_price = Float.of_string entry_price;
            exit_price = Float.of_string exit_price;
            quantity = Float.of_string quantity;
            pnl_dollars = Float.of_string pnl_dollars;
            pnl_percent = Float.of_string pnl_percent;
          }
      with _ -> None)
  | _ -> None

let _load_trades ~output_dir : Trading_simulation.Metrics.trade_metrics list =
  let path = Filename.concat output_dir "trades.csv" in
  if not (Sys_unix.file_exists_exn path) then []
  else
    let lines = In_channel.read_lines path in
    match lines with
    | [] -> []
    | _header :: rows -> List.filter_map rows ~f:_parse_trade_row

(* ---------------------------------------------------------------- *)
(* Optional cascade-rejections from trade_audit.sexp                  *)
(* ---------------------------------------------------------------- *)

(** Harvest one [(symbol, reason)] pair per alternative-skip across the audit.
    Renders the [skip_reason] variant via its sexp atom name. Renderer attaches
    these inline against missed-trade rows; missing audit ⇒ empty list ⇒ rows
    render without reason annotations. *)
let _load_cascade_rejections ~output_dir : (string * string) list =
  let path = Filename.concat output_dir "trade_audit.sexp" in
  if not (Sys_unix.file_exists_exn path) then []
  else
    try
      let blob =
        Backtest.Trade_audit.audit_blob_of_sexp (Sexp.load_sexp path)
      in
      List.concat_map blob.audit_records
        ~f:(fun (rec_ : Backtest.Trade_audit.audit_record) ->
          List.map rec_.entry.alternatives_considered
            ~f:(fun (alt : Backtest.Trade_audit.alternative_candidate) ->
              let reason =
                Sexp.to_string
                  (Backtest.Trade_audit.sexp_of_skip_reason alt.reason_skipped)
              in
              (alt.symbol, reason)))
    with _ -> []

(* ---------------------------------------------------------------- *)
(* Panel construction (cribbed from Panel_runner)                     *)
(* ---------------------------------------------------------------- *)

let _index_symbol = "GSPC.INDX"
let _warmup_days = 210

(** Build the trading-day calendar (weekdays only, holidays kept) over
    [warmup_start..end_]. Same shape Panel_runner uses. *)
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
    Returns the bar panels + the calendar array so callers can resolve dates. *)
let _build_bar_panels ~data_dir_fpath ~universe ~calendar :
    Bar_panels.t * Date.t array =
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
  let bar_panels =
    match Bar_panels.create ~ohlcv ~calendar with
    | Ok p -> p
    | Error err -> failwithf "Bar_panels.create failed: %s" (Status.show err) ()
  in
  (bar_panels, calendar)

(* ---------------------------------------------------------------- *)
(* Per-Friday analysis + scanning                                     *)
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
(* Scanning + scoring all candidates                                  *)
(* ---------------------------------------------------------------- *)

(** Run the scanner over all Fridays in the run and emit candidates. *)
let _scan_all_fridays ~bar_panels ~fridays ~universe ~sector_map ~stock_config
    ~scanner_config ~bar_lookback : OT.candidate_entry list =
  List.concat_map fridays ~f:(fun friday ->
      let analyses =
        List.filter_map universe ~f:(fun sym ->
            _analyze_symbol_on_friday ~bar_panels ~friday ~stock_config
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
(* Top-level                                                          *)
(* ---------------------------------------------------------------- *)

(** Number of weekly bars to slice for each per-Friday analysis. Large enough to
    satisfy the 30-week MA + breakout-base lookback in
    [Stock_analysis.default_config]. *)
let _bar_lookback_weeks = 90

let _scenario_name_of_dir dir =
  let basename = Filename.basename dir in
  if String.is_empty basename then dir else basename

let _build_actual_run ~output_dir : Report.actual_run =
  let actual = _load_actual_sexp ~output_dir in
  let summary = _load_summary_sexp ~output_dir in
  let trades = _load_trades ~output_dir in
  let cascade_rejections = _load_cascade_rejections ~output_dir in
  {
    scenario_name = _scenario_name_of_dir output_dir;
    start_date = summary.start_date;
    end_date = summary.end_date;
    universe_size = summary.universe_size;
    initial_cash = summary.initial_cash;
    final_portfolio_value = summary.final_portfolio_value;
    round_trips = trades;
    win_rate_pct = actual.win_rate;
    sharpe_ratio = actual.sharpe_ratio;
    max_drawdown_pct = actual.max_drawdown_pct;
    profit_factor = Float.nan;
    cascade_rejections;
  }

let main ~output_dir =
  eprintf "optimal_strategy: reading artefacts from %s\n%!" output_dir;
  let actual_run = _build_actual_run ~output_dir in
  eprintf "optimal_strategy: actual run %s..%s, universe=%d\n%!"
    (Date.to_string actual_run.start_date)
    (Date.to_string actual_run.end_date)
    actual_run.universe_size;
  let data_dir_fpath = Data_path.default_data_dir () in
  let sectors_tbl = Sector_map.load ~data_dir:data_dir_fpath in
  let universe =
    Hashtbl.keys sectors_tbl |> List.sort ~compare:String.compare
  in
  let warmup_start = Date.add_days actual_run.start_date (-_warmup_days) in
  let calendar =
    _build_calendar ~start:warmup_start ~end_:actual_run.end_date
  in
  eprintf "optimal_strategy: building panels (%d symbols × %d days)\n%!"
    (List.length universe + 1)
    (Array.length calendar);
  let bar_panels, _ = _build_bar_panels ~data_dir_fpath ~universe ~calendar in
  let sector_ctx_map = _build_sector_context_map sectors_tbl in
  let fridays =
    _fridays_in_range ~start:actual_run.start_date ~end_:actual_run.end_date
  in
  eprintf "optimal_strategy: scanning %d Fridays\n%!" (List.length fridays);
  let stock_config = Stock_analysis.default_config in
  let stage_config = stock_config.stage in
  let screener_config = Screener.default_config in
  let scanner_config = Scanner.config_of_screener_config screener_config in
  let scorer_config = Scorer.default_config in
  let candidates =
    _scan_all_fridays ~bar_panels ~fridays ~universe ~sector_map:sector_ctx_map
      ~stock_config ~scanner_config ~bar_lookback:_bar_lookback_weeks
  in
  eprintf "optimal_strategy: %d candidates emitted; scoring...\n%!"
    (List.length candidates);
  let scored =
    _score_all_candidates ~bar_panels ~all_fridays:fridays ~scorer_config
      ~stage_config ~bar_lookback:_bar_lookback_weeks candidates
  in
  eprintf "optimal_strategy: %d scored candidates; filling variants...\n%!"
    (List.length scored);
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
  eprintf "optimal_strategy: wrote %s\n%!" out_path

let () =
  let { output_dir } = _parse_args () in
  main ~output_dir
