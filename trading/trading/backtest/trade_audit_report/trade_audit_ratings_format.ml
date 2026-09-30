(** Markdown formatters for [Trade_audit_ratings]. Re-exported by
    [Trade_audit_ratings]; see its .mli for the contract. *)

open Core
open Trade_audit_ratings_types

let _outcome_label = function Win -> "W" | Loss -> "L"

let _quartile_label = function
  | Q1_top -> "Q1 (top)"
  | Q2 -> "Q2"
  | Q3 -> "Q3"
  | Q4_bottom -> "Q4 (bottom)"

let _fmt_pct_signed v = if Float.is_nan v then "—" else sprintf "%+.2f%%" v
let _fmt_pct_unsigned v = if Float.is_nan v then "—" else sprintf "%.2f%%" v
let _fmt_r_multiple v = if Float.is_nan v then "—" else sprintf "%+.2fR" v
let _fmt_score v = if Float.is_nan v then "—" else sprintf "%.2f" v

let _outlier_lines ~max_n outliers =
  let head = List.take outliers max_n in
  if List.is_empty head then [ "  _none_" ]
  else
    List.map head ~f:(fun o ->
        sprintf "  - %s %s — %s" o.symbol (Date.to_string o.entry_date) o.metric)

let _hold_anomaly_label = function
  | Stopped_immediately -> "stopped_imm"
  | Held_indefinitely -> "held_indef"
  | Normal -> "normal"

let _format_rating_row (r : rating) =
  sprintf "| %s | %s | %s | %s | %s | %s | %s | %s |" r.symbol
    (Date.to_string r.entry_date)
    (_outcome_label r.outcome)
    (_fmt_r_multiple r.r_multiple)
    (_fmt_pct_signed (r.mfe_pct *. 100.0))
    (_fmt_pct_signed (r.mae_pct *. 100.0))
    (_hold_anomaly_label r.hold_time_anomaly)
    (_fmt_score r.weinstein_score)

let format_per_trade_extras ~ratings : string list =
  let header =
    [
      "## Per-trade ratings";
      "";
      "| symbol | entry_date | outcome | r_multiple | mfe_% | mae_% | \
       hold_anomaly | weinstein_score |";
      "|---|---|---|---:|---:|---:|---|---:|";
    ]
  in
  let body =
    if List.is_empty ratings then [ "_No ratings._" ]
    else List.map ratings ~f:_format_rating_row
  in
  header @ body @ [ "" ]

let _format_over_trading (ot : over_trading) =
  let tpy =
    if Float.is_nan ot.trades_per_year then "—"
    else sprintf "%.1f" ot.trades_per_year
  in
  let warn = if ot.exceeds_threshold then " (ABOVE threshold)" else "" in
  [
    "### (a) Over-trading";
    sprintf "- Total trades: %d" ot.total_trades;
    sprintf "- Trades / year: %s%s" tpy warn;
    sprintf "- Concentrated-burst share: %.1f%%" ot.concentrated_burst_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 ot.outliers
  @ [ "" ]

let _format_exit_winners (ew : exit_winners_too_early) =
  [
    "### (b) Exit-winners-too-early";
    sprintf "- Winners evaluated: %d" ew.winners_evaluated;
    sprintf "- Flagged (realized < %.0f%% of MFE): %d" 50.0 ew.flagged_count;
    sprintf "- Avg pp left on the table: %.2f" ew.avg_left_on_table_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 ew.outliers
  @ [ "" ]

let _format_exit_losers (el : exit_losers_too_late) =
  [
    "### (c) Exit-losers-too-late";
    sprintf "- Losers evaluated: %d" el.losers_evaluated;
    sprintf "- Flagged (|R|>1.5 or MAE\xe2\x89\xa51.5\xc3\x97realized): %d"
      el.flagged_count;
    sprintf "- Stop discipline (|R|\xe2\x89\xa41.0): %.1f%%"
      el.stop_discipline_pct;
    "- Outliers (top 5):";
  ]
  @ _outlier_lines ~max_n:5 el.outliers
  @ [ "" ]

let _format_entering_losers (lo : entering_losers_often) =
  let rows =
    List.map lo.per_quartile ~f:(fun s ->
        sprintf "| %s | %d | %d | %.1f%% |"
          (_quartile_label s.quartile)
          s.trade_count s.win_count s.win_rate_pct)
  in
  [
    "### (d) Entering-losers-too-often (cascade quartile vs outcome)";
    "";
    "| quartile | trades | wins | win_rate |";
    "|---|---:|---:|---:|";
  ]
  @ rows
  @ [
      "";
      sprintf "- Flagged outliers: %d" lo.flagged_count;
      "- Outliers (top 5):";
    ]
  @ _outlier_lines ~max_n:5 lo.outliers
  @ [ "" ]

let format_behavioral_section (m : behavioral_metrics) : string list =
  [ "## Behavioural metrics"; "" ]
  @ _format_over_trading m.over_trading
  @ _format_exit_winners m.exit_winners_too_early
  @ _format_exit_losers m.exit_losers_too_late
  @ _format_entering_losers m.entering_losers_often

let _format_rule_row (s : rule_violation_summary) =
  let passes = s.applicable_count - s.fail_count - s.marginal_count in
  sprintf "| %s | %s | %d / %d | %.1f%% | %d |" (rule_label s.rule)
    (rule_description s.rule) passes s.applicable_count s.pass_rate_pct
    s.fail_count

let format_weinstein_section (w : weinstein_aggregate) : string list =
  let header =
    [
      "## Weinstein conformance";
      "";
      sprintf "- Spirit score (avg per-trade): %s" (_fmt_score w.spirit_score);
      "";
      "| rule | description | passed/applicable | pass_rate | fails |";
      "|---|---|---:|---:|---:|";
    ]
  in
  let rows = List.map w.per_rule ~f:_format_rule_row in
  let critical =
    if List.is_empty w.trades_with_critical_violation then
      [ ""; "- No critical (R3) violations." ]
    else
      "" :: "- Critical R3 violations:"
      :: _outlier_lines ~max_n:10 w.trades_with_critical_violation
  in
  header @ rows @ critical @ [ "" ]

let format_decision_quality_section (m : decision_quality_matrix) : string list
    =
  let row (s : cascade_quartile_stat) =
    sprintf "| %s | %d | %d | %.1f%% |"
      (_quartile_label s.quartile)
      s.trade_count s.win_count s.win_rate_pct
  in
  [
    "## Decision quality (cascade quartile vs outcome)";
    "";
    sprintf "- Total trades: %d" m.total_trades;
    sprintf "- Overall win rate: %s" (_fmt_pct_unsigned m.overall_win_rate_pct);
    "";
    "| quartile | trades | wins | win_rate |";
    "|---|---:|---:|---:|";
  ]
  @ List.map m.per_quartile ~f:row
  @ [ "" ]
