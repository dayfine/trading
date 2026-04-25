# Status: backtest-perf

## Last updated: 2026-04-25

## Status
PENDING

## Interface stable
N/A

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

- **PR #550** (this plan, doc-only) — open for human review. Covers
  scope + tier structure + decision items.

## Next steps (post-#550 merge)

1. Catalog the existing `goldens-small/`, `goldens-broad/`, and
   `perf-sweep/` scenarios into the 4 tiers (header tags only).
   ~1 LOC per scenario.
2. Define tier 1 (per-PR smoke, 2 cells) + add fast CI step in
   `ci.yml`. ~30 LOC YAML.
3. Define tier 2 (nightly, 5 cells) + create `perf-nightly.yml`.
   ~80 LOC YAML.
4. Define tier 3 (weekly, 4 cells) + sibling weekly workflow.
   ~80 LOC YAML.
5. Tier 4 (release-gate, 5000-stock decade-long) — gated on the
   incremental-indicators refactor (`dev/status/incremental-indicators.md`)
   landing first. Current Tiered would extrapolate to ~31 GB at
   5000×10y; need the refactor to fit in 8 GB ceiling.

## Ownership

`feat-backtest` agent (sibling of backtest-infra and backtest-scale).
Pure infra work — scenario cataloging, GHA workflows, report
generators.

## Branch

`feat/backtest-perf-<step>` per item above.

## Blocked on

- **Tier 4 release-gate scenarios** are blocked on the
  incremental-indicators refactor landing. Tiers 1-3 can proceed
  independently.

## Decision items (need human or QC sign-off)

Carried verbatim from `dev/plans/perf-scenario-catalog-2026-04-25.md`:

1. Are the tier costs (per-PR ≤2min, nightly ≤30min, weekly ≤2h,
   release ≤8h) the right budget?
2. Tier 4 pass criteria — what RSS / wall budget defines a passing
   release? Today's bull-crash 1000-symbol Tiered = 3.7 GB; 5000
   stocks would extrapolate to ~31 GB Tiered. Either widen the
   gate or invest in the incremental refactor.
3. Should `perf_catalog_check` fail builds or annotate-only?
   Initial: annotate-only.
4. Tracking format: CSV in repo (auditable, grows) vs external store.
   Initial: CSV in repo.

## References

- Plan: `dev/plans/perf-scenario-catalog-2026-04-25.md`
- Existing perf harness: `dev/scripts/run_perf_hypothesis.sh` (#537),
  `dev/scripts/run_perf_sweep.sh` (#547)
- Sibling track: `dev/status/incremental-indicators.md` — tier 4
  blocker
- Predecessor: `dev/status/backtest-infra.md` (MERGED) for the
  experiments/analysis side this builds on
