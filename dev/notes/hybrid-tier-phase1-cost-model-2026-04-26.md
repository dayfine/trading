# Hybrid-tier Phase 1 — cost model experiments (2026-04-26)

Phase 1 of `dev/plans/hybrid-tier-architecture-2026-04-26.md`. Two
experiments confirm whether β = 4.3 MB / loaded symbol scales with
**loaded N** (panel residency, prior_stages Hashtbl, indicator
caches) or **active N** (positions, screener candidate analysis).
The answer determines Phase 2's tier shape (2-tier Cold/Hot vs
3-tier Cold/Warm/Hot).

## Setup

- **Build**: post-#604 + `Gc_trace` infra (this PR, 2026-04-26).
- **GC tuning**: `OCAMLRUNPARAM=o=60,s=512k` for both runs (matches
  the 2026-04-26 baseline matrix).
- **Universe**: `universes/sp500.sexp` — 491-symbol S&P 500 snapshot
  (506 total loaded with index + sector ETFs).
- **Period**: 2019-01-02 → 2023-12-29 (5y; covers full Weinstein
  cycle: 2019 advance, 2020 H1 crash, 2020 H2–2021 recovery, 2022
  bear, 2023 rotation).
- **Initial cash**: $1M.
- **Scenarios**:
  - `goldens-hybrid-tier-experiment/sp500-default.sexp` — no
    overrides (control).
  - `goldens-hybrid-tier-experiment/sp500-no-candidates.sexp` —
    `((screening_config ((max_buy_candidates 0) (max_short_candidates 0))))`.
- **Container**: `trading-1-dev`.

## Experiment A — load-vs-activity decomposition

### Hypothesis

H_load: β scales with loaded N. M_filterup ≈ M_default (within ~5%).
H_active: β scales with active N. M_filterup < 0.7 · M_default.
H_mixed: split between the two; M_filterup falls 5–30%.

### Method

```bash
OCAMLRUNPARAM=o=60,s=512k \
dune exec trading/backtest/scenarios/scenario_runner.exe -- \
  --dir trading/test_data/backtest_scenarios/goldens-hybrid-tier-experiment
```

`/usr/bin/time -v` captures peak RSS for each variant. Both run
serially (not parallel) to keep RSS measurements clean.

### Result table (template — pending the actual run)

| Variant | Loaded N | Active N (concurrent) | Round trips | Peak RSS | Wall |
|---|---:|---:|---:|---:|---:|
| `sp500-default` | 506 | ~10–15 | ~133 | M_default | W_default |
| `sp500-no-candidates` | 506 | 0 | 0 | M_filterup | W_filterup |

### Decision rule

- **M_filterup ≈ M_default (within 5%)** → H_load wins. β scales
  with loaded N; per-position state is negligible at this scale.
  → **3-tier (Cold/Warm/Hot)** in Phase 2: most savings come from
  Cold-tier residency reduction. Estimated β-reduction: 4.3 → 0.5
  MB for cold symbols (~88% of universe at typical regimes).
- **M_filterup < 0.7 · M_default** → H_active wins. β scales with
  active N; per-position state hygiene is the wedge. → **2-tier
  (Cold/Hot)** suffices; Hot symbols carry full state, Cold carry
  metadata only. Skip the Warm middle tier.
- **5% ≤ Δ < 30%** (H_mixed) → start with 2-tier (simpler), add
  Warm only if the Cold→Hot promotion churn is too expensive in
  Phase 2 spike testing.

## Experiment B — phase-boundary `Gc.stat` snapshots

### Hypothesis

Hot/cold residency growth pattern across the run lifecycle
discriminates among:

- **B_panels**: stepwise growth at `load_universe_done` /
  `macro_done`, flat through `fill_done`. Panels + AD-bars
  dominate residency. Hybrid tier wins big.
- **B_pertick**: steady proportional growth `macro_done →
  fill_done`. Per-tick allocations promoted to major heap.
  Hybrid tier helps but per-tick code (engine layer) is the
  real wedge.
- **B_friday**: stepwise growth concentrated at `fill_done`
  (proxy for the simulator-loop end). Per-Friday bundle
  allocations. Hybrid tier directly addresses.

### Method

```bash
OCAMLRUNPARAM=o=60,s=512k \
_build/default/trading/backtest/bin/backtest_runner.exe \
  2019-01-02 2023-12-29 \
  --gc-trace /tmp/sp500-default.gc.csv

OCAMLRUNPARAM=o=60,s=512k \
_build/default/trading/backtest/bin/backtest_runner.exe \
  2019-01-02 2023-12-29 \
  --override "((screening_config ((max_buy_candidates 0) (max_short_candidates 0))))" \
  --gc-trace /tmp/sp500-no-candidates.gc.csv
```

The CSV has columns `phase,wall_ms,minor_words,promoted_words,
major_words,heap_words,top_heap_words`. On 64-bit OCaml, multiply
`top_heap_words` by 8 to get bytes — that's the high-water mark of
the major heap, which dominates RSS for this workload.

### Phase coverage caveat

The Phase 1 task asks for snapshots "every 50 Fridays during the
simulator loop". That requires hooking inside
`Trading_simulation.Simulator.run`, which is engine-layer code
outside backtest-infra's scope. The proxy: the runner-level phase
boundaries above bracket the simulator loop:

