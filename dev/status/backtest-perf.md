# Status: backtest-perf

## Last updated: 2026-04-27

## Status
IN_PROGRESS

Steps 1+2 (`feat/backtest-perf-tier1-catalog`, PR #574) merged
2026-04-26T16:07Z. **`perf-tier1.yml` landed via PR #616 on 2026-04-27**
— per-PR perf smoke is now wired (continue-on-error: true for now;
gate later). **Tier-2 nightly workflow landed via PR #622 on
2026-04-27**: `perf_tier2_nightly.sh` +
`.github/workflows/perf-nightly.yml`, six tier-2 cells, 30 min/cell
budget, cron `0 5 * * *` (22:00 PT). **Tier-3 weekly workflow open
at `feat/backtest-perf-tier3-weekly` on 2026-04-27**:
`perf_tier3_weekly.sh` + `.github/workflows/perf-weekly.yml`, two
tier-3 cells (`perf-sweep/{bull-1y, bull-3y}`), 2 h/cell budget,
cron `0 7 * * 1` (Monday 00:00 PT). **Engine-layer-pooling PR-1
(Gc.stat instrumentation, panel_runner per-step snapshots) merged
via PR #618 on 2026-04-27**; PR-2..PR-4 (per-symbol scratch +
float-array buffers + buffer pooling) gated on a 3-month
full-universe gc-trace run that confirms the engine-update-market
wedge. Step 5 (release_perf_report OCaml exe) tracked separately;
landed via #585 / #606 on the test-data + perf-runner side. Tier-4
release-gate scenarios structurally unblocked since data-panels
Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z.

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
- **`feat/backtest-perf-tier3-weekly`** (Step 4 — tier-3 weekly) —
  open for review. Adds `dev/scripts/perf_tier3_weekly.sh` +
  `.github/workflows/perf-weekly.yml`. Auto-discovers both
  `;; perf-tier: 3` scenarios under
  `trading/test_data/backtest_scenarios/perf-sweep/{bull-1y,bull-3y}.sexp`,
  runs each via `scenario_runner.exe --parallel 1` with
  `timeout 7200`, publishes wall + peak-RSS table to
  `$GITHUB_STEP_SUMMARY`. Cron `0 7 * * 1` (Monday 00:00 PT PDT /
  23:00 PT Sunday PST), 2 h after perf-nightly's 05:00 UTC slot and
  17 min before the orchestrator's 07:17 UTC slot. Non-blocking
  (`continue-on-error: true`) — same VISIBILITY-first posture as
  tier-1/tier-2. Tier-4 release-gate workflow remains outstanding
  (separate PR; gated on engine-pool PR-2..PR-5).

## Completed

- **Step 4 — tier-3 weekly perf workflow** (2026-04-27, PR pending).
  Mirrors the tier-1/tier-2 pattern. Adds
  `dev/scripts/perf_tier3_weekly.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 3` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 7200` = 2 h,
  captures wall + peak RSS, writes `summary.txt`) and
  `.github/workflows/perf-weekly.yml` (cron `0 7 * * 1` = 00:00 PT
  Monday PDT / 23:00 PT Sunday PST; 2 h after perf-nightly's 05:00
  UTC and 17 min before the orchestrator's 07:17 UTC; same
  `trading-ci:latest` container, same `_build` cache, same
  `continue-on-error: true` posture as tier-1/tier-2; publishes
  summary to `$GITHUB_STEP_SUMMARY`; `timeout-minutes: 300` job
  ceiling). Two tier-3 cells covered:
  `perf-sweep/{bull-1y, bull-3y}`. Verify locally:
  `dev/scripts/perf_tier3_weekly.sh` inside the devcontainer (or
  with `TRADING_IN_CONTAINER=1`); the workflow itself is exercised
  on its first scheduled run (next Monday 07:00 UTC) or via manual
  `workflow_dispatch`.

- **Step 3 — tier-2 nightly perf workflow** (2026-04-27, PR #622 merged).
  Mirrors the tier-1 pattern. Adds
  `dev/scripts/perf_tier2_nightly.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 2` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 1800`, captures
  wall + peak RSS, writes `summary.txt`) and
  `.github/workflows/perf-nightly.yml` (cron `0 5 * * *` = 22:00 PT
  PDT / 21:00 PT PST, well clear of the orchestrator's 07:17/12:17
  UTC slots; same `trading-ci:latest` container, same `_build` cache,
  same `continue-on-error: true` posture as tier-1; publishes summary
  to `$GITHUB_STEP_SUMMARY`). Six tier-2 cells covered:
  `goldens-small/{bull-crash-2015-2020, covid-recovery-2020-2024,
  six-year-2018-2023}` and `smoke/{bull-2019h2, crash-2020h1,
  recovery-2023}`. Verify locally: `dev/scripts/perf_tier2_nightly.sh`
  inside the devcontainer (or with `TRADING_IN_CONTAINER=1`); the
  workflow itself is exercised on its first scheduled run / manual
  `workflow_dispatch`.

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

