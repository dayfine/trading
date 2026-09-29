(** Single-run execution + instrumentation pipeline shared by every
    [backtest_runner] mode (single-run, baseline, smoke, fuzz).

    Wraps {!Backtest.Runner.run_backtest} with the trace / memtrace / gc-trace /
    progress-emitter plumbing and the result-writing side effects, so
    [backtest_runner.ml]'s per-mode drivers only need to supply the
    mode-specific overrides and output directory. *)

val run_and_write :
  start_date:Core.Date.t ->
  end_date:Core.Date.t ->
  overrides:Core.Sexp.t list ->
  output_dir:string ->
  ?sector_map_override:(string, string) Core.Hashtbl.t ->
  ?trace_path:string ->
  ?memtrace_path:string ->
  ?gc_trace_path:string ->
  ?bar_data_source:Backtest.Bar_data_source.t ->
  ?progress_every:int ->
  ?slippage_bps:int ->
  unit ->
  Backtest.Runner.result
(** Run a single backtest via {!Backtest.Runner.run_backtest} and write its full
    result set to [output_dir] ([params.sexp], [summary.sexp], [trades.csv],
    etc. via {!Backtest.Result_writer.write}), plus:
    - starts memtrace at [memtrace_path] before the run, if supplied;
    - threads a {!Backtest.Trace.t} / {!Backtest.Gc_trace.t} through the run and
      writes each to [trace_path] / [gc_trace_path] after, if supplied;
    - emits [progress.sexp] under [output_dir] every [progress_every] Friday
      cycles, if supplied;
    - emits [fold_health.sexp] (degenerate-fold + stuck-position diagnostics,
      #1553/#1557) unconditionally, diagnostic only — never aborts the run.

    Returns the [Backtest.Runner.result] so callers (e.g. baseline mode) can
    feed both runs into [Backtest.Comparison.compute] without re-reading the
    summary from disk. *)
