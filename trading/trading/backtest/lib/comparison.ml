open Core
module Metric_type = Trading_simulation_types.Metric_types.Metric_type

type metric_diff = {
  name : string;
  baseline : float option;
  variant : float option;
  delta : float option;
}

type t = {
  baseline_summary : Summary.t;
  variant_summary : Summary.t;
  metric_diffs : metric_diff list;
  scalar_diffs : (string * float) list;
}

(** Single registry mapping each [Metric_type.t] variant to its hand-rolled
    lowercase + underscored output label. Adding a new metric variant requires
    one new row here — both [_metric_label] and [all_metric_types] are derived
    from this table.

    The label is kept stable across refactors of the underlying enum. Existing
    baseline summaries on disk already use this convention (e.g. [total_pnl],
    [sharpe_ratio]). The derived [Metric_type.show] varies with module location
    and is unsuitable as a public label, so it cannot be used here. *)
let _metric_label_table : (Metric_type.t * string) list =
  [
    (TotalPnl, "total_pnl");
    (AvgHoldingDays, "avg_holding_days");
    (WinCount, "win_count");
    (LossCount, "loss_count");
    (WinRate, "win_rate");
    (SharpeRatio, "sharpe_ratio");
    (MaxDrawdown, "max_drawdown");
    (ProfitFactor, "profit_factor");
    (CAGR, "cagr");
    (CalmarRatio, "calmar_ratio");
    (OpenPositionCount, "open_position_count");
    (OpenPositionsValue, "open_positions_value");
    (UnrealizedPnl, "unrealized_pnl");
    (TradeFrequency, "trade_frequency");
    (* M5.2b: returns block *)
    (TotalReturnPct, "total_return_pct");
    (VolatilityPctAnnualized, "volatility_pct_annualized");
    (DownsideDeviationPctAnnualized, "downside_deviation_pct_annualized");
    (BestDayPct, "best_day_pct");
    (WorstDayPct, "worst_day_pct");
    (BestWeekPct, "best_week_pct");
    (WorstWeekPct, "worst_week_pct");
    (BestMonthPct, "best_month_pct");
    (WorstMonthPct, "worst_month_pct");
    (BestQuarterPct, "best_quarter_pct");
    (WorstQuarterPct, "worst_quarter_pct");
    (BestYearPct, "best_year_pct");
    (WorstYearPct, "worst_year_pct");
    (* M5.2b: trade aggregates *)
    (NumTrades, "num_trades");
    (LossRate, "loss_rate");
    (AvgWinDollar, "avg_win_dollar");
    (AvgWinPct, "avg_win_pct");
    (AvgLossDollar, "avg_loss_dollar");
    (AvgLossPct, "avg_loss_pct");
    (LargestWinDollar, "largest_win_dollar");
    (LargestLossDollar, "largest_loss_dollar");
    (AvgTradeSizeDollar, "avg_trade_size_dollar");
    (AvgTradeSizePct, "avg_trade_size_pct");
    (AvgHoldingDaysWinners, "avg_holding_days_winners");
    (AvgHoldingDaysLosers, "avg_holding_days_losers");
    (Expectancy, "expectancy");
    (WinLossRatio, "win_loss_ratio");
    (MaxConsecutiveWins, "max_consecutive_wins");
    (MaxConsecutiveLosses, "max_consecutive_losses");
    (* M5.2c: risk-adjusted *)
    (SortinoRatioAnnualized, "sortino_ratio_annualized");
    (MarRatio, "mar_ratio");
    (OmegaRatio, "omega_ratio");
    (* M5.2c: drawdown analytics *)
    (AvgDrawdownPct, "avg_drawdown_pct");
    (MedianDrawdownPct, "median_drawdown_pct");
    (MaxDrawdownDurationDays, "max_drawdown_duration_days");
    (AvgDrawdownDurationDays, "avg_drawdown_duration_days");
    (TimeInDrawdownPct, "time_in_drawdown_pct");
    (UlcerIndex, "ulcer_index");
    (PainIndex, "pain_index");
    (UnderwaterCurveArea, "underwater_curve_area");
    (* M5.2d: distributional *)
    (Skewness, "skewness");
    (Kurtosis, "kurtosis");
    (CVaR95, "cvar_95");
    (CVaR99, "cvar_99");
    (TailRatio, "tail_ratio");
    (GainToPain, "gain_to_pain");
    (* M5.2d: antifragility *)
    (ConcavityCoef, "concavity_coef");
    (BucketAsymmetry, "bucket_asymmetry");
  ]

let _metric_label (mt : Metric_type.t) : string =
  List.Assoc.find_exn _metric_label_table mt ~equal:Metric_type.equal

let metric_label = _metric_label
let all_metric_types : Metric_type.t list = List.map _metric_label_table ~f:fst

let _diff_for_metric ~baseline_set ~variant_set (mt : Metric_type.t) =
  let b = Map.find baseline_set mt in
  let v = Map.find variant_set mt in
  let delta =
    match (b, v) with Some bv, Some vv -> Some (vv -. bv) | _ -> None
  in
  { name = _metric_label mt; baseline = b; variant = v; delta }

