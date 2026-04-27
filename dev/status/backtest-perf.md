# Status: backtest-perf

## Last updated: 2026-04-27

## Status
IN_PROGRESS

Steps 1+2 (`feat/backtest-perf-tier1-catalog`, PR #574) merged 2026-04-26T16:07Z. The `perf-tier1.yml` workflow file remains **held out** (agent PAT lacks `workflow` scope) — needs maintainer follow-up to commit the drafted YAML from #574's PR body. Steps 3+4 (tier-2 nightly + tier-3 weekly workflows) outstanding and have the same scope-blocker. Step 5 (release_perf_report OCaml exe) tracked separately; landed via #585 / #606 on the test-data + perf-runner side. Tier-4 release-gate scenarios structurally unblocked since data-panels Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z. **Engine-layer-pooling PR-1 (Gc.stat instrumentation, ~50 LOC measurement-only)** open for review at PR #618 (branch `feat/backtest-perf-engine-pool-instrument`); confirms `Engine.update_market` dominates the per-tick allocator profile on real data so PR-2..PR-4 (per-symbol scratch + float-array buffers + buffer pooling) can land with confidence.

## Interface stable
NO

## Goal

Continuous perf coverage in CI + formal release-gate strategy. Two
regression dimensions tracked together:

1. **Trading-performance metrics** — return %, Sharpe ratio, win
   rate, max drawdown, trade count, P&L. Catches strategy
   regressions: "did this commit change Sharpe by 0.2?"
2. **Infra-performance profile** — peak RSS, wall-time, per-phase
   allocation breakdown, memtrace .ctf. Catches infra regressions:
   "did this commit double peak memory at N=1000?"

A single scenario run produces BOTH outputs, with separate
pass-criteria sections.

## Plan

`dev/plans/perf-scenario-catalog-2026-04-25.md` (PR #550) — full
4-tier catalog (per-PR / nightly / weekly / release) + cataloging
mechanics + release-gate procedure.

## Open work

- **PR #550** (plan, doc-only) — MERGED 2026-04-25.
- **`feat/backtest-perf-tier1-catalog`** (Steps 1+2) — open for review.
  Adds tier headers to all 15 catalog scenarios, the
  `perf_catalog_check.sh` integrity gate (annotate-only), the
  `perf_tier1_smoke.sh` runner, and the `perf-tier1.yml` GHA
  workflow.
- **`feat/backtest-perf-engine-pool-instrument`** (engine-pooling PR-1) —
  PR #618 open for review. Per-step `Gc.stat` snapshots in
  `Panel_runner.run`, gated by the existing `?gc_trace`. Confirms
  `Engine.update_market` is the dominant per-tick allocator before
  the buffer-reuse refactors land (PR-2..PR-4 per
  `dev/plans/engine-layer-pooling-2026-04-27.md`).

## Completed

- **Engine-pooling PR-1 — Gc.stat instrumentation** (2026-04-27, PR #618).
  Per-step `Gc.stat` snapshots in `Panel_runner.run`, gated by the
  existing `?gc_trace`. Phase labels `step_<YYYY-MM-DD>_before` /
  `step_<YYYY-MM-DD>_after` interleave between `macro_done` and
  `fill_done` so a CSV consumer can pair them by date and recover
  per-day deltas. When `gc_trace = None` the loop is functionally
  identical to `Simulator.run` modulo one `Option.is_some` check per
  step. Smoke check on a 6-month tier-1 run produces 476 per-step
  rows; cumulative `minor_words` climbs 2.8M→93M, ready to be
  diffed step-by-step. Verify:
  `_build/default/trading/backtest/bin/backtest_runner.exe \
   2019-06-03 2019-06-30 --gc-trace /tmp/gc_smoke.csv` then
  `grep -c step_ /tmp/gc_smoke.csv` (expect ~476). Files:
  `trading/trading/backtest/lib/panel_runner.{ml,mli}`,
  `trading/trading/backtest/lib/runner.{ml,mli}`,
  `trading/trading/backtest/test/test_panel_runner_gc_trace.ml`.

- **Step 1 — scenario catalog headers** (2026-04-26).
  Added `;; perf-tier: <1|2|3|4>` + `;; perf-tier-rationale: ...` to
  every scenario sexp under `goldens-small/`, `goldens-broad/`,
  `perf-sweep/`, `smoke/`. Tier breakdown:
  - **Tier 1** (per-PR, ≤2 min): 4 scenarios —
    `smoke/{tiered-loader-parity, panel-golden-2019-full}`,
    `perf-sweep/{bull-3m, bull-6m}`.
  - **Tier 2** (nightly, ≤30 min): 6 scenarios —
    `goldens-small/*`, `smoke/{bull-2019h2, crash-2020h1, recovery-2023}`.
  - **Tier 3** (weekly, ≤2 h): 2 scenarios —
    `perf-sweep/{bull-1y, bull-3y}`.
  - **Tier 4** (release-gate, ≤8 h): 3 scenarios —
    `goldens-broad/*` (currently SKIPPED placeholders).

  Verify: `sh trading/devtools/checks/perf_catalog_check.sh` -> "OK: 15
  scenarios all carry tier tags."
- **Step 2 — tier-1 smoke gate** (2026-04-26).
  - `trading/devtools/checks/perf_catalog_check.sh` + dune wiring —
    grep-based integrity check; annotate-only by default, strict via
    `PERF_CATALOG_CHECK_STRICT=1`.
  - `dev/scripts/perf_tier1_smoke.sh` — POSIX-sh runner that
    auto-discovers `;; perf-tier: 1` scenarios, runs each via
    `scenario_runner.exe` with `timeout 120`, captures wall-time + peak
    RSS, prints a summary table.
  - `.github/workflows/perf-tier1.yml` — **drafted but held out of this
    PR** because the agent's PAT lacks the `workflow` scope required to
    push GHA workflow files. The script + check + headers all land in
    this PR; a maintainer follow-up needs to add the workflow file
    using a workflow-scoped token. Draft YAML is in the PR body /
    branch history for paste-and-commit. Sibling workflow design
    (`pull_request` + `push: main` triggers, non-blocking
    (`continue-on-error: true`), publishes summary to
    `$GITHUB_STEP_SUMMARY`).
  - Verify locally: `dev/scripts/perf_tier1_smoke.sh` (run inside the
    devcontainer or with `TRADING_IN_CONTAINER=1`).

## Next steps

1. (NEXT) Define tier 2 (nightly, 5 cells per the plan, mapped onto the
   6 currently-tagged tier-2 scenarios) + create `perf-nightly.yml`.
   ~80 LOC YAML.
2. Define tier 3 (weekly, 4 cells per the plan, mapped onto the 2
   currently-tagged tier-3 scenarios — may need to expand) + sibling
   weekly workflow. ~80 LOC YAML.
3. Tier 4 (release-gate, 5000-stock decade-long) — was blocked on the
   `data-panels` refactor (`dev/status/data-panels.md`); stages 0-3
   landed (PRs #555, #557, #558, #559-565, #567, #569, #573).
   Likely follows Stage 4 too. Current Tiered would extrapolate to
   ~31 GB at 5000×10y; columnar projects to ~1.2 GB, well under the
   8 GB ceiling.
4. After ~10 PR cycles of tier-1 perf data: pin per-cell budgets and
   flip `continue-on-error: false` on `perf-tier1.yml` and
   `PERF_CATALOG_CHECK_STRICT=1` on the catalog check.
5. **`release_perf_report` OCaml exe.** Markdown report comparing the
   current release's tier-3/4 scenario results vs the prior release —
   N×T peak-RSS matrix, wall-time matrix, regression flags. Drives
   release-gate Step 3 in `dev/plans/perf-scenario-catalog-2026-04-25.md`.
   Replaces the deleted `dev/scripts/perf_sweep_report.py` (Legacy-vs-
   Tiered axis is gone post-PR #575; need single-mode N×T tables instead).
   Per `.claude/rules/no-python.md`: write fresh in OCaml, do not port.
   Lands together with or just before tier-3 weekly workflow (Step 2)
   so the weekly run produces a useful diff vs the prior week. ~150 LOC
   exe + .mli + tests.

## Ownership

`feat-backtest` agent (sibling of backtest-infra and backtest-scale).
Pure infra work — scenario cataloging, GHA workflows, report
generators.

## Branch

`feat/backtest-perf-<step>` per item above. Active:
`feat/backtest-perf-tier1-catalog` (Steps 1+2).

## Blocked on

- **Tier 4 release-gate scenarios** are blocked on the `data-panels`
  refactor (stages 0-3 at minimum) landing. Tiers 1-3 can proceed
  independently.

## Decision items (need human or QC sign-off)

Carried verbatim from `dev/plans/perf-scenario-catalog-2026-04-25.md`:

1. Are the tier costs (per-PR ≤2min, nightly ≤30min, weekly ≤2h,
   release ≤8h) the right budget?
2. Tier 4 pass criteria — what RSS / wall budget defines a passing
   release? Today's bull-crash 1000-symbol Tiered = 3.7 GB; 5000
   stocks would extrapolate to ~31 GB Tiered. The `data-panels`
   refactor (PR #554) projects ~1.2 GB at the same scale, so
   tier-4 criteria can stay tight (~8 GB ceiling) once it lands.
3. Should `perf_catalog_check` fail builds or annotate-only?
   Initial: annotate-only.
4. Tracking format: CSV in repo (auditable, grows) vs external store.
   Initial: CSV in repo.

## References

- Plan: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Existing perf harness: `dev/scripts/run_perf_hypothesis.sh` (#537),
  `dev/scripts/run_perf_sweep.sh` (#547)
- Sibling track: `dev/status/data-panels.md` — tier 4 blocker
  (supersedes the older `incremental-indicators` track)
- Predecessor: `dev/status/backtest-infra.md` (MERGED) for the
  experiments/analysis side this builds on
