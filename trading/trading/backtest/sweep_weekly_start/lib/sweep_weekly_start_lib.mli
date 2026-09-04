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

include module type of Sweep_types
(** The data model — {!Sweep_types.cell}, {!Sweep_types.summary},
    {!Sweep_types.sweep_result} and {!Sweep_types.config}, with their [sexp] /
    [eq] / [show] derivations. Re-exported so every caller can keep naming them
    through this module; {!Sweep_types} carries the per-field documentation. *)

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

val skip_message : Date.t -> exn -> string
(** [skip_message start_date exn] is the diagnostic line {!run_one} writes to
    stderr when it drops a cell. It names the skipped [start_date] and renders
    [exn] through [Printexc.to_string] — for
    {!Backtest.Window_filter.Empty_measurement_window} that expands to the
    registered printer's window description, so the line carries both the cell
    that was dropped and why.

    Pure and exposed so the {i content} of the report is testable without
    capturing stderr: a cell disappearing from [summary.n_cells] with no line
    naming it is the silent-shrink failure the warning exists to prevent. *)

val run_one :
  config ->
  Date.t ->
  sector_map_override:(string, string) Hashtbl.t ->
  cell option
(** Run a single BAH cell starting on [start_date]. Loads SPY bars via
    {!Backtest.Runner.run_backtest} with the configured [sector_map_override]
    and [strategy_choice = Bah_benchmark { symbol }]. Pure with respect to its
    inputs (modulo CSV loading) — the same arguments always produce the same
    result.

    [None] when [start_date .. cfg.end_date] holds no trading day, i.e. the
    runner raised {!Backtest.Window_filter.Empty_measurement_window}. That
    happens routinely here: [end_date] defaults to the run date while the
    committed bars stop at a fixed floor, so every Monday past the floor is
    unmeasurable. Such a cell carries no entry-timing information, and
    fabricating a flat 0%-return cell for it would drag the sweep's median /
    mean / stddev toward zero — so it is dropped, with a line on stderr naming
    the skipped date (issue #2632; before the fix the whole sweep died with
    [Invalid_argument "List.last"] on the first such Monday, taking every other
    cell down with it).

    Any other exception propagates: only the degenerate-window case is
    tolerated, never a genuine failure.

    [sector_map_override] is passed in (rather than constructed internally) so
    {!run} can load the universe file once and reuse it across cells. *)

val run : config -> sweep_result
(** Top-level entry point: enumerate Mondays, run one cell per Monday,
    summarise, and return the result. Calls {!Universe_file.load} on
    [config.fixtures_root ^ "/" ^ config.universe_path] to build the sector-map
    override. Sets [run_date] to [config.end_date] (today by default).

    Mondays whose window holds no trading day are skipped (see {!run_one}), so
    [summary.n_cells] can be smaller than the Monday count — and is [0], with
    the markdown renderer emitting its "no cells" notice, when every Monday in
    the window is past the data floor. *)
