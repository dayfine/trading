open Core
open Weinstein_snapshot
module Bar_reader = Weinstein_strategy.Bar_reader

type inputs = {
  config : Weinstein_strategy.config;
  system_version : string;
  as_of : Date.t;
  bar_reader : Bar_reader.t;
  ticker_sectors : (string * string) list;
  live_portfolio : Live_portfolio.t;
  portfolio_is_placeholder : bool;
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

(* Resistance-v2 sketch thunk for one ticker (§D4-D6, live bar-list path).
   When the overhead-supply score is armed ([overhead_supply = Some]), compute
   the sketch from the ticker's FULL daily history — the live path fetches the
   whole daily series ([daily_bars_for] has no lookback cap), which IS the deep
   history, so one Friday costs O(bars) (seconds), not the backtest 5h wall. A
   fetched window shorter than 520 weeks yields an honestly shallow sketch
   ([bars_seen] reflects it) rather than a fabricated one. Disarmed →
   [fun () -> None], bit-identical to the pre-feature bar-list path. *)
let _sketch_thunk ~(inputs : inputs) ~(analysis_config : Stock_analysis.config)
    ticker : unit -> Resistance_supply.sketch option =
  match analysis_config.overhead_supply with
  | None -> fun () -> None
  | Some _ ->
      let daily =
        Bar_reader.daily_bars_for inputs.bar_reader ~symbol:ticker
          ~as_of:inputs.as_of
      in
      let sketch = Live_resistance_sketch.of_daily_bars daily in
      fun () -> sketch

(* Analyse one ticker. Symbols with no weekly bars are dropped ([None]) — they
   cannot satisfy the screener's breakout / breakdown rules.

   Uses the callback shape directly ([callbacks_from_bars] +
   [analyze_with_callbacks], the same two steps [Stock_analysis.analyze] wraps)
   so the resistance-v2 [get_sketch] thunk can be injected. When the sketch is
   disarmed the thunk is [fun () -> None] — identical to the value
   [callbacks_from_bars] already installs, so the result is bit-identical to
   [Stock_analysis.analyze]. *)
let _analyze_ticker ~(inputs : inputs)
    ~(analysis_config : Stock_analysis.config) ~index_bars ticker :
    Stock_analysis.t option =
  let bars = _weekly_bars ~inputs ticker in
  if List.is_empty bars then None
  else
    let prior_stage =
      _chained_prior_stage ~stage_config:analysis_config.stage bars
    in
    let get_sketch = _sketch_thunk ~inputs ~analysis_config ticker in
    let callbacks =
      let base =
        Stock_analysis.callbacks_from_bars ~config:analysis_config ~bars
          ~benchmark_bars:index_bars
      in
      { base with get_sketch }
    in
    Some
      (Stock_analysis.analyze_with_callbacks ~config:analysis_config ~ticker
         ~callbacks ~prior_stage ~as_of_date:inputs.as_of)

(* Per-stock analysis for the screened universe. Threads the strategy config's
   [overhead_supply] (resistance-v2) into the per-stock analysis config so the
   continuous supply score runs on the live path when armed; [None] (default)
   keeps the analysis bit-identical to the binary-grade behaviour.
   [eligible_tickers] is pre-filtered by the sparse-tail gate (see
   [_eligible_tickers]) — this function no longer walks
   [inputs.ticker_sectors] directly. *)
let _analyze_universe ~(inputs : inputs) ~index_bars ~eligible_tickers :
    Stock_analysis.t list =
  let analysis_config =
    {
      Stock_analysis.default_config with
      overhead_supply = inputs.config.overhead_supply;
      entry_anchor_local_range_weeks =
        inputs.config.entry_anchor_local_range_weeks;
    }
  in
  List.filter_map eligible_tickers ~f:(fun ticker ->
      _analyze_ticker ~inputs ~analysis_config ~index_bars ticker)

(* Sparse-tail eligibility gate (issue #2083 fix 1, data hygiene not a Weinstein
   rule): the eligible tickers plus one warning line per dropped one. Disabled by
   default. See [Sparse_tail_gate.partition]. *)
let _eligible_tickers ~(inputs : inputs) tickers =
  Sparse_tail_gate.partition inputs.bar_reader ~as_of:inputs.as_of
    ~min_bars:inputs.config.sparse_tail_min_bars
    ~window_trading_days:inputs.config.sparse_tail_window_trading_days tickers

(* Live ticker-rename detection (issue #2083 fix 2, data hygiene not a Weinstein
   rule): the surviving tickers plus one warning line per detected succession,
   naming the successor so a dropped pick is actionable rather than merely
   absent. Runs BEFORE the sparse-tail gate, on the full ticker list — the
   zombie tail that identifies a superseded ticker is exactly what that gate
   removes. Disabled by default. See [Rename_gate.partition]. *)
let _live_tickers ~(inputs : inputs) tickers =
  Rename_gate.partition inputs.bar_reader ~as_of:inputs.as_of
    ~min_overlap_days:inputs.config.rename_detect_min_overlap_days
    ~match_fraction:inputs.config.rename_detect_match_fraction tickers

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

(* Size a long candidate against the live portfolio, mirroring the backtest's
   fixed-risk sizing. Shorts are left unsized (short entries are default-off in
   the live strategy); they keep the schema defaults. *)
let _size_long ~(inputs : inputs) ~portfolio_value ~sizing_cash candidate =
  Trade_sizing.size_candidate ~risk_config:inputs.config.portfolio_config
    ~portfolio_value ~sizing_cash ~side:`Long
    ~placeholder:inputs.portfolio_is_placeholder candidate

(* Issue #2084 Finding 2: overlays the real structural stop onto a screener
   candidate, replacing its fixed-8% [suggested_stop] proxy — see
   [Stop_recompute]. *)
let _overlay_structural_stop ~(inputs : inputs) ~side candidate =
  Stop_recompute.for_candidate ~stops_config:inputs.config.stops_config
    ~initial_stop_buffer:inputs.config.initial_stop_buffer
    ~bar_reader:inputs.bar_reader ~as_of:inputs.as_of ~side candidate

(* Issue #2103: classifies the candidate's CURRENT close against its (possibly
   weeks-stale) breakout entry — see [Entry_reconcile]. Must run BEFORE
   [_size_long]: the class decides [Weekly_snapshot.expected_fill_price], which
   is what the sizing pass sizes on. Disabled by default. *)
let _reconcile_entry ~(inputs : inputs) ~side candidate =
  Entry_reconcile.for_candidate inputs.bar_reader ~as_of:inputs.as_of ~side
    ~through_band_pct:inputs.config.entry_through_band_pct
    ~extension_max_pct:inputs.config.entry_extension_max_pct candidate

(* Ranked long / short candidate lists, fully decorated — structural stop
   overlay (#2084 F2), entry reconciliation (#2103, BOTH sides), fixed-risk
   sizing (longs only), spike-bar data-suspect flag (#2083 F3, which flags
   rather than drops) — plus the spike warnings:
   [(longs, shorts, spike_warnings)]. See [Spike_bar_gate.flag_candidates].

   Reconciliation sits between the stop overlay and sizing on purpose: the stop
   it reconciles against must already be the structural one, and the class it
   produces is what sizing anchors the fill price to. *)
let _build_candidates ~(inputs : inputs) ~(result : Screener.result)
    ~portfolio_value ~sizing_cash =
  let sc = inputs.config.screening_config in
  let to_candidate =
    Snapshot_display.candidate_of_scored ~weights:sc.weights
      ~early_stage2_max_weeks:sc.early_stage2_max_weeks
  in
  let longs =
    List.map result.buy_candidates ~f:(fun c ->
        to_candidate c
        |> _overlay_structural_stop ~inputs ~side:Trading_base.Types.Long
        |> _reconcile_entry ~inputs ~side:`Long
        |> _size_long ~inputs ~portfolio_value ~sizing_cash)
  in
  let shorts =
    List.map result.short_candidates ~f:(fun c ->
        to_candidate c
        |> _overlay_structural_stop ~inputs ~side:Trading_base.Types.Short
        |> _reconcile_entry ~inputs ~side:`Short)
  in
  let flag_spikes =
    Spike_bar_gate.flag_candidates inputs.bar_reader ~as_of:inputs.as_of
      ~threshold_pct:inputs.config.spike_bar_threshold_pct
  in
  let longs, long_warnings = flag_spikes longs in
  let shorts, short_warnings = flag_spikes shorts in
  (longs, shorts, long_warnings @ short_warnings)

let generate (inputs : inputs) : Weekly_snapshot.t =
  let index_bars = _weekly_bars ~inputs inputs.config.indices.primary in
  let macro = _macro_result ~inputs ~index_bars in
  let sector_map = _build_sector_map ~inputs ~index_bars in
  let live_tickers, rename_warnings =
    _live_tickers ~inputs (List.map inputs.ticker_sectors ~f:fst)
  in
  let eligible_tickers, sparse_warnings =
    _eligible_tickers ~inputs live_tickers
  in
  let stocks = _analyze_universe ~inputs ~index_bars ~eligible_tickers in
  let held_positions, held_tickers =
    Held_position_row.enrich_all inputs.bar_reader ~config:inputs.config
      ~as_of:inputs.as_of inputs.live_portfolio.positions
  in
  let result =
    Screener.screen ~config:inputs.config.screening_config
      ~macro_trend:macro.trend ~sector_map ~stocks ~held_tickers
  in
  let sizing_cash = inputs.live_portfolio.cash in
  let portfolio_value =
    sizing_cash +. Held_position_row.long_market_value held_positions
  in
  let long_candidates, short_candidates, spike_warnings =
    _build_candidates ~inputs ~result ~portfolio_value ~sizing_cash
  in
  (* Names that cleared every screener gate but were cut by the top-N cap
     (#2122 slice d): [grade_admitted - top_n_admitted] per side, floored at 0. *)
  let diag = result.cascade_diagnostics in
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = inputs.system_version;
    date = inputs.as_of;
    macro = Snapshot_display.macro_context macro;
    sectors_strong = _sectors_by_rating ~inputs ~index_bars Screener.Strong;
    sectors_weak = _sectors_by_rating ~inputs ~index_bars Screener.Weak;
    long_candidates;
    short_candidates;
    long_eligible_beyond_cap =
      Int.max 0 (diag.long_grade_admitted - diag.long_top_n_admitted);
    short_eligible_beyond_cap =
      Int.max 0 (diag.short_grade_admitted - diag.short_top_n_admitted);
    held_positions;
    warnings = rename_warnings @ sparse_warnings @ spike_warnings;
  }