- `start` (process start, before backtest work).
- `load_universe_done` (after sector-map / universe resolved).
- `macro_done` (after AD-breadth bars loaded).
- `fill_done` (after `Simulator.run` returns — entire simulator
  loop delta).
- `teardown_done` (after round-trip extraction).
- `end` (just before exit).

`fill_done` minus `macro_done` captures the entire simulator loop
in one delta. That still discriminates among the B_panels /
B_pertick / B_friday hypotheses qualitatively:

- B_panels expects most growth before `macro_done` (panels built
  in `Panel_runner._build_ohlcv` after macro returns; for now we
  fold panel build into the same delta as `fill_done`).
- B_pertick + B_friday both show growth between `macro_done` and
  `fill_done`; the two are distinguished by per-Friday-finer
  hooks (deferred to Phase 1.5 if needed).

If Experiment B is ambiguous at coarse boundaries, open Phase 1.5
PR with engine-layer hooks.

### Result table (template — pending the actual run)

| Phase | wall_ms | top_heap_words (default) | top_heap_words (no-candidates) | Δ MB |
|---|---:|---:|---:|---:|
| start | 0 | … | … | … |
| load_universe_done | … | … | … | … |
| macro_done | … | … | … | … |
| fill_done | … | … | … | … |
| teardown_done | … | … | … | … |
| end | … | … | … | … |

Convert words → MB: multiply by 8 (bytes / word) ÷ 1,048,576.

## Initial recommendation framing (pre-run)

The existing memtrace evidence (`dev/notes/panels-memtrace-postA-2026-04-26.md`)
already names the dominant allocators that **scale with loaded N
regardless of activity**:

1. `Trading_simulation_data__Price_cache.get_prices.(fun)` — 910K
   sampled allocations (~9 billion real, at sample rate 1e-4) over
   a 4-minute run. Per-symbol-per-date Hashtbl access, scales with
   `loaded N × T_days`.
2. `Trading_engine__Price_path._sample_*` — 4 KB transient
   allocations per per-day-per-symbol churn that promote to major
   heap before GC reclaims. Volume scales with loaded N.
3. `Data_panel__Ohlcv_panels._make_nan_panel` ×6 +
   `Indicator_panels._make_nan_panel` ×6 — ~50 MB at N=292, scales
   linearly with loaded N. Live for the whole run.

These three categories together dominate β. Two of them (1, 3)
scale with loaded N regardless of position state; the third (2) is
per-tick churn that sees similar volume regardless of whether
positions get opened.

**Predicted verdict**:

- Experiment A: M_filterup within 10% of M_default — H_load wins.
- Experiment B: most growth at `load_universe_done` (panels +
  symbol-index) plus a steady creep through `fill_done` (the
  per-tick churn). The creep continues regardless of active-N
  because it's per-tick, not per-position.

**Predicted recommendation**: 3-tier (Cold/Warm/Hot) per master
plan. Cold-tier residency reduction is the main wedge; Warm tier
catches Stage 1/3 watch candidates without paying full Hot cost
yet.

The empirical numbers will land in this note after the runs
complete; if reality contradicts the prediction, document the
deviation here and re-evaluate Phase 2 shape before any
data-structure work begins.

## Updated cost model (pending the runs)

If H_load + B_panels + B_pertick all confirm:

```
RSS(N, T) ≈ 68 + 4.3·N + 0.2·N·(T−1) MB        (current — full-cost-everywhere)
            ↓ Phase 2 hybrid tier
RSS(N, T) ≈ 68 + 0.5·N_cold + 5·N_hot + 0.2·N_hot·(T−1) MB
         ≈ 68 + 0.5·(0.9·N) + 5·(0.1·N) + 0.2·(0.1·N)·(T−1) MB    (10% hot rate)
         ≈ 68 + 0.95·N + 0.02·N·(T−1) MB
```

At N=5,000 × T=10y: 68 + 4,750 + 900 = **~5.7 GB** vs current
predicted 30 GB. **Fits the 8 GB tier-4 ceiling at N=5,000.**

Without per-symbol streaming for Cold (Phase 4 in master plan),
γ_cold > 0 and the projection grows. Phase 4 is required to make
the N=5,000 × T=10y target stick.

## Recommendation for next dispatch

If Experiment A + B confirm H_load + B_panels:

- **Phase 2 of hybrid-tier**: build `Tiered_panels.t` with
  Cold/Warm/Hot record types. Sized panel pool = `0.2 · N_loaded`.
  ~600 LOC, 3–4 PRs.

If H_active wins:

- **2-tier shape with Phase 4 priority**: build `Tiered_panels.t`
  Cold/Hot only and immediately flag `Stop_log` /
  `Trading_state` / `Position` accumulation hygiene as Phase 2's
  primary deliverable.

If H_mixed:

- Start 2-tier; revisit Warm based on Phase 2 spike measurements.

## References

- Master plan: `dev/plans/hybrid-tier-architecture-2026-04-26.md`
- Phase 1 plan: `dev/plans/hybrid-tier-phase1-2026-04-26.md`
- Source data: `dev/notes/panels-memtrace-postA-2026-04-26.md`
- Baseline: `dev/notes/sp500-golden-baseline-2026-04-26.md`
- GC-tuned matrix: `dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md`
- Status: `dev/status/hybrid-tier.md`
