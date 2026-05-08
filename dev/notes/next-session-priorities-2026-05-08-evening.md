# Next-session priorities — 2026-05-08 (evening, post-Q1/Q2/Q3/Q4)

## Where we are

Today's morning priorities (`next-session-priorities-2026-05-08.md`) all closed:

- **Q1 P0** memory cliff fixed via PRs #987 (note), #988 (Fix C stream), #992 (Fix A dedupe panels), #993 (Fix B skinny step_result.portfolio). 15y peak RSS **11.4 GB → 1.95 GB** (5.8× reduction, no OOM).
- **Q2 P1** bah-spy day-1 entry fixed via PR #986 — root cause was SPY CSV missing from `prepare_ci_data.sh` symbol list.
- **Q3 P2** Cell A-E perf measured via PR #996. Stage3 + Laggard add ~33% wall, **flat memory** across all 5 cells (~535-550 MB on 5y).
- **Q4 P1.5** golden-runs split via PR #990. 5y per-push, 15y nightly cron @ 09:00 UTC.

Plus permanent tooling fixes:
- **PR #991** pinned opam-repository commit SHA in Dockerfile. Root cause of ocamlformat container-vs-CI skew was `opam repository set-url default https://opam.ocaml.org && opam update` — pointing at HEAD of opam-repo at build time. Different image build dates → different package metadata → different binaries. Pinning eliminates drift.
- **PR #995** added missing `*_check.sh` deps to 3 dune test rules (`agent_compliance_test`, `rule_promotion_self_test`, `posix_sh_check_test`). Pre-existing harness bug surfaced when post-#992 cache invalidation hit strict-dep sandbox.

9 PRs total merged today.

## New priorities (in flight order)

### P0 — split-day adjustment regression on 15y

**Symptom:** 15y SP500 vanilla golden run completes (1.95 GB peak) but returns **-85.77% / 99.93% MaxDD** vs pinned baseline of **+5.15% / 16.12% MaxDD** (from `memory/project_sp500_baseline_conflict.md`). Trade count identical (102) — so trade selection logic is unchanged; the regression is in P&L trajectory.

**Equity curve evidence** (post-Q1 fix run, 2026-05-08T15:17Z):
- 2010-01-04: $1,000,000 (start)
- 2011-01-17: $20,323 (98% drawdown by 12 months in)
- 2012-07-02: $2,957 (single-day jump to $63K next day, 21× leverage-like move)
- Multiple days with 2-20× single-day jumps and reverses
- Final: $142,346

The 2-20× single-day equity jumps are the hallmark of **broken stock-split adjustment** — when a position's quantity isn't correctly adjusted on a split day, the system sees a 50-95% "price drop" and accumulates wild P&L errors.

**This is NOT a regression from today's Q1 fixes** — Cell A 5y vanilla matches the pinned baseline exactly (58.3%/81). The 2010-2013 split-heavy era exposes the bug; the 2019-2023 5y window doesn't trigger it.

