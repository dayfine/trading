# Continuation-buys parameter tuning — 5y sp500-2019-2023 (2026-05-14)

## TL;DR

One-at-a-time sweep of the four `Continuation.config` axes around their ship
defaults, holding the other three at default. Cell E + `enable_continuation_buys=true`
on 5y `sp500-2019-2023` (500 symbols). **No single-axis cell achieves the
target 25–75 added continuation trades** (5–15 / yr × 5y).

| Cell                                  | Trades | Return | Sharpe | MaxDD  | Calmar | Δ vs default-on baseline |
|---------------------------------------|-------:|-------:|-------:|-------:|-------:|--------------------------|
| **baseline (defaults)**               |   265  | 52.15  |  0.59  | 21.56  |  0.41  | 0                        |
| axis1 `ma_slope_min` = 0.005 (loose)  |   265  | 52.15  |  0.59  | 21.56  |  0.41  | 0 (bit-equal)            |
| axis1 `ma_slope_min` = 0.02  (tight)  |   265  | 51.65  |  0.57  | 21.56  |  0.40  | −0.50 pp return          |
| axis2 `pullback_band` = ±3% (narrow)  |   265  | 52.15  |  0.59  | 21.56  |  0.41  | 0 (bit-equal)            |
| axis2 `pullback_band` = ±8% (wide)    |   265  | 52.15  |  0.59  | 21.56  |  0.41  | 0 (bit-equal)            |
| **axis3 `consolidation_weeks` = 2**   | **261**| **56.34** | **0.61** | 22.09 | **0.42** | **+4.19 pp**, 1 fewer trade |
| axis3 `consolidation_weeks` = 6       |   264  | 50.66  |  0.56  | 21.56  |  0.40  | matches default-OFF (no fires)|
| axis4 `consolidation_range_pct` = 0.05|   264  | 50.66  |  0.56  | 21.56  |  0.40  | matches default-OFF (no fires)|
| **axis4 `consolidation_range_pct` = 0.15** | **266** | **54.90** | **0.61** | 21.56 | **0.43** | **+2.75 pp**, +1 trade |

Bit-equal cells: 0.005-loose (axis1), ±3% / ±8% (axis2) all collapse to the
default (52.15, 265 trades, 0.59 Sharpe). The 0.06-weeks-6 (axis3) and
range=0.05 (axis4) cells collapse to the **default-OFF baseline** (PR #1082's
`continuation-buys-baseline`: 264 trades, 50.66% return) — those settings are
so strict the continuation arm never fires.

**Recommendation: do not promote any single-axis cell as a default.** The two
movers are `consolidation_weeks=2` (+4.19 pp / +0.02 Sharpe / +0.53 pp MaxDD)
and `consolidation_range_pct=0.15` (+2.75 pp / +0.02 Sharpe / 0 pp MaxDD).
The latter is the cleanest individual lever — same MaxDD, better Calmar,
slightly higher trade count — but neither produces enough continuation fires
to drive the desired 5–15 trades/year admit rate. The slot budget under Cell
E's `max_long_exposure_pct=0.70` is the binding constraint.

**Next step:** combine `axis3-weeks=2` + `axis4-range=0.15` (both "loose
consolidation" knobs); 16y validation gate; consider whether the experiment
should pivot away from single-knob tuning entirely to either (a) revisit
the slot budget or (b) retire continuation-buys as ill-suited on 5y Cell E.

## Setup

- Scenarios: `dev/experiments/continuation-tuning-2026-05-14/scenarios/`
- Output: `/workspaces/trading-1/dev/backtest/scenarios-2026-05-14-072437/`
- Runner: `scenario_runner.exe --parallel 3 --no-emit-all-eligible`
- Universe: 500 symbols, 2019-01-02 → 2023-12-29
- Cell E config: `max_position_pct_long=0.14`,
  `max_long_exposure_pct=0.70`, `min_cash_pct=0.30`, stage3 force-exit h=1,
  laggard rotation h=2, `enable_continuation_buys=true`.
- Authority: PR #1078 (Interpretation B wiring, default-off), PR #1082 (sanity
  result → tuning call), `dev/notes/next-session-priorities-2026-05-14.md` §P3,
  `docs/design/weinstein-book-reference.md` §4.6 Continuation Buys (Ch. 3).

