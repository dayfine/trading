# Hold-period deep dive — does the strategy actually exit on Weinstein cadence?

Date: 2026-05-19. Companion to the v1 Bayesian sweep currently in flight
(`dev/notes/bayesian-prod-sweep-dispatch-2026-05-19.md`).

## Problem statement

Stan Weinstein's strategy (1988) is built around the **30-week
moving average**. Stage transitions take weeks; held positions are
intended to ride Stage-2 advances for months. The book is explicit:
this is **not a scalping strategy**.

Our current shipped strategy (cell-E, 2010-2025 backtest, 2090 trades)
exits on a very different cadence:

| Percentile | Days held |
|---:|---:|
| P50 | **12** |
| P75 | 42 |
| P90 | 119 |
| P95 | 175 |
| P99 | 273 |
| Max | 434 |
| Mean | 39.4 |

Half the trades close within 2 weeks. The mean hold is ~8 weeks — already
short for a 30-week-MA framework. **We are scalping a Weinstein-shaped
breakout signal, not riding Weinstein-style Stage-2 advances.**

### Where the fast churn comes from

Decomposing by `exit_trigger`:

| Exit trigger | N | % | P50 hold | P75 | P95 |
|---|---:|---:|---:|---:|---:|
| `stop_loss` | 1382 | 66.1% | **10** | 25 | 112 |
| `laggard_rotation` | 600 | 28.7% | 28 | 105 | 231 |
| `stage3_force_exit` | 102 | 4.9% | 14 | 63 | 196 |

The fast-churn population IS the `stop_loss` branch (P50=10d). The
laggard-rotation and stage3-force-exit branches hold roughly as long
as Weinstein would expect (P50=14-28d, P75=63-105d, P95=196-231d).

**Hypothesis (load-bearing):** the trailing stop tightens / triggers
on noise inside the first 1-2 weeks of every entry, exiting before
the Stage-2 thesis has time to play out. Two-thirds of entries die
this way.

## Why this might be fine, or might be wrong

### Why it might be FINE

- A tight stop is a valid trading style. If the median fast-exit loses
  only ~1% per trade and the few survivors do ≥+10R, the expectancy
  could still beat the loose-stop alternative.
- Cell-E's 5-year Sharpe (0.94 on 15y per `memory/project_sp500_baseline_conflict.md`)
  is not bad. So the current scalp-on-Weinstein-signal is profitable.
- The fast-churn population may be "early stage-2 false positives" the
  trailing stop correctly filters out — the framework's adverse-selection
  pruning, not a flaw.

### Why it might be WRONG

- Weinstein's book is explicit: weekly-bar timeframe + 30-week MA. The
  stop is meant to ride **beneath** the rising MA, not 5-8% beneath
  entry. Our `initial_stop_buffer` (1.00-1.10) + `installed_stop_min_pct`
  (0.04-0.15) produce far tighter stops than that.
- The 66% stop-loss share might be cutting winners that would have run
  for 3-6 months if given room. Selection bias in the survivors: only
  the trades that pass *both* the initial-stop gauntlet *and* the
  laggard-rotation gauntlet are reaching weeks-to-months holds.
- If we re-run with a Weinstein-faithful stop (e.g. 15-20% buffer below
  entry, OR explicit "exit only on weekly close below 30-week MA"),
  total return may be *higher* because surviving Stage-2 trades have
  more upside than the per-trade gain we capture today.

## Bayesian-sweep evidence

The v1 sweep currently running (4 knobs, budget=60) tunes:
- `initial_stop_buffer` ∈ [1.00, 1.10]
- `installed_stop_min_pct` ∈ [0.04, 0.15]

Two of four knobs ARE stop-placement. The Sharpe-objective winner will
implicitly answer:

- If winner's stop knobs are at the **upper** bound (loose stops), the
  fast-churn cost is real and the strategy wants to hold longer.
- If at the **lower** bound (tight stops), the current cadence is
  near-optimal and the median-12d hold is by design.

**Caveat**: the sweep optimises Sharpe, not hold-period. A winner with
loose stops + lower Sharpe than baseline still proves nothing about
cadence; sharpness penalises drawdown which loose stops increase.
**This sweep is a useful signal but not a definitive test.**

## Probes (post-v1)

