# Bayesian tuner — integer-bound knobs crash on first GP candidate (2026-05-19)

## What happened

Phase B prod sweep dispatched 2026-05-19 00:05 PT crashed inside fold-1
of iteration ~1 (after the initial cell-E baseline succeeded). All 7
knobs from the original `spec_prod.sexp` were active; the first
candidate emitted by `grid_search.cell_to_overrides` produced an
override `((stage3_force_exit_config ((hysteresis_weeks 0.18509605779011418))))`,
which fails `int_of_sexp` at `Backtest.Runner._load_deps`
(`runner.ml:198`).

Full crash log preserved at `dev/logs/bayesian-prod-sweep-2026-05-18-CRASHED.log`
(line 251 onward).

## Root cause

`Tuner.Grid_search._binding_to_sexp` (`grid_search.ml:61-67`) emits
every BO-sampled value via `sprintf "%s=%.17g" key value` and routes
through `Backtest.Config_override.parse_to_sexp` — which wraps the
value as a `Sexp.Atom` of the float literal. No rounding step
anywhere.

The fixture `trading/test_data/tuner/bayesian-multi-param-2026-05-16.sexp`
comments `;; (int — rounded by cell_to_overrides)` and references
`grid_search.mli:56-65` as the authority for integer-valued floats
being "encoded correctly". That comment is **wrong** — verified
2026-05-19:

- `grep -nE "round|Int\.of|integer" trading/trading/backtest/tuner/lib/{bayesian_opt,grid_search}.ml` → zero hits.
- `test_phase3_fixture_bounds_cover_expected_tracks` only asserts the
  11-knob parse + key order; it does NOT run the BO loop.

So the existing 11-knob fixture has never been executed end-to-end.
Any sweep that includes integer-typed config fields in `bounds`
crashes on the first non-integer BO sample.

## Affected integer-typed bounds (any spec that includes these is broken)

- `stage3_force_exit_config.hysteresis_weeks`
- `laggard_rotation_config.hysteresis_weeks`
- `stage3_reentry_cooldown_weeks`
- `laggard_reentry_cooldown_weeks`
- `screening_config.weights.w_positive_rs` (claimed int in the
  11-knob fixture)
- `screening_config.weights.w_strong_volume` (same)

## Workaround applied for v1 sweep (2026-05-19)

Dropped the 3 integer knobs from `spec_prod.sexp`. Remaining 4-D
sweep:

```
bounds:
  portfolio_config.max_position_pct_long             [0.05, 0.20]
  portfolio_config.max_long_exposure_pct             [0.50, 0.95]
  initial_stop_buffer                                [1.00, 1.10]
  screening_config.candidate_params.installed_stop_min_pct [0.04, 0.15]

acquisition       Expected_improvement
initial_random    10  (down from 15)
total_budget      60  (down from 80)
```

Plan §5 estimates 4-D BO converges in ~30-50 evals; budget=60 is
sufficient with headroom.

## Real fix (deferred — not on critical path for v1 sweep)

Author `dev/plans/bayesian-int-bound-encoding-2026-05-19.md`:

