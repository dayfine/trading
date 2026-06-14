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

(* Sector context per ETF, expanded to every ticker in that sector. ETFs with no
   bars are skipped; their tickers fall through to the screener's Neutral
   default. *)
let _build_sector_map ~(inputs : inputs) ~index_bars :
    (string, Screener.sector_context) Hashtbl.t =
  let sector_map = Hashtbl.create (module String) in
  let by_sector = String.Table.create () in
  List.iter inputs.ticker_sectors ~f:(fun (ticker, sector) ->
      Hashtbl.add_multi by_sector ~key:sector ~data:ticker);
  List.iter inputs.config.sector_etfs ~f:(fun (etf, sector_name) ->
      let sector_bars = _weekly_bars ~inputs etf in
      if not (List.is_empty sector_bars) then
        let result =
          Sector.analyze ~config:Sector.default_config ~sector_name ~sector_bars
            ~benchmark_bars:index_bars ~constituent_analyses:[]
            ~prior_stage:None
        in
        let ctx = Sector.sector_context_of result in
        List.iter (Hashtbl.find_multi by_sector sector_name) ~f:(fun ticker ->
            Hashtbl.set sector_map ~key:ticker ~data:ctx));
  sector_map

(* Per-stock analysis for the screened universe. Symbols with no weekly bars are
   dropped — they cannot satisfy the screener's breakout / breakdown rules. *)
let _analyze_universe ~(inputs : inputs) ~index_bars : Stock_analysis.t list =
  let analysis_config = Stock_analysis.default_config in
  List.filter_map inputs.ticker_sectors ~f:(fun (ticker, _sector) ->
      let bars = _weekly_bars ~inputs ticker in
      if List.is_empty bars then None
      else
        Some
          (Stock_analysis.analyze ~config:analysis_config ~ticker ~bars
             ~benchmark_bars:index_bars ~prior_stage:None
             ~as_of_date:inputs.as_of))

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

(* Strong / weak sector labels from the ETF-level ratings (deduplicated). *)
let _sectors_by_rating ~(inputs : inputs) ~index_bars wanted =
  List.filter_map inputs.config.sector_etfs ~f:(fun (etf, sector_name) ->
      let bars = _weekly_bars ~inputs etf in
      if List.is_empty bars then None
      else
        let result =
          Sector.analyze ~config:Sector.default_config ~sector_name
            ~sector_bars:bars ~benchmark_bars:index_bars
            ~constituent_analyses:[] ~prior_stage:None
        in
        if Screener.equal_sector_rating result.rating wanted then
          Some sector_name
        else None)
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
