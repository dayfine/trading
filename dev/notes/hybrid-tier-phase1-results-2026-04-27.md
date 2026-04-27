# Hybrid-tier Phase 1 results — H_load wins, but the wedge isn't where the plan assumed (2026-04-27)

Concrete results from the two experiments landed in #609. Together
they overturn the original hybrid-tier plan's working hypothesis:
the per-loaded-symbol cost is **not** in the strategy working set
(Cold/Warm/Hot tiering won't help much), but in the data load + engine
simulation (which load_universe_done → fill_done growth confirms).

## Setup

- Build: post-#609 main (`7692694e`).
- GC tuning: `OCAMLRUNPARAM=o=60,s=512k`.
- Scenarios: `goldens-hybrid-tier-experiment/sp500-default.sexp` and
  `sp500-no-candidates.sexp`. Both 491-symbol S&P 500, 5 years
  (2019-2023). Difference: no-candidates overrides
  `screening_config.max_buy_candidates` and `max_short_candidates`
  to 0 — the screener still runs full per-Friday work but emits
  zero candidates so no `Stock_analysis` runs for the survivor
  loop, no positions accumulate, no stop-log entries.
- Each scenario run individually (not via the combining
  scenario_runner so per-scenario peak RSS is clean).

## Experiment A — load vs activity decomposition

| Scenario | Peak RSS | Wall | Trades | Total return |
|---|---:|---:|---:|---:|
| sp500-default | 2,131 MB | 3:02 | 133 | +18.5% |
| sp500-no-candidates | 2,134 MB | 3:09 | 0 | 0.0% |
| **Δ** | **+0.14%** | +7s (noise) | n/a | n/a |

**RSS-no-candidates ≈ RSS-default** (within 0.2%). The empirical test
of `H_load` (load alone drives RSS) vs `H_active` (activity drives
RSS) lands clearly on `H_load`: even when zero candidates pass the
screener filter and zero positions ever open, RSS is identical to
the run with 133 round trips.

Wall +7s on no-candidates is run-to-run noise, not signal.

## Experiment B — phase-boundary GC trace

Source: `/tmp/gc-trace-292x6y.csv` (full backtest_runner run on
small-302, 6y, with `--gc-trace`).

| phase | wall_ms | minor_words | major_words | heap_words | top_heap_words |
|---|---:|---:|---:|---:|---:|
| start | 0 | 305K | 178K | 251K | 255K |
| load_universe_done | 4 | 322K | 181K | 255K | 255K |
| macro_done | 6 | 336K | 182K | 255K | 255K |
| fill_done | 105,120 | 14.1B | 1.29B | 61M | **178M** |
| teardown_done | 105,627 | 14.1B | 1.29B | 61M | 178M |
| end | 105,775 | 14.1B | 1.29B | 60M | 178M |

The major-heap-words promoted is **1.29 billion words ≈ 10.3 GB
cumulative promoted** over the run. `top_heap_words = 178M` (≈ 1.4
GB peak OCaml heap — matches the measured 1.45 GB peak RSS).

**All heap growth is in the `fill_done` phase** (the simulator loop).
Panel build + macro init add 4K words combined (negligible: 250K →
255K). After macro init, the runtime has zero appreciable working
set. The 60–61M word steady state appears entirely during the
simulator loop.

## Combined finding

- Exp A: RSS scales with **loaded N**, not active N. Strategy/screener/
  position-state hygiene won't move RSS.
- Exp B: heap growth happens during the simulator loop, NOT during
  panel build. Panels + indicator panels themselves are negligible
  (~50 MB per the spike notes); the OCaml-heap working set lives in
  per-tick allocations promoted to major heap.

**The combined story**: each tick, the simulator allocates per-loaded-
symbol working state — engine bar synthesis (`Price_path._sample_*`),
strategy screener bundle construction, callback closures, etc. — and
these allocations promote into the major heap before being reclaimed.
RSS reflects the **steady-state major-heap residency of per-tick
allocations**, which scales with the universe size N regardless of
whether positions open.

The deleted Tiered-loader memory bug from Stage 3 was a similar
phenomenon: per-symbol Hashtbl entries with their own per-symbol-per-
tick allocations driving cumulative residency. Stage 4 + 4.5 + #602
collapsed those for the strategy layer (lazy stage filter + price-cache
date-index); the engine/simulator layer still has them.

## Recommendation for Phase 2

**Revise the hybrid-tier plan.** The original `Tiered_panels.t` (Cold /
Warm / Hot) sat at the strategy / data layer, assuming the wedge was
in screener/strategy bundles. Exp A says that's wrong — those bundles
contribute nothing to RSS at this scale. Two options:

### Option 1: Pivot to engine-layer reduction (smaller scope)

The engine's `Price_path._sample_*` family is the proximate allocator
per the memtrace. Buffer pooling, in-place updates of a fixed-size
per-symbol scratch buffer, and avoiding per-symbol closure allocations
in `Engine.update_market` would directly reduce the steady-state
residency. ~600 LOC, scoped to `trading/engine/`.

This is **a smaller, more direct fix** than the original 3-tier plan.

### Option 2: Daily-snapshot streaming (larger but bigger payoff)

Per the user's shower-thought (2026-04-27): split the data pipeline
into ops-data offline (per-day cross-sections with all derived
indicators precomputed) + a streaming runtime that mmap's only the
current ±30 days of snapshots. RSS at scale becomes O(window) instead
of O(N·T). ~3,000 LOC across 5–8 PRs. Bigger payoff at N=10K release-
gate (~25 MB resident vs 60 GB extrapolated).

### Option 3: Combine

Option 2 reduces the loaded-N portion (panel residency); Option 1
reduces the per-tick engine churn. Both are needed for tier-4 release-
gate at N≥5,000.

## Recommendation

**Pursue Option 1 first** (engine-layer pooling) — the immediate fix
for the wedge Exp A+B identified. ~1 week. Lands incrementally.

**Then Option 2 (daily snapshots)** for tier-4 release-gate scale.
Larger plan, separate doc. The hybrid-tier plan as written is
superseded; close it or rewrite the §Phase 2 section to reflect the
new findings. Recommend rewriting since most of the §Phase 1 +
§Architecture content is still accurate (the layered-state reasoning
is sound; only the placement was wrong).

The user's shower-thought captures Option 2 cleanly. Recommend:

- Update `dev/plans/hybrid-tier-architecture-2026-04-26.md` §Phase 2
  to point at engine-layer first, daily-snapshots second.
- Open a new design doc: `dev/plans/daily-snapshot-streaming-2026-04-27.md`
  if Option 2 is the next architectural milestone.

## Update to status

`dev/status/hybrid-tier.md` flipped to **Phase 1 complete; Phase 2
awaiting plan revision**. Don't auto-launch Phase 2 — the original
3-tier shape is no longer the right fit; Phase 2 needs replanning
based on these results.

## References

- Source plan: `dev/plans/hybrid-tier-architecture-2026-04-26.md`
- Memory fit: `dev/plans/columnar-data-shape-2026-04-25.md` §Memory expectations
- Memtrace: `dev/notes/panels-memtrace-postA-2026-04-26.md`
- Matrix progression: `dev/notes/panels-rss-matrix-{,postA-,post602-,post602-gc-tuned-}*.md`
- S&P 500 baseline: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- User's shower-thought (Option 2 framing): conversation 2026-04-27
