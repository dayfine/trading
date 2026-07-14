(** KPI-tile row for the interactive report, computed from the run summary +
    reused report header. Every tile's [value] / [sub] is a formatted string
    derived from the run data — never hardcoded. *)

open Core

val of_run :
  report:Trade_audit_report.t ->
  metrics:(string * float) list ->
  initial_cash:float ->
  final_nav:float ->
  benchmark:(Date.t * float) list option ->
  benchmark_label:string ->
  Html_data.kpi_tile list
(** Build the KPI tiles: Final NAV (hero), MTM return, realized PnL, win rate,
    plus a benchmark-return tile when [benchmark] is present and CAGR / Sharpe
    tiles when the corresponding [metrics] (short-suffix keys ["cagr"],
    ["sharperatio"], ["maxdrawdown"]) are available. *)
