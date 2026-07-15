(** Shared data vocabulary for the interactive trade-audit report. See [.mli].
*)

open Core

type open_position = {
  symbol : string;
  entry_date : Date.t;
  entry_price : float;
  quantity : float;
  mark : float;
  value : float;
  unrealized : float;
  gain_pct : float;
}
[@@deriving sexp]

type trade_series = {
  dates : Date.t list;
  closes : float list;
  wma30 : float list;
  entry_idx : int;
  exit_idx : int;
  entry_stop : float option;
  exit_stop : float option;
}
[@@deriving sexp]

type trade_row = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
  exit_trigger : string;
  stage : string;
  stop_kind : string;
  cascade_score : int option;
  quality : Trade_audit_report.Trade_score.t option;
  series : trade_series option;
}
[@@deriving sexp]

type kpi_tile = { label : string; value : string; sub : string; hero : bool }
[@@deriving sexp]

type data = {
  scenario_name : string;
  subtitle : string;
  initial_cash : float;
  final_nav : float;
  curve : (Date.t * float) list;
  benchmark : (Date.t * float) list option;
  benchmark_label : string;
  utilization : float list option;
  opens : open_position list;
  stale_held : string list;
  kpis : kpi_tile list;
  analysis : Trade_audit_report.analysis option;
  trades : trade_row list;
}
[@@deriving sexp]
