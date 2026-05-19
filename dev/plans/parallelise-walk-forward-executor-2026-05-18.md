# Parallelise the walk-forward executor (2026-05-18)

Plan-only doc. Lays out the design + sequencing for adding parallel
execution to the walk-forward CV harness so the Bayesian production
sweep (`dev/plans/bayesian-production-sweep-2026-05-18.md`) can run in
~8-12 hr wall time instead of ~30-50 hr serial.

## 0. Problem statement

The Bayesian production sweep (#1192) budget is 80-120 evaluations × 5
folds × ~3-15 min per fold. At parallel=1 (the only mode the executor
currently supports) the wall clock is **~30-120 hr serial**, well outside
a single-session window.

The walk-forward executor's own docstring confirms the gap:

```
(* trading/trading/backtest/walk_forward/lib/walk_forward_executor.mli:75 *)
Sequential execution. Parallelisation is a follow-up that does not change
this signature.
```

The Bayesian sweep plan assumes "parallel=4 (~8-10 hr)" but there is
nothing in the shipped code that supports that assumption. This plan
closes that gap.

## 1. Precedent: scenario_runner already forks

`trading/trading/backtest/scenarios/scenario_runner.ml` lines 295-360
implement a fork-based worker pool (`Core_unix.fork` + `Core_unix.waitpid`)
with a `--parallel N` flag defaulting to 4. Each child runs one scenario
to completion, writes its `actual.sexp` to disk, and exits; the parent
reaps and aggregates.

The decision below is **adopt this exact pattern for walk-forward**. The
reasoning:

- Identical concurrency model: each (variant, fold) is the parallelisable
  unit, exactly analogous to a scenario in scenario_runner.
- Zero new dependencies. We already pay for `Core_unix.fork` everywhere.
- No OCaml-5-Domains coordination story to design from scratch (no need
  for `Domainslib.Task.run`, no risk of accidentally sharing Hashtbls
  across Domains).
- Fork-after-load means the child inherits the parent's already-loaded
  base scenario + spec via copy-on-write, so we don't re-parse those.
- Determinism is automatic: each child runs an independent backtest with
  no shared mutable state.

The three alternatives (Domainslib, subprocess via dune exec, threads)
are evaluated in §10 below; tl;dr they're all worse.

## 2. Concurrency boundary

**The parallelisable unit is the per-(variant, fold) call to
`_run_one ~fixtures_root` in
`trading/trading/backtest/walk_forward/lib/walk_forward_executor.ml`.**

Today (line 66-70):

```ocaml
let _evaluate_all ~fixtures_root ~base ~(spec : Spec.t) ~progress =
  let folds = WS.generate spec.window_spec in
  List.concat_map spec.variants ~f:(fun variant ->
      List.map folds ~f:(fun fold ->
          _evaluate_one_pair ~fixtures_root ~base ~fold ~variant ~progress))
```

Parallel rewrite (sketch — not the final code):

```ocaml
let _evaluate_all_parallel ~fixtures_root ~base ~(spec : Spec.t) ~progress
    ~(parallel : int) =
  let folds = WS.generate spec.window_spec in
  (* Build the canonical (variant outer, fold inner) workload as a
     flat indexed list so we can reorder results back into canonical
     order after parallel completion. *)
  let work =
    List.concat_mapi spec.variants ~f:(fun vi variant ->
        List.mapi folds ~f:(fun fi fold -> ((vi, fi), variant, fold)))
  in
  let by_index = (* (vi, fi) -> fold_actual *)
    _fork_pool_run ~parallel ~fixtures_root ~base ~progress work
  in
  (* Reorder back to canonical (variant outer, fold inner). *)
  List.map work ~f:(fun (key, _, _) -> Hashtbl.find_exn by_index key)
```

Workers fork-exec a single `(variant, fold)` evaluation, serialise the
resulting `fold_actual` to a temp file (sexp), and exit. The parent reaps
and assembles a Hashtbl keyed on `(variant_index, fold_index)`, then
projects back into the canonical (variant outer, fold inner) list shape
that `Walk_forward_report.compute` consumes.

The signature of `execute_spec` does NOT change; the docstring loses
the "Sequential execution" line.

## 3. Determinism

`Backtest.Runner.run_backtest` is pure of its arguments. Grep-verified
(2026-05-18):

| Hazard                | Result | Citation |
|-----------------------|--------|----------|
| Module-level `ref` / `Atomic` | NONE | `grep -rnE 'let.* = ref' trading/trading/backtest/lib/*.ml` empty |
| Global Hashtbl shared across calls | NONE | Hashtbls are locally constructed inside `Runner.run_backtest` (line 123) and discarded |
| `Random.` / `Splittable_random` usage | NONE | `grep -rnE 'Random\.\|Splittable_random' trading/trading/backtest/lib/ analysis/weinstein/` empty (excluding tests) |
| Shared mutable state in storage layer | NONE | `grep -rnE 'let.* = ref' analysis/data/storage/` empty |

The on-disk bars cache is read-only during a sweep, so concurrent file
reads from N children are safe (POSIX file reads are atomic for
small-buffer `pread`; OCaml `In_channel.read_all` calls do separate
fds, no shared cursor).

**Aggregate ordering invariant.** `Walk_forward_report.compute`
documents: "The stability list aggregates by variant label in
first-appearance order." So `_evaluate_all`'s output list shape must
remain (variant outer, fold inner). The parallel path satisfies this by
indexing children with `(variant_index, fold_index)` keys and projecting
back into the canonical iteration order after `waitpid` completes for
all of them. **Test plan §8 §B is the byte-identical-aggregate property
test that proves this.**

**Floating-point determinism.** Each fold is a single backtest in a
single process, so float ops are deterministic within that child. There
is no cross-fold accumulation that could be order-sensitive. The
aggregate metrics in `Walk_forward_report.compute` are stable reductions
(mean, max, min, count) over fold_actual records that are ordered
deterministically post-reassembly.

## 4. Resource budget

Container has typically 8 cores per the Docker dev environment used
for sweeps. `--parallel 4` is the sensible default (matches
scenario_runner); `--parallel 8` is the practical ceiling.

**RAM cost per child.** Each child loads:

- Universe symbols (~510 for sp500-2010-2026): ~50 KB sexp/CSV
- Daily bars: ~510 symbols × ~4000 trading days × 56 bytes/bar = ~115 MB
  per child (peak)
- Macro/sector indicator panels: ~50 MB
- Strategy state: <10 MB

Conservative per-child working set: **~250 MB**. At parallel=4 the peak
is ~1 GB, well inside the dev container's typical 8-16 GB allocation.
At parallel=8 the peak is ~2 GB.

**No mmap sharing of bars.** Children fork after the base scenario is
parsed but before any bars are loaded — each child reads the bars from
its own `Bar_data_source` path. We could share via mmap in a follow-up
PR (not in scope here); the win is modest because the bars are already
in OS page cache after the first child reads them.

**Configuration surface.**

- CLI flag: `--parallel N` on both `walk_forward_runner.exe` and
  `bayesian_runner.exe`. Default = 1 (sequential — preserves current
  behavior for existing callers).
- Env var: `WALK_FORWARD_PARALLEL=N` overrides the CLI default if no
  `--parallel` flag is given. Convenient for cron / orchestrator
  dispatch.
- Hard cap: 16 (sanity check; refuse `--parallel > 16` to prevent
  accidental fork-bombs).

## 5. Failure semantics

Today: any backtest failure raises `Failure` and aborts the whole sweep.

Under parallelism: **first-failure short-circuit** — when any child
exits with a non-zero status, the parent (a) terminates remaining
in-flight children with `SIGTERM`, (b) waits for them to reap, and (c)
re-raises the failure with the variant_label + fold_name attached.

This matches current behavior modulo timing: a serial sweep would have
stopped at the first failure too. The user gets the same exception
shape, just sooner.

Rationale for not "wait-all + aggregate errors": the BO loop's next
iteration depends on the current iteration's score. If iteration k
fails, iterations k+1..N have no use anyway. Aggregating errors for a
later-discarded run wastes wall time.

Scenario_runner takes a different position (it persists per-scenario
`actual.sexp` even on crash so the parent can show a FAIL row in the
summary table). That's right for catalog runs where the operator wants
to see N/M failures at a glance. The walk-forward case is different:
the BO loop is the consumer and it has no "partial sweep" semantics.

**Implementation: parent uses `Core_unix.kill ~pid ~signal:Signal.term`
on every remaining child once one fails.** Test plan §8 §D covers this.

## 6. Memory: in-process vs subprocess

| Approach            | Per-child RSS | Bar-cache sharing | Setup cost |
|---------------------|---------------|---------------------|------------|
| `Core_unix.fork`    | ~250 MB       | Via OS page cache (warm reads) | One fork + waitpid per (variant, fold) — millisecond range |
| Domainslib          | ~50 MB (shared heap) | Native (same heap) | New dependency + Domains-safe rewrite required for any module touching mutable state |
| Subprocess + exec   | ~250 MB + OCaml startup (~200 ms) | Via OS page cache (warm reads) | Sexp marshalling on stdin/stdout |

`Core_unix.fork` is the clear winner for this workload: low-overhead per
unit, no dependency cost, and matches the established scenario_runner
pattern.

A future optimisation could load the bars panel **once in the parent**
and rely on copy-on-write to share the (read-only) bars across children.
For the 510-symbol sp500-2010-2026 cell that saves ~115 MB per child ×
(N-1) children = ~345 MB at parallel=4. Worth a follow-up PR once we
have actual RSS measurements from the Phase A smoke run; not in scope
for this design.

## 7. CLI surface

### `walk_forward_runner.exe`

```
Usage: walk_forward_runner.exe --spec <spec.sexp> --out-dir <dir>
                               [--fixtures-root <path>]
                               [--parallel N]    (default 1, max 16)
```

### `bayesian_runner.exe`

```
Usage: bayesian_runner.exe --spec <spec.sexp> --out-dir <dir>
                           [--fixtures-root <path>]
                           [--parallel N]    (default 1, max 16)
```

The BO loop is inherently serial (each iteration's score informs the
next acquisition), so `--parallel` here applies **only to the
walk-forward CV grid inside one BO iteration**. With `--parallel 4` and
5 folds × 2 variants = 10 (variant, fold) cells per iteration, the
fork pool processes them in 3 batches of 4 + 1 batch of 2 = ~max-fold-time
× 3 wall time per iteration.

For the §0 reference: 80 iterations × ~3 batches × 5 min/batch ≈ 20 hr.
That's well inside the "8-12 hr" target if individual folds clock under
5 min, and 24 hr if they clock at 5-7 min.

## 8. Test plan

### A. Unit: fork pool reorders correctly (small)

Hand-craft a stub `_run_one` that returns a deterministic `fold_actual`
keyed by (variant_label, fold_name) — e.g. `total_return_pct =
hash(variant_label, fold_name) mod 100`. Run with 3 variants × 4 folds
at parallel=2, parallel=4, parallel=12. Assert all three runs produce
**byte-identical** `fold_actuals` lists.

Implementation hint: stub via dependency-injecting a `run_one` function
through `execute_spec`, mirroring how `bayesian_runner_evaluator.ml`
already injects `default_executor`. Avoids any real `Backtest.Runner`
invocation in the unit test.

### B. Property: parallel ≡ sequential on real backtests (slow)

Pick a small spec (1 variant × 2 folds, 30-day windows, 5-symbol
universe). Run with `--parallel 1` and `--parallel 4`. Assert the
emitted `aggregate.sexp` files are byte-identical via
`diff -q seq.sexp par.sexp`. Run both modes 5 times to flush out any
race condition / timing-dependent path.

Run via `dune runtest trading/trading/backtest/walk_forward/test`; tag
the test `@long` so it runs in CI but isn't part of the default fast
loop.

### C. Property: random fold-count + variant-count

Hypothesis-style generator: pick 1..5 variants, 1..8 folds, parallel
∈ {1, 2, 4, 8}; run twice (different parallel) and assert
byte-identical aggregates. 50 random configurations.

This is the structural test the §3 claim leans on. If it ever fires,
either determinism is broken or the result-reassembly logic is buggy.

### D. Failure injection: child crashes ⇒ parent terminates siblings

Stub `_run_one` to call `failwith "boom"` when `(variant_idx,
fold_idx) = (1, 2)`. Spawn at parallel=4 with 3 variants × 4 folds.
Assert:
- The parent re-raises `Failure "boom"` (or wraps it with variant/fold
  context).
- All sibling child PIDs are reaped within 5 seconds (no orphans).
- No `fold_actuals` partial file is left in `--out-dir`.

### E. Smoke: Bayesian sweep with parallel=4

Run the Bayesian production sweep spec (§Phase A of #1192's plan) with
`total_budget=5 --parallel 4`. Verify:
- bo_log.csv has 5 rows.
- The wall time is roughly 3-4× lower than `--parallel 1` smoke (modulo
  fork overhead).
- best.sexp parses + the param values vary across the 5 evals.

### Acceptance for the parallel feature itself

All of A, B, C, D pass; E demonstrates ≥3× speedup at parallel=4 on the
production spec. If E shows less than 3× speedup, root-cause before
landing PR-3 (might be I/O bottleneck on bars-cache reads — see §6's
mmap follow-up).

## 9. Effort estimate (PR-sized chunks)

### PR-1: `Fork_pool` library (~200 LOC + test)

New module `trading/trading/backtest/walk_forward/lib/fork_pool.ml{,i}`.
Generic `(work_item, result) Hashtbl.t fork pool` parameterised by:
- `parallel : int`
- `work : ('key * 'work) list` (must be marshallable as sexp)
- `run_one : 'work -> 'result` (must be marshallable as sexp)

Internals: `Core_unix.fork` + temp-file sexp write/read for IPC + a
worker queue keyed by child PID. Reuses scenario_runner's fork-pool
shape but generalised — once this lib lands, scenario_runner can
optionally migrate to it later (not in scope here).

Tests: §8 A + D against an in-process stub.

Files:
- `trading/trading/backtest/walk_forward/lib/fork_pool.ml` (~180 LOC)
- `trading/trading/backtest/walk_forward/lib/fork_pool.mli` (~50 LOC docstring)
- `trading/trading/backtest/walk_forward/test/test_fork_pool.ml` (~150 LOC)
- `trading/trading/backtest/walk_forward/lib/dune` (+1 dep: `core_unix`)
- `trading/trading/backtest/walk_forward/test/dune` (+1 test target)

### PR-2: Wire fork pool into `Walk_forward_executor` (~150 LOC + test)

Add `?parallel:int` parameter to `execute_spec`. Default is `1`
(sequential — preserves current behavior). When `parallel > 1`, route
the workload through `Fork_pool` instead of `List.concat_map`. The
post-pool reassembly produces the same list shape so
`Walk_forward_report.compute` is byte-identical.

Tests: §8 B + C against real (small) backtests.

Files:
- `trading/trading/backtest/walk_forward/lib/walk_forward_executor.ml`
  (~40 LOC delta; adds `_evaluate_all_parallel` helper)
- `trading/trading/backtest/walk_forward/lib/walk_forward_executor.mli`
  (~10 LOC delta; adds `?parallel:int`, updates docstring)
- `trading/trading/backtest/walk_forward/test/test_walk_forward_executor_parallel.ml`
  (~250 LOC; new file — gated `@long` if needed for CI cost)

### PR-3: CLI flag on both runners (~80 LOC)

Add `--parallel N` to `walk_forward_runner.exe` and `bayesian_runner.exe`
argument parsing. Wire to the new `?parallel` argument on `execute_spec`
(walk-forward path) and to `default_executor` (Bayesian path — needs a
small refactor so it can take a `~parallel` arg).

Files:
- `trading/trading/backtest/walk_forward/bin/walk_forward_runner.ml`
  (~20 LOC delta in `_parse_args` + 1 line in `_main`)
- `trading/trading/backtest/tuner/bin/bayesian_runner_evaluator.ml`
  (~15 LOC delta to make `default_executor` take a `~parallel` arg —
  injection point at line 67-70)
- `trading/trading/backtest/tuner/bin/bayesian_runner_evaluator.mli`
  (~5 LOC delta to docstring)
- `trading/trading/backtest/tuner/bin/bayesian_runner.ml` (~15 LOC delta
  to plumb the flag through)
- `trading/trading/backtest/tuner/bin/test/` (~20 LOC delta to existing
  test — verify the new flag is accepted but doesn't change semantics
  at default=1)

### Total estimate

~430 LOC across 3 PRs. PR-1 is the only "new module" PR; PR-2 and PR-3
are surgical edits. All three should land in the same session if the
`Fork_pool` design checks out under review.

## 10. Alternatives rejected

### (a) Domainslib

**Rejected.** OCaml 5.3.0 supports it (verified via `opam list`), but:

1. `Backtest.Runner` and `Weinstein_strategy` were written
   pre-Multicore. Even with no module-level `ref`/`Atomic`, the
   in-function Hashtbls + closures haven't been audited for Domains
   safety. Going Domainslib means an audit + likely some surgical
   `Atomic.t` upgrades in spots we don't know about yet.
2. Domainslib is not currently installed in the dev container
   (`opam list domainslib` reports `--`). Adding it is a new
   first-class dependency and a CI install step.
3. The win — shared heap, lower per-worker RSS — is dominated by the
   I/O cost of reading bars from disk (~115 MB/child sequential reads
   from OS page cache). The marginal speedup over fork is small.
4. We pay nothing today for fork; we pay an indefinite "Domains-safe?"
   tax forever if we adopt Domainslib.

If a future profile shows fork's RSS or startup cost dominating, we
can revisit. For the current sweep budget, fork is the right call.

### (b) Subprocess via `dune exec`

**Rejected.** Same RSS cost as fork (~250 MB per child) PLUS ~200 ms
OCaml startup + dune-build-context init per child. At 80 BO iterations
× 10 (variant, fold) cells = 800 spawns, the dune-exec overhead alone
is ~3 minutes total wall time, plus dune file-lock contention. No win
over fork.

### (c) Pthreads / Lwt / Async

**Rejected.** OCaml threads run on a single Domain so there's no
parallelism for CPU-bound backtests; Lwt/Async are I/O-concurrency
libraries, not CPU-parallelism libraries. Wrong tool.

## 11. Risks

| Risk                                              | Likelihood | Mitigation |
|---------------------------------------------------|------------|------------|
| Child fork inherits a parent-side file-handle that's not safe to share | Low | All file I/O in the backtest path is opened+closed within `run_backtest`; no parent-held cache fds. Test plan §B/C would surface this. |
| Result-reassembly key collision (`vi`, `fi` not unique enough) | Low | `(vi, fi)` is exactly the canonical iteration order; collisions are impossible. Tested in §8 A. |
| Fork bomb if a user passes `--parallel 1000` | Low | Hard cap at 16; reject with a helpful error. |
| `Core_unix.waitpid` hangs on a child that's deadlocked | Medium | Per-(variant, fold) timeout (e.g., 30 min) via `Core_unix.alarm` in the parent's reap loop. PR-1 includes this. |
| Sexp marshalling of `fold_actual` across the fork IPC introduces float-precision loss | Low | `fold_actual` derives `sexp`, but Sexp float printing uses %.17g (full IEEE 754 round-trip). Round-trip test in §8 A. |
| Child crashes before writing its result file ⇒ silent missing-key in the Hashtbl | Medium | Wrap child body in try/with that writes a sentinel "crashed" sexp before `exit 1`. Parent's reassembly detects sentinel + raises a structured error. Mirrors scenario_runner's `_write_crashed_actual` at line 304. |
| Bars cache contention at parallel=16 stresses disk I/O | Low | OS page cache absorbs repeat reads after the first child loads each bar. Worst case: the first batch is sequential-disk-bound but every batch after is cache-hot. |

## 12. Out of scope

- Bars-cache mmap sharing across children (§6) — separate follow-up
  PR; modest win, not blocking the Bayesian sweep.
- Domainslib migration — see §10 (a). Could revisit in a future
  M7-era multicore refactor.
- Cross-iteration BO parallelism (parallelising the BO loop itself
  via parallel-BO algorithms like q-EI / Thompson sampling) — different
  algorithm change, separate plan. The current plan only parallelises
  the walk-forward CV grid inside one iteration.
- Scenario_runner migration to the new `Fork_pool` lib — clean-up
  follow-up. The two fork pools are duplicative once PR-1 lands.
- Resume from partial sweep (`--resume`) — mentioned as a Risk in the
  Bayesian sweep plan §9; a separate ~1 LOC change to
  `bayesian_runner_runner` per that plan.

## 13. Acceptance gates (for this plan itself)

This plan is APPROVED when:

1. The fork-based concurrency boundary (§2) is acknowledged as the
   right unit (i.e., no objection that "the BO loop itself should be
   parallel").
2. The first-failure short-circuit policy (§5) is accepted (vs.
   wait-all + aggregate).
3. The 3-PR sequencing (§9) is accepted, including the call to land
   `Fork_pool` as a reusable library rather than walk-forward-specific
   plumbing.
4. The test plan (§8) is accepted — specifically the byte-identical
   aggregate assertion under §B + §C.

If any gate fails, revise the plan and re-circulate. If all pass,
proceed to PR-1.

## 14. Companion docs

- `dev/plans/bayesian-production-sweep-2026-05-18.md` — the sweep that
  motivates this work
- `trading/trading/backtest/walk_forward/lib/walk_forward_executor.mli`
  — the surface being parallelised (line 75 acknowledges the gap)
- `trading/trading/backtest/scenarios/scenario_runner.ml` lines 295-360
  — the fork-pool precedent we're cloning
- `dev/plans/bayesian-opt-2026-05-03.md` — original Bayesian T-B design
  (predates walk-forward CV)
