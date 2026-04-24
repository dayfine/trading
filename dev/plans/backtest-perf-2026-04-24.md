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

- **B1.** Wrap `Tiered_runner.promote_universe_metadata` in a new
  `Trace.Phase.Promote_metadata` variant. Closes the documented
  trace hole. Tiny: ~30 LOC + new variant in `trace.mli`.
- **B2.** Add `Gc.stat` snapshot to `phase_metrics`: new fields
  `live_words : int option`, `heap_words : int option`,
  `allocated_bytes : float option` (cumulative). All optional so
  legacy traces deserialize. ~50 LOC.
- **B3.** Add flush-on-error to `Trace.t`: write
  `dev/backtest/traces/<id>.sexp` after every `Trace.record` call,
  not at end-of-run. Cost: more I/O per phase. Benefit: SIGKILL'd
  OOM runs leave the smoking-gun phase recorded. ~40 LOC.
- **B4.** Add `--trace` flag to `backtest_runner.exe` (currently
  only `scenario_runner.exe` enables tracing). ~20 LOC.
- **B5.** Split `Macro` (= AD-breadth load) into sub-phases:
  `Macro_load_advances`, `Macro_load_declines`,
  `Macro_compute_breadth`. Reveals what's really happening inside
  the monolithic `Weinstein_strategy.Ad_bars.load`. ~80 LOC.
- **B6 (optional).** Background sampler thread reading
  `/proc/self/statm` at 100ms for honest peak-during-phase numbers
  (current `peak_rss_kb` reads VmHWM AFTER the phase, so transient
  spikes are hidden). Only worth it if B1+B2+B3 don't explain a
  given OOM. ~120 LOC.

Estimated total: ~250 LOC across 5–6 PRs.

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

## Workstream order (once started)

Suggested order to unblock the most measurement value soonest:
1. **A1** (gate; no PR — wait for #522 image rebuild)
2. **C1** (config overrides for H-series)
3. **B1 + B4** (Metadata-promote phase + `--trace` flag) — minimum
   to get phase-level measurement on `backtest_runner.exe`
4. **A2** (CSV aggregation in CI) — start collecting nightly data
5. **B3** (flush-on-error) — needed to investigate OOMs
6. **C2** (hypothesis-test harness) — formalize the manual
   one-shot reports we've been writing today into reproducible
   experiment dirs
7. **B2 + B5** — refine attribution
8. **C3 + C4** — broader fixtures + bear scenarios

Workstreams A and B can proceed in parallel after #522 image
rebuild. C1 must happen before any H-series test can run.

## Acceptance per PR

Standard `feat-backtest` checklist (`.claude/agents/feat-backtest.md` §
Acceptance Checklist) applies. Per-workstream additions:
- **A**: any A2/A3 PR must include a manual workflow_dispatch
  showing the new CSV row landed in main.
- **B**: any B1–B6 PR must include a sample trace sexp on a known
  scenario showing the new field/phase populated.
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
