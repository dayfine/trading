(** In-process walk-forward CV execution. Library entry point shared by the
    [walk_forward_runner.exe] binary and the Phase-3 Bayesian optimizer
    evaluator.

    Hoists the per-fold + cross-grid execution loop out of
    [bin/walk_forward_runner.ml] so the Bayesian tuner can run a walk-forward
    sweep per BO iteration without spawning a subprocess. The binary becomes a
    thin wrapper that calls {!execute_spec} and writes its three output files;
    the tuner consumes {!result.aggregate} directly to score the cell via
    {!Tuner_bin.Bayesian_runner_scoring.score_cell}.

    Pure orchestration on top of {!Backtest.Runner.run_backtest} plus
    {!Walk_forward_report.compute}. No filesystem writes here — the caller
    persists results when it chooses to. *)

open Core

type result = {
  fold_actuals : Walk_forward_report.fold_actual list;
      (** Flat list of per-(variant, fold) measurement rows, in the same order
          {!Walk_forward_runner.build_all} produces scenarios: outer = variants
          in input order, inner = folds in generation order. The binary persists
          this verbatim as [fold_actuals.sexp] for replay; the tuner ignores it
          and reads {!aggregate} instead. *)
  aggregate : Walk_forward_report.aggregate;
      (** The structured cross-fold summary, computed via
          {!Walk_forward_report.compute} from [fold_actuals] using the spec's
          [baseline_label] and [gate]. The Bayesian-optimizer scorer reads this
          field directly. *)
}
(** What an end-to-end walk-forward CV produces, before any output writer
    decides whether to serialise it. *)

type progress_callback =
  variant_label:string ->
  fold_name:string ->
  test_start:Date.t ->
  test_end:Date.t ->
  unit
(** Called once per (variant, fold) pair immediately before
    {!Backtest.Runner.run_backtest} fires. Implementations may log to stderr
    (the binary does this) or ignore the call (the tuner does this).

    Under [?parallel > 1] every pair's progress event is emitted in the parent
    process up-front, before any forks. That preserves a deterministic schedule
    log even when children finish out of order. *)

val noop_progress : progress_callback
(** A {!progress_callback} that does nothing. Default for callers that don't
    want progress noise. *)

type fold_runner = Scenario_lib.Scenario.t -> Walk_forward_report.fold_actual
(** Per-scenario evaluator. Production wiring (when [?run_one] is omitted) calls
    {!Backtest.Runner.run_backtest} and projects its summary metrics into a
    {!Walk_forward_report.fold_actual}. Tests inject a deterministic stub via
    [?run_one] to exercise the parallel / sequential code paths without invoking
    the real backtest. *)

val execute_spec :
  base:Scenario_lib.Scenario.t ->
  spec:Spec.t ->
  fixtures_root:string ->
  ?progress:progress_callback ->
  ?parallel:int ->
  ?bar_data_source:Backtest.Bar_data_source.t ->
  ?run_one:fold_runner ->
  unit ->
  result
(** [execute_spec ~base ~spec ~fixtures_root ?progress ?parallel
     ?bar_data_source ?run_one ()] runs the full walk-forward CV grid:

    + For each [variant] in [spec.variants] (outer loop), and for each [fold] in
      [Window_spec.generate spec.window_spec] (inner loop):
    + Build a per-fold {!Scenario_lib.Scenario.t} via
      {!Walk_forward_runner.build_fold_scenario}.
    + Call [progress ~variant_label ~fold_name ~test_start ~test_end] (no-op by
      default) — emitted up-front in the parent for the full (variant, fold)
      schedule when [?parallel > 1], so the operator sees the schedule even when
      children finish out of order.
    + Resolve the scenario's universe via
      {!Scenario_lib.Universe_file.to_sector_map_override} against
      [fixtures_root].
    + Run {!Backtest.Runner.run_backtest} on that scenario and convert its
      summary metrics into a {!Walk_forward_report.fold_actual}.
    + Tag the result with the fold name and variant label.

    After every (variant, fold) is run, compute the
    {!Walk_forward_report.aggregate} by calling {!Walk_forward_report.compute}
    with [spec.baseline_label] and [spec.gate]. Returns the combined {!result}.

    [?parallel] (default [1], must satisfy [1 <= parallel <= 16]) controls how
    many (variant, fold) pairs run concurrently via {!Fork_pool.run_parallel}.
    The default [1] preserves the original behaviour bit-exactly (no fork, no
    marshal — pairs run in the parent process). For [parallel > 1] each pair
    runs in a forked child; the parent reassembles results in canonical (variant
    outer, fold inner) order, so {!Walk_forward_report.compute} sees a
    byte-identical input list regardless of [parallel]. See plan #1197 §7 PR-2.

    [?bar_data_source] selects the OHLCV backend each fold's
    {!Backtest.Runner.run_backtest} reads from. Omitted (the default) leaves
    [run_backtest] on [Bar_data_source.Csv] — byte-identical to the pre-snapshot
    behaviour. Pass [Some (Snapshot {...})] (resolved from a [--snapshot-dir]
    via {!Scenario_lib.Bar_source_resolver.resolve}) to read from a pre-built
    snapshot warehouse instead; this is the only tractable backend for
    broad-universe (N >= 1000) WF-CV, where CSV mode is superlinear and OOMs.
    Snapshot is purely a faster bar backend — per-fold metrics are identical to
    CSV mode on the same input bars. Ignored when [?run_one] is supplied (the
    test stub bypasses the real backtest).

    [?run_one] (default {!Backtest.Runner.run_backtest}-backed) is a test seam
    for substituting a deterministic per-scenario evaluator. Production callers
    should omit it. Documented in the body's {!fold_runner} doc.

    The [base] scenario is loaded by the caller (typically
    {!Scenario_lib.Scenario.load} on [spec.base_scenario]); accepted as an
    argument so the Bayesian-optimizer evaluator can load it once and reuse it
    across many BO iterations without re-parsing.

    @raise Invalid_argument
      if [parallel < 1] or [parallel > Fork_pool.max_parallel] (propagated from
      {!Fork_pool.run_parallel}).

    @raise Failure
      if any per-pair evaluation raises (in [parallel = 1] mode this surfaces
      directly; in [parallel > 1] mode {!Fork_pool.run_parallel} wraps the
      message with the failing job's index), when the universe file is
      malformed, or when {!Walk_forward_report.compute} finds no folds or a
      missing baseline (see its docstring). *)
