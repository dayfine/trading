(** Supplementary release-report comparison sections: the all-eligible
    opportunity-cost diagnostic and the benchmark-relative (CAPM-style
    residual-return) sub-table.

    Pure string formatting only — no I/O. Extracted from {!Release_report} (a
    file-length cleanup; see [trading/devtools/checks/linter_exceptions.conf])
    to keep both files under the file/function-length limits. This module takes
    small primitive/record inputs rather than {!Release_report}'s domain records
    ([scenario_run] etc.) so it has no dependency on [release_report.ml] —
    avoiding a circular module dependency within the [release_report] library,
    since [Release_report.render] is what calls into this module.
    [Release_report] adapts its loaded [scenario_run] pairs into these shapes
    before calling in. Same pattern as {!Release_report_diagnostics}. *)

(** {1 All-eligible diagnostic} *)

type all_eligible_fields = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;  (** Decimal fraction in \[0.0, 1.0\]. *)
  mean_return_pct : float;  (** Decimal fraction. *)
  median_return_pct : float;  (** Decimal fraction. *)
  total_pnl_dollars : float;
  trades_csv_path : string;
      (** Relative path to the per-trade [trades.csv] drill-down. *)
}
(** Mirrors {!Release_report.all_eligible_summary}'s fields. *)

type all_eligible_pair = {
  ae_name : string;  (** Scenario name, rendered as the section's subheading. *)
  ae_current : all_eligible_fields option;
  ae_prior : all_eligible_fields option;
}
(** One paired scenario's all-eligible inputs. *)

val render_all_eligible : all_eligible_pair list -> string list
(** [render_all_eligible pairs] renders the "## All-eligible diagnostic" section
    as a list of markdown lines (no trailing newline): per-pair trade count /
    winners / losers / win rate / mean+median return / total P&L, current vs
    prior, for every pair where at least one side has [Some _]. Returns [[]]
    when every pair has [None] on both sides — the caller should then omit the
    section entirely. *)

(** {1 Benchmark-relative} *)

type benchmark_relative_fields = {
  alpha_pct_annualized : float;
  beta : float;
  information_ratio : float;
  tracking_error_pct_annualized : float;
  correlation : float;
}
(** Mirrors {!Release_report.benchmark_relative_summary}'s fields. *)

type benchmark_relative_pair = {
  br_name : string;  (** Scenario name, rendered as the section's subheading. *)
  br_current : benchmark_relative_fields option;
  br_prior : benchmark_relative_fields option;
}
(** One paired scenario's benchmark-relative inputs. *)

val render_benchmark_relative : benchmark_relative_pair list -> string list
(** [render_benchmark_relative pairs] renders the "## Benchmark-relative"
    section as a list of markdown lines (no trailing newline): α, β, Information
    Ratio, Tracking Error, and Pearson correlation, current vs prior vs Δ, for
    every pair where at least one side has [Some _]. Returns [[]] when every
    pair has [None] on both sides. *)