1. (DONE) Tier 2 (nightly) — `perf-nightly.yml` +
   `perf_tier2_nightly.sh` merged in PR #622 on 2026-04-27. Six
   tier-2 cells, 30 min budget per cell, cron `0 5 * * *` (22:00 PT).
2. (DONE on this PR) Tier 3 (weekly) — `perf-weekly.yml` +
   `perf_tier3_weekly.sh`, two tier-3 cells
   (`perf-sweep/{bull-1y, bull-3y}`), 2 h budget per cell, cron
   `0 7 * * 1` (Monday 00:00 PT). The tier-3 cell count is below
   the original plan's 4 because tagged tier-3 scenarios are
   currently 2; expanding the catalog (e.g., bull-crash 1000×6y,
   covid-recovery 300×4y, six-year 300×6y per the plan's Tier 3
   table) is a follow-up scenario-authoring task, not gating on
   the workflow itself.
3. Tier 4 (release-gate, 5000-stock decade-long) — was blocked on the
   `data-panels` refactor (`dev/status/data-panels.md`); stages 0-3
   landed (PRs #555, #557, #558, #559-565, #567, #569, #573).
   Likely follows Stage 4 too. Current Tiered would extrapolate to
   ~31 GB at 5000×10y; columnar projects to ~1.2 GB, well under the
   8 GB ceiling.
4. **Tier-1 smoke is broken — universe_path resolution.** As of
   2026-04-27, every tier-1 run since #616 landed fails 4/4 with
   `Sys_error: ".../trading/trading/test_data/backtest_scenarios/
   universes/broad.sexp: No such file or directory"` (note the
   doubled `trading/trading/`). The smoke's `_stage_<name>` copy
   approach loses the original fixtures-root context, so
   `scenario_runner.exe --dir <stage>` resolves `(universe_path
   "universes/broad.sexp")` against the wrong base path.
   `continue-on-error: true` masks the failure in the job-level
   conclusion. Functionally tier-1 smoke gates nothing right now.
   **Defer the fix to after engine-pool PR-2..5 land** so we don't
   churn `dev/scripts/` mid-stack. Then fix the universe_path
   resolution + flip `continue-on-error: false` +
   `PERF_CATALOG_CHECK_STRICT=1`.
5. After ~10 PR cycles of *real* tier-1 perf data (i.e. post
   smoke-fix above): pin per-cell budgets. Same flip applies to
   `perf-nightly.yml` once tier-2 budgets are pinned (~10 weeks of
   nightly data) and to `perf-weekly.yml` once tier-3 budgets are
   pinned (~10 weekly cycles).
6. **`release_perf_report` OCaml exe.** Markdown report comparing the
   current release's tier-3/4 scenario results vs the prior release —
   N×T peak-RSS matrix, wall-time matrix, regression flags. Drives
   release-gate Step 3 in `dev/plans/perf-scenario-catalog-2026-04-25.md`.
   Replaces the deleted `dev/scripts/perf_sweep_report.py` (Legacy-vs-
   Tiered axis is gone post-PR #575; need single-mode N×T tables instead).
   Per `.claude/rules/no-python.md`: write fresh in OCaml, do not port.
   Now lands as a follow-up after tier-3 weekly so the weekly run
   has data to diff against. ~150 LOC exe + .mli + tests.

## Ownership

`feat-backtest` agent (sibling of backtest-infra and backtest-scale).
Pure infra work — scenario cataloging, GHA workflows, report
generators.

## Branch

`feat/backtest-perf-<step>` per item above. Active:
`feat/backtest-perf-tier3-weekly` (Step 4) and
`feat/backtest-perf-engine-pool-instrument` (engine-pooling PR-1).

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
