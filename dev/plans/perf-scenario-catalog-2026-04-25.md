# Plan: perf scenario catalog + release-gate strategy (2026-04-25)

## Why

Today's sweep harness (#547) produces a one-shot N×T complexity matrix
on demand. That's good for hypothesis testing but doesn't track perf
regressions over time, and doesn't define what "production-ready" looks
like for a release. This plan structures both:

1. **Continuous perf coverage in GHA** — a tiered set of scenarios
   that run on different cadences (push / nightly / weekly / release).
2. **Release-gate strategy** — a top-tier scenario suite that defines
   "ship-ready" for major/minor versions, with explicit memory + wall-time
   budgets at decade-long scale on 5000+ stocks.

Both feed off the same scenario catalog under
`trading/test_data/backtest_scenarios/perf-catalog/` (proposed).

## Proposed scenario catalog

Three tiers by run cost. Each cell defines (universe size N) × (run length T).

### Tier 1: per-PR (≤2 min total in CI)

Goal: catch regression in basic memory/wall-time invariants on every
push. Acceptable per-PR cost ~1-2 min. Two cells.

| ID | N | T | Strategy | Expected RSS | Expected wall |
|---|---:|---:|---|---:|---:|
| t1-smoke | 50 | 6m | Both | <300 MB | <30s |
| t1-smoke-tiered-promote | 50 | 6m | Tiered | <500 MB | <40s |

Wired into `ci.yml` as a fast smoke step. Failure = unbroken pipeline
catches RSS regressions early (e.g., a refactor that doubles per-symbol
overhead).

### Tier 2: nightly (≤30 min total)

Goal: characterize complexity at moderate scale. Catches degradations
in slope or absolute baseline. Five cells.

| ID | N | T | Strategy |
|---|---:|---:|---|
| t2-100-1y | 100 | 1y | Both |
| t2-300-1y | 300 | 1y | Both |
| t2-500-1y | 500 | 1y | Both |
| t2-300-3y | 300 | 3y | Both |
| t2-bull-crash-300 | 300 | 6y | Both |

Wired into `tiered-loader-ab.yml` (or sibling `perf-nightly.yml`).
Output appended to `dev/perf/<date>-nightly.csv` for trend tracking.

### Tier 3: weekly (≤2 hours total)

Goal: hit production-realistic universe + duration. Catches the kind
of structural regressions that only show up at scale (today's
bull-crash 2015-2020 finding wouldn't have shown on tier 2).

| ID | N | T | Strategy |
|---|---:|---:|---|
| t3-1000-3y | 1000 | 3y | Both |
| t3-bull-crash-1000 | 1000 | 6y | Both |
| t3-covid-recovery-300 | 300 | 4y | Both |
| t3-six-year-300 | 300 | 6y | Both |

Wired into a sibling weekly workflow. Output also appended to the perf
CSV history.

### Tier 4: release-gate (≤8 hours total, run once per major/minor)

Goal: certify that a release can do what we claim. Decade-long
simulations on 5000+ stocks with bounded memory. **The current
codebase does NOT pass this gate** — bull-crash 2015-2020 at 1000
stocks already takes 3.7 GB Tiered; 5000 stocks would extrapolate
to ~18 GB. Either the gate's criteria need to widen, or further
memory work is required.

| ID | N | T | Strategy | Pass criteria (proposed) |
|---|---:|---:|---|---|
| r-decade-broad | 5000 | 10y | Both | RSS < 8 GB, wall < 6h, no OOM |
| r-decade-broad-bear | 5000 | 10y (incl 2008 + 2020) | Both | as above |
| r-broad-spans-eras | 5000 | 25y (1999-2024) | Both | RSS < 12 GB, wall < 12h |

The pass criteria are guesses; needs human refinement. The point is
that they exist and are formally checked at tag time.

## Cataloging mechanics

Each scenario file gets a header tag declaring its tier:

```
;; PERF-CATALOG: tier=2 cadence=nightly id=t2-300-1y
;; Pass criteria:
;;   RSS_kb_max: 1200000
;;   wall_seconds_max: 90
```

A small OCaml helper (`dev/scripts/perf_catalog_check.ml` —
not committed yet, sketched here) reads these headers + the latest
sweep run output and emits a pass/fail report. Wired into the
respective workflows.

The headers + pass criteria evolve as the codebase improves. They're
auditable in git history; no dashboard needed yet.

## Implementation sequence

1. **Catalog the existing scenarios into tiers.** Add the headers to
   the existing `goldens-small/`, `goldens-broad/`, and `perf-sweep/`
   scenario files. ~1 LOC each.
2. **Define tier 1 cells** + add a fast CI step that runs them on
   every push. ~30 LOC YAML + reuse the existing `--memtrace`
   instrumentation. Pass criteria initially loose; tighten over time.
3. **Define tier 2 cells** + create `perf-nightly.yml` workflow that
   appends to `dev/perf/<date>-nightly.csv`. ~80 LOC YAML.
4. **Define tier 3 cells** + sibling weekly workflow. ~80 LOC YAML.
5. **Tier 4 is gated on memory work first.** Skip implementation
   until the bull-crash retention pattern is fixed and the slope is
   such that 5000-symbol decade runs fit in budget.

## Release-gate strategy

Tag-time procedure (proposed):

1. Cut a release branch (`release/vX.Y`).
2. Run all tier-4 scenarios via dispatched workflow. ~6-12 hours.
3. Generate release-perf-report comparing this release vs the prior.
4. If pass criteria met: tag `vX.Y.0`, publish image, write release
   notes including the perf-report numbers.
5. If pass criteria fail: bug, not release. Either fix or document
   the regression as a known issue with explicit user impact note.

**Frequency expectations:**
- Major version (vX.0): full tier 4. Decade × 5000 stocks.
- Minor version (vX.Y): full tier 3 + spot checks of tier 4.
- Patch version (vX.Y.Z): tier 2 + delta against last release.
- Pre-release / RC: same as major.

This is heavyweight for major releases by design — it's the
"can we actually run this in production" gate.

## What's NOT in this plan

- Dashboards / charts / visualizations. Markdown reports + raw CSV
  per-run is enough until volume justifies more.
- Comparing perf across PRs in PR comments (the GitHub bot pattern).
  Maintenance overhead exceeds value at our PR cadence.
- Deciding what "good enough" pass criteria are. That's a separate
  decision item — the catalog ships first, criteria evolve.
- Migrating the existing Python report scripts to OCaml (per
  `feedback_no_more_python.md`). When `perf_catalog_check.ml` is
  written it can subsume those over time.

## Decision items for the human

1. Are the tier costs (per-PR ≤2min, nightly ≤30min, weekly ≤2h,
   release ≤8h) the right budget? Could tighten if cron usage is
   limited (orchestrator was just turned off for cost; same pressure
   may apply here).
2. Tier 4 pass criteria — what RSS / wall budget defines a passing
   release? Today's bull-crash 1000-symbol Tiered = 3.7 GB; 5000
   stocks would be ~18 GB Tiered linear-extrapolated. Either widen
   the gate or invest in another round of memory work.
3. Do we want the `perf_catalog_check` helper to fail builds, or
   just annotate? Initial recommendation: annotate-only until enough
   history exists to set meaningful thresholds.
4. Tracking format: CSV in repo (auditable but grows) vs external
   store (cleaner but stops being self-contained). Initial
   recommendation: CSV in repo for the first ~6 months.
