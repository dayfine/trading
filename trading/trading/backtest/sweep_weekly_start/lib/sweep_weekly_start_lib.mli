(** Weekly-start sweep: for each Monday in a trailing N-year window, run a
    Buy-and-Hold simulation from that Monday through [end_date] and collect the
    resulting return / drawdown / Sharpe metrics into a single result.

    Output is dual-format:
    - A sexp [sweep_result] suitable for pinning as a golden under
      [trading/test_data/].
    - A markdown rendering with a per-cell table + summary block, suitable for
      committing under [dev/sweep/] as a human-readable report.

    Entry-timing dispersion is the user-facing intent: visualising the
    distribution of "if I started on Monday X" outcomes makes the strategy /
    benchmark's start-date sensitivity legible. For Buy-and-Hold-SPY the
    dispersion reflects raw market timing risk; future iterations can swap the
    [strategy_choice] to compare an active strategy's start-date sensitivity
    against the passive baseline.

    All non-IO functions are pure: same input → same output. Tests pin the
    pure-formatter outputs against fixture cell lists; the [run] entry point is
    the only IO-touching surface (loads SPY bars through
    {!Backtest.Runner.run_backtest}). *)

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
    run. *)

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
          [config.years_back × 52] when the calendar window starts mid-week or
          includes leap-week artefacts; the source of truth is [cells]. *)
}
[@@deriving sexp, eq, show]
(** Aggregate stats across the cell list. Computed by {!summarize}; serialized
    as part of {!sweep_result}. *)

type sweep_result = {
  run_date : Date.t;  (** Date the sweep was generated. *)
  end_date : Date.t;
      (** End date used for every cell. Equal to [run_date] when the user does
          not override [--end-date]; settable via the CLI / API for reproducible
          tests and replay. *)
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
}
[@@deriving sexp, eq, show]
(** Full result of one sweep invocation, serializable as the golden artifact. *)

type config = {
  symbol : string;  (** Symbol for the BAH strategy, e.g. ["SPY"]. *)
  initial_cash : float;  (** Starting cash for every cell. *)
  years_back : int;  (** Trailing-window length in years. *)
  end_date : Date.t;  (** End date for every cell. *)
  fixtures_root : string;
      (** Path to [trading/test_data/backtest_scenarios] used to resolve the
          single-symbol universe file. *)
  universe_path : string;
      (** Universe-file path relative to [fixtures_root], e.g.
          ["universes/spy-only.sexp"]. *)
}
(** Inputs to {!run}. *)

val mondays_in_window : end_date:Date.t -> years_back:int -> Date.t list
(** Enumerate every Monday in [(end_date - years_back years) .. end_date],
    chronologically. The window start is computed as
    [Date.add_years end_date (-years_back)]; the first Monday at or after the
    window start is the head of the returned list. The returned list always
    excludes [end_date] when [end_date] itself is a Monday — the sweep wants
    [start_date < end_date] so each cell can produce a non-empty return. *)

val summarize : cell list -> summary
(** Aggregate stats. When the input is empty, returns
    [{ best_cell_start = epoch; best_cagr = 0.0; worst_cell_start = epoch;
     worst_cagr = 0.0; median_cagr = 0.0; mean_cagr = 0.0; stddev_cagr = 0.0;
     n_cells = 0 }] with [epoch = Date.create_exn ~y:1970 ~m:Jan ~d:1] — the
    caller is responsible for treating an empty result as a degenerate case (the
    markdown renderer prints a "no cells" notice). *)

val format_sexp : sweep_result -> Sexp.t
(** Serialise to the canonical sexp shape used by the golden file. Uses
    [sexp_of_sweep_result]. *)

val format_markdown : ?max_cells:int -> sweep_result -> string
(** Render to markdown: a header block, a summary block, and a per-cell table.

    [?max_cells] caps the per-cell table to that many rows by sampling uniformly
    across [cells] (head + spread + tail) — useful when the cell count exceeds
    ~30 and the table would otherwise be unreadable. When [None] (the default),
    every cell is rendered. *)

val run_one :
  config -> Date.t -> sector_map_override:(string, string) Hashtbl.t -> cell
(** Run a single BAH cell starting on [start_date]. Loads SPY bars via
    {!Backtest.Runner.run_backtest} with the configured [sector_map_override]
    and [strategy_choice = Bah_benchmark { symbol }]. Pure with respect to its
    inputs (modulo CSV loading) — the same arguments always produce the same
    cell.

    [sector_map_override] is passed in (rather than constructed internally) so
    {!run} can load the universe file once and reuse it across cells. *)

val run : config -> sweep_result
(** Top-level entry point: enumerate Mondays, run one cell per Monday,
    summarise, and return the result. Calls {!Universe_file.load} on
    [config.fixtures_root ^ "/" ^ config.universe_path] to build the sector-map
    override. Sets [run_date] to [config.end_date] (today by default). *)