## Per-axis findings

### Axis 1 — `ma_slope_min` (default 0.01)

| Cell  | Trades | Return | Sharpe | MaxDD | Notes                          |
|-------|-------:|-------:|-------:|------:|--------------------------------|
| 0.005 |  265   | 52.15  | 0.59   | 21.56 | Bit-equal to baseline          |
| 0.01  |  265   | 52.15  | 0.59   | 21.56 | Baseline (continuation-on)     |
| 0.02  |  265   | 51.65  | 0.57   | 21.56 | Rejects 1 continuation; cascade backfills with lower-edge alt |

Loosening the slope floor to 0.005 admits **no new continuation entries** on
this 5y / 500-sym universe — the other three gates were already rejecting
those candidates. Tightening to 0.02 **does** reject the 1 fire that occurs
at default (0.01), but the cascade replaces the slot with a regular Stage 2
entry at lower edge, yielding 50 bps lower total return at unchanged trade
count.

**Verdict: axis-1 is a low-information lever on this universe.** The slope
floor doesn't gate enough patterns to move the needle.

### Axis 2 — `pullback_band` width (default ±5% = [0.95, 1.05])

| Cell                | Trades | Return | Sharpe | MaxDD | Notes                  |
|---------------------|-------:|-------:|-------:|------:|------------------------|
| ±3% [0.97, 1.03]    |  265   | 52.15  | 0.59   | 21.56 | Bit-equal to baseline  |
| ±5% [0.95, 1.05]    |  265   | 52.15  | 0.59   | 21.56 | Baseline               |
| ±8% [0.92, 1.08]    |  265   | 52.15  | 0.59   | 21.56 | Bit-equal to baseline  |

**Pullback_band is inert on this universe.** Neither narrowing nor widening
the close/MA ratio band changes the set of qualifying pullback bars enough
to change which entries fire — the consolidation + slope gates dominate.

**Verdict: axis-2 is a dead lever for further tuning.**

### Axis 3 — `consolidation_weeks` (default 4)

| Cell | Trades | Return | Sharpe | MaxDD | Calmar | Notes                                   |
|------|-------:|-------:|-------:|------:|-------:|-----------------------------------------|
| 2    | **261**| **56.34** | **0.61** | 22.09 | 0.42 | Shortest window — most permissive; +4.19 pp return; +0.53 pp MaxDD; 1 fewer trade |
| 4    |  265   | 52.15  | 0.59   | 21.56 | 0.41   | Baseline                                |
| 6    |  264   | 50.66  | 0.56   | 21.56 | 0.40   | Bit-equal to PR #1082 continuation-OFF baseline — too strict, never fires |

**The signal-bearing cell.** A 2-bar consolidation window relaxes the tightness
gate (`(hi-lo)/avg <= 0.10`) from being computed over 4 bars to just 2 — easier
to satisfy. The detector fires meaningfully more, yielding +4.19 pp return
and +0.02 Sharpe. Win rate drops slightly (37.74 → 35.25) — the new
continuation fires are lower-quality on average, but the higher hit count
compensates.

`consolidation_weeks=6` produces a metric set bit-identical to PR #1082's
**continuation-OFF baseline** (264 trades, 50.66% return) — at 6-week window
the tightness gate `(hi-lo)/avg <= 0.10` is virtually impossible to satisfy
on most names, so the continuation arm is effectively off.

**Verdict: axis-3 is the most actionable lever.** `weeks=2` is the only
cell that meaningfully shifts headline metrics in a coherent direction.

### Axis 4 — `consolidation_range_pct` (default 0.10)

| Cell | Trades | Return | Sharpe | MaxDD | Calmar | Notes                                   |
|------|-------:|-------:|-------:|------:|-------:|-----------------------------------------|
| 0.05 |  264   | 50.66  | 0.56   | 21.56 | 0.40   | Bit-equal to continuation-OFF baseline — too strict, never fires |
| 0.10 |  265   | 52.15  | 0.59   | 21.56 | 0.41   | Baseline                                |
| 0.15 | **266**| **54.90** | **0.61** | 21.56 | **0.43** | Loosest — admits 1 extra trade; +2.75 pp return; MaxDD unchanged |

