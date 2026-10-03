(** Record types of the trade-audit report. See [trade_audit_report.mli]. *)

open Core

(* Types ------------------------------------------------------------------ *)

type scenario_header = {
  scenario_name : string option;
  period_start : Date.t option;
  period_end : Date.t option;
  universe_size : int option;
  total_round_trips : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  total_realized_return_pct : float;
}
[@@deriving sexp]

type best_worst = {
  best : (string * Date.t * float) option;
  worst : (string * Date.t * float) option;
}
[@@deriving sexp]

type per_trade_row = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  side : Trading_base.Types.position_side;
  entry_price : float;
  exit_price : float;
  pnl_dollars : float;
  pnl_percent : float;
  exit_trigger : string;
  entry_stage : Weinstein_types.stage option;
  entry_rs_trend : Weinstein_types.rs_trend option;
  entry_macro_trend : Weinstein_types.market_trend option;
  cascade_grade : Weinstein_types.grade option;
  cascade_score : int option;
  fill_vs_trigger_pct : float option;
  faithful : bool option;
}
[@@deriving sexp]

type analysis = {
  ratings : Trade_audit_ratings.rating list;
  behavioral : Trade_audit_ratings.behavioral_metrics;
  weinstein : Trade_audit_ratings.weinstein_aggregate;
  decision_quality : Trade_audit_ratings.decision_quality_matrix;
}
[@@deriving sexp]

type t = {
  header : scenario_header;
  best_worst : best_worst;
  rows : per_trade_row list;
  analysis : analysis option;
  split_safe_tally : Backtest.Split_safe_metric.tally;
}
[@@deriving sexp]
