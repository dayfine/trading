# Plan: Stage 4.5 — lazy-tier cascade in `_screen_universe` (2026-04-26)

## Status

PROPOSED. Companion to `dev/plans/columnar-data-shape-2026-04-25.md`
(master plan §"Stage 4.5"). Triggered by the post-PR-D RSS matrix
finding (`dev/notes/panels-rss-matrix-2026-04-26.md`).

## Wedge

The post-Stage-4 matrix shows `RSS ≈ 86 + 5.12·N + 0.22·N·(T−1)` MB —
**dominated by N (universe size), not T**. At N=292 T=6y the per-symbol
slope is ~5 MB. Extrapolated to release-gate tier 4 (N=5,000 T=10y) →
~35 GB, well over the 8 GB ceiling.

Code inspection of `_screen_universe` confirms the cause:

```ocaml
let stocks = List.filter_map config.universe ~f:_analyze_ticker in    (* runs for ALL N *)
let screen_result = Screener.screen ~macro_trend ~sector_map ~stocks   (* filters AFTER *)
```

`_analyze_ticker` runs **the full per-symbol heavy work** for every
loaded symbol on every Friday — `weekly_view_for` + `Panel_callbacks.
stock_analysis_callbacks_of_weekly_views` (Stage / Rs / Volume /
Resistance) + `Stock_analysis.analyze_with_callbacks`. The screener
cascade gates **after** all per-symbol analysis is already done. No
early-exit. Bearish-macro and weak-sector regimes still pay the full
cost.

This is the opposite of how the deleted Tiered loader was supposed to
work — only "interesting" candidates should pay full per-day analysis
cost. Panel mode lost the explicit tier mechanism in #573 but didn't
replace it with lazy-allocation discipline.

## Goal

Restructure `_screen_universe` so per-symbol heavy work fires only for
symbols that pass cheap early gates. Keep panels (Bigarray storage)
loaded for the full universe — that's already cheap. Make the per-Friday
allocation churn proportional to **candidate** count, not **loaded**
count.

Expected impact: at typical mixed regimes ~50–200 of 292 symbols survive
the Stage 1 filter. Per-symbol cost drops from ~5 MB to
`~5 MB × (survivors / loaded)`. Could halve RSS at full universe; bigger
win at scale (5,000 stocks, where most are Stage 4 most of the time).

## PRs

### PR-A: Two-phase `_analyze_ticker` — cheap stage classify → full analysis for survivors

Refactor `_screen_universe` so per-symbol work splits into:

