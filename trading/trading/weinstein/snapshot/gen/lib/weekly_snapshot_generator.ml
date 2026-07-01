open Core
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader

type inputs = {
  config : Weinstein_strategy.config;
  system_version : string;
  as_of : Date.t;
  bar_reader : Bar_reader.t;
  ticker_sectors : (string * string) list;
  held_positions : Weekly_snapshot.held_position list;
}

(* Weekly bars for one symbol as of [as_of], using the strategy's own
   aggregation (so what the generator screens on is bit-identical to what the
   live strategy sees). Returns [] when the symbol has no resident bars. *)
let _weekly_bars ~(inputs : inputs) symbol =
  Bar_reader.weekly_bars_for inputs.bar_reader ~symbol
    ~n:inputs.config.lookback_bars ~as_of:inputs.as_of

(* Macro regime for [as_of] from the primary index. Degrades to [Neutral] when
   the index has too few bars (mirrors the strategy's no-index fallback). *)
let _macro_result ~(inputs : inputs) ~index_bars : Macro.result =
  Macro.analyze ~config:inputs.config.macro_config ~index_bars ~ad_bars:[]
    ~global_index_bars:[] ~prior_stage:None ~prior:None

(* Analyse one sector ETF and write its context onto every ticker in that
   sector. ETFs with no bars are skipped; their tickers fall through to the
   screener's Neutral default. *)
let _set_sector_ctx_for_etf ~(inputs : inputs) ~index_bars ~by_sector
    ~sector_map (etf, sector_name) =
  let sector_bars = _weekly_bars ~inputs etf in
  if not (List.is_empty sector_bars) then begin
    let result =
      Sector.analyze ~config:Sector.default_config ~sector_name ~sector_bars
        ~benchmark_bars:index_bars ~constituent_analyses:[] ~prior_stage:None
    in
    let ctx = Sector.sector_context_of result in
    List.iter (Hashtbl.find_multi by_sector sector_name) ~f:(fun ticker ->
        Hashtbl.set sector_map ~key:ticker ~data:ctx)
  end

(* Sector context per ETF, expanded to every ticker in that sector. *)
let _build_sector_map ~(inputs : inputs) ~index_bars :
    (string, Screener.sector_context) Hashtbl.t =
  let sector_map = Hashtbl.create (module String) in
  let by_sector = String.Table.create () in
  List.iter inputs.ticker_sectors ~f:(fun (ticker, sector) ->
      Hashtbl.add_multi by_sector ~key:sector ~data:ticker);
  List.iter inputs.config.sector_etfs
    ~f:(_set_sector_ctx_for_etf ~inputs ~index_bars ~by_sector ~sector_map);
  sector_map

(* Reconstruct the chained prior-week stage the way the backtest does: roll the
   stage classifier over the weekly prefix threading [prior_stage], and return
   the stage AFTER the second-to-last week. The generator is a one-shot with no
   cross-week state, so without this it passed [prior_stage:None] and the
   classifier reset [weeks_advancing] to ~1 for EVERY Stage-2 stock — collapsing
   the whole Stage-2 lifecycle to "Early Stage2" and admitting extended
   advancers the <=4-week gate should reject. See
   [dev/notes/live-generator-prior-stage-bug-2026-07-01.md]. *)
let _chained_prior_stage ~(stage_config : Stage.config) weekly_bars =
  let arr = Array.of_list weekly_bars in
  let n = Array.length arr in
  if n <= 1 then None
  else begin
    let prior = ref None in
    for i = 0 to n - 2 do
      let bars = Array.to_list (Array.sub arr ~pos:0 ~len:(i + 1)) in
      prior :=
        Some
          (Stage.classify ~config:stage_config ~bars ~prior_stage:!prior).stage
    done;
    !prior
  end

(* Analyse one ticker. Symbols with no weekly bars are dropped ([None]) — they
   cannot satisfy the screener's breakout / breakdown rules. *)
let _analyze_ticker ~(inputs : inputs)
    ~(analysis_config : Stock_analysis.config) ~index_bars ticker :
    Stock_analysis.t option =
  let bars = _weekly_bars ~inputs ticker in
  if List.is_empty bars then None
  else
    let prior_stage =
      _chained_prior_stage ~stage_config:analysis_config.stage bars
    in
    Some
      (Stock_analysis.analyze ~config:analysis_config ~ticker ~bars
         ~benchmark_bars:index_bars ~prior_stage ~as_of_date:inputs.as_of)

(* Per-stock analysis for the screened universe. *)
let _analyze_universe ~(inputs : inputs) ~index_bars : Stock_analysis.t list =
  let analysis_config = Stock_analysis.default_config in
  List.filter_map inputs.ticker_sectors ~f:(fun (ticker, _sector) ->
      _analyze_ticker ~inputs ~analysis_config ~index_bars ticker)

let _rs_vs_spy (analysis : Stock_analysis.t) : float option =
  Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.current_normalized)

let _resistance_grade (analysis : Stock_analysis.t) : string option =
  Option.map analysis.resistance ~f:(fun (r : Resistance.result) ->
      Weinstein_types.show_overhead_quality r.quality)

(* Map one screener candidate to the decoupled snapshot shape. The snapshot
   schema is independent of [scored_candidate] (see weekly_snapshot.mli §Design),
   so this is a deliberate field-by-field copy. *)
let _candidate_of_scored (c : Screener.scored_candidate) :
    Weekly_snapshot.candidate =
  {
    symbol = c.ticker;
    score = Float.of_int c.score;
    grade = Weinstein_types.grade_to_string c.grade;
    entry = c.suggested_entry;
    stop = c.suggested_stop;
    sector = c.sector.sector_name;
    rationale = String.concat ~sep:"; " c.rationale;
    rs_vs_spy = _rs_vs_spy c.analysis;
    resistance_grade = _resistance_grade c.analysis;
  }

(* Clean regime label (the [@@deriving show] form is module-qualified, e.g.
   "Weinstein_types.Bullish"; the snapshot schema documents the bare label). *)
let _regime_label : Weinstein_types.market_trend -> string = function
  | Bullish -> "Bullish"
  | Bearish -> "Bearish"
  | Neutral -> "Neutral"

let _macro_context (macro : Macro.result) : Weekly_snapshot.macro_context =
  { regime = _regime_label macro.trend; score = macro.confidence }

(* Rating of one sector ETF, or [None] when it has no bars. *)
let _etf_rating ~(inputs : inputs) ~index_bars (etf, sector_name) =
  let bars = _weekly_bars ~inputs etf in
  if List.is_empty bars then None
  else
    let result =
      Sector.analyze ~config:Sector.default_config ~sector_name
        ~sector_bars:bars ~benchmark_bars:index_bars ~constituent_analyses:[]
        ~prior_stage:None
    in
    Some result.rating

(* [sector_name] if its ETF analyses to the [wanted] rating, else [None]. ETFs
   with no bars are skipped. *)
let _sector_name_if_rated ~(inputs : inputs) ~index_bars ~wanted
    ((_etf, sector_name) as etf_sector) =
  match _etf_rating ~inputs ~index_bars etf_sector with
  | Some rating when Screener.equal_sector_rating rating wanted ->
      Some sector_name
  | Some _ | None -> None

(* Strong / weak sector labels from the ETF-level ratings (deduplicated). *)
let _sectors_by_rating ~(inputs : inputs) ~index_bars wanted =
  List.filter_map inputs.config.sector_etfs
    ~f:(_sector_name_if_rated ~inputs ~index_bars ~wanted)
  |> List.dedup_and_sort ~compare:String.compare

let generate (inputs : inputs) : Weekly_snapshot.t =
  let index_bars = _weekly_bars ~inputs inputs.config.indices.primary in
  let macro = _macro_result ~inputs ~index_bars in
  let sector_map = _build_sector_map ~inputs ~index_bars in
  let stocks = _analyze_universe ~inputs ~index_bars in
  let held_tickers =
    List.map inputs.held_positions
      ~f:(fun (h : Weekly_snapshot.held_position) -> h.symbol)
  in
  let result =
    Screener.screen ~config:inputs.config.screening_config
      ~macro_trend:macro.trend ~sector_map ~stocks ~held_tickers
  in
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = inputs.system_version;
    date = inputs.as_of;
    macro = _macro_context macro;
    sectors_strong = _sectors_by_rating ~inputs ~index_bars Screener.Strong;
    sectors_weak = _sectors_by_rating ~inputs ~index_bars Screener.Weak;
    long_candidates = List.map result.buy_candidates ~f:_candidate_of_scored;
    short_candidates = List.map result.short_candidates ~f:_candidate_of_scored;
    held_positions = inputs.held_positions;
  }
