# Strategy diagnostic survey — 2026-05-28

**Why:** v7 sweep + 3 v8 design iterations exposed that BO over 11 knobs may be chasing parameter alpha that doesn't exist. Before more tuning, we need structural diagnostics to find where (if anywhere) Weinstein extracts alpha.

**Approach:** decompose alpha by universe-layer, isolating each signal source.

## 3-way alpha decomposition

| # | Universe | Tests | Alpha source isolated |
|---|---|---|---|
| 1 | **SPY-only** (1 symbol) | Weinstein vs BAH-SPY | Market-timing only |
| 2 | **11 SPDR sector ETFs** | Weinstein vs BAH-SPY | Market-timing + sector-rotation |
| 3 | **Top-3000 stocks** (v7 setup) | Weinstein vs BAH-SPY | Market-timing + sector-rotation + stock-picking |

Differences:
- (2) − (1) = pure **sector-rotation alpha**
- (3) − (2) = pure **stock-picking alpha**

## Run matrix

Each diagnostic must be run at TWO param settings to avoid being throttled by Cell-E's universe-size assumptions:

| Run | Universe | Params | Status | Verdict |
|---|---|---|---|---|
| 1a | SPY-only | Cell-E defaults (`max_position=0.14`, `max_long_exposure=0.70`, `min_cash=0.30`) | DONE (agent `experiment/spy-only-diagnostic`) | **LOSES_TO_SPY by -7.13pp CAGR** (28y window). 1.68% total, 11 trades, MaxDD 0.83%, time-in-market 4.4%. See `dev/notes/spy-only-diagnostic-2026-05-28.md`. |
| 1b | SPY-only | universe-appropriate (`max_position=1.0`, `max_long_exposure=1.0`, `min_cash=0.0`) | DONE (this agent `experiment/diagnostics-fullsize`) | **LOSES_TO_SPY by -6.61pp CAGR** (27.03y window). 0.22% total, 10 trades, MaxDD 2.09%, time-in-market 3.77%. **Lifted caps did NOT rescue.** See `dev/notes/spy-only-fullsize-2026-05-28.md`. |
| 2a | 11 SPDR ETFs | Cell-E defaults | DONE (agent `experiment/sector-etf-diagnostic`) | **LOSES_TO_SPY by -6.13pp CAGR** (27.31y window). 11.60% total, 189 trades, MaxDD 7.4%. See `dev/notes/sector-etf-diagnostic-2026-05-28.md`. |
| 2b | 11 SPDR ETFs | universe-appropriate (`max_position=0.1` so 100% fully diversified across 11, `max_long_exposure=1.0`, `min_cash=0.0`) | DONE (this agent `experiment/diagnostics-fullsize`) | **LOSES_TO_SPY by -6.36pp CAGR** (27.03y window). 7.43% total, 193 trades, MaxDD 7.31%. **Lifted caps did NOT rescue.** See `dev/notes/sector-etf-fullsize-2026-05-28.md`. |
| 3 | Top-3000 stocks | v7 iter-42 + Cell-E (already-run) | DONE | v7-iter42: -0.155 Sharpe vs cell-E on sp500-2010-2026. Random ≈ BO per `dev/notes/v7-random-baseline-verdict-2026-05-25.md`. |

## Verdict synthesis (post-1a+1b+2a+2b)

**All four diagnostic cells lose to BAH-SPY by ~6-7 pp CAGR.** The portfolio-config layer is NOT the binding constraint — lifting `max_position_pct_long` and `min_cash_pct` did not materially change the outcome on either universe.

Per the "Expected interpretations" table below:
- Row 1 ("Even 1b loses to BAH") → **TRUE.** Stop tuning timing knobs.
- (Implied row, not in original table) "1b loses AND 2b doesn't rescue" → sector-rotation is value-neutral; cross-section adds churn without edge.

The binding constraint is in the strategy mechanics themselves (screener cascade / stop_initial_distance_pct / laggard_rotation / Stage-2 entry timing), NOT in any tunable parameter.

## Why both 1a + 1b (not just 1b)

1a is the "diagnostic of the diagnostic" — confirms that Cell-E's hardcoded position-size assumptions are what's hurting (vs. some other interaction). If 1a shows extreme underperformance and 1b shows neutral/positive, we know the portfolio-config layer is universe-size-coupled. That's an actionable design finding.

**Outcome:** 1a and 1b were within 1.5pp of each other on total return; 2a and 2b within 4pp. **The lifted caps were NOT the rescue mechanism.** Cell-E's portfolio sizing was not the dominant pain point — but it's also not the solution.

## Open questions to record from each run

