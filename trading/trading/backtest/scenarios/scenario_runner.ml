(** Scenario runner — runs one or more backtest scenarios and compares actual
    metrics against the [expected] ranges declared in each scenario file.

    Usage: scenario_runner
    [--goldens-small | --goldens-broad | --goldens | --smoke | --dir <path>]
    [--parallel N] [--fixtures-root <path>] [--snapshot-dir <path>]
    [--progress-every N] [--no-emit-all-eligible] [--emit-candidates]

    [--goldens-small] — small-universe goldens (~300 symbols; local-friendly).
    [--goldens-broad] — broad-universe goldens (full sector-map; nightly/GHA).
    [--goldens] — alias for [--goldens-small] for backwards compat.

    [--snapshot-dir <path>] — run every cell in snapshot (streaming) mode,
    reading OHLCV from the pre-built snapshot warehouse at [path] instead of
    building per-symbol bars in-process from CSVs. The manifest at
    [<path>/manifest.sexp] is read once at parse time and the resulting
    [Bar_data_source.t] is reused for every cell. With no [--snapshot-dir], the
    run stays bit-identical to CSV mode. The load-bearing use is large-N goldens
    (e.g. N=3000) that OOM the dev container in CSV mode (~14 GB resident).

    [--fixtures-root <path>] — directory the scenario [universe_path] field is
    resolved against (defaults to [TRADING_DATA_DIR/backtest_scenarios]). The
    perf-tier smoke scripts pass this explicitly because they stage the scenario
    sexp into a per-cell scratch dir, which loses the original fixtures-root
    context.

    [--progress-every N] — emit a tail-able [progress.sexp] under each
    scenario's output directory every [N] Friday cycles. Default is
    {!Scenario_progress.default_every_n_fridays} (≈ monthly cadence) so
    multi-hour multi-scenario runs (e.g. 15y SP500, broad-10k 10y) emit
    checkpoints by default. Mirrors the [backtest_runner.exe --progress-every]
    flag from PR #820, but threads one emitter per scenario into each child.

    [--no-emit-all-eligible] — disable the per-scenario all-eligible diagnostic
    post-step. By default, after each child writes [actual.sexp] /
    [summary.sexp], the runner invokes
    {!Backtest_all_eligible.Scenario_post_step.emit} to produce
    [<scenario_dir>/all_eligible/grade-C/{trades.csv,summary.md,config.sexp}] —
    a per-trade alpha snapshot of every Stage-1→2 breakout that fired across the
    run window. Use [--no-emit-all-eligible] to suppress for perf sweeps / quick
    smoke pipelines that don't want to pay the diagnostic's scan + score cost.

    [--emit-candidates] — opt into the per-week candidate list (issue #2490),
    writing [<scenario_dir>/candidates.sexp]: for every screened Friday, the
    names the entry walk passed over and their decision-time signals — emitted
    even on Fridays that funded nothing, which is the gap [trade_audit.sexp]
    cannot fill. Default OFF, mirroring [--no-emit-all-eligible]'s polarity in
    reverse: this one costs strategy-side work per Friday, so it opts in rather
    than out. Observability only — the gate lives on the audit recorder, moves
    no strategy behaviour, and cannot change a golden.

    Reads all *.sexp files from the selected directory, runs each via
    {!Backtest.Runner.run_backtest}, prints a pass/fail table, and writes
    per-scenario output to [dev/backtest/scenarios-<timestamp>/<name>/].

    Scenarios run in parallel child processes (default 4). Each child is a fresh
    process — no shared mutable state leaks across scenarios. Children write
    [actual.sexp] alongside the other artefacts; the parent reads it back to
    compute checks and print the table in declaration order. *)

open Core
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root
module Scenario_progress = Scenario_lib.Scenario_progress
module Bar_source_resolver = Scenario_lib.Bar_source_resolver
open Scenario_lib.Scenario_checks
module Cli_args = Scenario_lib.Cli_args
module Output_root = Scenario_lib.Output_root

(* Run one scenario inside a child process *)

(** Run the {!Backtest.Fold_health} degenerate-fold guard over a completed run
    and surface any findings loudly: each finding is printed to stderr with a
    [WARN: fold-health] prefix and the full list is written to
    [<scenario_dir>/fold_health.sexp]. A healthy run writes the empty list (so
    the artefact's presence is uniform across runs) and prints nothing. The
    equity-curve series is the per-step [portfolio_value] over the in-window
    steps — the same series {!Backtest.Result_writer} writes to
    [equity_curve.csv]. Purely diagnostic: no metric or return value changes. *)
let _emit_fold_health ~scenario_dir ~(result : Backtest.Runner.result) =
  (* Delegates to the shared runner-path emission (#1557) so the scenario
     catalog and the [backtest_runner] binary surface the same finding union
     ([Fold_health.check] invariants ∪ the #1553 divergence guard) identically.
     Behaviour-identical to the prior inline form. *)
  Backtest.Fold_health_runner.emit ~output_dir:scenario_dir result

let _run_scenario_in_child ~output_root ~fixtures_root ~progress_every
    ~emit_all_eligible ~emit_candidates ~bar_data_source ~scenario_path
    (s : Scenario.t) =
  eprintf "\n>>> Running %s: %s (%s to %s)\n%!" s.name s.description
    (Date.to_string s.period.start_date)
    (Date.to_string s.period.end_date);
  let scenario_dir = Output_root.scenario_dir ~output_root s in
  Core_unix.mkdir_p scenario_dir;
  let sector_map_override, universe_membership_at =
    Scenario_lib.Scenario_universe.of_scenario ~fixtures_root s
  in
  let progress_emitter =
    Scenario_progress.make_emitter ~scenario_dir ~every_n_fridays:progress_every
  in
  let t_start = Time_ns_unix.now () in
  (* Stream closed round-trips into [trades.csv] as the run progresses (#2502),
     on the same Friday cadence as [progress.sexp]. The [Result_writer.write]
     below truncates and rewrites the file, so a completed scenario's artefact
     is unchanged; the value is a crashed or OOM-killed scenario keeping the
     trades it had already closed. *)
  let result =
    Backtest.Result_writer.with_trades_stream ~output_dir:scenario_dir
      ~every_n_fridays:progress_every ~start_date:s.period.start_date
      ~f:(fun ~on_step_setup ->
        Backtest.Runner.run_backtest ~start_date:s.period.start_date
          ~end_date:s.period.end_date ~overrides:s.config_overrides
          ?sector_map_override ~strategy_choice:s.strategy ~progress_emitter
          ?slippage_bps:s.slippage_bps ?cost_model:s.cost_model ?bar_data_source
          ?candidate_log:(Backtest.Candidate_log.create_if emit_candidates)
          ?universe_membership_at ~on_step_setup ())
  in
  Backtest.Result_writer.write ~output_dir:scenario_dir result;
  (* Post-step: per-week candidate list (#2490). Runs after the canonical
     artefacts are on disk and swallows its own failures, so a writer problem
     cannot cost the scenario its result. No-op when the flag is off. *)
  Backtest.Candidate_log.emit ~enabled:emit_candidates ~scenario_dir
    result.candidate_weeks;
  let a = actual_of_result result in
  Sexp.save_hum (Output_root.actual_path ~output_root s) (sexp_of_actual a);
  (* Degenerate-fold guard: surface the silent-garbage signature (zero in-window
     round-trips + flat equity + an unexplained terminal move — the A2 warmup-
     leak class) loudly to stderr and as [fold_health.sexp]. Purely a reporting
     post-step; it changes no metric and never aborts the run. *)
  _emit_fold_health ~scenario_dir ~result;
  (* Post-step: emit the all-eligible diagnostic alongside actual.sexp /
     summary.sexp so every scenario surfaces raw-signal alpha without manual
     [all_eligible_runner.exe] invocation. Failures inside the runner are
     logged + swallowed by [Scenario_post_step.emit] so a diagnostic crash
     never aborts the parent scenario. *)
  (* In snapshot mode, hand the diagnostic the same warehouse the backtest used
     so it works on broad universes the CSV [data/] store doesn't hold. *)
  let warehouse_dir =
    match bar_data_source with
    | Some (Backtest.Bar_data_source.Snapshot { snapshot_dir; _ }) ->
        Some snapshot_dir
    | Some Backtest.Bar_data_source.Csv | None -> None
  in
  Backtest_all_eligible.Scenario_post_step.emit ~enabled:emit_all_eligible
    ~scenario_path ~scenario_dir ~warehouse_dir;
  (* Emit wall_seconds.txt — the canonical perf-report convention
     (release_report._read_optional_float). Goldens may pin
     [expected.wall_seconds] to catch runtime regressions; scenarios that
     don't pin are unaffected. Measured from [t_start] (before
     [run_backtest]) through here — i.e. AFTER every post-step above,
     including the all-eligible diagnostic — so the pinned band covers the
     full wall a human waits for, not just the backtest core. A prior
     version stopped the clock immediately after [run_backtest], which let
     the all-eligible diagnostic's cost (48+ min when enabled — issue #2606)
     run entirely outside the measured span. *)
  let wall_seconds =
    Time_ns.Span.to_sec (Time_ns.diff (Time_ns_unix.now ()) t_start)
  in
  Out_channel.write_all
    (Filename.concat scenario_dir "wall_seconds.txt")
    ~data:(sprintf "%.3f\n" wall_seconds)

(* Fork-based worker pool. Scenarios run in parallel child processes up to
   [parallel] at a time. *)

(** Write a sentinel [actual.sexp] for a crashed child so the parent's row
    reports a meaningful FAIL (with [-100%] return / [100%] drawdown sentinels
    and the exception message) rather than the silent "did not write
    actual.sexp" path that loses the failure mode in CI logs. The [scenario_dir]
    is created defensively in case the crash predates the
    [_run_scenario_in_child] mkdir call. *)
let _write_crashed_actual ~output_root (s : Scenario.t) ~msg =
  let scenario_dir = Output_root.scenario_dir ~output_root s in
  Core_unix.mkdir_p scenario_dir;
  Sexp.save_hum
    (Output_root.actual_path ~output_root s)
    (sexp_of_actual (crashed_actual ~msg))

let _fork_scenario ~output_root ~fixtures_root ~progress_every
    ~emit_all_eligible ~emit_candidates ~bar_data_source ~scenario_path
    (s : Scenario.t) =
  match Core_unix.fork () with
  | `In_the_child -> (
      try
        _run_scenario_in_child ~output_root ~fixtures_root ~progress_every
          ~emit_all_eligible ~emit_candidates ~bar_data_source ~scenario_path s;
        Stdlib.exit 0
      with e ->
        let msg = Exn.to_string e in
        eprintf "Scenario %s crashed: %s\n%!" s.name msg;
        (* Write a sentinel actual.sexp so the parent row reports a
           meaningful FAIL with crash metadata instead of the silent
           "did not write actual.sexp" path. Wrap in its own try/with
           because a writer failure on a crash path must still exit
           cleanly. *)
        (try _write_crashed_actual ~output_root s ~msg
         with e2 ->
           eprintf "Scenario %s: failed to write crashed actual.sexp: %s\n%!"
             s.name (Exn.to_string e2));
        Stdlib.exit 1)
  | `In_the_parent pid -> pid

type _child_status = Succeeded | Crashed

let _await_one running =
  let _, pid = Queue.dequeue_exn running in
  match Core_unix.waitpid pid with Ok () -> Succeeded | Error _ -> Crashed

let _run_scenarios_parallel ~output_root ~fixtures_root ~parallel
    ~progress_every ~emit_all_eligible ~emit_candidates ~bar_data_source
    (scenarios : (string * Scenario.t) list) =
  let running = Queue.create () in
  let statuses = Hashtbl.create (module String) in
  let reap () =
    let pair = Queue.peek_exn running in
    let s, _ = pair in
    let status = _await_one running in
    Hashtbl.set statuses ~key:s.Scenario.name ~data:status
  in
  List.iter scenarios ~f:(fun (scenario_path, s) ->
      if Queue.length running >= parallel then reap ();
      let pid =
        _fork_scenario ~output_root ~fixtures_root ~progress_every
          ~emit_all_eligible ~emit_candidates ~bar_data_source ~scenario_path s
      in
      Queue.enqueue running (s, pid));
  while not (Queue.is_empty running) do
    reap ()
  done;
  List.map scenarios ~f:(fun (_, s) ->
      let status =
        Hashtbl.find statuses s.Scenario.name |> Option.value ~default:Crashed
      in
      (s, status))

let () =
  let {
    Cli_args.dir;
    parallel;
    fixtures_root;
    snapshot_dir;
    progress_every;
    emit_all_eligible;
    emit_candidates;
  } =
    Cli_args.parse_args ()
  in
  let fixtures_root = Fixtures_root.resolve ?fixtures_root () in
  (* Resolve the snapshot warehouse once at parse time; the same
     [Bar_data_source.t] is reused for every cell in the run. [None] keeps the
     pre-existing CSV behaviour bit-identical. Exits 1 on a missing/corrupt
     manifest. *)
  let bar_data_source = Bar_source_resolver.resolve snapshot_dir in
  let files = Output_root.list_scenario_files dir in
  if List.is_empty files then (
    eprintf "No .sexp scenario files found in %s\n" dir;
    Stdlib.exit 1);
  let parallel = min parallel (List.length files) in
  eprintf "Loading %d scenarios from %s (parallel=%d)\n%!" (List.length files)
    dir parallel;
  eprintf "Fixtures root: %s\n%!" fixtures_root;
  eprintf "Bar data source: %s\n%!"
    (match snapshot_dir with
    | Some d -> sprintf "snapshot mode (%s)" d
    | None -> "CSV mode");
  eprintf "Progress emission: every %d Friday cycle(s) per scenario\n%!"
    progress_every;
  eprintf "All-eligible diagnostic: %s\n%!"
    (if emit_all_eligible then "enabled" else "disabled");
  eprintf "Per-week candidate emission: %s\n%!"
    (if emit_candidates then "enabled" else "disabled");
  let scenarios_with_paths =
    List.map files ~f:(fun file -> (file, Scenario.load file))
  in
  let output_root =
    Output_root.make_timestamped_root ~repo_root:(Cli_args.repo_root ())
  in
  eprintf "Output root: %s\n%!" output_root;
  let results =
    _run_scenarios_parallel ~output_root ~fixtures_root ~parallel
      ~progress_every ~emit_all_eligible ~emit_candidates ~bar_data_source
      scenarios_with_paths
  in
  print_header ();
  let pass_flags =
    List.map results ~f:(fun (s, _) -> process_result ~output_root s)
  in
  let all_pass = List.for_all pass_flags ~f:Fn.id in
  let n_pass = List.count pass_flags ~f:Fn.id in
  let n_total = List.length pass_flags in
  printf "\n%d/%d scenarios passed.\n" n_pass n_total;
  if not all_pass then Stdlib.exit 1
