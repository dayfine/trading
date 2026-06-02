---
name: SP500 5y + 15y canonical baselines pinned (2026-05-05)
description: Both sp500-2019-2023 (500-sym, post-#851 dedup) and sp500-2010-2026 (510-sym, with #855 position-sizing override) tight-pinned 2026-05-05 in their scenario sexps with ±10-25% tolerance bands.
type: project
originSessionId: 1b3c22f4-6967-4e7d-bdd3-6cfe881e12e5
---

**Both SP500 baselines tight-pinned 2026-05-05** in `data/backtest_scenarios/`:

### sp500-2019-2023 (5y, 500-sym universe post-#851 share-class dedup)

```
total_return_pct  58.34   total_trades 81   win_rate 19.75
sharpe_ratio       0.54   max_drawdown 33.60  avg_holding_days 84.10
open_positions_value 1,553,948.90
```

Tolerances ±10-15% in `goldens-sp500/sp500-2019-2023.sexp`.

### sp500-2019-2023-long-only (5y, 503-sym, pre-#851 dedup)

```
total_return_pct  79.74   total_trades 74   win_rate 27.03
sharpe_ratio       0.66   max_drawdown 30.79  avg_holding_days 94.55
```

Pinned via #850. Will narrow to 500-sym actuals on next run.

### sp500-2010-2026 (15y, 510-sym Wiki-replayed, with #855 position-sizing override)

```
total_return_pct   5.15   total_trades 102   win_rate 21.57
sharpe_ratio       0.40   max_drawdown 16.12  avg_holding_days 130.58
open_positions_value 1,026,057.64
```

CAGR is anemic (0.31%) — see issue #856 for return-tuning follow-up.
Tolerances ±15-25% in `goldens-sp500-historical/sp500-2010-2026.sexp`.

### Position-sizing override (15y only)

```
((portfolio_config ((max_position_pct_long 0.05))))
((portfolio_config ((max_long_exposure_pct 0.50))))   ;; INERT — dominated by per-position cap
((portfolio_config ((min_cash_pct 0.30))))             ;; INERT — never wired in production
```

Per qc-behavioral #855 F1: only `max_position_pct_long` is the binding knob.
The other two are no-ops at present. Future tuning (#856) should sweep
`max_position_pct_long ∈ {0.07, 0.10, 0.13, 0.16, 0.20}`.

### Default `Portfolio_risk.config` UNCHANGED

Other goldens (sp500-2019-2023, broad goldens, etc.) depend on the
default sizing. The 15y override is scenario-local in `config_overrides`.

### History (resolved entries)

- **2026-04-28**: prior canonical was 134/70.8%/97.7%MaxDD on bfbd105f (PR #657).
  97.7% MaxDD was the AAPL 2020-08-31 split-day MtM bug; resolved by the
  broker-model redesign #658..#667 (2026-04-28..29).
- **2026-05-02**: re-pinned post-#744+#745+#746+#771 to 60.86%/86 (491-sym universe).
- **2026-05-03 → 2026-05-04**: F.2 default-flip + F.3.a wiring caused 491-sym
  metrics to drop to 22.2%/112 (issue #843). Root-caused to `Bar_reader.of_snapshot_views`
  via bisect + verified path-dependent (#852). Restored via Option-1 partial
  revert in #847 (strategy uses panels; simulator uses snapshot).
- **2026-05-04**: #851 deduped GOOG/FOX/NWS share-class pairs (503 → 500 sym);
  metrics shifted to today's pinned 58.34%/81.
- **2026-05-04**: #855 added position-sizing override on 15y scenario, raising
  trade count from 16 to 102 over 16y.

Determinism contract still holds: same commit + same scenario = bit-identical N runs.
Pinned by PR #648 (well before this session).