Five experiments, each independent, ordered by cost:

### P1: exit-trigger × P&L decomposition (1 PR, ~50 LOC analysis)

Already have the data. Aggregate cell-E 15y trades by `exit_trigger`
and compute per-bucket: mean R, win-rate, mean P&L %, total contribution
to PnL. Answers "are the 1382 stop-loss exits net-positive or
net-negative? do they justify their 66% share?". One-shot analysis,
no new backtest.

### P2: stop-only ablation runs (1 sweep, ~6 hr)

Run 5 configs sweeping ONLY stops, holding other knobs at cell-E:
1. tight (initial_stop_buffer=1.00, installed_stop_min_pct=0.04) — current floor
2. cell-E baseline
3. loose (initial_stop_buffer=1.10, installed_stop_min_pct=0.15) — current ceiling
4. very-loose (initial_stop_buffer=1.20, installed_stop_min_pct=0.20) — outside current bounds
5. weinstein-faithful (initial_stop_buffer=1.20, installed_stop_min_pct=0.05,
   PLUS a flag "exit only on weekly close below 30-week MA" if implementable)

Per config: full 15y backtest. Report median/P75/P95 hold-days +
Sharpe + MaxDD + total return. If config #4 or #5 dominates on Sharpe
AND has 3-5× longer median hold, the current bounds were too tight and
v2 sweep should widen them.

### P3: time-to-first-stop-trigger histogram (1 PR, ~30 LOC analysis)

Existing column `days_to_first_stop_trigger` on each trade. Plot
histogram for the 1382 stop-loss exits. If the mode is days 1-3, the
stop is firing on entry-bar noise — we're stopping out before the
position even establishes. Fix: add a 5-day or 10-day "settling
window" after entry where the stop is disabled. Tunable knob.

### P4: per-stage hold-distribution (1 PR, ~30 LOC analysis)

Existing column `entry_stage`. Decompose hold-days by stage at entry.
If we have many Stage-3 or Stage-4 entries (despite the screener
filter), those may have wrong-direction risk and short holds.
Hypothesis: laggard-rotation eviction is correctly catching false
Stage-2 entries; the 600 laggard-rotation trades' P50=28d is the
holding period of the trades the screener mis-classified.

### P5: composite objective sweep with cadence term (depends on PR #1196)

Plan #1196 (`wire spec.objective into score_cell`) lets us define a
multi-term objective. Add a soft penalty for `median_hold < 30 days`:

```
score = 0.50 × Sharpe
      + 0.30 × Calmar
      - 0.10 × MaxDD
      - 0.10 × max(0, 30 − median_hold) / 30
```

Re-run v2 sweep with this objective. If the cadence term moves the
winner's stop knobs upward by >2σ, it's confirmation the fast-churn is
a real cost the Sharpe-only objective hides.

## Decision tree

```
After v1 lands:
├─ P1 + P3 + P4 (cheap analyses) — establish whether fast-churn is profitable
│   ├─ Net-positive contribution → fast-churn is by design, close this plan
│   └─ Net-negative or marginal → continue
├─ P2 (widen-stops ablation) — does loosening dominate?
│   ├─ Loose wins on Sharpe → file PR to widen v2 sweep bounds
│   └─ Loose loses on Sharpe → continue to P5
└─ P5 (composite-objective sweep) — does the cadence-aware scorer find a longer-hold winner?
    ├─ Yes → that's the v3 winner; ship
    └─ No → the strategy genuinely is a scalp-on-Weinstein-signal; document and close
```

## What this is NOT

- This plan is **not** advocating for a Weinstein-purist rewrite. The
  shipped strategy may be a legitimate (if non-canonical) interpretation.
  The plan is "measure what we have, then decide".
- Not a quick-win — these probes will take 1-2 weeks of analysis +
  sweep wall-time. Sequencing should follow v1 + plan #1196 landing.

## Sizing + sequencing

- P1, P3, P4: tiny analysis PRs, ~30-50 LOC each. Independent. Land in
  one session after v1 lands.
- P2: 1 sweep (~6 hr wall at parallel=4 with the now-shipped Fork_pool).
- P5: blocked on plan #1196 (Composite scorer). ~12 hr wall once #1196
  lands.

Total wall to a decision: ~1 week if motivated.
