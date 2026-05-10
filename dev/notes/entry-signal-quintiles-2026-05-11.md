## Entry-signal feature quintiles — Cell E 0.14/exp0.70 rolling 5y validation (2026-05-11)

### Background

Overnight 2026-05-10 note flagged three entry-signal levers from an earlier 4480-trade aggregate:
1. Cap screener score < 80 — top quintile worst WR (27.2%)
2. Cap volume_ratio < 2.5× — extreme volume loses on WR
3. Stop buffer Q3 (~12% distance) only quintile with negative $/trade

This note re-validates those claims on the **post-sweep 0.14/exp0.70 rolling 5y trade set** (7 windows × ~250 trades = **1,793 trades**, source `dev/backtest/scenarios-2026-05-11-012222/cell-e-5y-*/trades.csv`). The earlier aggregate (4,480 trades) used the legacy 0.05/exp0.50 config; this re-cut uses the new default.

### Findings — Score bucket

| Bucket | N | WR % | Avg $ | Avg % |
|---|---:|---:|---:|---:|
| Q1: <65   | 567 | 39.2 | +$1,382 | +1.60 |
| Q2: 65-69 | 182 | 38.5 | -$1,137 | -0.16 |
| Q3: 70-74 | 288 | **43.8** | **+$4,297** | **+3.44** |
| Q4: 75-79 | 564 | 34.2 | +$1,747 | +1.81 |
| **Q5: ≥80**   | **192** | **28.6** | **+$6** | **+0.13** |

**Confirmed**: Q5 (score ≥80) has 28.6% WR (worst of all buckets) and essentially zero $/trade. Q3 (70-74) is the sweet spot. The highest-scoring candidates produce no edge.

### Findings — Volume_ratio bucket

| Bucket | N | WR % | Avg $ | Avg % |
|---|---:|---:|---:|---:|
| Q2: 1.5-2.0 | 791 | 37.9 | +$1,349 | +1.67 |
| Q3: 2.0-2.5 | 567 | 39.0 | **+$2,678** | **+2.18** |
| **Q4: 2.5-3.0** | **234** | **35.0** | **-$994** | **-0.67** |
| Q5: ≥3.0    | 201 | 31.3 | +$2,229 | +2.57 |

**Partially confirmed**: Q4 (2.5-3.0) is the only **negative-$/trade** bucket and has the second-worst WR. But extreme volume (≥3.0) recovers on $/trade (positive +$2,229) despite lower WR — fat-tail bull setups. The right cap is "exclude 2.5-3.0", not "exclude ≥2.5".

### Findings — Stop_initial_distance_pct bucket

| Bucket | N | WR % | Avg $ | Avg % |
|---|---:|---:|---:|---:|
| Q1: <6%    | 370 | 37.0 | +$1,627 | +0.99 |
| Q2: 6-9%   | 181 | **29.8** | +$1,660 | +1.69 |
| Q3: 9-12%  | 164 | 39.0 | **+$162** | +0.77 |
| Q4: 12-18% | 422 | 37.0 | +$974 | +1.33 |
| Q5: ≥18%   | 656 | 38.9 | **+$2,227** | **+2.38** |

**Different from earlier aggregate**: Q3 (9-12%) is the **lowest** $/trade bucket but not negative ($162). Q2 (6-9%) has the worst WR (29.8%). Q5 (≥18%) wins on both metrics — wider stops let winners run. The earlier "Q3 negative" claim was specific to the legacy config.

### Cross-cutting observation

P2's finding (`dev/notes/cell-e-candidate-supply-bottleneck-2026-05-11.md`) showed cascade supply is 10× downstream fill rate. Adding entry-signal caps will reduce the candidate pool but **not** the fill rate — the slots are still capacity-bound by holding-period lock-up. The expected effect is therefore on **WR/Sharpe**, not on trade count. Specifically:

- A `max_score_override = 79` cap would discard ~192/1793 = 10.7% of entered trades, replacing them with the next-best candidates from the 12.5/Friday cascade pool. The replacement candidates should have higher expected WR (since Q5 was the worst bucket).

### Recommended actions

| # | Action | Type | Effort |
|---|---|---|---|
| 1 | Add `max_score_override : int option` to `Screener.config` (mirror of `min_score_override`). Reject candidates with `score >= cap` from cascade output. | Code | Small (~80 LOC + tests) |
| 2 | Add `volume_ratio_exclude_range : (float * float) option` to screener config. Reject candidates whose volume_ratio falls in `[low, high]`. | Code | Small (~80 LOC + tests) |
| 3 | Move stop_initial_distance_pct floor from default 0.08 to 0.10 (allow wider initial stops). | Strategy config | Trivial — already a knob |
| 4 | Run a 3-arm sweep on 15y Cell E: (a) baseline 0.14/exp0.70, (b) +max_score=79, (c) +max_score=79 + volume_excl=[2.5,3.0]. Compare WR/Sharpe/MaxDD. | Sweep | Medium — runs only |

**Sequencing**: actions 1 & 2 belong in one PR (small, mechanical screener-config extensions); action 3 is a one-line scenario override and can be tested independently; action 4 follows after 1+2 land.

### Open question — score Q5 paradox

Q5 (≥80) has 28.6% WR despite being the cascade's "best" candidates. The score is built from cascade_score_components — likely overweighting signals that look strong at the breakout moment but lack follow-through (e.g., extreme RS, extreme volume, late-Stage-2 timing). A scoring rebalance might be more durable than a hard cap. Add as separate exploration item.