1. **Phase 1 (universe-wide)**: `Stage.classify_with_callbacks` only.
   Uses the panel-cached `Weekly_ma_cache` (PR-D #594). Cost: a handful
   of panel cell reads per symbol; no allocation per symbol beyond the
   small `Stage.result` record.
2. **Phase 2 (survivors only)**: For symbols whose `stage` qualifies
   (per the screener's stage-eligibility rules — currently Stage 1
   late-base or Stage 2 in the cascade), build the full callback
   bundle and run `Stock_analysis.analyze_with_callbacks`. Volume +
   Resistance kernels (the most expensive callbacks) only fire here.
3. The `Screener.screen` call shape is unchanged — it still receives
   `stocks : Stock_analysis.t list`. The list is now filtered to
   survivors only; symbols skipped in Phase 2 are simply absent from
   the list.

**Parity contract**: the `Screener.buy_candidates` /
`short_candidates` output must be bit-identical for any input where
the screener would have rejected the skipped stage anyway. The
mechanical rule: a stage that produces "no buy / no short" in the
current screener is safe to skip in Phase 2.

**Files**:
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
  (`_screen_universe`, `_analyze_ticker` split)
- New helper or refactor in `panel_callbacks.ml` if useful (Stage-only
  callback constructor)
- Test: `test_weinstein_strategy.ml` — pin that for a bearish-macro or
  Stage-4-heavy fixture, the per-symbol Stock_analysis runs only for
  the survivors. Use a counter in test fixture to assert call count.
- Test: `test_panel_loader_parity` round_trips golden — bit-equal
  trades, must not move (load-bearing).

**LOC**: ~400 production + ~200 tests.

### PR-B: Sector pre-filter as second early-exit gate

After Phase 1 (Stage filter), drop symbols whose sector failed sector
RS in `sector_map`. The `sector_map` is already computed in
`_run_screen` before `_screen_universe` — it just isn't used for
early exit yet.

**Cascade after PR-B**:
1. Stage classify (cheap, all N).
2. Stage filter (drop Stage 1 weak / Stage 4).
3. Sector lookup + sector-RS gate (drop weak-sector survivors).
4. Full `Stock_analysis` for symbols that survive both.

**Parity contract**: same as PR-A — symbols dropped here are ones the
screener would have rejected on `sector_map` lookup later anyway.

**Files**:
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
  (`_screen_universe` cascade extension)
- Test: extend the PR-A counter test to also pin sector-filtered
  symbols.

**LOC**: ~150 production + ~80 tests.

### PR-C (optional): Tunable filter thresholds in config

If PR-A + PR-B drop the per-symbol slope enough to fit the tier-4
release-gate ceiling, skip this PR. Otherwise:

- Add config fields for "minimum stage to pass Phase 1" and "minimum
  sector RS to pass Phase 2". Today these are implicit in the
  screener's downstream rules; making them explicit lets the user
  tighten the filter for synthetic stress tests or loosen it for
  research scenarios.

**Files**:
- `trading/trading/weinstein/strategy/lib/weinstein_strategy.{ml,mli}`
  (config record extension)
- `trading/trading/weinstein/strategy/test/test_weinstein_strategy.ml`

**LOC**: ~100 production + ~50 tests.

## Parity gates

Same load-bearing gate every PR shares:

- `test_panel_loader_parity` round_trips golden — bit-equal trades.
- `test_weinstein_backtest` (3 simulation tests) — relaxed structural
  invariants must still hold.
- `test_weinstein_strategy{,_smoke}`, `test_macro_inputs`,
  `test_stops_runner` — green.

Plus per-PR new tests:

- PR-A: counter test asserting per-symbol Stock_analysis call count
  matches survivor count, not loaded count.
- PR-B: same counter, extended to track sector-filtered drops.
- PR-C: config plumbing tests.

## Sweep validation

After each PR lands, re-run the N × T matrix
(`dev/notes/panels-rss-matrix-2026-04-26.md`) at the four cells
{50, 292} × {1y, 6y}. Goal: drive the slope `β` from 5.12 MB/symbol
toward ≤ 1.5 MB/symbol. If `β` drops as expected after PR-A, PR-B
should compound it. If `β` doesn't drop, the wedge is not in
`_screen_universe` and we re-evaluate (memtrace required).

## Out of scope

- The deleted Tiered loader's Summary/Full distinction — Panel mode is
  the only path; this PR adds laziness within Panel mode, not a tier
  system.
- `Ohlcv_panels` / `Indicator_panels` themselves — they stay loaded
  universe-wide. They're already cheap (Bigarray, ~50 MB total).
- Memtrace — independently useful but not gated on this work. Run
  before or in parallel.
- Live-mode universe rebalance — Stage 5 territory; deferred.

## LOC budget

| PR | Production | Tests | Total |
|---|---:|---:|---:|
| PR-A | ~400 | ~200 | ~600 |
| PR-B | ~150 | ~80 | ~230 |
| PR-C (optional) | ~100 | ~50 | ~150 |
| **Total** | **~650–750** | **~330–380** | **~980–1,130** |

## Risk

### R1: parity drift

A naïve filter implementation could drop a symbol that the existing
screener would have accepted via some downstream code path. Mitigation:
load-bearing parity gate (`test_panel_loader_parity`) catches
divergence in trade output. If it fires, narrow the filter — accept a
slightly weaker speedup over a behavior change.

### R2: the wedge is elsewhere

If after PR-A the matrix shows `β` unchanged or barely moved, the
per-symbol cost lives outside `_screen_universe`. Most likely
candidates: `Stops_runner.update` (runs daily on held positions), or
`Macro` / `Sector` analysis allocations. Memtrace becomes the next
diagnostic.

### R3: late-Stage-2 or recovery edge cases

The "drop Stage 1 weak / Stage 4" rule may misclassify symbols
transitioning from Stage 1 → Stage 2 (the screener's most valuable
catch). Mitigation: PR-A's filter is the cheap-Stage-classify result,
which already includes the `late_stage_2` field. The exact filter
predicate must mirror the screener's stage-eligibility rules — write
the test in PR-A to pin this explicitly.

## References

- Master plan: `dev/plans/columnar-data-shape-2026-04-25.md` §"Stage 4.5"
- Matrix finding: `dev/notes/panels-rss-matrix-2026-04-26.md`
- Spike progression: `dev/notes/panels-rss-spike-{,postB,postC,postD}-*.md`
- Strategy entry point: `trading/trading/weinstein/strategy/lib/weinstein_strategy.ml`
  (`_screen_universe`, `_analyze_ticker`)
- Screener cascade: `trading/trading/analysis/weinstein/screener/`
- Stage classifier: `trading/trading/analysis/weinstein/stage/`

## Triggers to start

- Stage 4.5 work is unblocked and ready to dispatch.
- PR-A's design is well-scoped; PR-B's depends only on PR-A's filter
  shape.
- Recommend dispatching feat-backtest for PR-A in worktree isolation.