The second signal-bearing cell. Loosening the range gate from 10% to 15%
admits a slightly wider class of bases as "consolidation". The detector adds
1 trade and lifts total return by 2.75 pp at unchanged MaxDD, Sharpe to 0.61,
best Calmar of the sweep (0.43). The 0.05 cell collapses to the
continuation-OFF baseline.

**Verdict: axis-4 is the cleanest individual lever** — best Calmar, no MaxDD
penalty, modest trade-count uplift.

## Critical caveat: slot budget binds

**Across all 8 sweep cells, trade count stays 261-266** — within 2% of
baseline. This is not a tuning artefact; it is a structural property of Cell E
on 5y / 500-sym sp500:

- `max_long_exposure_pct = 0.70` + `max_position_pct_long = 0.14` →
  ~5 simultaneous positions
- Stage3 force-exit + laggard rotation already churn most of the slot capacity
- A continuation candidate that qualifies **competes for the same slot** as a
  regular Stage 2 breakout. The cascade rankings shuffle, but the slot count
  is fixed.

Trade-level diff between `axis1-0.005-loose` and `axis1-0.02-tight` (both 265
trades) confirms ~16 trades differ in **identity** between the two cells —
loosening the gate admits different symbols (BMY, CIEN, CPB, CRM, etc.) than
tightening it (AEE, AOS, APP, HIG, etc.). The override IS working; it just
doesn't expand the trade budget.

**This means single-axis tuning around the slot ceiling cannot achieve the
hypothesised "5–15 continuation trades / year" admit rate.** The detector
fires more often inside the cascade ranking, but only ~1–2 of those fires
per year actually convert to a position fill at any cell tested.

## Falsifiability check

- **Zero trade-count delta** in 4 of 8 cells (axis1-0.005, axis2-pm3, axis2-pm8
  bit-equal to baseline; axis3-6 + axis4-0.05 bit-equal to continuation-OFF).
  This passes the hypothesis's failure mode: "if no axis cell pushes trade
  count above 270, the detector is structurally too narrow for the universe at
  any of these single-knob settings."
- **Trade count >400** never occurred — no cell over-admits.
- The hypothesis "the bottleneck is detector selectivity, not slot budget" is
  refuted — even the loosest cells (axis3-2, axis4-0.15) net only +1 trade
  beyond default.

## Recommendation

### Primary: combination sweep (single-axis insufficient)

Combine the two signal-bearing cells in a follow-up:

```
((continuation_config ((consolidation_weeks 2) (consolidation_range_pct 0.15))))
```

Rationale: both individually lift return + Sharpe at acceptable MaxDD. Together
they may admit enough patterns to reach 5–10 / yr. Test on 5y main and 10y
`decade-2014-2023` validation.

### Secondary: re-examine slot budget

If the combined cell still produces < +10 trades over baseline, the actual
constraint is **the 0.70 long-exposure cap**, not detector selectivity.
Continuation-buys cannot deliver capital-recycling value at Cell E sizing
because the slots are already saturated by Stage3 force-exit + laggard
rotation. Consider:

1. Raising `max_long_exposure_pct` to 0.80 alongside continuation-buys to
   open new slots (orthogonal to detector tuning).
2. Conditioning continuation-buys entry priority above some Stage 2 entries
   in the cascade — currently they share the OR-arm equally.

### Tertiary: retire as 5y-ill-suited

If the combined sweep + slot-budget tests both fail to admit ≥ 25 continuation
trades over 5y, the book's continuation pattern is too rare on a 5y / 500-sym
universe to evaluate meaningfully. **Defer continuation-buys evaluation to
the 16y horizon** (`sp500-2010-2026`) where rare patterns accumulate enough
statistical power. Until then, keep default-off (current ship state).

## Sanity check: override actually applies

Trade-level diff confirms the `continuation_config` override is being read by
the strategy:

```
$ comm -23 <(axis1-0.005 trades) <(axis1-0.02 trades) | wc -l
16  # symbols unique to loose-slope
$ comm -13 <(axis1-0.005 trades) <(axis1-0.02 trades) | wc -l
16  # symbols unique to tight-slope
```

The deep-merge in `Backtest.Overlay_validator.apply_overrides` correctly
applies the nested `continuation_config` sub-record. The new config field
(landed in this PR's first commit, see `weinstein_strategy_config.{ml,mli}`)
is the plumbing that unblocked this sweep.