**Already tracked** by the broker-model split-day redesign (`docs/design/split-day-broker-model-2026-04-28.md`, original PR #656 / closed predecessor #641). Not all phases landed. The OOM previously masked this — Q1 fixes lifted the cover.

**Investigation path:**
1. Verify which split-day phases are merged by reading `docs/design/split-day-broker-model-2026-04-28.md` §Status.
2. Bisect on a small window straddling a known split: AAPL 4:1 (2020-08-31), TSLA 5:1 (2020-08-31), GOOG 20:1 (2022-07-18), NVDA splits, KO splits.
3. Pin the failing case as a regression test scenario.

**Priority: P0** — blocks pinning a 15y baseline, blocks all 15y experiments. Cannot promote `golden-runs-sp500-15y.yml` to per-push until this is resolved.

### P1 — re-pin 5y CI baseline post-Q1 fixes

`memory/project_sp500_baseline_conflict.md` pinned 5y baseline at 766 MB peak, 299s wall on CI hardware. Post-Q1-Fix-B local Cell A measurement: **533 MB peak, 248s wall** — 30% RSS reduction, 18% wall reduction.

The on-disk scenario `goldens-sp500/sp500-2019-2023.sexp` has tolerance bands around the old return numbers (those are still bit-equal — Q1 fixes were memory-only). But the **CI baseline expectations doc / memory may need refresh** to reflect the new RSS floor so future drift detection isn't anchored to stale numbers.

**Action items:**
- Re-run sp500-2019-2023 5y golden in CI image (not local) to capture the new GHA-hardware peak RSS + wall.
- Update memory `project_sp500_baseline_conflict.md` with new values.
- Verify the on-disk scenario tolerance bands don't trip — they shouldn't (return is bit-equal), but worth a sanity check.

**Priority: P1** — quality-of-life for diff-detection. Not blocking.

### P1 — run E3 stop-buffer sweep

Scenarios pre-built at `trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep/buffer-1.XX.sexp` (8 cells: 1.00, 1.02, 1.05, 1.08, 1.10, 1.12, 1.15, 1.20 stop-buffer multipliers on `goldens-sp500/sp500-2019-2023`). Hypothesis + README at `dev/experiments/m5-4-e3-stop-buffer-sweep/`.

Run: `dune exec backtest/scenarios/scenario_runner.exe -- --dir trading/test_data/backtest_scenarios/experiments/m5-4-e3-stop-buffer-sweep --parallel 5` (~5×2h tier-3 budget).

Deliverable: `dev/experiments/m5-4-e3-stop-buffer-sweep/report.md` with verdict on which buffer multiplier produces best risk-adjusted return.

**Priority: P1** — feeds tuning track decisions.

### P1 — run E4 scoring-weight sweep

Scenarios at `trading/test_data/backtest_scenarios/experiments/m5-4-e4-scoring-weight-sweep/<axis>.sexp` (8 cells: baseline + 7 single-axis-doubled perturbations of `Screener.scoring_weights`). Same shape as E3.

Deliverable: `dev/experiments/m5-4-e4-scoring-weight-sweep/report.md`. Feeds the M5.5 T-A grid sweep priors.

**Priority: P1** — pairs with E3.

### P2 — 81-cell flagship sweep on `screening.weights.*` via T-A grid_search.exe

T-A `grid_search.exe` MERGED via PR #893; T-B `bayesian_runner.exe` MERGED via PR #914. The flagship sweep is the next-tier validation — 3-axis (rs / volume / resistance) × 3-3-3 cell grid = 81 cells, all on the 5y SP500 baseline window.

Wall budget: ~81 cells × ~5 min = ~7 hours single-process; ~2 hours at `--parallel 5`. Local-only.

Deliverable: `dev/experiments/m5-5-flagship-grid-2026-XX-XX/report.md` + sweep artifacts.

**Priority: P2** — meaningful tuning signal but not blocking; should follow E3+E4 results.

### P2 — all-eligible PR-3 wiring into release-report pipeline

`all-eligible` track has PR-1 (lib) + PR-2 (CLI exe) + min_grade quality gate + Friday-breakout dedup all merged. Remaining: **PR-3** wiring `all_eligible_runner.exe` outputs into the release-perf-report pipeline so `Δ-to-all-eligible` numbers appear alongside `Δ-to-optimal` numbers. Spec at `dev/status/all-eligible.md`.

**Priority: P2** — connects existing pieces; medium-size PR (~300-500 LOC).

### P3 — image.yml auto-trigger investigation (minor)

When PR #991 merged, the `.devcontainer/Dockerfile` change to pin opam-repo SHA should have triggered `.github/workflows/image.yml` automatically (path filter `.devcontainer/Dockerfile` matches). It didn't — had to manually `gh workflow run image.yml`. Possibly path-filter quoting issue or eventual-consistency lag.

**Action:** check workflow trigger logs / quotation, possibly add a `paths-ignore` clarifier or unquote the path.

**Priority: P3** — annoyance, not blocker. Cron rebuilds weekly.

### P3 — promote `golden-runs-sp500-15y.yml` to per-push

Currently nightly cron. Promote to per-push once 15y reliably (a) completes within budget — which it now does (57 min < 90 min) — and (b) passes scenario assertion — which is **blocked on P0 split-day fix**.

**Priority: P3** — gated on P0.

## Sequencing recommendation

1. **P0 first** — split-day adjustment investigation. Read `docs/design/split-day-broker-model-2026-04-28.md` to understand current state of the redesign. Identify which sub-phase is missing. May require feature-track-level work in `feat-backtest`.
2. **E3 + E4 sweeps in parallel** — independent runs, 2-5h wall each, no code change needed. Can dispatch agents that just run + write report.
3. **5y baseline re-pin** — small. After E3/E4 close.
4. **Flagship 81-cell sweep** — after E3/E4 close (priors learned).
5. **all-eligible PR-3 wiring** — independent of above; can interleave.
6. **image.yml + 15y promotion** — last, low-priority.

## Notes for orchestrator / autonomous dispatch

- Memory `feedback_no_pr_merging.md` allows autonomous merge in this repo when 3 gates green. Use that.
- Memory `feedback_cleanup_local_lint_then_merge.md` for cleanup-class PRs.
- Memory `feedback_no_permission_asking.md` (refreshed today): make best decisions; don't block on tradeoff-free choices.
- The `golden-runs-sp500-15y.yml` cron at 09:00 UTC daily will produce a fresh 15y measurement each morning. Use that as the canonical post-fix RSS source after split-day P0 lands.
- Q3 follow-up: the local Cell A-E results in `dev/experiments/capital-recycling-combined-2026-05-07/perf-2026-05-08T163314Z/` are valid as a **relative** comparison but not a **CI-comparable** baseline (different hardware). The CI 5y baseline runs as-needed via `golden-runs-sp500-5y.yml` per-push.
