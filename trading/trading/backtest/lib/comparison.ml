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

(** Hand-rolled lowercase + underscored metric name, kept stable across
    refactors of the underlying enum. Existing baseline summaries on disk
    already use this convention (e.g. [total_pnl], [sharpe_ratio]). The derived
    [Metric_type.show] varies with module location and is unsuitable as a public
    label. *)
let _metric_label : Metric_type.t -> string = function
  | TotalPnl -> "total_pnl"
  | AvgHoldingDays -> "avg_holding_days"
  | WinCount -> "win_count"
  | LossCount -> "loss_count"
  | WinRate -> "win_rate"
  | SharpeRatio -> "sharpe_ratio"
  | MaxDrawdown -> "max_drawdown"
  | ProfitFactor -> "profit_factor"
  | CAGR -> "cagr"
  | CalmarRatio -> "calmar_ratio"
  | OpenPositionCount -> "open_position_count"
  | OpenPositionsValue -> "open_positions_value"
  | UnrealizedPnl -> "unrealized_pnl"
  | TradeFrequency -> "trade_frequency"

let _all_metric_types : Metric_type.t list =
  [
    TotalPnl;
    AvgHoldingDays;
    WinCount;
    LossCount;
    WinRate;
    SharpeRatio;
    MaxDrawdown;
    ProfitFactor;
    CAGR;
    CalmarRatio;
    OpenPositionCount;
    OpenPositionsValue;
    UnrealizedPnl;
    TradeFrequency;
  ]

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
  List.filter_map _all_metric_types ~f:(fun mt ->
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

let _metric_diff_to_sexp (d : metric_diff) =
  Sexp.List
    [
      Sexp.Atom d.name;
      Sexp.List
        [
          Sexp.List [ Sexp.Atom "baseline"; _float_opt_atom d.baseline ];
          Sexp.List [ Sexp.Atom "variant"; _float_opt_atom d.variant ];
          Sexp.List [ Sexp.Atom "delta"; _float_opt_atom d.delta ];
        ];
    ]

let _scalar_diff_to_sexp (name, delta) =
  Sexp.List [ Sexp.Atom name; _float_atom delta ]

let to_sexp t =
  Sexp.List
    [
      Sexp.List
        [ Sexp.Atom "baseline_summary"; Summary.sexp_of_t t.baseline_summary ];
      Sexp.List
        [ Sexp.Atom "variant_summary"; Summary.sexp_of_t t.variant_summary ];
      Sexp.List
        [
          Sexp.Atom "metric_diffs";
          Sexp.List (List.map t.metric_diffs ~f:_metric_diff_to_sexp);
        ];
      Sexp.List
        [
          Sexp.Atom "scalar_diffs";
          Sexp.List (List.map t.scalar_diffs ~f:_scalar_diff_to_sexp);
        ];
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
