# Plan: backtest performance — measurement, attribution, hypothesis testing (2026-04-24)

## Why

Three findings in the last 24h converged on a single conclusion: we
ship perf-relevant code without measurement infra, and pay for it in
post-merge surprises.

1. **Local 10K-symbol A/B (PR #523)** — both Legacy and Tiered OOM at
   7.7 GB before the backtest loop starts. The shared `Loading
   universe from sectors.csv` and `Loading AD breadth bars` paths
   dominate at scale, upstream of any Tier-aware throttling.
2. **Local 292-symbol A/B (PR #524)** — Tiered uses **+95% RSS** vs
   Legacy (3.65 GB vs 1.87 GB). Diagnosis: `Bar_history` is
   append-only, never trimmed, so 1510 trading days × 292 symbols of
   stale bars accumulate in both — Tiered worse because it carries
   `Full.t.bars` on top of the same unbounded `Bar_history`.
3. **GHA `tiered-loader-ab` reports `peak RSS: UNAVAILABLE`** for
   every run because `/usr/bin/time` was missing from the dev
   container until #522 (now merged; image rebuild pending). So we've
   had ZERO continuous memory data on `main` since #508 landed
   2026-04-22.

User's three explicit asks (consolidated):
- Continuous CPU + memory monitoring on every `tiered-loader-ab` run,
  even after the Tiered flip.
- Memory attribution per phase / per data structure (so AD-breadth,
  inventory loading, Bar_history, Full.t.bars are each measurable
  individually).
- Broader goldens once perf is solved (rebuild the 7-symbol CI
  fixture; add bear-window scenarios).

This plan ties them together and adds the hypothesis-testing piece —
config flags + scoped fixtures so we can quickly answer "would
trimming Bar_history close the gap?" or "does AD-breadth dominate
RSS at scale?" without hand-rolling new harnesses each time.

## Goal

A measurement infrastructure where every `tiered-loader-ab` run
emits CPU + RSS + per-phase attribution data into a tracked CSV,
where individual hypotheses can be tested by toggling config flags
on a controlled scenario set, and where broader-universe goldens
exist as first-class scenarios with maintained baselines.

## Three workstreams (parallelizable, sequenced within each)

### Workstream A — Continuous CPU + RSS monitoring in CI

Goal: every `tiered-loader-ab` run leaves a chartable history row
in `dev/perf/<date>-runN.csv` on main.

- **A1.** Wait for #522 image rebuild to complete + cache
  invalidation, then verify `tiered-loader-ab` next run reports
  numeric peak RSS for both Legacy and Tiered. (Gate, not a PR.)
- **A2.** Add aggregation step to `tiered-loader-ab.yml` that
  appends one row per scenario × strategy to a `dev/perf/<date>-runN.csv`
  file. Columns: `date, scenario, strategy, peak_rss_kb, wall_time_s,
  user_cpu_s, sys_cpu_s, git_sha, runner_arch`. Commit on a
  separate `perf/` branch with auto-merge so historical chart data
  grows in main without per-run reviewer overhead.
- **A3.** Optional: render a chart from `dev/perf/*.csv` and post
  to PR comments / GitHub Pages. Skip until ~30 days of data exists.

Estimated total: ~150 LOC (mostly YAML + a small aggregator script).

### Workstream B — Memory attribution / Trace.Phase gap-fill

Goal: every backtest run's `Trace.t` records peak RSS + GC heap +
allocated bytes per phase, including the currently-unwrapped
Metadata-promote path; partial traces survive OOM via flush-on-error.

Reference: `dev/notes/memory-profiling-framework-2026-04-24.md`
captures the existing-vs-missing analysis. Steps below pick the
6-step sketch from that note and concretize it.

- **B1 [DONE, #534].** Wrap `Tiered_runner.promote_universe_metadata`
  in a new `Trace.Phase.Promote_metadata` variant. Closes the
  documented trace hole.
- **~~B2.~~ ~~Add `Gc.stat` snapshot to `phase_metrics`.~~**
  **CANCELLED 2026-04-24** — superseded by B7 (memtrace). Memtrace
  gives per-callsite allocation attribution at higher resolution
  than aggregate Gc.stat-per-phase, with no manual instrumentation
  cost. Don't ship.
- **B3 [in flight].** Add flush-on-error to `Trace.t`: write
  `dev/backtest/traces/<id>.sexp` after every `Trace.record` call,
  not at end-of-run. Cost: more I/O per phase. Benefit: SIGKILL'd
  OOM runs leave the smoking-gun phase recorded. ~40 LOC.
- **B4 [DONE, #533].** Add `--trace` flag to `backtest_runner.exe`
  (previously only `scenario_runner.exe` enabled tracing).
- **B5 [DEFERRED].** Split `Macro` (= AD-breadth load) into
  sub-phases: `Macro_load_advances`, `Macro_load_declines`,
  `Macro_compute_breadth`. Partially superseded by B7 — memtrace
  shows AD-breadth's allocation pattern at callsite granularity
  without needing per-sub-phase wrapping. Defer indefinitely; pick
  up only if memtrace data points at AD-breadth as the dominant
  allocator AND the wrapping would add operational value (e.g.,
  CI failure-on-regression by sub-phase RSS).
- **B6 (optional).** Background sampler thread reading
  `/proc/self/statm` at 100ms for honest peak-during-phase numbers
  (current `peak_rss_kb` reads VmHWM AFTER the phase, so transient
  spikes are hidden). Only worth it if B7 (memtrace) data leaves a
  question about transient vs sustained peaks. Likely never needed.
  ~120 LOC.
- **B7 [NEW, prioritized].** Adopt
  [`memtrace`](https://github.com/janestreet/memtrace) — Jane Street's
  OCaml memory profiler using `Gc.Memprof` statistical sampling.
  Per-callsite allocation traces in `.ctf` format consumable by
  `memtrace_viewer` (separate package; produces flamegraphs +
  allocation tables). Adoption shape: add `memtrace` opam dep,
  gate `Memtrace.start_tracing` on either an env var
  (`MEMTRACE_OUT=/path/to/trace.ctf`) or a `--memtrace <path>` flag
  on `backtest_runner.exe`. Default off; zero overhead when
  unused. Once the dep is in, `dev/scripts/run_perf_hypothesis.sh`
  (C2) gains a third output file per run (`<side>.memtrace.ctf`).
  ~50 LOC integration + opam dep + Dockerfile add. **First real
  use:** run the 292-symbol scoped A/B from `h1-result-2026-04-24.md`
  with memtrace on; the resulting `.ctf` shows exactly which
  callsite allocates the missing ~1.8 GB / ~3.6 GB.

  **Why it supersedes B2/B5:** B2 + B5 together would have given
  per-phase Gc.stat + a 3-way Macro split (~5 fields per phase ×
  ~14 phases × 1500 days = ~100K aggregate data points).
  Memtrace gives per-allocation samples (~1e-5 sampling rate
  default = ~10K samples per backtest) with full call stacks. The
  attribution resolution is higher AND the data volume is lower.
  Maintenance cost (one opam dep) is far less than B2's ongoing
  responsibility for the Gc.stat schema.

Estimated total post-revision: ~150 LOC across 3 PRs (B3 in
flight, B7 new, B6 optional/skip).

### Workstream C — Hypothesis-testing harness + broader goldens

Goal: single command runs a controlled A/B with a named hypothesis,
emits a short report (RSS, PV, trade-count, Sharpe deltas) keyed on
a hypothesis ID. Plus broader scenario coverage.

- **C1.** Hypothesis-toggle config fields. Add to
  `Weinstein_strategy.config`:
  - `bar_history_max_lookback_days : int option` (drives the
    Bar_history trim from `bar-history-trim-2026-04-24.md`)
  - `skip_ad_breadth : bool` (gates `Ad_bars.load`; for measuring
    "what if AD-breadth load were O(1)?")
  - `skip_sector_etf_load : bool` (similar)
  - `universe_cap : int option` (truncate sector map to N symbols
    after sort)
  Each independently togglable via `--override`. ~60 LOC + mli + tests.

- **C2.** `dev/scripts/run_perf_hypothesis.sh <name> <scenario>
  <override>` — wraps `tiered_loader_ab_compare.sh` with a named
  hypothesis ID. Writes `dev/experiments/perf/<hypothesis-id>/`
  with: `legacy.{rss,trace,output}`, `tiered.{rss,trace,output}`,
  `report.md` (auto-generated comparative table), `repro.sh`
  (regenerable command). ~100 LOC of bash.

- **C3.** Rebuild `goldens-broad/` with a real broad sector map.
  Two shapes:
  - **(a) Fixture-as-data.** Commit a 1654-symbol `sectors.csv` +
    matching CSV fixtures into the repo (large but auditable).
  - **(b) Fixture-via-fetch.** GHA workflow fetches a snapshot of
    `data/sectors.csv` + per-symbol CSVs into runner cache before
    `tiered-loader-ab` runs. (Smaller repo, depends on fetch infra.)
  Decide based on size of the snapshot. Estimated: ~200 LOC + data.

- **C4.** Add bear-window scenarios to `goldens-small/` and
  `goldens-broad/`: `bear-2008-crisis.sexp`,
  `bear-2022-rate-hikes.sexp`, etc. Unblocks the
  `short-side-strategy.md` § Follow-up #1 (bear-window backtest
  regression). ~5 scenarios × ~30 LOC each.

- **C5 (optional).** Per-scenario expected RSS / wall-time pinning,
  parallel to the existing PV / Sharpe expected ranges. Lets
  `tiered-loader-ab` fail on perf regression independently of
  parity regression. ~50 LOC.

Estimated total: ~700 LOC across 5 PRs.

## Hypothesis catalog (testable once C1 lands)

Each entry = one row of `dev/experiments/perf/<id>/report.md` once
the harness runs. Suggested order — H1 first because the agent is
already working on the trim primitive (`bar-history-trim-2026-04-24.md`).

| ID | Hypothesis | Test (config overrides) | Expected if true |
|---|---|---|---|
| **H1** | Bar_history trim closes the +95% Tiered RSS gap | `--loader-strategy {legacy,tiered} --override '(bar_history_max_lookback_days 365)'` | Both RSS drop ~3×; Tiered/Legacy ratio approaches 1.0 + small bounded `Full.t.bars` overhead |
| **H2** | `Full.t.bars` duplication dominates Tiered's residual after H1 | A/B with H1 + with/without `Full_compute.tail_days` halved | Tiered RSS drops further by half of `Full.t.bars` size |
| **H3** | AD-breadth load dominates upstream RSS at ≥10K-symbol scale | `--override '(skip_ad_breadth true)'` on broad universe | RSS drops by AD-breadth slice; OOM avoided |
| **H4** | Sector ETF + index loads are bounded (not the bottleneck) | `--override '(skip_sector_etf_load true)'` | RSS unchanged by more than ~50 MB |
| **H5** | RSS scales linearly with universe size | `--override '(universe_cap N)'` for N ∈ {100, 300, 1000, 3000, 10000} | Linear fit holds; intercept = AD-breadth + fixed-overhead |
| **H6** | Per-bar phase tracing overhead < 5% | A/B with/without `--trace` | Wall-time delta < 5% |

Each hypothesis test = a single command + one report. Cheap to
re-run after any landed PR to confirm the prediction held or update
the doc with the actual finding.

## Integration with existing tracks

- `bar-history-trim-2026-04-24.md` (the existing 6-PR sequence
  triggered by PR #524's diagnosis) IS the implementation of H1's
  premise. PR 4 in that plan is exactly the H1 measurement using
  C1's `bar_history_max_lookback_days` override. So C1 must land
  before that PR 4 — adding it as a dependency.
- `backtest-scale.md` § Follow-up "Broad-universe goldens are
  testing on a 7-symbol fixture" — that's exactly C3. Move ownership
  here once this plan lands.
- Reciprocal short-side practical block in `backtest-scale.md` §
  Follow-up — unblocks via C4.

## Suggested status file

Create `dev/status/backtest-perf.md` to track this plan. Status
fields:
- Status: PENDING (no PRs open yet)
- Owner: feat-backtest (sibling track to backtest-scale and
  backtest-infra)
- Branch convention: `feat/backtest-perf-<workstream>-<step>` (e.g.
  `feat/backtest-perf-A2-csv-aggregation`)

Add a row to `dev/status/_index.md` once the status file lands.

## Workstream order (revised 2026-04-24 post-memtrace)

Status of completed steps in **bold**.

1. **A1 [DONE]** (#522 image rebuild — `/usr/bin/time` available; A/B
   workflow now reports numeric peak RSS).
2. **C1 [DONE, #528]** (config overrides for H-series).
3. **B1 [DONE, #534] + B4 [DONE, #533]** (Metadata-promote phase +
   `--trace` flag) — phase-level tracing on `backtest_runner.exe`
   is live.
4. **B3 [in flight] + C2 [in flight]** — flush-on-error +
   hypothesis-test harness (parallel agents). After both land, the
   profiling tool stack is feature-complete for non-allocation
   data.
5. **B7 [next]** — adopt memtrace. Once the dep is in,
   `run_perf_hypothesis.sh` (C2) gains a `<side>.memtrace.ctf`
   output per run. **THIS** is the missing piece for the +95%
   Tiered RSS investigation.
6. **A2** — CSV aggregation in CI for continuous monitoring.
7. **First real H-series measurements using memtrace data:**
   - **H3** (skip_ad_breadth on broad universe) — does AD-breadth
     dominate at scale? Memtrace shows the answer directly.
   - **H2** (Full.t.bars duplication accounts for Tiered's
     residual after H1 was disproved). Memtrace shows what's
     duplicated.
   - **H5** (RSS scales linearly with universe size). Memtrace +
     `universe_cap` overrides give the curve.
8. **C3 + C4** — broader fixtures + bear scenarios. Likely needed
   to validate H3 at production scale.

Workstreams can proceed in parallel where files don't conflict.
B3 + C2 are running concurrently right now.

**~~B2.~~ ~~B5.~~** Cancelled / deferred — see Workstream B above.

## Acceptance per PR

Standard `feat-backtest` checklist (`.claude/agents/feat-backtest.md` §
Acceptance Checklist) applies. Per-workstream additions:
- **A**: any A2/A3 PR must include a manual workflow_dispatch
  showing the new CSV row landed in main.
- **B**: any B1–B6 PR must include a sample trace sexp on a known
  scenario showing the new field/phase populated.
- **B7**: must include a sample `.ctf` file showing memtrace captured
  allocations on a small backtest, plus a `memtrace_viewer` screenshot
  or text summary identifying at least the top-3 allocators.
- **C**: any C1–C5 PR must include a `dev/experiments/perf/<id>/`
  directory exercising the new override / fixture.

## Out of scope (separate tracks)

- **AD-breadth refactor itself.** This plan instruments and
  measures AD-breadth memory cost; it does not propose how to make
  AD-breadth O(1)-memory. That's a separate strategy / data-layer
  concern owned by `feat-weinstein` or a new track.
- **Parallel backtest workers.** Orthogonal axis; if anything,
  measurement infra here makes the case for / against parallelism
  cleaner once we have hypothesis-test data.
- **Tiered loader correctness fixes.** Owned by
  `backtest-scale.md`; this plan assumes the Tiered flip will
  proceed (or not) per that track's gates.
