(** The weekly-start sweep's data model: one {!cell} per start date, the
    aggregate {!summary} over the cells, the serializable {!sweep_result} that
    pairs them, and the {!config} that drives a run.

    Split out of [sweep_weekly_start_lib] so that module keeps to the behaviour
    — enumerating Mondays, running cells, aggregating, rendering — while the
    shapes it exchanges with the CLI, the golden artefact and the tests live in
    one place. [Sweep_weekly_start_lib] re-exports everything here, so callers
    can keep using either name. *)

open Core

type cell = {
  start_date : Date.t;
      (** Monday on which the simulation starts. The BAH strategy itself enters
          on the first trading day at or after [start_date], so when this Monday
          is a US market holiday the actual fill happens on Tuesday — see
          {!Backtest.Runner.run_backtest} fill semantics. *)
  final_value : float;
      (** Final portfolio value at [end_date], in dollars. Equal to
          [Summary.final_portfolio_value]. *)
  total_return : float;
      (** Total return as a fraction (not percent):
          [(final_value - initial_cash) / initial_cash]. Convert to percent by
          multiplying by 100. *)
  cagr : float;
      (** Compound annual growth rate as a fraction. Equal to the simulator's
          [CAGR] metric divided by 100 (the simulator stores CAGR in percent;
          this field stores it as a fraction for parity with [total_return]). *)
  max_dd : float;
      (** Maximum peak-to-trough drawdown as a fraction (always ≥ 0). Equal to
          the simulator's [MaxDrawdown] metric divided by 100. *)
  sharpe : float;
      (** Annualized Sharpe ratio (dimensionless). Equal to the simulator's
          [SharpeRatio] metric. *)
}
[@@deriving sexp, eq, show]
(** One cell of the sweep: the metrics for a single (start_date, end_date) BAH
    run. Only start dates whose window held at least one trading day produce a
    cell — see [Sweep_weekly_start_lib.run_one]. *)

type summary = {
  best_cell_start : Date.t;
      (** Start date of the cell with the highest CAGR. *)
  best_cagr : float;  (** Best CAGR (fraction). *)
  worst_cell_start : Date.t;
      (** Start date of the cell with the lowest CAGR. *)
  worst_cagr : float;  (** Worst CAGR (fraction). *)
  median_cagr : float;
      (** Median CAGR across all cells (fraction). For an even cell count the
          median is the arithmetic mean of the two central values. *)
  mean_cagr : float;  (** Arithmetic mean CAGR across all cells (fraction). *)
  stddev_cagr : float;
      (** Sample standard deviation of CAGR across cells. [0.0] when fewer than
          2 cells. *)
  n_cells : int;
      (** Total number of cells in the sweep. May differ from
          [config.years_back × 52] when the calendar window starts mid-week,
          includes leap-week artefacts, or contains start dates past the data
          floor (those are skipped); the source of truth is [cells]. *)
}
[@@deriving sexp, eq, show]
(** Aggregate stats across the cell list. Computed by
    [Sweep_weekly_start_lib.summarize]; serialized as part of {!sweep_result}.
*)

type coverage = {
  requested_end_date : Date.t;
      (** The end date the caller asked for ([config.end_date]) — the run date
          when the CLI's [--end-date] is omitted. *)
  last_bar_date : Date.t;
      (** Date of the symbol's last bar in the CSV store at run time. Always
          rendered in the report header, so a stale data floor is visible
          without opening the workflow log (issue #2915). *)
  tolerance_days : int;
      (** The [config.max_end_date_gap_days] the guard was evaluated with. *)
  clamped : bool;
      (** [true] when [requested_end_date] was more than [tolerance_days]
          calendar days past [last_bar_date], so every cell was measured to
          [last_bar_date] instead. Without the clamp the simulator's CAGR
          annualizes over the dead calendar days after the last bar, which drags
          every cell's CAGR down a little more each week the data is not
          refreshed while the prices themselves are unchanged. *)
}
[@@deriving sexp, eq, show]
(** Result of the end-date-vs-data-floor guard. Computed by
    [Sweep_weekly_start_lib.resolve_coverage]. *)

type dropped_cell = {
  start_date : Date.t;  (** The Monday whose cell was not produced. *)
  reason : string;
      (** Why — the rendered exception, e.g. the
          {!Backtest.Window_filter.Empty_measurement_window} window description.
      *)
}
[@@deriving sexp, eq, show]
(** A start date the sweep enumerated but could not measure. Recorded in the
    result and rendered in the markdown report — not only on stderr — so a
    shrinking [n_cells] is always explained in the artefact itself. *)

type sweep_result = {
  run_date : Date.t;  (** Date the sweep was generated. *)
  end_date : Date.t;
      (** Effective end date used for every cell. Equal to [run_date] (the
          requested end date) unless the end-date guard clamped it to the last
          bar — see [coverage]. The requested date is settable via the CLI / API
          for reproducible tests and replay. *)
  symbol : string;  (** Symbol used by the BAH strategy. *)
  initial_cash : float;
      (** Starting cash for every cell. Same value across cells — the sweep
          intentionally normalises capital so the only varying axis is
          start-date. *)
  years_back : int;  (** Configured trailing-window length, in years. *)
  cells : cell list;
      (** Cells in chronological order (earliest start_date first). *)
  summary : summary;
      (** Aggregate stats. Derived from [cells] — recomputable. *)
  coverage : coverage option; [@sexp.option]
      (** End-date guard outcome. [None] only for results built without
          consulting the bar store (hand-built fixtures, pre-#2915 goldens);
          {!Sweep_weekly_start_lib.run} always sets it. When [clamped],
          [end_date] above is [coverage.last_bar_date], not the requested date.
      *)
  dropped_cells : dropped_cell list; [@sexp.list]
      (** Start dates enumerated but not measured, chronologically. Omitted from
          the sexp when empty. *)
}
[@@deriving sexp, eq, show]
(** Full result of one sweep invocation, serializable as the golden artifact. *)

type config = {
  symbol : string;  (** Symbol for the BAH strategy, e.g. ["SPY"]. *)
  initial_cash : float;  (** Starting cash for every cell. *)
  years_back : int;  (** Trailing-window length in years. *)
  end_date : Date.t;
      (** Requested end date for every cell; the guard may clamp the effective
          end to the last bar (see [max_end_date_gap_days]). *)
  fixtures_root : string;
      (** Path to [trading/test_data/backtest_scenarios] used to resolve the
          single-symbol universe file. *)
  universe_path : string;
      (** Universe-file path relative to [fixtures_root], e.g.
          ["universes/spy-only.sexp"]. *)
  max_end_date_gap_days : int;
      (** Guard tolerance, in calendar days: when [end_date] is more than this
          many days past the symbol's last bar, the sweep clamps the effective
          end date to the last bar and flags the report. Default
          [Sweep_weekly_start_lib.default_max_end_date_gap_days]. *)
}
(** Inputs to [Sweep_weekly_start_lib.run]. *)
