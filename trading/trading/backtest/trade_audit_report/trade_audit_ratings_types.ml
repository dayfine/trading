(** Record types, config, and rule metadata for [Trade_audit_ratings].
    Re-exported by [Trade_audit_ratings]; see its .mli for field docs. *)

open Core

(* Configuration ---------------------------------------------------------- *)

type config = {
  trades_per_year_warn : int;
  concentrated_burst_window_days : int;
  exit_early_mfe_fraction : float;
  loser_r_multiple_threshold : float;
  loser_mae_to_realized_ratio : float;
  recent_plunge_lookback_days : int;
  recent_plunge_min_drop_pct : float;
  recent_plunge_proximity_days : int;
  volume_confirmation_min_ratio : float;
}
[@@deriving sexp]

let default_config =
  {
    trades_per_year_warn = 50;
    concentrated_burst_window_days = 30;
    exit_early_mfe_fraction = 0.5;
    loser_r_multiple_threshold = 1.5;
    loser_mae_to_realized_ratio = 1.5;
    recent_plunge_lookback_days = 30;
    recent_plunge_min_drop_pct = 0.10;
    recent_plunge_proximity_days = 5;
    volume_confirmation_min_ratio = 2.0;
  }

(* Core types ------------------------------------------------------------- *)

type hold_time_anomaly = Stopped_immediately | Held_indefinitely | Normal
[@@deriving sexp, eq]

type outcome = Win | Loss [@@deriving sexp, eq]

type rule_outcome = Pass | Fail | Marginal | Not_applicable
[@@deriving sexp, eq]

type rule_id =
  | R1_long_above_30w_ma_flat_or_rising
  | R2_long_breakout_volume_2x
  | R3_no_long_in_stage_4
  | R4_short_below_30w_ma_flat_or_falling
  | R5_short_stage_4_breakdown
  | R6_no_recent_plunge
  | R7_exit_on_stage_3_to_4
  | R8_macro_alignment
[@@deriving sexp, eq]

type rule_evaluation = { rule : rule_id; outcome : rule_outcome }
[@@deriving sexp]

type rating = {
  symbol : string;
  entry_date : Date.t;
  r_multiple : float;
  mfe_pct : float;
  mae_pct : float;
  hold_time_anomaly : hold_time_anomaly;
  outcome : outcome;
  weinstein_score : float;
}
[@@deriving sexp]

type outlier_trade = { symbol : string; entry_date : Date.t; metric : string }
[@@deriving sexp]

type over_trading = {
  total_trades : int;
  trades_per_year : float;
  exceeds_threshold : bool;
  concentrated_burst_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type exit_winners_too_early = {
  winners_evaluated : int;
  flagged_count : int;
  avg_left_on_table_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type exit_losers_too_late = {
  losers_evaluated : int;
  flagged_count : int;
  stop_discipline_pct : float;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type cascade_quartile = Q1_top | Q2 | Q3 | Q4_bottom [@@deriving sexp, eq]

type cascade_quartile_stat = {
  quartile : cascade_quartile;
  trade_count : int;
  win_count : int;
  win_rate_pct : float;
}
[@@deriving sexp]

type entering_losers_often = {
  per_quartile : cascade_quartile_stat list;
  flagged_count : int;
  outliers : outlier_trade list;
}
[@@deriving sexp]

type behavioral_metrics = {
  over_trading : over_trading;
  exit_winners_too_early : exit_winners_too_early;
  exit_losers_too_late : exit_losers_too_late;
  entering_losers_often : entering_losers_often;
}
[@@deriving sexp]

type rule_violation_summary = {
  rule : rule_id;
  fail_count : int;
  marginal_count : int;
  applicable_count : int;
  pass_rate_pct : float;
}
[@@deriving sexp]

type weinstein_aggregate = {
  per_rule : rule_violation_summary list;
  spirit_score : float;
  trades_with_critical_violation : outlier_trade list;
}
[@@deriving sexp]

type decision_quality_matrix = {
  per_quartile : cascade_quartile_stat list;
  total_trades : int;
  overall_win_rate_pct : float;
}
[@@deriving sexp]

(* Rule metadata ---------------------------------------------------------- *)

let all_rules =
  [
    R1_long_above_30w_ma_flat_or_rising;
    R2_long_breakout_volume_2x;
    R3_no_long_in_stage_4;
    R4_short_below_30w_ma_flat_or_falling;
    R5_short_stage_4_breakdown;
    R6_no_recent_plunge;
    R7_exit_on_stage_3_to_4;
    R8_macro_alignment;
  ]

let rule_label = function
  | R1_long_above_30w_ma_flat_or_rising -> "R1"
  | R2_long_breakout_volume_2x -> "R2"
  | R3_no_long_in_stage_4 -> "R3"
  | R4_short_below_30w_ma_flat_or_falling -> "R4"
  | R5_short_stage_4_breakdown -> "R5"
  | R6_no_recent_plunge -> "R6"
  | R7_exit_on_stage_3_to_4 -> "R7"
  | R8_macro_alignment -> "R8"

let rule_description = function
  | R1_long_above_30w_ma_flat_or_rising ->
      "Long entry above 30w MA AND MA flat-or-rising (Ch.2, \xc2\xa74.1)"
  | R2_long_breakout_volume_2x ->
      "Long entry breakout with volume \xe2\x89\xa52x avg (Ch.4)"
  | R3_no_long_in_stage_4 -> "Never long in Stage 4 (Ch.2, CRITICAL)"
  | R4_short_below_30w_ma_flat_or_falling ->
      "Short entry below 30w MA AND MA flat-or-falling (Ch.7, \xc2\xa76.1)"
  | R5_short_stage_4_breakdown -> "Short entry is a Stage-4 breakdown (Ch.7)"
  | R6_no_recent_plunge ->
      "No entry within 5d of a 10% drop in last 30d (Ch.4 \xe2\x80\x94 \
       plunge-buy avoidance)"
  | R7_exit_on_stage_3_to_4 ->
      "Exit on Stage3 \xe2\x86\x92 Stage4 transition, and never reach \
       force-liquidation (Ch.6)"
  | R8_macro_alignment ->
      "Macro alignment: Bullish for longs, Bearish for shorts (Ch.3, Ch.8)"
