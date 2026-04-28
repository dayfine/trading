# Status: backtest-perf

## Last updated: 2026-04-28

## Status
IN_PROGRESS

Steps 1+2 (`feat/backtest-perf-tier1-catalog`, PR #574) merged
2026-04-26T16:07Z. **`perf-tier1.yml` landed via PR #616 on 2026-04-27**
— per-PR perf smoke is now wired. **Tier-1 universe-path bug fixed
+ gate flipped to strict on `fix/perf-tier1-universe-path`
2026-04-28**: explicit `--fixtures-root` flag, `Fixtures_root.resolve`
helper, `continue-on-error: false`, `PERF_CATALOG_CHECK_STRICT=1`;
local smoke 4/4 PASS. **Tier-2 nightly workflow landed via PR #622 on
2026-04-27**: `perf_tier2_nightly.sh` +
`.github/workflows/perf-nightly.yml`, six tier-2 cells, 30 min/cell
budget, cron `0 5 * * *` (22:00 PT). **Tier-3 weekly workflow open
at `feat/backtest-perf-tier3-weekly` on 2026-04-27**:
`perf_tier3_weekly.sh` + `.github/workflows/perf-weekly.yml`, two
tier-3 cells (`perf-sweep/{bull-1y, bull-3y}`), 2 h/cell budget,
cron `0 7 * * 1` (Monday 00:00 PT). **Engine-layer-pooling PR-1
(Gc.stat instrumentation, panel_runner per-step snapshots) merged
via PR #618 on 2026-04-27**; **PR-2 (per-symbol Scratch type +
buffer-reusing internal helpers + parity gate) merged via PR #626
on 2026-04-27**; **PR-3 (thread Scratch through `Engine.update_market`
per-tick loop) opened at `feat/backtest-perf-engine-pool-thread` on
2026-04-27 — collapses per-tick float-array allocs to per-symbol-once;
parity-tested via `test_panel_loader_parity` and
`test_engine_scratch_threading_parity`**; **PR-4 (transient
buffer pool for `_sample_student_t.sum_squares` accumulator +
`Hashtbl.find_or_add` in `update_market`) merged via PR #632 on
2026-04-27**; **PR-5 (matrix re-run validation) opened at
`feat/backtest-perf-engine-pool-matrix` on 2026-04-28 — measured
β: 4.3 → 3.94 MB/symbol (−8%, far short of plan's 1-1.5 target);
wall: −36% at 292×6y (2:51 → 1:49). All 5 engine-pool PRs landed
or in flight. See `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`**.
Step 5 (release_perf_report OCaml exe) tracked separately;
landed via #585 / #606 on the test-data + perf-runner side. Tier-4
release-gate scenarios structurally unblocked since data-panels
Stage 4.5 PR-B (#604) merged 2026-04-27T02:33Z. **Tier-4 release-gate
workflow at N=1000 open at `feat/backtest-perf-tier4-release-gate` on
2026-04-28**: `perf_tier4_release_gate.sh` +
`.github/workflows/perf-release-gate.yml` (manual-only — no cron),
four `goldens-broad/` cells (`bull-crash-2015-2020`,
`covid-recovery-2020-2024`, `decade-2014-2023` (NEW),
`six-year-2018-2023`) all baking `(config_overrides
((universe_cap 1000)))`, 8 h/cell budget. **N≥5000 release-gate stays
P1** pending daily-snapshot streaming.

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
- **`feat/backtest-perf-engine-pool-thread`** (engine-pooling PR-3) —
  open for review. Threads `Price_path.Scratch.t` through
  `Engine.update_market` per-tick by giving `Engine.t` a
  `(symbol, Scratch.t) Hashtbl.t` and replacing the
  `Price_path.generate_path` call site with `generate_path_into ~scratch`.
  Adds `Price_path.Scratch.required_capacity` to make the per-symbol
  re-allocation decision pure (no throwaway probe scratch). New
  `test_engine_scratch_threading_parity` pins bit-equality between a
  reused engine and N fresh engines. Bit-exact parity vs PR-2
  validated by `test_panel_loader_parity` on both `tiered-loader-parity`
  and `panel-golden-2019-full` scenarios.
  See `dev/notes/engine-pool-pr3-impact-2026-04-27.md` for the
  per-call allocation breakdown (~3.2 KB float-array alloc dropped
  per `update_market` call after the symbol's first day).
- **`feat/backtest-perf-engine-pool-pool`** (engine-pooling PR-4) —
  PR #632 merged 2026-04-27. Adds `Buffer_pool.{ml,mli}` (Stack-backed
  pool of `float array` workspaces with `acquire ?capacity () /
  release` API, bounded by `max_size`). Routes the per-call
  `_sample_student_t` chi-squared accumulator (was `let acc = ref
  0.0`) through a 1-slot float array borrowed from a per-`Scratch`
  pool. Switches `Engine._scratch_for_symbol` from `match Hashtbl.find
  … with Some …` to `Hashtbl.find_or_add … ~default` to remove the
  per-call `Some` allocation that dominated `update_market.(fun)` per
  the post-PR-A memtrace. FP order is unchanged — same left-fold for
  loop, just a different storage location for the accumulator. New
  9-test `test_buffer_pool.ml` pins the pool's API contract;
  `test_golden_bit_equality` and `test_panel_loader_parity` (the
  load-bearing parity gates) pass unchanged.
- **`feat/backtest-perf-engine-pool-matrix`** (engine-pooling PR-5) —
  open for review. Re-runs the 4-cell matrix (N×T = {50,292}×{1y,6y})
  with all four engine-pool PRs landed. **β: 4.3 → 3.94 MB/symbol
  (−8%, far short of plan's 1-1.5 MB/symbol target). Wall: −36% at
  292×6y (2:51 → 1:49)**. The cumulative-promotion target *was* hit
  (50×1y `promoted_words = 85.8M` < plan's 100M target); peak RSS
  didn't move because at the post-#602+GC-tuned baseline RSS is
  dominated by the major-heap working set, not allocation churn. New
  fit: `RSS ≈ 67 + 3.94·N + 0.19·N·(T−1)` MB. Tier-4 implication:
  N=1000×10y at ~5.7 GB still fits 8 GB; N≥5000 still requires
  daily-snapshot streaming (separate plan
  `dev/plans/daily-snapshot-streaming-2026-04-27.md`). Note:
  `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`. No
  code changes — pure measurement + docs PR.
- **`feat/backtest-perf-release-report`** (Step 6 — release_perf_report
  OCaml exe) — open for review. Adds
  `trading/trading/backtest/release_report/` library +
  `trading/trading/backtest/bin/release_perf_report.ml` binary +
  11-test fixture (`test_release_perf_report.ml`). Replaces the
  deleted Python `perf_sweep_report.py`. End-to-end smoke verified:
  feeding two synthetic scenario dirs reproduces the full markdown
  shape including the `:rotating_light:` flag on +20% RSS regression.
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
  tier-1/tier-2.
- **`feat/backtest-perf-tier4-release-gate`** (Step 5 — tier-4
  release-gate at N=1000) — open for review. Adds
  `dev/scripts/perf_tier4_release_gate.sh` +
  `.github/workflows/perf-release-gate.yml` (**manual-only** —
  `workflow_dispatch` only, no cron schedule). Auto-discovers four
  `;; perf-tier: 4` scenarios under
  `trading/test_data/backtest_scenarios/goldens-broad/{bull-crash-2015-2020,covid-recovery-2020-2024,decade-2014-2023,six-year-2018-2023}.sexp`,
  runs each via `scenario_runner.exe --parallel 1` with
  `timeout 28800` (8 h), publishes wall + peak-RSS table to
  `$GITHUB_STEP_SUMMARY`. All four sexps now bake
  `(config_overrides ((universe_cap 1000)))` so each cell runs at
  N=1000 self-contained. The four sexps had been SKIPPED placeholders
  pinned to the 1,654-symbol era; this PR resets them to
  BASELINE_PENDING (wide ranges) for the first manual dispatch to
  fill in. The new `decade-2014-2023.sexp` is the canonical 10-year
  release-gate cell. Per
  `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`,
  N=1000×10y projects to ~5.7 GB (fits 8 GB ceiling). N≥5000 stays
  blocked on daily-snapshot streaming. First manual dispatch is
  **not yet scheduled** — out-of-PR follow-up.

## Completed

- **Tier-1 smoke universe_path resolution + flip continue-on-error: false**
  (2026-04-28, PR #634). Fix for next-step #4.
  Root cause: `scenario_runner._fixtures_root` did
  `Data_path.default_data_dir() |> Fpath.parent ^ "trading/test_data/..."`
  which assumed `TRADING_DATA_DIR` pointed at the legacy `data/` location
  at the repo root. The perf workflows set
  `TRADING_DATA_DIR=$WS/trading/test_data`, so `Fpath.parent` walked
  one level too high and `^ "trading/..."` produced a
  doubled-segment path
  `.../trading/trading/test_data/backtest_scenarios`. Net: every
  tier-1 run since #616 crashed 4/4 on the universe lookup, masked
  by `continue-on-error: true`.
  Files:
  - `trading/trading/backtest/scenarios/fixtures_root.{ml,mli}` — new
    `Fixtures_root.resolve ?fixtures_root ()` helper. With
    `?fixtures_root`, returns it verbatim. Without, returns
    `Data_path.default_data_dir() / "backtest_scenarios"` (matches the
    convention `test/test_panel_loader_parity.ml` and the perf
    workflows already use).
  - `trading/trading/backtest/scenarios/scenario_runner.ml` — adds
    `--fixtures-root <path>` CLI flag, threads it through
    `_run_scenario_in_child` so each child resolves the scenario's
    `universe_path` against the original fixtures root rather than
    the per-cell `_stage_<name>/` scratch dir.
  - `trading/trading/backtest/scenarios/test/test_fixtures_root.ml` —
    4-test regression suite; pins explicit-override behaviour, env
    fallback, and the no-doubled-`trading/trading` invariant.
  - `dev/scripts/perf_tier{1_smoke,2_nightly,3_weekly}.sh` — pass
    `--fixtures-root "$SCENARIO_ROOT"`.
  - `.github/workflows/perf-tier1.yml` —
    `continue-on-error: false` (tier-1 is the per-PR gate; tier-2/3
    stay `true` while their warm-up budgets accumulate).
  - `trading/devtools/checks/dune` — set
    `PERF_CATALOG_CHECK_STRICT=1` on the dune rule so missing tier
    tags fail the build (was annotate-only).
  Verify:
  ```
  TRADING_DATA_DIR=$(pwd)/trading/test_data \
    dev/scripts/perf_tier1_smoke.sh
  ```
  expected: 4/4 PASS. Also run
  `dune runtest trading/backtest/scenarios/` (4 + 7 + 10 tests, all
  green). Plan: `dev/plans/perf-tier1-universe-path-2026-04-28.md`.
  Follow-up: `_repo_root()`/`_make_output_root()` in
  `scenario_runner.ml` still uses the old `Fpath.parent` heuristic
  (writes artefacts to `<ws>/trading/dev/backtest/scenarios-...`
  instead of `<ws>/dev/backtest/...`); the path resolves and the dir
  is created, just lands one level too deep. Not load-bearing —
  separate clean-up.

- **Step 5 — tier-4 release-gate workflow at N=1000** (2026-04-28, PR pending).
  Mirrors the tier-1/2/3 pattern but is **manual-only**
  (`workflow_dispatch` — no cron). Adds
  `dev/scripts/perf_tier4_release_gate.sh` (POSIX-sh runner that
  auto-discovers `;; perf-tier: 4` scenarios via grep, runs each via
  `scenario_runner.exe --parallel 1` with `timeout 28800` = 8 h,
  captures wall + peak RSS, writes `summary.txt`) and
  `.github/workflows/perf-release-gate.yml` (manual-only via
  `workflow_dispatch`; same `trading-ci:latest` container, same
  `_build` cache, same `continue-on-error: true` posture as tier-1/2/3;
  publishes summary to `$GITHUB_STEP_SUMMARY`; `timeout-minutes: 350`
  job ceiling, just under the 360 min platform ceiling on
  ubuntu-latest). Four tier-4 cells covered, all under
  `goldens-broad/`: `bull-crash-2015-2020` (~6y), `covid-recovery-2020-2024`
  (~5y), `decade-2014-2023` (~10y, NEW canonical decade-long cell),
  `six-year-2018-2023` (6y). All four bake
  `(config_overrides ((universe_cap 1000)))` so each cell is
  self-contained at N=1000 (the largest size that fits the 8 GB
  ubuntu-latest ceiling at decade-length per β=3.94 MB/symbol). Expected
  ranges intentionally wide (BASELINE_PENDING) — first manual
  dispatch produces the canonical baseline; tighten ranges via
  follow-up PR. **N≥5000 release-gate stays P1** awaiting
  daily-snapshot streaming
  (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). First manual
  dispatch is **not yet scheduled**; operator triggers when ready to
  cut a release. Verify locally:
  `dev/scripts/perf_tier4_release_gate.sh` inside the devcontainer
  (or with `TRADING_IN_CONTAINER=1`); the workflow itself is
  exercised on its first manual `workflow_dispatch` invocation.
  Files: `dev/scripts/perf_tier4_release_gate.sh`,
  `.github/workflows/perf-release-gate.yml`,
  `trading/test_data/backtest_scenarios/goldens-broad/{bull-crash-2015-2020,covid-recovery-2020-2024,decade-2014-2023,six-year-2018-2023}.sexp`.

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

- **Engine-pooling PR-4 — Buffer_pool for transient workspaces** (2026-04-27, PR #632 open).
  New `trading/trading/engine/lib/buffer_pool.{ml,mli}` — Stack-backed
  pool of `float array` workspace buffers; pre-seeds one buffer at
  construction so the first `acquire` is allocation-free; bounded by
  `max_size` (drops on overflow). `Price_path._sample_student_t` now
  acquires a 1-slot float-array accumulator on entry and releases it
  on exit, removing the `let acc = ref 0.0` per-call heap allocation
  (~85K sampled events / ~850M real allocations on `bull-crash-292x6y`
  per the post-PR-A memtrace). `Engine._scratch_for_symbol` now uses
  `Hashtbl.find_or_add ~default`, removing the per-call `Some`
  allocation that dominated `update_market.(fun)` (~316 KB / 19,800
  sampled events). Bit-equality preserved: chi-squared accumulation
  order is identical (same left-fold for-loop, just `acc.(0)` instead
  of `!acc`); `test_golden_bit_equality` and `test_panel_loader_parity`
  pass unchanged. Verify:
  `dune runtest trading/engine/test` (96 tests) +
  `TRADING_DATA_DIR=$(pwd)/test_data dune exec
  trading/backtest/test/test_panel_loader_parity.exe`. Files:
  `trading/trading/engine/lib/buffer_pool.{ml,mli}`,
  `trading/trading/engine/lib/{price_path,engine,dune}.ml`,
  `trading/trading/engine/test/test_buffer_pool.ml`.

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
3. **(DONE on `feat/backtest-perf-tier4-release-gate`)** Tier 4
   (release-gate) at **N=1000 × decade-long** — `perf-release-gate.yml`
   + `perf_tier4_release_gate.sh`, four tier-4 cells under
   `goldens-broad/` (`bull-crash-2015-2020`, `covid-recovery-2020-2024`,
   `decade-2014-2023` (NEW), `six-year-2018-2023`), 8 h budget per
   cell, **manual-only** (`workflow_dispatch`; no cron — release-gate
   runs at release-cut time, not on a recurring schedule). The four
   sexps now bake `(config_overrides ((universe_cap 1000)))` so each
   cell is self-contained — no CLI override needed. Per
   `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md` (β=3.94
   MB/symbol), N=1000×10y projects to ~5.7 GB peak RSS, fits the 8 GB
   ubuntu-latest ceiling. **N≥5000 release-gate stays P1 awaiting
   daily-snapshot streaming** (`dev/plans/daily-snapshot-streaming-2026-04-27.md`):
   at β=3.94, N=5000×10y projects to ~28 GB, far beyond the runner
   ceiling. Expected ranges are intentionally wide for the four cells
   (BASELINE_PENDING) — first manual dispatch produces the canonical
   baseline; tighten ranges via follow-up PR after that run lands.
4. **(DONE on `fix/perf-tier1-universe-path`)** Tier-1 smoke
   universe_path resolution + flip the gate. Added
   `Scenario_lib.Fixtures_root.resolve` plus `--fixtures-root` CLI
   flag on `scenario_runner.exe` that the three tier scripts pass
   explicitly. Flipped `.github/workflows/perf-tier1.yml`
   `continue-on-error: false` (tier-1 is the per-PR gate; tier-2/3
   stay VISIBILITY-first). Set `PERF_CATALOG_CHECK_STRICT=1` in
   `trading/devtools/checks/dune`. Verified: 4/4 PASS post-fix. Plan:
   `dev/plans/perf-tier1-universe-path-2026-04-28.md`.
5. After ~10 PR cycles of *real* tier-1 perf data: pin per-cell
   budgets. Same flip applies to `perf-nightly.yml` once tier-2
   budgets are pinned (~10 weeks of nightly data) and to
   `perf-weekly.yml` once tier-3 budgets are pinned (~10 weekly
   cycles).
6. (DONE on `feat/backtest-perf-release-report`) **`release_perf_report`
   OCaml exe.** New library
   `trading/trading/backtest/release_report/` (`release_report.{ml,mli}`,
   `dune`) + binary `trading/trading/backtest/bin/release_perf_report.ml`
   + 11 tests in `trading/trading/backtest/test/test_release_perf_report.ml`.
   Reads two release `dev/backtest/scenarios-<ts>/` directories (each
   subdirectory = one scenario with `actual.sexp`, `summary.sexp`, and
   optional `peak_rss_kb.txt` / `wall_seconds.txt` sidecars from the
   perf-tier runners), pairs scenarios by name, and emits a markdown
   report with three matrices: trading metrics (return %, Sharpe, win
   rate, max DD, trades, avg holding) side-by-side; peak-RSS (current
   vs prior, ∆%); wall-time (current vs prior, ∆%). PR-level regression
   flags fire when ∆% exceeds defaults from
   `dev/plans/perf-scenario-catalog-2026-04-25.md` (RSS > +10%, wall
   > +25%); both thresholds are CLI-overridable via
   `--threshold-rss-pct N` / `--threshold-wall-pct M`. Verify:
   `dune build trading/backtest/release_report
   trading/backtest/bin/release_perf_report.exe` then run
   `_build/default/trading/backtest/bin/release_perf_report.exe
   --current <dir> --prior <dir>`; tests via
   `dune test trading/backtest/test/test_release_perf_report.exe`
   (11/11 PASS). Pure OCaml per `.claude/rules/no-python.md`.
7. (DONE on `docs/goldens-performance-baselines`) **Goldens performance
   baselines — small + sp500.** Ran the four non-broad goldens
   (`goldens-small/{bull-crash-2015-2020, covid-recovery-2020-2024,
   six-year-2018-2023}` + `goldens-sp500/sp500-2019-2023`) and
   documented per-cell metrics + buy-and-hold context in
   `dev/notes/goldens-performance-baselines-2026-04-28.md`. Pure
   docs PR. Headline finding: strategy underperforms B&H on 4/4
   windows; closest on bull-crash (−2.2 pp), worst on covid-recovery
   (−49.6 pp). Three of the four cells are now red against their
   pinned `total_trades` ranges — trade-count drift since the
   2026-04-18 pinning is the next thing the trade-audit work
   (`dev/plans/trade-audit-2026-04-28.md`) needs to explain.
   Surfaced an Aug-2020 mark-to-market anomaly on the sp500 cell
   (portfolio briefly $25K during AAPL/Tesla split window) — flagged
   for trade-audit follow-up.

## Ownership

`feat-backtest` agent (sibling of backtest-infra and backtest-scale).
Pure infra work — scenario cataloging, GHA workflows, report
generators.

## Branch

`feat/backtest-perf-<step>` per item above. Active:
`feat/backtest-perf-tier4-release-gate` (Step 5 — tier-4 release-gate
at N=1000) and `feat/backtest-perf-tier3-weekly` (Step 4).

## Blocked on

- **Tier 4 release-gate at N≥5000** stays blocked on daily-snapshot
  streaming (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). At
  the post-engine-pool β=3.94 MB/symbol, N=5000×10y projects to ~28 GB
  RSS, far beyond the 8 GB ubuntu-latest ceiling. Tier-4 at N=1000 is
  **unblocked** and shipped on `feat/backtest-perf-tier4-release-gate`.

## Decision items (need human or QC sign-off)

Carried verbatim from `dev/plans/perf-scenario-catalog-2026-04-25.md`:

1. Are the tier costs (per-PR ≤2min, nightly ≤30min, weekly ≤2h,
   release ≤8h) the right budget?
2. Tier 4 pass criteria — what RSS / wall budget defines a passing
   release? Per `dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md`,
   post-engine-pool β=3.94 MB/symbol; tier-4 at N=1000×10y projects
   to ~5.7 GB (fits 8 GB ceiling). N≥5000 release-gate still requires
   daily-snapshot streaming
   (`dev/plans/daily-snapshot-streaming-2026-04-27.md`). Initial
   tier-4 ranges are intentionally wide (BASELINE_PENDING); first
   manual dispatch produces the canonical baseline.
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
