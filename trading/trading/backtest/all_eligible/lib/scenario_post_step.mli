(** Per-scenario post-step that invokes {!All_eligible_runner.run_with_args} so
    every backtest scenario emits the all-eligible diagnostic alongside its
    [actual.sexp] / [summary.sexp] artefacts.

    Called from [scenario_runner.exe] after the per-scenario
    {!Backtest.Result_writer.write} + [actual.sexp] writes complete. The runner
    is invoked in single-cell mode with library defaults; the artefacts land
    under [<scenario_dir>/all_eligible/grade-C/].

    Layout produced under [scenario_dir]:

    {v
    <scenario_dir>/
      actual.sexp           — written by scenario_runner
      summary.sexp          — written by Backtest.Result_writer
      all_eligible/
        grade-C/            — default min-grade cell from
                              All_eligible.default_config
          trades.csv
          summary.md
          config.sexp
    v}

    {1 Failure isolation}

    {!emit} wraps the all-eligible run in [try/with]. A failure (missing CSV
    bars, snapshot construction error, scanner crash) is logged to [stderr] and
    swallowed — the diagnostic is purely informational and must never abort the
    parent scenario's backtest. The host scenario_runner has already written
    [actual.sexp] / [summary.sexp] before this hook runs, so a failure here
    leaves those upstream artefacts intact.

    {1 Disabled mode}

    When [enabled = false] the function is a no-op: no directory is created, no
    runner is invoked. This is the toggle the
    [scenario_runner.exe --no-emit-all-eligible] flag flips. *)

val emit : enabled:bool -> scenario_path:string -> scenario_dir:string -> unit
(** [emit ~enabled ~scenario_path ~scenario_dir] writes the all-eligible
    diagnostic under [scenario_dir/all_eligible/] when [enabled = true].

    Parameters:
    - [enabled] — gate flag. When [false], the function returns immediately
      without invoking the runner or creating the [all_eligible] subdir.
    - [scenario_path] — absolute path to the scenario sexp file. The runner
      re-loads it (cheap; sexp-only).
    - [scenario_dir] — the per-scenario output directory the host scenario
      runner already populated with [actual.sexp] / [summary.sexp].

    Side effects (when [enabled = true]):
    - Creates [scenario_dir/all_eligible/].
    - Invokes {!All_eligible_runner.run_with_args} in single-cell mode with
      [out_dir = scenario_dir/all_eligible/] and the library default config. The
      runner emits [grade-C/{trades.csv,summary.md,config.sexp}].
    - On any [Failure] / exception from the runner, logs the message to [stderr]
      with a [scenario:] tag and returns normally (does not raise). *)