For each (universe, params) cell, capture:
- CAGR vs BAH-SPY (signed, with absolute values)
- Sharpe (full-window)
- MaxDD
- Total trades
- Avg holding days
- **% time in market** (key signal — distinguishes "timing alpha" from "cash drag")
- Equity curve shape (text description: smooth-and-steady vs spiky vs bear-protective vs bull-capturing)

## Expected interpretations

| Pattern | What it tells us |
|---|---|
| Even 1b loses to BAH-SPY | Weinstein timing on the market index is value-neutral or harmful. Stop tuning timing knobs. |
| 1b ties BAH-SPY but 2b beats it | Sector-rotation is the alpha layer. Tune sector-selection logic, not stop-loss params. |
| 1b ties + 2b ties but 3 beats | Stock-picking is the alpha layer. Universe quality + screener weights matter; portfolio params are noise. |
| 1b > BAH AND 2b > 1b AND 3 > 2b | Alpha compounds across layers. Then the current direction (tune everything) is correct in principle but our score formula has been wrong. |
| 1b > BAH but 2b/3 don't add | Timing is the only alpha; cross-section adds churn without edge. Simplify drastically. |

## Surgery needed for 1b and 2b

The Weinstein strategy and screener layers are unchanged. Only `portfolio_config` overrides:

```sexp
(portfolio_config
  ((max_position_pct_long 1.0)        ; was 0.14 — allow full position in single asset
   (max_long_exposure_pct 1.0)        ; was 0.70 — allow full investment
   (min_cash_pct 0.0)))               ; was 0.30 — no cash buffer required
```

For 2b (11 ETFs), use `max_position_pct_long=0.10` (1/11 ≈ 9.1%) so all 11 can be held simultaneously without overflow at 100% exposure.

Potential complication: the screener / sizing math may divide-by-zero or behave oddly with min_cash_pct=0.0. If 1b/2b runs surface bugs in those edge cases, document and patch minimally.

**Result:** no edge-case bugs surfaced. `_check_cash` uses strict `<` so 0% threshold is safe. `max_position_pct_long=1.0` works; the position sizer apparently still hits some other constraint (1b's only successful long trade deployed ~9% of NAV, not 100%) — worth investigating in a follow-up.

## Coordination with v8 round-3

v8 round-3 redesign is running in parallel (`docs/v8-round3-redesign`). Its design is independent of these diagnostics, but the diagnostic verdict may obsolete v8 entirely (if 1b shows market-timing is value-neutral, the BO is tuning noise).

Sequencing: complete the 1a/1b/2a/2b matrix first, then re-evaluate v8 launch in light of the alpha-layer findings.

**Update 2026-05-28 post-diagnostics:** all 4 cells LOSE to BAH-SPY by similar magnitude. **v8 launch should be paused** until the strategy-mechanic redesign question (per `memory/feedback_strategy_mechanic_changes_too_explorative.md`) is addressed. Tuning over the same broken mechanic will not produce alpha.

## Follow-up: mechanism ablation (2026-05-29)

After all 4 cells lost to BAH-SPY, dispatched a 9-variant mechanism ablation
to isolate WHICH strategy mechanic is the alpha-killer. Result: full report
in `dev/notes/mechanism-ablation-2026-05-29.md`.

**Headline:** `laggard_rotation` is the alpha-killer on both SPY-only and
sector-ETF surfaces.

| Single-knob ablation | 1b SPY-only Δreturn | 2b sector-ETF Δreturn |
|---|---:|---:|
| Disable `enable_laggard_rotation` | +0.22% → **+9.54%** (+9.3pp) | +7.43% → **+49.45%** (+42.0pp) |
| Disable `enable_stage3_force_exit` | +0.22% → +0.22% (inert) | (not run, expected small) |
| Widen stops to 30% | +0.22% → +0.30% (+0.08pp) | +7.43% → +5.35% (-2.1pp) |
| Maximally permissive (no laggard + no stage3 + wide stops) | +0.22% → +6.46% (4 trades, 1 still open) | +7.43% → +27.22% (worse than no-laggard alone) |

**Verdict:** disabling laggard_rotation alone produces a ~6.7x return
improvement on the sector-ETF surface (Sharpe 0.15 → 0.43). Wide stops add
noise; Stage3 is inert on a single-asset universe. Even the maximally
permissive variant still loses to BAH-SPY by ~98%, so the Stage-2 admission
criterion is the residual bind — but laggard_rotation is the dominant
single bind.

**Recommended action:** flip `enable_laggard_rotation = false` as the
Cell-E default, then re-evaluate the v8 BO surface.
