(** Pure markdown renderer for the optimal-strategy counterfactual report.

    See [optimal_strategy_report.mli] for the API contract. *)

open Core

type variant_pack = {
  round_trips : Optimal_types.optimal_round_trip list;
  summary : Optimal_types.optimal_summary;
}

type actual_run = {
  scenario_name : string;
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  initial_cash : float;
  final_portfolio_value : float;
  round_trips : Trading_simulation.Metrics.trade_metrics list;
  win_rate_pct : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  profit_factor : float;
  cascade_rejections : (string * string) list;
}

type input = {
  actual : actual_run;
  constrained : variant_pack;
  score_picked : variant_pack;
  relaxed_macro : variant_pack;
}

(* ---------------------------------------------------------------- *)
(* Number formatting helpers                                         *)
(* ---------------------------------------------------------------- *)

let _fmt_pct_signed v = sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = sprintf "%.2f%%" v
let _fmt_float_2 v = sprintf "%.2f" v
let _fmt_int i = Int.to_string i
let _fmt_float_or_inf v = if Float.is_finite v then sprintf "%.2f" v else "∞"
let _fmt_pp v = sprintf "%+.2f pp" v

(** Convert a counterfactual fractional return (e.g. [0.30]) to percentage
    points (e.g. [30.0]). The actual run reports its return already in
    percentage units (e.g. [+18.5]) — keep them comparable. *)
let _frac_to_pct v = v *. 100.0

(** Convert a counterfactual fractional drawdown (e.g. [0.42]) to percentage. *)
let _dd_frac_to_pct v = v *. 100.0

(** Counterfactual win-rate is stored as a fraction; the actual run reports
    percentage. Normalise both to percentage for table rendering. *)
let _wr_frac_to_pct v = v *. 100.0

(** Total return percentage of the actual run, derived from
    [(final - initial) / initial * 100]. *)
let _actual_total_return_pct (a : actual_run) : float =
  if Float.(a.initial_cash <= 0.0) then 0.0
  else (a.final_portfolio_value -. a.initial_cash) /. a.initial_cash *. 100.0

(** Mean R-multiple over a list of [Metrics.trade_metrics]. The actual side does
    not record R-multiples directly, so we approximate by the per-trade
    [pnl_percent] (already a percentage of entry price) — this is a rough proxy,
    but the headline table is for human comparison; the exact stat is in the
    full backtest summary already. *)
let _actual_avg_r (a : actual_run) : float =
  match a.round_trips with
  | [] -> 0.0
  | rts ->
      let n = List.length rts in
      List.sum
        (module Float)
        rts
        ~f:(fun (rt : Trading_simulation.Metrics.trade_metrics) ->
          rt.pnl_percent)
      /. Float.of_int n /. 100.0

(* ---------------------------------------------------------------- *)
(* Section: run header                                                *)
(* ---------------------------------------------------------------- *)

let _section_header (input : input) : string list =
  let a = input.actual in
  [
    sprintf "# Optimal-strategy counterfactual — %s" a.scenario_name;
    "";
    sprintf "- Period: %s → %s"
      (Date.to_string a.start_date)
      (Date.to_string a.end_date);
    sprintf "- Universe: %d symbols" a.universe_size;
    sprintf "- Starting cash: $%s" (_fmt_float_2 a.initial_cash);
    "";
    "**Disclaimer.** The counterfactual uses look-ahead — it scores every \
     candidate's realized exit using future bars, then greedily packs the \
     ranking under the live sizing envelope. It is **unrealizable**: a \
     real-time strategy cannot peek at future R-multiples. Treat the \
     counterfactual as an **upper bound** on what the cascade ranking + sizing \
     envelope could deliver if it were perfectly informed.";
    "";
  ]

(* ---------------------------------------------------------------- *)
(* Section: headline comparison table                                 *)
(* ---------------------------------------------------------------- *)

let _comp_row label ~actual ~constrained_v ~score_picked_v ~relaxed ~delta =
  sprintf "| %s | %s | %s | %s | %s | %s |" label actual constrained_v
    score_picked_v relaxed delta

let _delta_pp ~constrained_v ~actual = _fmt_pp (constrained_v -. actual)

let _row_total_return ~actual_return ~c ~s ~r =
  let constrained_return = _frac_to_pct c.summary.total_return_pct in
  let score_picked_return = _frac_to_pct s.summary.total_return_pct in
  let relaxed_return = _frac_to_pct r.summary.total_return_pct in
  _comp_row "Total return"
    ~actual:(_fmt_pct_signed actual_return)
    ~constrained_v:(_fmt_pct_signed constrained_return)
    ~score_picked_v:(_fmt_pct_signed score_picked_return)
    ~relaxed:(_fmt_pct_signed relaxed_return)
    ~delta:(_delta_pp ~constrained_v:constrained_return ~actual:actual_return)

