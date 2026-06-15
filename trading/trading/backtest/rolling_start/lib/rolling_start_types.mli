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
          buy-and-hold from this start; negative = lost to it. {b Contaminated}
          by terminal mark-to-market on still-open positions (a single
          AXTI-style paper monster flatters it); kept for the realized-vs-MTM
          gap diagnostic. The honest counterpart is [realized_edge_pct]. *)
  realized_edge_pct : float;
      (** The {b honest, primary} edge column (factor-decomposition lens primary
          outcome): the {!realized_return_pct} annualised over the same window
          via {!Rolling_start_runner.per_start_of_summary}'s CAGR convention,
          minus [benchmark_cagr_pct]. Strips the terminal mark-to-market that
          contaminates [edge_pct], so a still-open paper winner cannot flatter a
          recent start. [Float.nan] when [benchmark_cagr_pct] is [nan] (mirrors
          [edge_pct]). A large [edge_pct -. realized_edge_pct] gap flags a
          mark-dependent start (concentration in unrealized winners). *)
  forward_index_max_dd_pct : float;
      (** The benchmark's worst peak-to-trough drawdown over this start's
          [start_date .. end_date] window, as a {b negative} percent (same sign
          convention as [max_drawdown_pct]: [0.0] = no decline, [-25.0] = a 25%
          peak-to-trough drop). The factor-decomposition lens H1
          ("dodge-a-correction") factor — a large forward index DD is the
          correction the strategy's Stage-4 exits may sidestep. [Float.nan] when
          no benchmark series priced the window (same nan discipline as
          [benchmark_cagr_pct]). Computed via
          {!Rolling_start_runner.bench_max_dd_pct}. *)
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
  factors : Rolling_start_factors.factors;
      (** The screener-based factor columns evaluated as-of [start_date] — the
          factor-decomposition lens stage 5b candidate {b causes} (SPY/macro
          stage, macro composite, Stage-2 candidate count, sector-RS dispersion)
          that the analysis step correlates against [realized_edge_pct]. See
          {!Rolling_start_factors.factors}. {!Rolling_start_factors.empty}
          (all-unavailable) for a run with no snapshot warehouse to read from
          (CSV mode / no benchmark). Appended as a strict superset: pre-existing
          consumers that don't read it are unaffected. *)
}
[@@deriving sexp, equal]
(** One backtest's terminal outcome, tagged with the start date it ran from. *)

type report = {
  end_date : Date.t;  (** The fixed end date every run terminated on. *)
  min_window_days : int;
      (** The minimum window length (inclusive [start_date .. end_date] calendar
          days) a start must span to be counted in the aggregate/dispersion
          summaries below. Starts whose window is strictly shorter than this are
          {b excluded from every summary} ([cagr] / [edge] / drawdowns /
          {!pct_beating_benchmark}) because annualising a very short window
          produces an absurd CAGR that poisons the aggregate (a sub-15-month
          window can read +2393%/yr). They are {b still rendered} in the
          per-start detail table, flagged [(short window, excluded)], so the raw
          rows stay visible — only the summary is protected. [0] (the default,
          via {!build}) excludes nothing: every start is counted, identical to
          the pre-guard behaviour. *)
  starts : per_start list;
      (** {b All} per-start rows in start-date order (earliest first), including
          any below [min_window_days] — the detail table shows everything; the
          summaries are computed over only the eligible subset. *)
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
          / empty edge column yields a zero-[n] summary. {b MTM-contaminated} —
          see [realized_edge] for the honest version. *)
  realized_edge : Dispersion_stats.summary;
      (** Dispersion of {!per_start.realized_edge_pct} across [starts], skipping
          [nan] rows (starts with no benchmark). The {b honest} headline
          distribution — the MTM-stripped counterpart of [edge]. *)
  forward_index_max_dd : Dispersion_stats.summary;
      (** Dispersion of {!per_start.forward_index_max_dd_pct} across [starts],
          skipping [nan] rows (starts whose window could not be priced). The H1
          "dodge-a-correction" factor distribution. *)
}
[@@deriving sexp, equal]
(** The full rolling-start dispersion report: the raw per-start rows plus one
    {!Dispersion_stats.summary} per collected metric. *)

val build : ?min_window_days:int -> end_date:Date.t -> per_start list -> report
(** [build ~end_date starts] sorts [starts] by [start_date] (ascending) and
    computes a {!Dispersion_stats.summary} for each metric column via
    {!Dispersion_stats.summarize}. The [edge] summary skips [nan] rows (starts
    with no benchmark). An empty [starts] yields all-zero-n summaries — see
    {!Dispersion_stats.summarize}'s empty-list contract.

    [?min_window_days] (default [0]) is the {!report.min_window_days} guard: a
    start whose inclusive window [start_date .. end_date] is strictly shorter
    than [min_window_days] calendar days is excluded from {b every} summary (its
    annualised CAGR would be absurd and poison the aggregate), but is still
    retained in [starts] for the detail table. The default [0] excludes nothing
    — bit-identical to the un-guarded behaviour.

    @raise Invalid_argument if [min_window_days < 0]. *)

val pct_beating_benchmark : report -> float
(** [pct_beating_benchmark report] is the percentage (in [0.0, 100.0]) of starts
    with a defined ([non-nan]) [edge_pct] that is strictly positive — i.e. the
    share of start dates from which the strategy beat the benchmark's
    buy-and-hold. Computed over only the benchmarked starts (denominator = count
    of non-[nan] [edge_pct]) that {b also} clear [report.min_window_days]
    (short-window starts are excluded, consistent with the summaries); returns
    [Float.nan] when no eligible start has a benchmark. The single headline
    robustness number. *)

val is_short_window :
  min_window_days:int -> end_date:Date.t -> per_start -> bool
(** [is_short_window ~min_window_days ~end_date s] is [true] iff [s]'s inclusive
    window ([s.start_date .. end_date], counted in calendar days) is strictly
    shorter than [min_window_days] — i.e. [s] is excluded from the summaries.
    Always [false] when [min_window_days <= 0]. Exposed so callers / tests can
    reproduce the exclusion predicate {!build} applies. *)

val to_markdown : report -> string
(** [to_markdown report] renders a human-readable report: a header line naming
    the fixed end date and start count, a per-metric dispersion table (one row
    per metric: median / 10th-pct / IQR / min / max / n), and a per-start detail
    table. Mirrors the [walk_forward_render] table style. Floats are formatted
    to two decimals; an empty report renders the header with a "no starts" note.

    The per-start detail table's columns are a strict superset: the outcome
    columns, then the four factor-decomposition lens columns ([SPY stage] /
    [Macro composite] / [Stage-2 count] / [Sector-RS dispersion], from each
    row's {!per_start.factors}), then the [note] cell. An unavailable factor
    ([None] / [nan]) renders blank / [nan]. *)
