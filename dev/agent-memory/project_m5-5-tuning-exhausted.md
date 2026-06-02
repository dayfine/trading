---
name: M5.5 tuning plan — all 3 axes rejected, single-lever is exhausted
description: 2026-05-14 conclusion: single-lever Cell E tuning doesn't move risk-adjusted metrics. Bottleneck is elsewhere.
type: project
originSessionId: 6b136992-6cc4-4ab4-bc18-44211fdc0bdd
---
The M5.5 4-axis tuning plan (`dev/notes/p3-tuning-sweep-design-2026-05-13.md`,
PR #1064) ran to completion. Result: **3 of 4 axes rejected/neutral; single-
lever Cell E tuning is exhausted**.

Per-axis verdict:

| Axis | 5y winner | Long-horizon verdict | Status |
|---|---|---|---|
| Axis-1 (`installed_stop_min_pct = 0.08`) | Calmar +0.13 (PR #1079) | CONDITIONAL GO; partial — 10y broad-1000 inconclusive (PR #1081); destructive when combined with axis-2 (PR #1084) | **Hold** (don't promote alone) |
| Axis-2 (`min_correction_pct = 0.10`) | Calmar +0.37 (PR #1083) | STOP catastrophic — 16y long-only MaxDD 19.9%→60.1%, ΔCalmar −0.24 (PR #1086) | **REJECTED** |
| Axis-3 (`min_score_override` floor) | Best Calmar +0.042 (PR #1087) | Below +0.05 threshold; trade-count counter-directional (floor tightens but trades rise) | **Neutral** |
| E5 Q5 soft-penalty (PR #1080) | All 3 cells worse than baseline | — | **REJECTED** |

**Mechanism observations:**

- The 5y window has a specific shape (late-2019 bull → COVID crash →
  V-recovery → 2022 short tail) that rewards wider stops. Long horizons
  (10y, 16y) capture multiple full bear cycles where wider stops let
  positions ride down catastrophically.
- The cascade gate is grade-driven; only ~1.3 of 12.5 admitted candidates
  enter per Friday. Tightening the score floor reshuffles rank order but
  doesn't filter the actual entered set (axis-3 plateau structure: cells
  45/50 identical, 55/60 identical).
- Both Q5 cap (hard, entry-caps arm B 2026-05-12) and Q5 soft penalty
  (E5/PR #1080) degrade metrics. Q5 candidates' high profit factor is
  load-bearing even with 28.6% WR.

**Conclusion**: Cell E is near-optimal on the levers it exposes. Further
single-lever sweeps under Cell E are unlikely to materially move
risk-adjusted metrics. Bottleneck is elsewhere.

**Next research directions (per #1087 conclusion):**

1. **Cost model** — transaction cost / slippage may be the dominant drag
   on Cell E's 0.56 Sharpe. Sweep `engine_config.slippage_bps`.
2. **Sector exposure** — current Cell E caps max long exposure at 70% but
   no sector concentration. Test sector caps.
3. **Sizing dynamics** — Cell E uses `max_position_pct_long = 0.14`. May be
   too concentrated; sweep 0.07/0.10/0.14/0.18.
4. **Continuation buys parameter tuning** (per #1082) — the ship-default
   continuation B detector only fired 2 trades on 5y. Sweep
   `ma_slope_min` / `pullback_band` / `consolidation_weeks` to see if it
   admits more.
5. **Short-side margin Phase 1** (per #1075 plan) — orthogonal to single-
   lever cell tuning; could unlock long-short Sharpe if shorts have edge.

**Things to NOT keep trying:**

- More stop-distance sweeps (axis-1/2/cross all done).
- Q5 score-weight manipulation (hard cap + soft penalty both rejected).
- Wider single-cell parameter sweeps without long-horizon validation gates.