let _row_win_rate ~(a : actual_run) ~c ~s ~r =
  _comp_row "Win rate"
    ~actual:(_fmt_pct_unsigned a.win_rate_pct)
    ~constrained_v:(_fmt_pct_unsigned (_wr_frac_to_pct c.summary.win_rate_pct))
    ~score_picked_v:(_fmt_pct_unsigned (_wr_frac_to_pct s.summary.win_rate_pct))
    ~relaxed:(_fmt_pct_unsigned (_wr_frac_to_pct r.summary.win_rate_pct))
    ~delta:
      (_delta_pp
         ~constrained_v:(_wr_frac_to_pct c.summary.win_rate_pct)
         ~actual:a.win_rate_pct)

let _row_max_dd ~(a : actual_run) ~c ~s ~r =
  _comp_row "MaxDD"
    ~actual:(sprintf "-%.2f%%" a.max_drawdown_pct)
    ~constrained_v:
      (sprintf "-%.2f%%" (_dd_frac_to_pct c.summary.max_drawdown_pct))
    ~score_picked_v:
      (sprintf "-%.2f%%" (_dd_frac_to_pct s.summary.max_drawdown_pct))
    ~relaxed:(sprintf "-%.2f%%" (_dd_frac_to_pct r.summary.max_drawdown_pct))
    ~delta:
      (_delta_pp
         ~constrained_v:(-._dd_frac_to_pct c.summary.max_drawdown_pct)
         ~actual:(-.a.max_drawdown_pct))

let _row_sharpe ~(a : actual_run) =
  _comp_row "Sharpe"
    ~actual:(_fmt_float_2 a.sharpe_ratio)
    ~constrained_v:"n/a" ~score_picked_v:"n/a" ~relaxed:"n/a" ~delta:"n/a"

let _row_profit_factor ~(a : actual_run) ~c ~s ~r =
  _comp_row "Profit factor"
    ~actual:(_fmt_float_or_inf a.profit_factor)
    ~constrained_v:(_fmt_float_or_inf c.summary.profit_factor)
    ~score_picked_v:(_fmt_float_or_inf s.summary.profit_factor)
    ~relaxed:(_fmt_float_or_inf r.summary.profit_factor)
    ~delta:"—"

let _row_round_trips ~(a : actual_run) ~c ~s ~r =
  _comp_row "Round-trips"
    ~actual:(_fmt_int (List.length a.round_trips))
    ~constrained_v:(_fmt_int c.summary.total_round_trips)
    ~score_picked_v:(_fmt_int s.summary.total_round_trips)
    ~relaxed:(_fmt_int r.summary.total_round_trips)
    ~delta:"—"

let _row_avg_r ~actual_avg_r ~c ~s ~r =
  _comp_row "Avg R-multiple"
    ~actual:(_fmt_float_2 actual_avg_r)
    ~constrained_v:(_fmt_float_2 c.summary.avg_r_multiple)
    ~score_picked_v:(_fmt_float_2 s.summary.avg_r_multiple)
    ~relaxed:(_fmt_float_2 r.summary.avg_r_multiple)
    ~delta:"—"

(** Header lines for the headline section: title, gap-decomposition narrative,
    and table column header / divider. Pulled out so [_headline_section] stays
    short enough to fit the function-length linter. *)
let _headline_header_lines : string list =
  [
    "## Headline comparison";
    "";
    "Variant ordering reads left-to-right as a gap decomposition:";
    "- **Actual → Score_picked** = cascade-ranking error (closeable: improve \
     scoring).";
    "- **Score_picked → Constrained** = outcome-foresight bonus (uncloseable: \
     requires hindsight).";
    "- **Constrained → Relaxed_macro** = macro-gate cost.";
    "";
    "| Metric | Actual | Optimal (constrained) | Optimal (score_picked) | \
     Optimal (relaxed macro) | Δ to constrained |";
    "|---|---:|---:|---:|---:|---:|";
  ]

let _headline_section (input : input) : string list =
  let a = input.actual in
  let c = input.constrained in
  let s = input.score_picked in
  let r = input.relaxed_macro in
  let actual_return = _actual_total_return_pct a in
  let actual_avg_r = _actual_avg_r a in
  _headline_header_lines
  @ [
      _row_total_return ~actual_return ~c ~s ~r;
      _row_win_rate ~a ~c ~s ~r;
      _row_max_dd ~a ~c ~s ~r;
      _row_sharpe ~a;
      _row_profit_factor ~a ~c ~s ~r;
      _row_round_trips ~a ~c ~s ~r;
      _row_avg_r ~actual_avg_r ~c ~s ~r;
      "";
    ]

(* ---------------------------------------------------------------- *)
(* Top-level                                                          *)
(* ---------------------------------------------------------------- *)

let render (input : input) : string =
  let a = input.actual in
  let lines =
    _section_header input @ _headline_section input
    @ Optimal_strategy_report_sections.divergence_section
        ~actual_round_trips:a.round_trips
        ~constrained_round_trips:input.constrained.round_trips
    @ Optimal_strategy_report_sections.missed_section
        ~actual_round_trips:a.round_trips
        ~constrained_round_trips:input.constrained.round_trips
        ~cascade_rejections:a.cascade_rejections
    @ Optimal_strategy_report_sections.implications_section
        ~actual_initial_cash:a.initial_cash
        ~actual_final_portfolio_value:a.final_portfolio_value
        ~constrained_summary:input.constrained.summary
  in
  String.concat ~sep:"\n" lines ^ "\n"
