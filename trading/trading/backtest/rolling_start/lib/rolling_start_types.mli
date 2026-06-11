(** Types + renderers for the rolling-start dispersion report.

    A rolling-start evaluation runs the same scenario from many start dates to a
    fixed end date and collects, per start, a small set of terminal metrics.
    This module names the per-start row ({!per_start}), aggregates the per-start
    rows into a {!report} (a {!Dispersion_stats.summary} per metric), and
    renders the report as both a sexp (machine-readable, for downstream tooling)
    and a human-readable markdown table — mirroring the [walk_forward_render] /
    [walk_forward_report] output style.

    Plan: [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §2 P1. The
    runner that actually executes the N backtests and fills {!per_start} lands
    in a follow-up; this module is the pure assembly + presentation layer the
    runner will call, kept separate so it is testable without a backtest. *)

open Core

type per_start = {
  start_date : Date.t;
      (** The clipped start date this run began from (every run shares one fixed
          end date, omitted here since it is constant across the report). *)
  cagr_pct : float;
      (** Annualised terminal return over [start_date .. end_date]. The primary
          return axis. *)
  max_underwater_vs_initial_pct : float;
      (** Worst (NAV - initial_capital) / initial_capital, in percent, over the
          run — how far below the {b starting stake} NAV ever went (0.0 if never
          below). The capital-relative drawdown metric
          ([MaxUnderwaterVsInitialPct], PR #1471). The psychological-depth lens.
      *)
  max_drawdown_pct : float;
      (** Worst peak-relative drawdown over the run, in percent. Kept alongside
          the capital-relative measure for contrast (plan §1.2: MaxDD demoted
          but not dropped). *)
  benchmark_cagr_pct : float;
      (** Buy-and-hold CAGR of the benchmark over the {b same}
          [start_date .. end_date] window (e.g. BAH-SPY). [Float.nan] when no
          benchmark was configured for the run. Computed via
          {!Rolling_start_runner.bah_cagr_pct}. The head-to-head reference that
          turns the bare strategy CAGR into an [edge]. *)
  edge_pct : float;
      (** [cagr_pct -. benchmark_cagr_pct] — the strategy's annualised
          out/under-performance versus buy-and-hold from this start. [Float.nan]
          when [benchmark_cagr_pct] is [nan]. Positive = strategy beat
          buy-and-hold from this start; negative = lost to it. The primary
          honest-evaluation column. *)
  sharpe : float;
      (** The run's Sharpe ratio (summary [SharpeRatio] metric); [Float.nan] if
          absent. The risk-adjusted lens alongside the raw CAGR — a high-CAGR
          start with a low Sharpe got there with more volatility. *)
  time_underwater_pct : float;
      (** Fraction (percent, [0..100]) of the equity-curve observations sitting
          strictly below their running prior high-water mark
          ({!Convexity_stats.time_underwater_pct}). The duration-of-pain lens
          complementing the depth-of-pain [max_underwater_vs_initial_pct]. [0.0]
          when the equity curve was empty / not supplied. *)
  realized_return_pct : float;
      (** Realized-basis total return:
          [(final_value -. unrealized_pnl -. initial_cash) /. initial_cash *.
           100]. Strips the terminal mark-to-market on still-open positions (the
          summary [UnrealizedPnl] metric) so a single AXTI-style unrealized
          monster cannot flatter a recent-start row — the simplest honest
          realized number. Equals the raw total return when nothing is held at
          end. [Float.nan] only if [initial_cash] is non-positive. *)
}
[@@deriving sexp, equal]
(** One backtest's terminal outcome, tagged with the start date it ran from. *)

type report = {
  end_date : Date.t;  (** The fixed end date every run terminated on. *)
  starts : per_start list;
      (** Per-start rows in start-date order (earliest first). *)
  cagr : Dispersion_stats.summary;
      (** Dispersion of {!per_start.cagr_pct} across [starts]. *)
  max_underwater_vs_initial : Dispersion_stats.summary;
      (** Dispersion of {!per_start.max_underwater_vs_initial_pct} across
          [starts]. *)
  max_drawdown : Dispersion_stats.summary;
      (** Dispersion of {!per_start.max_drawdown_pct} across [starts]. *)
  edge : Dispersion_stats.summary;
      (** Dispersion of {!per_start.edge_pct} across [starts], skipping [nan]
          rows (starts with no benchmark). The headline distribution: median
          edge, worst-start edge ([min]), and spread directly answer "does the
          strategy robustly beat the benchmark across start dates?" An all-[nan]
          / empty edge column yields a zero-[n] summary. *)
}
[@@deriving sexp, equal]
(** The full rolling-start dispersion report: the raw per-start rows plus one
    {!Dispersion_stats.summary} per collected metric. *)

val build : end_date:Date.t -> per_start list -> report
(** [build ~end_date starts] sorts [starts] by [start_date] (ascending) and
    computes a {!Dispersion_stats.summary} for each metric column via
    {!Dispersion_stats.summarize}. The [edge] summary skips [nan] rows (starts
    with no benchmark). An empty [starts] yields all-zero-n summaries — see
    {!Dispersion_stats.summarize}'s empty-list contract. *)

val pct_beating_benchmark : report -> float
(** [pct_beating_benchmark report] is the percentage (in [0.0, 100.0]) of starts
    with a defined ([non-nan]) [edge_pct] that is strictly positive — i.e. the
    share of start dates from which the strategy beat the benchmark's
    buy-and-hold. Computed over only the benchmarked starts (denominator = count
    of non-[nan] [edge_pct]); returns [Float.nan] when no start has a benchmark.
    The single headline robustness number. *)

val to_markdown : report -> string
(** [to_markdown report] renders a human-readable report: a header line naming
    the fixed end date and start count, a per-metric dispersion table (one row
    per metric: median / 10th-pct / IQR / min / max / n), and a per-start detail
    table. Mirrors the [walk_forward_render] table style. Floats are formatted
    to two decimals; an empty report renders the header with a "no starts" note.
*)
