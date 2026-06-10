# Cascade-selection inversion — validated + decomposed — 2026-06-10

**P0 from `next-session-priorities-2026-06-10.md`.** The resurrected
`trade_audit_report` surfaced a lead on Cell-E top-3000: the cascade score we
*rank/select* on looked anti-predictive (Q1 best-grade win-rate < Q4 worst).
This session validated it across the breadth gradient and decomposed it to a
single locus.

## TL;DR

1. **The inversion is REAL, not noise.** It replicates across top-3000 / top-1000
   / top-500 (same Cell-E config, 2011-2026, snapshot mode) and **strengthens on
   narrower breadth** — the *opposite* of the fat-tail / top-3000-only signature
   that sank laggard-disable, stage2-ma-hold, and stage3-force-exit-off.
2. **The locus is the cascade `score==85` (grade A+) bucket** — it is the worst
   bucket on win-rate AND mean return on all three breadths (net-negative total
   pnl on top-1000 and top-500).
3. **The discriminating component is the stage signal.** A+ trades are exactly
   the **confirmed Stage1→Stage2 breakouts** (`w_stage2_breakout = +30`); the
   higher-win-rate trades are **early-Stage2** entries (`weeks_advancing ≤ 4`,
   `+15`). The textbook confirmed breakout underperforms the early entry, yet the
   cascade scores it **+30 vs +15**, so under cash constraint the strategy
   **prefers the worse entries**.
4. **BUT the return edge is non-stationary.** Early ≫ breakout on *return* in
   2011-2018; in 2019-2026 it collapses (on top-3000 the breakouts' fat-tail
   winners reverse it on mean). The **win-rate** inversion persists into the
   recent era across all breadths; the **return** case for a reweight does not.
   → A naive "boost early / penalise breakout" reweight is unlikely to clear
   WF-CV cleanly. The miscalibration is real but the promotable edge is not
   established.

## Method

Single full-period `scenario_runner` runs (snapshot mode, `snap_top3000_2011`
warehouse — a superset, so top-1000/500 reuse it via `universe_path` swap),
canonical Cell-E config (`enable_short_side false`, `max_position_pct_long 0.14`,
`max_long_exposure_pct 0.70`, `min_cash_pct 0.30`, stage3-force-exit on h=1,
laggard on h=2). Each emits `trade_audit.sexp` + `trades.csv`; rendered with
`trade_audit_report_bin`. Specs committed under
`dev/experiments/cascade-selection-inversion-2026-06-10/`.

The selection signal is behavioural-metric **(d) entering-losers-too-often** —
buckets by **`cascade_score` descending** (Q1_top = highest score). This is
distinct from the report's *decision-quality matrix*, which buckets by
`r_multiple` (outcome) and is trivially monotonic — do not read that one for
selection quality. We then joined the audit records (component signals) to
`trades.csv` (pnl%) by `(symbol, nearest entry_date ±5d)` — the audit decision
date leads the fill date by ~1 day.

## Result 1 — inversion replicates + strengthens on narrow breadth

Per-distinct-cascade-score (scores are discrete: stage+vol+rs+resist+sector):

| score | top-3000 win% / mean | top-1000 win% / mean | top-500 win% / mean |
|------:|---------------------:|---------------------:|--------------------:|
| 70 | 43.3% / +4.11% | 34.7% / +2.90% | 33.8% / +0.14% |
| 75 | 37.1% / +3.18% | 33.0% / +0.84% | 33.9% / +0.74% |
| **85** | **31.3% / +1.22%** | **26.5% / −0.26%** | **26.4% / −0.31%** |

`score ≥ 85` vs `< 85` aggregate:

| breadth | score≥85 win% / total-pnl% | score<85 win% / total-pnl% |
|---------|---------------------------:|---------------------------:|
| top-3000 | 31.3% / +384.7% | 37.7% / +924.5% |
| top-1000 | 26.5% / **−51.0%** | 34.0% / +347.4% |
| top-500 | 26.4% / **−39.2%** | 35.3% / +969.7% |

The top cascade grade (A+) is the worst bucket on every breadth and *loses money*
on the two narrower ones. Two-proportion z on the original top-3000 Q1 vs Q4 ≈
2.18 (p≈0.03) — mild on one run, but the cross-breadth replication is the real
evidence.

## Result 2 — locus = the stage signal (breakout +30 vs early +15)

Within `score==85`, volume / RS / sector are **constant** (all Strong /
Positive_flat / Strong) — the bucket is a fixed recipe. The arithmetic forces
`85 = breakout(30) + strong-vol(20) + RS-flat(10) + resistance(15) + sector(10)`.
The only thing separating it from `score==70` (identical vol/rs/resist/sector) is
the **stage signal**: full `Stage1→Stage2 breakout` (+30, requires an observed
prior Stage1) vs `Early Stage2` (`weeks_advancing ≤ 4`, +15).

