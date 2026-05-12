(** The wire-up loop used by [grid_search.exe]: take a parsed spec, an
    evaluator, and an output directory; run the grid + write all three
    artefacts. Factored out so a unit test can drive the same code path against
    a stub evaluator without forking the binary. *)

val run_and_write :
  spec:Grid_search_spec.t ->
  out_dir:string ->
  evaluator:Tuner.Grid_search.evaluator ->
  parallel:int ->
  Tuner.Grid_search.result
(** [run_and_write ~spec ~out_dir ~evaluator ~parallel] enumerates every cell in
    [spec.params], calls [evaluator] on every [(cell, scenario)] pair,
    aggregates per-cell mean objective scores, and writes:
    - [<out_dir>/grid.csv] — every row of the grid (cells × scenarios) plus
      computed metrics + objective column;
    - [<out_dir>/best.sexp] — the argmax cell rendered as the partial
      config-override sexp consumed by [Backtest.Runner.run_backtest];
    - [<out_dir>/sensitivity.md] — per-param sensitivity table.

    Creates [out_dir] via [mkdir -p] if it does not exist. Returns the full
    {!Tuner.Grid_search.result} so callers can log [best_score] / [best_cell]
    without re-reading the artefacts.

    [parallel] caps the number of forked child processes running cells at once.
    [parallel <= 1] runs sequentially in the parent (byte-identical to the
    pre-parallel implementation). [parallel >= 2] forks one child per cell up to
    [parallel] at a time; each child evaluates exactly one cell across all
    scenarios and writes its rows to [<out_dir>/.cell-shards/cell-NNNNN.sexp].
    The parent then concatenates shards in cell-enumeration order and proceeds
    with the same argmax + sensitivity + write logic, so the output artefacts
    are unchanged from the sequential path.

    Raises [Failure] if any cell child exits non-zero — the parent waits for all
    children before raising. *)
