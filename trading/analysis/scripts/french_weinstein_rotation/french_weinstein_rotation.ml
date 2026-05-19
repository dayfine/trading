(** Daily-bar Weinstein-style industry rotation on the Kenneth French
    49-Industry daily fixture.

    Pipeline:
    - Load the pinned [french-49ind-2026-05-20.csv.gz] fixture.
    - Filter to the requested block (VW by default, EW available).
    - Compute the rotation strategy via
      {!French_weinstein_rotation_lib.Rotation}.
    - Emit a decade-by-decade table mirroring the M1 Shiller binary, plus a
      headline summary and (optionally) ASCII charts of chosen decades.

    Per [dev/plans/cross-cycle-weinstein-validation-2026-05-19.md] §M2 PR-D. *)

open Core
module Loader = French_weinstein_rotation_lib.Loader
module Rotation = French_weinstein_rotation_lib.Rotation
module Metrics = French_weinstein_rotation_lib.Metrics

(* ────────────────────────────────────────────────────────────
   Pretty-printing
   ──────────────────────────────────────────────────────────── *)

let _format_pct ?(decimals = 2) x = sprintf "%.*f%%" decimals (100.0 *. x)

let _print_table (reports : Rotation.decade_report list) =
  printf
    "\n\
     | Decade  | N days | %% Gross | Strat CAGR | Strat Sharpe | Strat MaxDD | \
     B&H CAGR  | B&H Sharpe | B&H MaxDD |\n\
     |---------|--------|---------|------------|--------------|-------------|-----------|------------|-----------|\n";
  List.iter reports ~f:(fun (r : Rotation.decade_report) ->
      printf
        "| %-7s | %6d | %6.1f%% | %10s | %12.2f | %11s | %9s | %10.2f | %9s |\n"
        r.decade_label r.n_days r.pct_days_invested
        (_format_pct r.strategy_cagr)
        r.strategy_sharpe
        (_format_pct r.strategy_maxdd)
        (_format_pct r.bh_cagr) r.bh_sharpe (_format_pct r.bh_maxdd))

let _trading_days_per_year = 252.0

let _print_headline ~strat ~bh =
  let n = Array.length bh in
  let strat_cum = Metrics.cumulative_return ~returns:strat in
  let bh_cum = Metrics.cumulative_return ~returns:bh in
  let strat_cagr =
    Metrics.cagr ~returns:strat ~periods_per_year:_trading_days_per_year
  in
  let bh_cagr =
    Metrics.cagr ~returns:bh ~periods_per_year:_trading_days_per_year
  in
  let strat_sharpe =
    Metrics.sharpe ~returns:strat ~periods_per_year:_trading_days_per_year
  in
  let bh_sharpe =
    Metrics.sharpe ~returns:bh ~periods_per_year:_trading_days_per_year
  in
  let strat_maxdd = Metrics.max_drawdown ~returns:strat in
  let bh_maxdd = Metrics.max_drawdown ~returns:bh in
  let years = Float.of_int n /. _trading_days_per_year in
  printf
    "\n\
     === Headline (%.1f years, %d trading days) ===\n\
     Strategy : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n\
     B&H (EW) : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n"
    years n (_format_pct strat_cagr) strat_sharpe (_format_pct strat_maxdd)
    strat_cum (_format_pct bh_cagr) bh_sharpe (_format_pct bh_maxdd) bh_cum

let _print_diagnostics ~result =
  let beta =
    Metrics.beta ~strategy:result.Rotation.strategy_daily_returns
      ~market:result.benchmark_daily_returns
  in
  let n_industries = List.length result.industries in
  printf
    "\n\
     === Diagnostics ===\n\
     Industries loaded: %d\n\
     β (strat vs EW market): %.3f (β<1 = lower-vol regime)\n\
     Config: ma_days=%d, rs_days=%d, rebalance_days=%d, top_k=%d, variant=%s\n"
    n_industries beta result.config.ma_trading_days
    result.config.rs_lookback_days result.config.rebalance_days
    result.config.top_k
    (Rotation.show_variant result.config.variant)

(* ────────────────────────────────────────────────────────────
   CLI
   ──────────────────────────────────────────────────────────── *)

let _parse_block_arg = function
  | "VW" -> Loader.VW
  | "EW" -> Loader.EW
  | other ->
      failwithf "french_weinstein_rotation: -block must be VW or EW (got %S)"
        other ()

let _parse_variant_arg = function
  | "long-only" -> Rotation.Long_only
  | "long-short" -> Rotation.Long_short
  | other ->
      failwithf
        "french_weinstein_rotation: -variant must be long-only or long-short \
         (got %S)"
        other ()

let _parse_chart_decades_arg s =
  if String.is_empty s then []
  else
    String.split s ~on:',' |> List.map ~f:String.strip
    |> List.filter ~f:(fun x -> not (String.is_empty x))
    |> List.map ~f:Int.of_string

let _decade_idx_range ~dates ~decade =
  let from_year = decade in
  let to_year = decade + 9 in
  Array.filter_mapi dates ~f:(fun i d ->
      let y = Date.year d in
      if y >= from_year && y <= to_year then Some i else None)