1. Extend `Bayesian_runner_spec.bound_spec` with an `Int_round` variant
   (similar to PR-D's `Sentinel`).
2. Thread `Int_round` through `cell_to_overrides` so the emitted value
   is `(printf "%d" (int_of_float (Float.round_nearest value)))` instead
   of `%.17g`.
3. Add a sweep-loop integration test: BO bounds with `Int_round` over
   `[0.0, 4.0]` on `hysteresis_weeks`, run for 5 evals on a stub
   evaluator, assert every emitted override parses cleanly through
   `Backtest.Config_override.parse_to_sexp`.
4. Convert the 11-knob fixture's claim from comment-only to
   `(Int_round (0.0 4.0))` shape.

Estimate: ~1 PR, ~250 LOC.

This is what should have been PR-D in the multi-param-scaling stack
(`dev/plans/bayesian-multi-param-scaling-2026-05-16.md`). The shipped
PR-D handles `Sentinel` (Option-typed floats) but not `Int_round`.

## Root cause identified 2026-05-19 PM: cumulative memory leak → OOM-kill (SIGKILL)

After re-tooling with eprintf tracers, a budget-bisect dispatch, and
direct memory observation, the silent crash IS:

**Container OOM-kill (exit 137 / SIGKILL).** Docker does not write to
stderr when the kernel kills an OOM'd process — that's why the original
3rd dispatch died "silently" at the same 97th backtest.

Memory observations on the 30-fold × budget=2 reproducer:

```
Backtest  RSS       VmPeak    /proc/meminfo available
1         ~1.2 GB
30        ~3.0 GB
60        ~5.5 GB
90        7.3 GB    8.88 GB   100 MB
97        — killed at iter 1 candidate fold 4 mid-execution
```

Linear ~90 MB/backtest growth in resident set. Container has 7.7 GB
physical + 1 GB swap. At ~96 backtests, RSS + swap = ~8.4 GB, exhausted
total. Kernel selects bayesian_runner.exe (oom_score 1263) and sends
SIGKILL.

### Attempted mitigations (2026-05-19 PM)

| Mitigation                               | Live-words growth         | Effect                                                |
|------------------------------------------|---------------------------|-------------------------------------------------------|
| (baseline)                               | ~90 MB/backtest           | OOM at 97                                             |
| `Gc.compact` after each backtest         | ~25 MB/backtest           | Delays OOM to ~280; insufficient                      |
| Explicit `Daily_panels.close` at end of  | ~25 MB/backtest           | No additional effect — daily_panels cache             |
|  `Panel_runner.run`                      |                           | wasn't the retainer                                   |
| `_extract_fold` w/ `[@inline never]` to  | ~25 MB/backtest           | No effect — `result` isn't surviving via stack-root   |
|  scope `result` out before `Gc.compact`  |                           | retention                                             |

So `Gc.compact` halves the per-backtest leak (~90 → 25 MB), proving that
~65 MB/backtest IS transient (collectible with major+compact). The
remaining ~25 MB IS GENUINELY REACHABLE between backtests — somewhere
holds a strong reference. None of the inspected closures, module-level
refs, or recorder structs (Trade_audit, Stop_log, Force_liquidation_log,
Daily_panels, Csv_storage, Sector_map) explain it.

### Implications

- Every multi-iter sweep with ≥ ~200 backtests will OOM-kill silently
  on this container (7.7 GB).
- The v1 production sweep (60 budget × 2 variants × 31 folds =
  3720 backtests) is unrunnable in-process. Plan #1196 + the bisect
  notes file's mention of "v1 needs Int_round encoding" was correct in
  spirit but mis-attributed the failure mode — even the 4-knob
  drop-Int_round version dies the same way.
- The plan #1197 fork-per-fold parallelisation work is **load-bearing**,
  not merely an optimisation. Each forked child gets a fresh heap; on
  exit the OS reclaims everything including the 25 MB/backtest unknown
  retainer. With parallel=1 (no concurrency benefit) it still fixes the
  leak.

### Recommended next action

Bypass the leak by running ONE backtest per fork (plan #1197), even at
parallel=1. This unblocks v1 sweep regardless of root-cause progress.
Root-cause hunt for the 25 MB/backtest path can run async (use
`Gc.Memprof` or heap snapshot diff to identify the retained allocations).

The eprintf instrumentation added during this investigation
(`bayesian_runner_runner.ml _run_loop`, `panel_step_loop.ml
run_simulator_with_gc_trace`, `walk_forward_executor.ml _run_one` with
`_extract_fold` + `Gc.compact` + `Gc.stat` logging) is left in working
copy as diagnostic context for the next session. Decide whether to
strip before merge or keep behind a flag.

## Original third-failure write-up (superseded — kept for history)

## Third failure (2026-05-19 04:41 PT): silent deterministic crash at iter 1 candidate fold 3

After /tmp cleanup sidecar was in place, the 3rd dispatch (4-float spec
seed=2026) died at the **exact same 97th backtest** as the 2nd dispatch:
iter 1 candidate fold 3 (rolling-window test_period
`2011-07-01..2012-06-29`).

Evidence:

- Both `bayesian-prod-sweep-2026-05-19-tmpfull.log` (2nd dispatch) and
  `bayesian-prod-sweep.log` (3rd dispatch) are 46756 bytes / 777 lines.
- `diff` shows they differ only in random snapshot-dir suffixes:
  `panel_runner_csv_snapshot_380f18` vs `_621fb4`. Otherwise byte-identical.
- Both die immediately after writing
  `Panel_runner: snapshot bar reader wired (calendar 411 days)` at
  line 777 — no stderr stack trace.
- Container memory at observation = 476 MB / 7.75 GB (6%), `/tmp` clean
  (sidecar working — 5 snapshots / 9.1 GB at last check), no SIGKILL
  evidence in `docker stats`.
- Seed=2026 + 4 floats + `initial_random=10` ⇒ iter 1 is the 2nd
  pure-random BO sample; identical across dispatches. Iter 1 candidate
  fold 3 = identical (config, period, universe) triple.

So the crash is reproducible from `(seed=2026, BO sample 2)`. NOT
infrastructure (memory, disk, OOM). Something in the simulator path for
that specific (config, fold-3-2011) combination kills the process
without writing stderr.

Candidate root causes (none verified):

1. **Out_of_memory or Stack_overflow without stack trace** — OCaml
   sometimes prints "Out of memory" but if heap-exhausted at the wrong
   call site, the exception handler may not flush stderr before exit.
2. **`exit 2`-like behavior from a `failwith` inside a nested `match`**
   that bypasses normal logging — but `_run_loop` doesn't catch and
   the trace would still print.
3. **Float-NaN in the BO sample causing downstream divide-by-zero**
   that triggers an FP-trap (not OCaml's default but possible).
4. **Specific candidate config (e.g., installed_stop_min_pct near
   upper bound + initial_stop_buffer high) producing a degenerate
   strategy state on the 2011 H2 window.**

## What to do next session

This is a stop-the-line investigation:

1. **Reproduce with stderr capture**: run with `OCAMLRUNPARAM=b,l=1000000`
   + `script -q -c '...' /tmp/sweep.script`; the `script` wrapper
   captures TTY exit codes even on SIGSEGV.
2. **Bisect via budget**: try `total_budget=2 initial_random=2` first —
   if iter 0 + iter 1 candidate fold 3 crashes, confirms determinism.
3. **Print BO sample**: patch `_run_loop` to `eprintf` the suggested
   parameters before each evaluator call. Reveals what iter 1's
   candidate is.
4. **Repro with different seed**: change to `seed=42` — if crash
   moves to a different iter, it's BO-sample-specific (overrides v1
   sweep can dodge by re-running with different seed). If it stays at
   iter 1.5 regardless, it's a per-iter structural issue (e.g., shared
   state contamination across iters — `Backtest.Runner` carries
   process-level Hashtbls?).

The cleanup sidecar has been killed; output dir + crash log preserved
for next-session diagnosis. v1 sweep results are NOT obtainable
without this fix.

## Second failure (2026-05-19 03:04 PT): /tmp blow-out

After the 4-D re-dispatch, the sweep ran ~3 iters then died silently
(no error in log; process gone). Diagnosis:

- Container `/tmp` had **206 `panel_runner_csv_snapshot_*` dirs**
  totalling **17 GB** (~82 MB each).
- `Panel_runner` writes a CSV snapshot per (variant, fold) and never
  cleans up. With 62 backtests per BO iter, 3 iters = 186 dirs — matches.
- Host disk at 90% triggered overlay/aufs OOM → SIGKILL.
- Memory `project_2026-05-13_session.md` flags this exact pattern
  ("~61 GB reclaimed").

Mitigation: launched a sidecar inside the container that runs

```sh
while true; do
  find /tmp -maxdepth 1 -name "panel_runner_csv_snapshot_*" -mmin +3 \
    -exec rm -rf {} + 2>/dev/null
  sleep 60
done
```

every 60 s, deleting snapshots older than 3 min. Re-dispatched at
03:30 PT with this in place.

This is a harness gap: `Walk_forward_executor` should `rm -rf` the
snapshot dir after the per-fold backtest returns. Followup: file an
issue for `Panel_runner` to either (1) auto-clean in `at_exit`, (2)
accept an `--out-dir` flag, or (3) put snapshots under
`Filename.temp_dir` with auto-cleanup. Without this fix, every
multi-iter sweep needs the sidecar.

## What this means for v1 results

The v1 sweep optimises 4 of the 7 knobs from `bayesian-production-sweep-2026-05-18.md` §2:
sizing × 2 + stops × 2. The 3 Axis-C cascade/rotation knobs are
FIXED at Cell-E baseline values (h_force_exit=1, h_laggard=2,
reentry_cooldown=0).

That's narrower than the plan's claim ("7-knob sweep over the
production knob inventory") but still tunes the four most-cited
sensitive parameters. If the 4-D sweep produces a promotable winner,
a v2 sweep with Int_round support can extend to the 3 Axis-C knobs
afterwards.
