## Cell E candidate-supply bottleneck — corrected diagnosis (2026-05-11)

### Background

`dev/notes/overnight-2026-05-10-results.md` posited that the `max_position_pct_long=0.10 / max_long_exposure_pct=0.70` sweep (where 7 slots are nominally available) only filled 5 because **"Cell E's screener doesn't find 7+ qualifying candidates simultaneously"** — i.e. that cascade supply was the constraint and that relaxing the score floor / sector filter / breakout gate would unlock more concurrent positions.

This note tests that hypothesis against the actual cascade_summaries written into `trade_audit.sexp`.

### Source

`dev/backtest/scenarios-2026-05-10-223952/cell-e-15y-maxpos-0.10-exp0.70/trade_audit.sexp`
(758 Fridays, 2010-01-08 → 2024-12-27, 15y Cell E with `max_position_pct_long=0.10`,
`max_long_exposure_pct=0.70`, `min_cash_pct=0.30`, stage3 force-exit on h=1, laggard rotation on h=2.)

### Funnel — avg per Friday across 758 Fridays

| Phase | Avg / Friday | Δ vs prior phase |
|---|---:|---:|
| `total_stocks`                              | 330.0 | — |
| `candidates_after_held` (held-ticker filter) | 322.5 | −7.4 |
| `long_macro_admitted` (macro gate)          | 296.3 | −26.3 |
| `long_breakout_admitted` (breakout filter)  | **18.5** | **−277.8** |
| `long_sector_admitted` (sector filter)      | 18.5 | −0.0 |
| `long_grade_admitted` (grade floor)         | 18.4 | −0.1 |
| `long_top_n_admitted` (top-N cap, max_buy=20)| 12.5 | −5.9 |
| `entered`                                   | **1.3** | **−11.2** |

### Findings

1. **The cascade IS surfacing supply.** Avg `long_top_n_admitted` is **12.5 candidates/Friday**, with **71.8% of Fridays** producing ≥7 candidates (more than enough for the 7 nominal slots in this config) and **79.8%** producing ≥5.

2. **Mean shortfall is 11.2 candidates/Friday** between cascade output and entries. **80.3% of Fridays** discard ≥3 cascade-approved candidates that are never entered.

3. **The breakout filter (`Stock_analysis.is_breakout_candidate`) is the dominant cascade-side cliff** — it drops 277.8 candidates/Friday on average (≈94% of the macro-admitted pool). The grade floor and sector filter are nearly no-ops in comparison. **But this still leaves 12-18 cascade survivors per Friday**, so it isn't the binding constraint on portfolio fill.

4. **Real bottleneck is downstream.** Of the 12.5 cascade-approved candidates per Friday, only 1.31 enter. The `trade_audit.sexp` skip-reason counts confirm:
   - `Insufficient_cash`: **8,263** total
   - `Stop_too_wide`: **2,424** total
   - Ratio: **3.4:1** Insufficient_cash dominates.

5. **Holding-period capital lock-up is the root cause.** With Cell E's avg holding period ~100 days (~14 weeks per overnight note) and 7-slot cap, once 7 positions enter, all slots stay occupied for ~14 weeks until exits free capital. Laggard rotation h=2 + stage3 force-exit h=1 are partial but not full mitigations — most of the time, the next 11+ cascade-approved candidates each Friday hit `Insufficient_cash` because no slot is available.

### Implications

The overnight note's recommendation to "relax cascade score floor / breakout gate to surface more candidates" is **misdiagnosed**. Cascade output is already 10× what the strategy can deploy. Relaxing those filters would only widen the already-discarded pool.

To actually increase portfolio concurrency, the levers are downstream:

- **Faster rotation (sell side):** shorter holding periods. Tighter trailing stops, more aggressive stage3 force-exit (h=1→h=0), more aggressive laggard rotation (h=2→h=1), or a take-profit ceiling. Each frees capital sooner. *Tradeoff: cuts into compounding of winners.*
- **More slots from same capital:** lower `max_position_pct_long` (e.g. 0.05–0.07). The overnight sweep already tested this — 0.07 gives 2,365 trades (heavy turnover) but DD blew out to 60.9%. So just dividing finer trades risk for return.
- **Same-week capital recycling:** if the strategy currently sells on Friday open and buys on the same Friday's close, that's already optimal. If sells settle T+1 and buys wait until next Friday, ~1 week of cash sits idle. Verify by inspecting position transitions in `trades.csv`.

### Recommended follow-up

1. **Quantify capital-recycling lag.** Look at intra-Friday trade ordering in `trades.csv`. If sells and buys are on the same Friday, recycling is already tight and the lock-up is purely from holding-period structure.
2. **Run a holding-period sensitivity sweep.** Vary `stage3_force_exit.hysteresis_weeks` (h=0/1/2/3) × `laggard_rotation.hysteresis_weeks` (h=1/2/3/4) on the new `0.14/exp0.70` default. Find the configuration that minimises `Insufficient_cash` skips without driving DD over 25%.
3. **Don't relax cascade filters.** Score floor, sector filter, breakout gate are not the binding constraints — touching them adds noise to the candidate set without changing fill rate.

### Open question

The 0.14/exp0.70 winning config holds 5 positions (not 7), suggesting `max_long_exposure_pct=0.70` is the binding cap (5 × 0.14 = 0.70). Re-running this funnel analysis on the 0.14 winner would confirm whether the same downstream-bottleneck pattern holds at that config, or whether the larger per-position size genuinely changes the dynamics.
