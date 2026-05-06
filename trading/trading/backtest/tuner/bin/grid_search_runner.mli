(** The wire-up loop used by [grid_search.exe]: take a parsed spec, an
    evaluator, and an output directory; run the grid + write all three
    artefacts. Factored out so a unit test can drive the same code path against
    a stub evaluator without forking the binary. *)

val run_and_write :
  spec:Grid_search_spec.t ->
  out_dir:string ->
  evaluator:Tuner.Grid_search.evaluator ->
  Tuner.Grid_search.result
(** [run_and_write ~spec ~out_dir ~evaluator] enumerates every cell in
    [spec.params], calls [evaluator] on every [(cell, scenario)] pair,
    aggregates per-cell mean objective scores, and writes:
    - [<out_dir>/grid.csv] — every row of the grid (cells × scenarios) plus
      computed metrics + objective column;
    - [<out_dir>/best.sexp] — the argmax cell rendered as the partial
      config-override sexp consumed by [Backtest.Runner.run_backtest];
    - [<out_dir>/sensitivity.md] — per-param sensitivity table.

    Creates [out_dir] via [mkdir -p] if it does not exist. Returns the full
    {!Tuner.Grid_search.result} so callers can log [best_score] / [best_cell]
    without re-reading the artefacts. *)