Bucketed by stage signal (all trades, full 15y):

| breadth | breakout (n / win% / mean / total) | early (n / win% / mean / total) |
|---------|-----------------------------------:|--------------------------------:|
| top-3000 | 527 / 33.8% / +2.12% / +1114.8% | 90 / 42.2% / +2.64% / +237.3% |
| top-1000 | 426 / 28.9% / **−0.06%** / **−26.1%** | 206 / 35.9% / +1.44% / +296.7% |
| top-500 | 333 / 32.4% / +0.81% / +268.6% | 327 / 36.1% / +1.39% / +455.7% |

`score==85` is ~100% breakout; `score==70` is ~100% early. The confirmed breakout
— the canonical Weinstein entry — has the **lower win-rate on every breadth**,
yet the cascade rewards it +30 vs +15, ranking it *above* the higher-win-rate
early entries.

⚠ Mechanism caveat: "early" = Stage2 with `weeks_advancing ≤ 4` **and prior_stage
≠ Stage1** (else the breakout arm matches first). prior_stage is typically `None`
→ these are entries where we **lacked the history to confirm a clean Stage1
base**. So part of the effect may be an observability/data confound (symbols with
shorter in-universe history), not purely a strategy signal. This needs causal
validation, not just the in-sample cut.

## Result 3 — the return edge is non-stationary (the catch)

Stage cut split by entry era:

| breadth | era | breakout win% / mean | early win% / mean |
|---------|-----|---------------------:|------------------:|
| top-3000 | 2011-18 | 34.8% / +2.00% | 40.9% / **+5.08%** |
| top-3000 | 2019-26 | 31.9% / **+2.32%** | 43.5% / +0.30% |
| top-1000 | 2011-18 | 29.8% / +0.06% | 41.3% / **+2.70%** |
| top-1000 | 2019-26 | 27.3% / −0.26% | 27.5% / −0.55% |
| top-500 | 2011-18 | 36.4% / +2.00% | 39.8% / +2.62% |
| top-500 | 2019-26 | 28.1% / −0.49% | 30.9% / −0.33% |

- **Win-rate**: early ≥ breakout in *every* cell (both eras, all breadths). Robust.
- **Mean return**: early ≫ breakout in 2011-18; in 2019-26 the gap closes and on
  top-3000 it **reverses** — the confirmed breakouts caught the recent bull's
  fat-tail winners (mean +2.32 vs +0.30 despite a lower win-rate). Classic
  let-winners-run: lower hit-rate, bigger tails.

So the breakout-premium is robustly miscalibrated on **consistency**, but the
**return** case for down-weighting it is a 2011-18 phenomenon and weak-to-negative
recently. A full-15y-tuned reweight would mostly be fitting the early regime.

## What this means / next steps

- **First real strategy lead from the forensics tool** — and it points at
  **selection (cascade scoring), not timing**, consistent with the breadth
  findings (selection ≫ timing).
- **It is not a free win.** The honest read: the cascade over-rewards the
  confirmed Stage1→2 breakout relative to its realised win-rate, but breakouts
  carry the fat-tail upside that early entries lack, and the net return edge from
  reweighting is regime-dependent. This is exactly the precision-vs-payoff
  trade-off the program keeps hitting.
- **The fix is a config dial, and Weinstein-faithful.** `scoring_weights`
  (`w_stage2_breakout`, the early `/2` split) are config. Re-weighting *within*
  Stage2 entries does not touch the spine (still Stage2-only, breakout+volume,
  stage3/4 exit, stop below base, macro/sector gate). It is an entry-timing dial.
- **Route through `experiment-gap-closing`, not a default flip.** Define a
  variant SURFACE over the breakout/early weight ratio (e.g.
  `w_stage2_breakout ∈ {30,22,15}` holding early at 15, or equivalently equalise
  them), run WF-CV on top-3000-2011 + a narrower-breadth cell + a deep regime
  cell, rank with DSR/Pareto, then the confirmation grid. **Budget for a likely
  no-promote** given Result 3 — the recent fold shows no return edge — but the
  experiment is worth running because the miscalibration is the first
  forensically-grounded hypothesis we've had, and a *consistency* gain
  (higher win-rate / lower DD) may matter even if mean return is flat.

## Reproduce

```
# specs: dev/experiments/cascade-selection-inversion-2026-06-10/scn-top{3000,1000,500}.sexp
docker exec -d trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir <dir-with-one-spec> --snapshot-dir /tmp/snap_top3000_2011 \
    --fixtures-root / --parallel 1 --no-emit-all-eligible'
# then: trade_audit_report_bin --scenario-dir <out>/<name>
# selection signal = behavioural metric (d), bucketed by cascade_score (NOT the
# r_multiple decision-quality matrix).
```
