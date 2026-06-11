(** Drive a rolling-start dispersion evaluation: enumerate start dates at a
    fixed cadence, run one backtest per start to a common end date, project each
    run's terminal metrics into a {!Rolling_start_types.per_start}, and assemble
    the {!Rolling_start_types.report}.

    Plan: [dev/plans/evaluation-objective-and-metrics-2026-06-07.md] §2 P1. This
    is PR-2 of the rolling-start work — the executable layer on top of the pure
    {!Dispersion_stats} / {!Rolling_start_types} core (PR-1, #1472). The
    start-date enumeration and per-run metric extraction are split out as pure
    functions so they are unit-testable without forking a real backtest (the
    multi-start PIT run is data-gated); the orchestrating {!run} threads them
    through {!Backtest.Runner.run_backtest}. *)

open Core

val enumerate_starts :
  scenario_start:Date.t -> end_date:Date.t -> stride_days:int -> Date.t list
(** [enumerate_starts ~scenario_start ~end_date ~stride_days] is the ascending
    list of clipped start dates to run a backtest from. Starting at
    [scenario_start], it steps forward by [stride_days] calendar days (default
    quarterly = 91) and emits every start strictly before [end_date], so each
    enumerated start spans a non-empty window.

    - The first element is always [scenario_start] when
      [scenario_start < end_date].
    - A start equal to [end_date] is excluded (zero-length window); the last
      element is the greatest [scenario_start + k*stride_days] that is still
      [< end_date].
    - Returns the empty list when [scenario_start >= end_date].

    @raise Invalid_argument if [stride_days <= 0]. *)

val enumerate_starts_jittered :
  scenario_start:Date.t ->
  end_date:Date.t ->
  stride_days:int ->
  jitter_seed:int ->
  Date.t list
(** [enumerate_starts_jittered ~scenario_start ~end_date ~stride_days
     ~jitter_seed] is {!enumerate_starts}'s base grid with a deterministic
    per-point jitter applied, so the enumerated starts do not all land on the
    same calendar boundary (every base point is
    [scenario_start + k*stride_days], which for a Jan-1 scenario start would
    otherwise put every start on the first of a month — a calendar-boundary
    artefact this avoids).

    - The base grid is exactly {!enumerate_starts}'s:
      [scenario_start + k* stride_days] for [k = 0, 1, ...], every base point
      strictly before [end_date].
    - The first base point ([k = 0], = [scenario_start]) is pinned — no jitter —
      so the sweep still begins at the scenario's natural start.
    - Every later base point [b] is shifted forward by a uniform offset in the
      range [\[0, stride_days)] calendar days, drawn from a
      [Stdlib.Random.State.t] seeded by [jitter_seed]. The draws are consumed in
      ascending base-point order, so the result is fully determined by
      [(scenario_start, end_date, stride_days, jitter_seed)].
    - A jittered point that lands [>= end_date] is dropped, preserving the
      strictly-before-end / non-empty-window invariant.
    - Result is ascending and may be shorter than the base grid (when a late
      jittered point crosses [end_date]).

    @raise Invalid_argument if [stride_days <= 0]. *)

val bah_cagr_pct :
  start_date:Date.t ->
  end_date:Date.t ->
  close_series:(Date.t * float) list ->
  float
(** [bah_cagr_pct ~start_date ~end_date ~close_series] is the annualised
    buy-and-hold CAGR of a benchmark over [start_date .. end_date], computed
    purely from its [close_series] (chronological [(date, close)] pairs — use
    adjusted closes so dividends/splits are reflected).

    - Entry close = the first pair whose date is [>= start_date]; exit close =
      the last pair whose date is [<= end_date]. Buy-and-hold total return is
      [(exit -. entry) /. entry *. 100], annualised over the inclusive day count
      via {!Walk_forward.Walk_forward_runner.cagr_pct} — the same convention
      {!per_start_of_summary} uses for the strategy's CAGR, so the two are
      directly comparable as an edge.
    - Returns [Float.nan] when the window cannot be priced: fewer than two
      usable closes span it (empty series, all dates outside the window, or only
      one bar), or the entry close is [<= 0.0]. The caller renders [nan] as a
      blank cell rather than crashing.
    - [close_series] need not be sorted — entry/exit are selected by date
      comparison, not list position — but is expected chronological in practice.

    Designed to be benchmark-agnostic: any symbol's close series (SPY, BRK-B,
    GSPC.INDX) projects through the same function. *)

val per_start_of_summary :
  ?benchmark_cagr_pct:float ->
  ?equity_curve:float list ->
  start_date:Date.t ->
  end_date:Date.t ->
  Backtest.Summary.t ->
  Rolling_start_types.per_start
