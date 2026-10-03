(** Disk loaders for the trade-audit report; split out of [Trade_audit_report]
    (file-length cleanup). *)

val read_trades_csv : string -> Trading_simulation.Metrics.trade_metrics list
(** Read trades.csv, tolerating both the post-G2 (with [side]) and legacy
    layouts. Fails on an empty file or an unparseable row. *)

type summary_meta = {
  start_date : Core.Date.t;
  end_date : Core.Date.t;
  universe_size : int;
}
(** Minimal shape of [summary.sexp] needed for the report header. *)

val load_summary_meta : string -> summary_meta option
(** [None] when the file is missing or unparseable. *)

val load_trade_audit : string -> Backtest.Trade_audit.audit_record list
(** Load [trade_audit.sexp] (full blob envelope or bare record list); [[]] when
    the file is missing. *)
