(** Per-scenario progress emitter for [scenario_runner.exe].

    Mirrors the [backtest_runner.exe] emitter wired in PR #820 (see
    [trading/trading/backtest/bin/backtest_runner.ml] §[_make_progress_emitter])
    but shaped for the scenario-runner output convention: one [progress.sexp]
    per scenario subdirectory under [dev/backtest/scenarios-<ts>/<name>/], next
    to the existing [summary.sexp] / [trades.csv] artefacts.

    Threaded through {!Backtest.Runner.run_backtest} as
    [?progress_emitter:Backtest_progress.emitter]. Default behaviour when
    [scenario_runner.exe] is invoked without [--progress-every] is to emit every
    [4] Friday cycles (≈ monthly cadence) so multi-hour multi-scenario runs
    (e.g. 15y SP500, broad-10k 10y) gain recoverability without operator opt-in.
*)

val default_every_n_fridays : int
(** Default emission cadence: 4 Friday cycles ≈ monthly. The fast write path
    (atomic-rename single sexp) makes this cheap in I/O terms even for a 15y
    simulation (~195 checkpoints). Compare with PR #820's [backtest_runner.exe]
    where [--progress-every] is opt-in (default [None]); for [scenario_runner]
    we default to ON because the exe is the long-running multi-scenario entry
    point and running blind for hours has no upside. *)

val make_emitter :
  scenario_dir:string ->
  every_n_fridays:int ->
  Backtest.Backtest_progress.emitter
(** [make_emitter ~scenario_dir ~every_n_fridays] returns an emitter whose
    [on_progress] callback writes [progress.sexp] under [scenario_dir] via
    {!Backtest.Backtest_progress.write_atomic}. The path convention matches the
    other per-scenario artefacts ([summary.sexp], [trades.csv], [actual.sexp]).

    [every_n_fridays] must be [>= 1]; values [< 1] are rejected by the CLI
    parser before this function is called. *)