(** [per_start_of_summary ~start_date ~end_date summary] projects one backtest's
    {!Backtest.Summary.t} into a {!Rolling_start_types.per_start} tagged with
    the [start_date] it ran from. Pure — depends only on the summary, so it is
    unit-tested by constructing a [Summary.t] directly without a backtest.

    - [cagr_pct] is the annualised total return over [start_date .. end_date],
      computed via {!Walk_forward_runner.cagr_pct} from the summary's
      initial-cash / final-value total return and the inclusive day count
      (matching the walk-forward executor's CAGR convention).
    - [max_underwater_vs_initial_pct] is read from the summary's
      [MaxUnderwaterVsInitialPct] metric (capital-relative drawdown, #1471);
      [Float.nan] if absent.
    - [max_drawdown_pct] is read from the summary's [MaxDrawdown] metric (peak-
      relative); [Float.nan] if absent.
    - [benchmark_cagr_pct] (default [Float.nan] = "no benchmark") is recorded
      verbatim, and [edge_pct] is set to [cagr_pct -. benchmark_cagr_pct] (so
      [edge_pct] is also [nan] when no benchmark is supplied). Pass the result
      of {!bah_cagr_pct} for the same window.
    - [sharpe] is the summary [SharpeRatio] metric ([nan] if absent).
    - [realized_return_pct] strips the summary [UnrealizedPnl] metric from the
      terminal value: [(final -. unrealized -. initial) /. initial *. 100].
    - [time_underwater_pct] is {!Convexity_stats.time_underwater_pct} over
      [equity_curve] (default [[]] -> [0.0]); pass the run's per-step NAV series
      (chronological). *)

type config = {
  scenario : Scenario_lib.Scenario.t;
      (** The base scenario: supplies the universe path, config overrides,
          strategy choice, slippage, and the scenario's natural start date (the
          earliest start the sweep runs from). *)
  end_date : Date.t;
      (** The fixed end date every enumerated run terminates on. Overrides the
          scenario's own [period.end_date] so the sweep span is explicit. *)
  stride_days : int;
      (** Calendar-day cadence between successive start dates (91 = quarterly).
      *)
  jitter_seed : int option;
      (** When [Some seed], the start grid is jittered via
          {!enumerate_starts_jittered} with this seed (avoids calendar-boundary
          artefacts). [None] keeps the un-jittered fixed grid
          ({!enumerate_starts}) — the pre-existing behaviour. *)
  benchmark_symbol : string option;
      (** When [Some sym] {b and} a snapshot [bar_data_source] is configured,
          each start's [benchmark_cagr_pct] / [edge_pct] is filled by reading
          [sym]'s adjusted-close series from the snapshot and projecting a
          buy-and-hold CAGR over the same window ({!bah_cagr_pct}). [None] (or
          CSV mode, which has no shared-panels handle) leaves the benchmark
          columns [nan] — the report renders them blank, backward-compatibly. *)
  parallel : int;
      (** Number of starts to run concurrently. Each start is an independent
          full backtest, so they fork cleanly. [1] runs every start in its own
          short-lived child ({!Fork_pool.run_each_forked}) — the broad-universe
          (N=3000) memory-safe path that mirrors the walk-forward fork-per-fold
          runner: each child's exit reclaims the per-backtest heap residue and
          resets the macOS [VMAllocationTracker] slab. [> 1] runs up to that
          many children at once ({!Fork_pool.run_parallel}). Result order is
          always input (ascending start-date) order, independent of completion
          order. *)
  fixtures_root : string;
      (** Directory the scenario's [universe_path] is resolved against (mirrors
          [scenario_runner --fixtures-root]). *)
  bar_data_source : Backtest.Bar_data_source.t option;
      (** Optional snapshot bar source, resolved once from [--snapshot-dir] via
          {!Scenario_lib.Bar_source_resolver.resolve} and reused for every
          start. [None] keeps the pre-snapshot CSV behaviour. *)
}
(** Everything {!run} needs to enumerate starts and run one backtest per start.
*)

val run : config -> Rolling_start_types.report
(** [run config] enumerates the start dates ({!enumerate_starts_jittered} when
    [config.jitter_seed] is [Some], else {!enumerate_starts}, over
    [config.scenario.period.start_date] / [config.end_date] /
    [config.stride_days]), resolves the benchmark close series once (when
    [config.benchmark_symbol] + a snapshot source are set), runs
    {!Backtest.Runner.run_backtest} once per start (clipping the start, holding
    the end fixed, threading the scenario's overrides / strategy / slippage /
    cost model and the resolved sector-map override + optional snapshot source),
    projects each result via {!per_start_of_summary} (with the benchmark CAGR
    for that start's window via {!bah_cagr_pct}), and assembles the
    {!Rolling_start_types.report} via {!Rolling_start_types.build}.

    Sequential — each backtest is run in-process, one after another. The cost is
    N backtests, so callers should keep the cadence coarse and only sweep on PIT
    universes (plan §2 P1). *)
