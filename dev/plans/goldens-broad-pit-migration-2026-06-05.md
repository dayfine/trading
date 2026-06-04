# Migrate `goldens-broad` regression cells off the top-N sentinel to PIT composition universes

**Status:** PLANNED · 2026-06-05 · supersedes `dev/status/backtest-infra.md`
"Follow-up items" #5 (re-pin broad goldens on the top-N sentinel).

## Problem

The four `goldens-broad/` cells — `covid-recovery-2020-2024`,
`six-year-2018-2023`, `decade-2014-2023`, `bull-crash-2015-2020` — define their
universe as:

```
(universe_path "universes/broad.sexp")   ;; = Full_sector_map sentinel
(config_overrides (... ((universe_cap (1000))) ...))
```

`broad.sexp` is a sentinel that tells the runner to **load the live
`data/sectors.csv`** (now 10,513 rows and growing) and `universe_cap` takes the
**first 1,000 of the sorted list** (`runner.ml:_apply_universe_cap` → `List.take`).
This has two defects:

1. **Non-reproducible.** *Which* 1,000 of 10,513 get selected shifts whenever
   `sectors.csv` changes — e.g. #1194 backfilled +40 symbols on 2026-05-18,
   after the cells were last pinned (2026-05-11). The universe under test is not
   frozen.
2. **Off the per-PR CI path.** These are `perf-tier: 4` cells, run only
   on-demand via `dev/scripts/perf_tier4_release_gate.sh`. Nothing runs them
   between releases, so drift accumulates silently.

**Observed 2026-06-05:** a flag-off reproduction of `covid-recovery-2020-2024`
on current main returned **139.9% / 52.9% MaxDD** against the pinned
**294.5% / 38.6%** (2026-05-11) — far outside every `expected` band; the cell
would fail today, and nobody would have noticed. Attribution was confounded
(universe-composition shift + 25 strategy PRs + a bar-CSV schema change that the
old code couldn't even parse), which is exactly the symptom of an
un-reproducible, un-gated golden.

## Solution (the machinery already exists)

A **point-in-time-clean composition universe series** is already committed under
`trading/test_data/goldens-custom-universe/composition/`:

- `top-{500,1000,3000}-{1998..2025}.sexp` — one frozen list **per year × per
  breadth**.
- **PIT-clean / survivorship-correct:** each list is the top-N by historical
  cap-weight among symbols that *existed as of that date*, including ones that
  failed afterward. Verified: `top-3000-2019` contains SIVB (failed 2023-03),
  FRC/FRCB (2023-05), BBBY (2023); `top-3000-1998` contains LEH and AIG. No
  survivorship filter. (NB: the *top-500* subset is a mega-cap *size* selection
  and outperforms — use ≥1000 for a representative breadth; the size bias is not
  a survivorship bias.)
- **Reproducible:** frozen committed lists, immune to `sectors.csv` drift.
- **Tradeable:** real tickers with real CSV bars; the
  `trading/trading/backtest/scenarios/universe_snapshot.ml` consumer
  (#1161/#1164/#1169) bridges a snapshot sexp into the runner's
  `(symbol, sector)` pairs. `golden-runs-custom-universe` CI already runs a
  composition cell (`top-500-2019`), so the path is proven.

These snapshots post-date PR #399 (the April two-tier-universe work that
introduced the `broad.sexp` sentinel as a placeholder), which is why the broad
cells were never migrated — the better universe didn't exist yet.

## Migration

For each cell, point `universe_path` at the composition snapshot dated **at or
before the window start** (no look-ahead), and drop the `universe_cap` override
(the snapshot *is* the universe):

| cell | window | snapshot |
|---|---|---|
| `bull-crash-2015-2020` | 2015-01 → 2020-12 | `top-1000-2015.sexp` |
| `six-year-2018-2023`   | 2018-01 → 2023-12 | `top-1000-2018.sexp` |
| `covid-recovery-2020-2024` | 2020-01 → 2024-12 | `top-1000-2020.sexp` |
| `decade-2014-2023`     | 2014-01 → 2023-12 | `top-1000-2014.sexp` |

Standardize the regression gate on **N=1000** — representative breadth that fits
the 7.75 GB local Docker ceiling. Keep an optional **N=3000** variant as a
tier-4 / bigger-CI-runner cell if a wider-breadth gate is wanted later (same
tiering logic already in the perf catalog).

Steps:

1. Edit the four cells' `universe_path` → `../goldens-custom-universe/composition/top-1000-<year>.sexp`; remove `((universe_cap (1000)))`. (Relocate the cells under `goldens-custom-universe/` if that keeps the `universe_path` resolution clean.)
2. **Re-pin** each cell's `expected` ranges by running it once on current main
   (the centers will differ from the top-N numbers — that is expected and
   correct; the old pins were measuring a different, drifting universe).
3. **CI-gate** them via the existing `golden-runs-custom-universe` workflow (or a
   sibling scheduled workflow), so they live on the maintained path and stop
   drifting silently. Remove the `perf-tier: 4` / on-demand-only framing.
4. Delete the `STATUS: SKIPPED` / always-pass-band workaround from each sexp.

## Out of scope

- A continuously-time-varying broad index-membership series (rebalancing the
  universe mid-backtest). The per-year snapshots are point-in-time at the window
  start, which removes look-ahead for a forward window; intra-window
  rebalancing is a separate, larger effort.
- Retiring `broad.sexp` / `Full_sector_map` entirely — it is still used by
  ad-hoc perf sweeps (`--override '((universe_cap (N)))'` capacity probes). This
  plan only moves the **regression cells** off it.

## Acceptance

- The four cells use a frozen PIT composition `universe_path`, no `universe_cap`.
- `expected` ranges re-pinned on current main, `STATUS: SKIPPED` removed.
- A CI workflow runs them per-PR (or on a schedule tight enough to catch drift),
  so a future drift fails CI instead of surfacing by accident.