let _build_metric_diffs ~baseline ~variant =
  let baseline_set = baseline.Summary.metrics in
  let variant_set = variant.Summary.metrics in
  List.filter_map all_metric_types ~f:(fun mt ->
      let d = _diff_for_metric ~baseline_set ~variant_set mt in
      match (d.baseline, d.variant) with None, None -> None | _ -> Some d)

let _scalar_diffs ~baseline ~variant =
  [
    ( "final_portfolio_value",
      variant.Summary.final_portfolio_value
      -. baseline.Summary.final_portfolio_value );
    ( "n_round_trips",
      Float.of_int variant.Summary.n_round_trips
      -. Float.of_int baseline.Summary.n_round_trips );
    ( "n_steps",
      Float.of_int variant.Summary.n_steps
      -. Float.of_int baseline.Summary.n_steps );
  ]

let compute ~baseline ~variant =
  {
    baseline_summary = baseline;
    variant_summary = variant;
    metric_diffs = _build_metric_diffs ~baseline ~variant;
    scalar_diffs = _scalar_diffs ~baseline ~variant;
  }

(* ----- Sexp rendering ----- *)

(** Render a [float option] as a sexp atom; [None] becomes [-]. *)
let _float_opt_atom = function
  | None -> Sexp.Atom "-"
  | Some f -> Sexp.Atom (sprintf "%.4f" f)

let _float_atom f = Sexp.Atom (sprintf "%.4f" f)

(** Build a single [(name value)] sexp pair. Pulled out to keep render functions
    flat — the surrounding [Sexp.List] wrapping nests deeply enough on its own.
*)
let _pair name value = Sexp.List [ Sexp.Atom name; value ]

(** Inner [(baseline ..) (variant ..) (delta ..)] sexp body of a metric diff
    row. Returned as a [Sexp.t] (already wrapped in a list) for inclusion in the
    outer pair. *)
let _metric_diff_body (d : metric_diff) =
  Sexp.List
    [
      _pair "baseline" (_float_opt_atom d.baseline);
      _pair "variant" (_float_opt_atom d.variant);
      _pair "delta" (_float_opt_atom d.delta);
    ]

let _metric_diff_to_sexp (d : metric_diff) =
  Sexp.List [ Sexp.Atom d.name; _metric_diff_body d ]

let _scalar_diff_to_sexp (name, delta) = _pair name (_float_atom delta)

let _metric_diffs_block (t : t) =
  _pair "metric_diffs"
    (Sexp.List (List.map t.metric_diffs ~f:_metric_diff_to_sexp))

let _scalar_diffs_block (t : t) =
  _pair "scalar_diffs"
    (Sexp.List (List.map t.scalar_diffs ~f:_scalar_diff_to_sexp))

let to_sexp t =
  Sexp.List
    [
      _pair "baseline_summary" (Summary.sexp_of_t t.baseline_summary);
      _pair "variant_summary" (Summary.sexp_of_t t.variant_summary);
      _metric_diffs_block t;
      _scalar_diffs_block t;
    ]

(* ----- Markdown rendering ----- *)

let _format_float_opt = function None -> "-" | Some f -> sprintf "%.4f" f
let _format_float f = sprintf "%.4f" f

let _markdown_header (t : t) =
  let b = t.baseline_summary in
  let v = t.variant_summary in
  sprintf
    "# Backtest comparison\n\n\
     - Date range: %s .. %s\n\
     - Universe size: %d (baseline) / %d (variant)\n\
     - Initial cash: $%.2f\n\
     - Final portfolio value: $%.2f (baseline) / $%.2f (variant), delta = $%.2f\n\
     - Round-trips: %d (baseline) / %d (variant), delta = %d\n\n"
    (Date.to_string b.start_date)
    (Date.to_string b.end_date)
    b.universe_size v.universe_size b.initial_cash b.final_portfolio_value
    v.final_portfolio_value
    (v.final_portfolio_value -. b.final_portfolio_value)
    b.n_round_trips v.n_round_trips
    (v.n_round_trips - b.n_round_trips)

let _markdown_metric_table_row (d : metric_diff) =
  sprintf "| %s | %s | %s | %s |\n" d.name
    (_format_float_opt d.baseline)
    (_format_float_opt d.variant)
    (_format_float_opt d.delta)

let _markdown_metric_table (t : t) =
  let header = "| Metric | Baseline | Variant | Delta |\n|---|---|---|---|\n" in
  let rows =
    List.map t.metric_diffs ~f:_markdown_metric_table_row |> String.concat
  in
  "## Metric diffs\n\n" ^ header ^ rows ^ "\n"

let _markdown_scalar_table (t : t) =
  let header = "| Field | Delta (variant - baseline) |\n|---|---|\n" in
  let rows =
    List.map t.scalar_diffs ~f:(fun (name, delta) ->
        sprintf "| %s | %s |\n" name (_format_float delta))
    |> String.concat
  in
  "## Scalar diffs\n\n" ^ header ^ rows ^ "\n"

let to_markdown t =
  _markdown_header t ^ _markdown_metric_table t ^ _markdown_scalar_table t

let write_sexp ~output_path t = Sexp.save_hum output_path (to_sexp t)

let write_markdown ~output_path t =
  Out_channel.write_all output_path ~data:(to_markdown t)
