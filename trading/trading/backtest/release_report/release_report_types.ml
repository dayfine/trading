(** Record types (and sexp converters) shared by [Release_report] and
    [Release_report_loader]. Re-exported by [Release_report]; see its .mli for
    field docs. *)

open Core

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  open_positions_value : float option; [@sexp.option]
      (** Post-rename signed mark-to-market value of open positions. Optional
          for backward compat with actual.sexp files written before the rename
          (those carry the same value under [unrealized_pnl] instead). *)
  unrealized_pnl : float option; [@sexp.option]
      (** Post-rename: true unrealized P&L (OpenPositionsValue - cost basis).
          Pre-rename actual.sexp files carry the legacy mtm-value here. *)
  force_liquidations_count : int; [@sexp.default 0]
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type summary_meta = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  n_steps : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type optimal_summary = {
  total_round_trips : int;
  winners : int;
  losers : int;
  total_return_pct : float;
  win_rate_pct : float;
  avg_r_multiple : float;
  profit_factor : float;
  max_drawdown_pct : float;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type optimal_summary_pair = {
  constrained : optimal_summary;
  relaxed_macro : optimal_summary;
  report_path : string;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type all_eligible_summary = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
  trades_csv_path : string;
}
[@@deriving sexp] [@@sexp.allow_extra_fields]

type benchmark_relative_summary = {
  alpha_pct_annualized : float;
  beta : float;
  information_ratio : float;
  tracking_error_pct_annualized : float;
  correlation : float;
}
[@@deriving sexp]

type scenario_run = {
  name : string;
  actual : actual;
  summary : summary_meta;
  peak_rss_kb : int option;
  wall_seconds : float option;
  trade_quality : Trade_audit_report.t option;
  optimal_strategy : optimal_summary_pair option;
  all_eligible : all_eligible_summary option;
  benchmark_relative : benchmark_relative_summary option;
}
[@@deriving sexp]
