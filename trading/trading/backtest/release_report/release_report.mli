(** Release perf report — compare two batches of scenario runs (a "current" and
    a "prior" release-gate run) and emit a markdown report.

    Each batch is a directory of the shape produced by
    {!Backtest.Result_writer.write} alongside [scenario_runner.ml]'s
    [actual.sexp]:

    {v
    <batch-dir>/
      <scenario-name>/
        actual.sexp        — total_return_pct, sharpe_ratio, ...
        summary.sexp       — start/end dates, universe size, metrics
        peak_rss_kb.txt    — optional, integer kB (one line)
        wall_seconds.txt   — optional, integer or float seconds (one line)
    v}

    The report compares scenario-by-scenario:

    - Trading metrics (return %, Sharpe, win rate, max DD) — current vs prior
      side-by-side, with a delta column.
    - Peak RSS matrix — current vs prior, ∆%, with a regression flag when ∆%
      exceeds [threshold_rss_pct].
    - Wall-time matrix — current vs prior, ∆%, with a regression flag when ∆%
      exceeds [threshold_wall_pct].

    Only scenarios present in both batches are diffed; scenarios in only one
    side are listed under "current-only" / "prior-only".

    The library is pure: [load] reads from disk, [render] is a deterministic
    pure function on the loaded value. Tests pin the markdown by feeding
    synthetic [t] values directly into [render]. *)

open Core

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  unrealized_pnl : float option;
}
[@@deriving sexp]
(** Trading metrics extracted from a scenario's [actual.sexp]. Mirrors the
    fields written by [scenario_runner.ml]'s [_actual_of_result], with
    [unrealized_pnl] optional for backward-compat with pre-#393 actuals that
    omit the field. *)

type summary_meta = {
  start_date : Date.t;
  end_date : Date.t;
  universe_size : int;
  n_steps : int;
  initial_cash : float;
  final_portfolio_value : float;
}
[@@deriving sexp]
(** Run-shape metadata extracted from a scenario's [summary.sexp]. We only pull
    the run-identifying fields that are useful in a comparison header; detailed
    per-metric data is already in [actual]. *)

type scenario_run = {
  name : string;
  actual : actual;
  summary : summary_meta;
  peak_rss_kb : int option;
  wall_seconds : float option;
  trade_quality : Trade_audit_report.t option;
      (** Loaded from [trade_audit.sexp] + [trades.csv] in the scenario dir when
          present. [None] for pre-PR-2 outputs that did not capture an audit
          trail, or when [trades.csv] is missing. The report renders an
          additional "Trade quality" section for paired scenarios where at least
          one side has [Some _]. *)
}
[@@deriving sexp]
(** One scenario's per-run readings — the [actual] block plus optional
    infra-perf measurements and an optional trade-audit summary. Both
    [peak_rss_kb] and [wall_seconds] are [None] when the corresponding sibling
    files are absent in the batch dir; the report still renders trading metrics
    in that case. [trade_quality] is [None] when no audit artefacts were found
    or when the audit was empty (no trades). *)

type t = {
  current_label : string;
      (** Display label for the current side of the comparison (e.g. the batch
          dir name). *)
  prior_label : string;  (** Display label for the prior side. *)
  paired : (scenario_run * scenario_run) list;
      (** Scenarios with a run on both sides, sorted by name. *)
  current_only : string list;
      (** Scenario names found only in the current batch, sorted. *)
  prior_only : string list;
      (** Scenario names found only in the prior batch, sorted. *)
}
[@@deriving sexp]
(** A loaded comparison: a list of (current, prior) pairs for scenarios present
    in both batches, plus the names of any one-sided scenarios. *)

type thresholds = { threshold_rss_pct : float; threshold_wall_pct : float }
[@@deriving sexp]
(** Regression-flag thresholds — a per-scenario regression is flagged if
    [(current - prior) / prior * 100 > threshold]. Defaults match the
    release-gate procedure in [dev/plans/perf-scenario-catalog-2026-04-25.md]:
    RSS regression > 10%, wall regression > 25%. *)

val default_thresholds : thresholds
(** [{ threshold_rss_pct = 10.0; threshold_wall_pct = 25.0 }]. *)

val load_scenario_run : dir:string -> scenario_run
(** Read [actual.sexp], [summary.sexp], and (optionally) [peak_rss_kb.txt] and
    [wall_seconds.txt] from a single scenario subdirectory. The scenario name is
    taken from the basename of [dir]. Raises [Failure] if [actual.sexp] or
    [summary.sexp] is missing or malformed. *)

val load : current:string -> prior:string -> t
(** Load both batch directories and pair scenarios by name. Each batch directory
    is expected to contain one subdirectory per scenario. *)

val render : ?thresholds:thresholds -> t -> string
(** Render the comparison as a markdown report (returned as a string). Defaults
    to {!default_thresholds}. The output is deterministic for a given [t] — no
    timestamps, no environment-dependent fields. *)
