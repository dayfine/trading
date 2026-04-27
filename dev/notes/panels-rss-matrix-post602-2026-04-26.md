# Post-#602 RSS matrix — wall halves, RSS bumps up (2026-04-26)

Companion to `dev/notes/panels-rss-matrix-postA-2026-04-26.md`. Re-run
on the merged tip after PR #602 (date-indexed `Price_cache`) lands.

## Setup

Same as prior matrix. Container `trading-1-dev`, opam env, panel build
on post-#602 main (`730d6cbf`).

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    <START> <END> --override "((universe_cap (<N>)))"
```

Four cells: {50, 292} × {1y (2019), 6y (2015–2020)}.

## Result

| N | T | post-PR-A RSS / Wall | post-#602 RSS / Wall | Δ RSS | Δ Wall |
|---:|---:|---:|---:|---:|---:|
| 50 | 1y | 342 MB / 0:13 | 363 MB / 0:06 | +21 (+6%) | −7s (−54%) |
| 50 | 6y | 407 MB / 1:01 | 511 MB / 0:21 | +104 (+26%) | −40s (−66%) |
| 292 | 1y | 1,581 MB / 1:01 | 1,704 MB / 0:28 | +123 (+8%) | −33s (−54%) |
| 292 | 6y | 1,866 MB / 4:05 | 2,323 MB / 1:44 | +457 (+25%) | −2:21 (−58%) |

## Fit

`RSS ≈ 86 + 5.5·N + 0.5·N·(T − 1)` MB

| Component | post-PR-A | post-#602 | Δ |
|---|---:|---:|---:|
| Fixed (α) | ~86 MB | ~86 MB | 0 |
| Per-symbol (β) | 5.12 | ~5.5 | +0.4 (+7%) |
| Per-symbol-per-year (γ) | 0.22 | ~0.5 | +0.28 (+125%) |

The β bump is small. The **γ doubled** — the per-symbol-per-year cost
went from ~0.22 to ~0.5 MB. The longer the backtest, the bigger the
RSS regression.

## Verdict: **wall win, RSS regression is real but trade-off favours #602**

**Wall halves to two-thirds across all cells.** 54% to 66% improvement
in wall time. For tier-3 / tier-4 release-gate runs (N=5000 T=10y),
this turns a ~hours-long run into half-or-less. Throughput win is
unambiguous.

**RSS goes up ~6–26%, more pronounced at larger T.** Cumulative Stage
4 + #602 RSS at N=292 T=6y: 3,468 MB → 2,323 MB. Still −33% vs the
pre-Stage-4 baseline; just a partial regression of the post-D
position.

The post-#602 single-sample regression earlier (1,866 → 2,330 MB at
N=292 T=6y) is **confirmed**, not noise. The γ doubling explains it:
the per-tick allocation churn was previously forcing aggressive GC
compaction that kept the major heap small. With #602 eliminating the
churn, the major heap stabilises at a higher level.

## Why γ doubled

Two related effects:

1. **OCaml GC steady-state shift.** Before #602, ~9 billion cons-cell
   allocations per run (per memtrace) drove constant minor-heap
   pressure. The GC ran often, kept the major heap compacted, and peak
   RSS reflected actual residency. After #602, the allocation rate
   collapses; the GC runs less; the major heap grows to its
   no-back-pressure steady state. RSS reflects steady-state allocation
   high-water-marks, not retained working set.

2. **The new `by_date` Hashtbl.** Per symbol, ~1500 dates × Hashtbl
   overhead. The values are POINTERS to the same `Daily_price.t`
   records as the existing `cache` field — no record duplication —
   but the Hashtbl bucket structure itself is ~80 bytes per entry.
   At 307 symbols × 1500 days = 460K entries × 80 bytes = ~37 MB.
   Visible at γ but small relative to the GC-shift component.

## Release-gate projection

Plan target: ≤ 8 GB at N=5000 T=10y.

`RSS(5000, 10) ≈ 86 + 5.5·5000 + 0.5·5000·9 = 86 + 27,500 + 22,500 = 50 GB`

**Worse than pre-#602** (35 GB → 50 GB at this scale). But wall halved
across the matrix, so the time budget for a 50 GB run is now ~half
what it was. The trade-off depends on whether wall or RSS is the
binding constraint at scale. For interactive iteration, wall matters
more.

## Recommendation

### Option A: accept the trade-off (recommended for now)

Keep #602 as merged. Wall halving is the bigger win for normal use.
For RSS-bound release-gate runs (tier-4), apply OCaml GC tuning at
runtime: `OCAMLRUNPARAM=o=60,s=512k` (more aggressive major-GC,
smaller minor heap). This usually reverses 50–80% of the
allocation-rate-driven RSS shift without touching code.

### Option B: revert the new `by_date` Hashtbl

Roll #602 back. Wall regresses to baseline. RSS recovers to post-PR-A.
Probably not worth it given the wall savings.

### Option C: keep the date index but force aggressive GC inline

Add `Gc.compact ()` at strategic points (e.g. between Friday cycles)
to force major-heap compaction. Trade some wall for RSS. Tunable
mid-run rather than at startup.

**Recommendation**: A first. If tier-4 release-gate hits the 8 GB
ceiling, try the env-var tuning. If still over, do C.

## What this means for Stage 4.5

PR-A landed and didn't move RSS (small-302 universe is mostly Stage 2/4
which both pass the filter). #602 lands and halves wall but bumps RSS.

PR-B (sector pre-filter) is still planned and may compound the
allocation-elimination story — fewer per-symbol bundles built means
fewer transient closures. But the wedge confirmed in memtrace lives
in `Price_cache.get_prices.(fun)` (now fixed) and `Price_path._*`
(engine-layer, untouched). PR-B targets the strategy layer, which the
memtrace already showed is not where the residual lives.

Going to dispatch PR-B per plan, but flag in its PR description that
the matrix evidence suggests it'll have minimal RSS impact at this
scale on small-302. The win for PR-B will be cleaner laziness, not
RSS.

## References

- Pre-#602 matrix: `dev/notes/panels-rss-matrix-postA-2026-04-26.md`
- Memtrace findings: `dev/notes/panels-memtrace-postA-2026-04-26.md`
- #602 PR description.
- Master plan: `dev/plans/columnar-data-shape-2026-04-25.md` §Stage 4.5
- Stage 4.5 plan: `dev/plans/panels-stage045-lazy-tier-cascade-2026-04-26.md`