let _print_decade_chart_row ~result ~decade ~idxs =
  let dates = result.Rotation.dates in
  let f = Array.get idxs 0 in
  let t = Array.get idxs (Array.length idxs - 1) in
  let strat_slice =
    Array.sub result.strategy_daily_returns ~pos:f ~len:(t - f + 1)
  in
  let bh_slice =
    Array.sub result.benchmark_daily_returns ~pos:f ~len:(t - f + 1)
  in
  let strat_cum = Metrics.cumulative_return ~returns:strat_slice in
  let bh_cum = Metrics.cumulative_return ~returns:bh_slice in
  printf "  %ds  strat %.2fx  vs  B&H %.2fx  (%s..%s)\n" decade strat_cum bh_cum
    (Date.to_string dates.(f))
    (Date.to_string dates.(t))

let _print_one_decade_chart ~result decade =
  let idxs = _decade_idx_range ~dates:result.Rotation.dates ~decade in
  if not (Array.is_empty idxs) then
    _print_decade_chart_row ~result ~decade ~idxs

let _maybe_print_decade_charts ~chart_decades ~result =
  if List.is_empty chart_decades then ()
  else begin
    printf "\n=== Decade charts (cumulative strategy vs EW market) ===\n";
    List.iter chart_decades ~f:(_print_one_decade_chart ~result)
  end

let _build_config ~ma_days ~rs_days ~rebalance_days ~top_k ~variant
    ~slope_lookback ~slope_threshold =
  {
    Rotation.ma_trading_days = ma_days;
    rs_lookback_days = rs_days;
    rebalance_days;
    top_k;
    variant;
    slope_lookback_days = slope_lookback;
    slope_threshold_pct = slope_threshold;
  }

let _run ~csv_gz ~block ~ma_days ~rs_days ~rebalance_days ~top_k ~variant
    ~slope_lookback ~slope_threshold ~chart_decades =
  let series = Loader.load_block ~csv_gz_path:csv_gz ~block in
  printf "Loaded %d trading days × %d industries (block=%s)\n"
    (Array.length series.rows)
    (List.length series.industries)
    (Loader.show_block series.block);
  let config =
    _build_config ~ma_days ~rs_days ~rebalance_days ~top_k ~variant
      ~slope_lookback ~slope_threshold
  in
  let result =
    Rotation.compute_strategy ~rows:series.rows ~industries:series.industries
      ~config
  in
  _print_table result.decade_reports;
  _print_headline ~strat:result.strategy_daily_returns
    ~bh:result.benchmark_daily_returns;
  _print_diagnostics ~result;
  _maybe_print_decade_charts ~chart_decades ~result

let command =
  Command.basic
    ~summary:
      "Daily-bar Weinstein industry rotation on the Kenneth French 49-Industry \
       dataset"
    (let%map_open.Command csv_gz =
       flag "-csv-gz" (required string)
         ~doc:
           "PATH gzipped derived CSV (block,date,ind1...ind49). See \
            analysis/data/sources/kenneth_french/fixture/"
     and block_s =
       flag "-block"
         (optional_with_default "VW" string)
         ~doc:"VW|EW return block to use (default VW)"
     and variant_s =
       flag "-variant"
         (optional_with_default "long-only" string)
         ~doc:"long-only|long-short (default long-only)"
     and ma_days =
       flag "-ma-trading-days"
         (optional_with_default 150 int)
         ~doc:"INT MA window in trading days (default 150 = 30wk × 5d/wk)"
     and rs_days =
       flag "-rs-lookback-days"
         (optional_with_default 65 int)
         ~doc:
           "INT relative-strength lookback in trading days (default 65 = 13wk \
            × 5d/wk)"
     and rebalance_days =
       flag "-rebalance-days"
         (optional_with_default 5 int)
         ~doc:"INT rebalance cadence in trading days (default 5 = weekly)"
     and top_k =
       flag "-top-k"
         (optional_with_default 5 int)
         ~doc:"INT basket size (default 5)"
     and slope_lookback =
       flag "-slope-lookback-days"
         (optional_with_default 30 int)
         ~doc:"INT slope assessment lookback in trading days (default 30)"
     and slope_threshold =
       flag "-slope-threshold-pct"
         (optional_with_default 0.005 float)
         ~doc:
           "FLOAT MA slope threshold separating Stage 2/4 from 1/3 (default \
            0.005 = 0.5%%)"
     and chart_decades_s =
       flag "-chart-decades"
         (optional_with_default "" string)
         ~doc:
           "CSV comma-separated decade starts to chart, e.g. '1930,1970,2000'"
     in
     fun () ->
       let block = _parse_block_arg block_s in
       let variant = _parse_variant_arg variant_s in
       let chart_decades = _parse_chart_decades_arg chart_decades_s in
       _run ~csv_gz ~block ~ma_days ~rs_days ~rebalance_days ~top_k ~variant
         ~slope_lookback ~slope_threshold ~chart_decades)

let () = Command_unix.run command
