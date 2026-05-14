# Axis-2 validation on 10y + 16y horizons — **STOP**

## TL;DR

`stops_config.min_correction_pct = 0.10` (PR #1083 axis-2 5y winner)
**catastrophically fails on all 3 long-horizon validation cells**. STOP per
pre-registered ±0.02 decision rule on every cell.

**Do NOT promote axis-2 to a Cell E default.** The 5y win was a window-
specific phenomenon.

## Pre-registered decision rule

Per `dev/notes/p3-tuning-sweep-design-2026-05-13.md` (PR #1064) + dispatch
hypothesis:

- ΔCalmar ≥ +0.02 on ALL 3 horizons → GO
- ≥ +0.02 on 2 of 3 → CONDITIONAL GO
- in band ±0.02 → keep as candidate
- < −0.02 on ANY → STOP

## Results

| Horizon | Baseline (current main) | + 0.10 | ΔCalmar | Decision |
|---|---:|---:|---:|---|
| 5y `sp500-2019-2023` (axis-2 sweep, PR #1083) | 0.40 | 0.77 | **+0.37** | originally promoted |
| 10y `decade-2014-2023` | 0.35 | **0.31** | **−0.04** | STOP |
| 16y `sp500-2010-2026` long-only | 0.45 | **0.21** | **−0.24** | STOP (catastrophic) |
| 16y `sp500-2010-2026-longshort` | 0.46 | **0.41** | **−0.05** | STOP |

## Full per-horizon metric breakdown

| Horizon | Variant | Return | Trades | Sharpe | MaxDD | Calmar | AvgHold | Force-liqs |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 10y decade | baseline | 343.0% | 552 | 0.60 | 46.4% | 0.35 | 40.6d | 4 |
| 10y decade | + 0.10 | 253.8% | 551 | 0.56 | 44.2% | **0.31** | 41.0d | 3 |
| 16y long-only | baseline | 307.2% | 683 | 0.71 | **19.9%** | 0.45 | 46.8d | **0** |
| 16y long-only | + 0.10 | 620.5% | 474 | 0.50 | **60.1%** | **0.21** | 53.9d | **26** |
| 16y long-short | baseline | 316.1% | 708 | 0.70 | 19.8% | 0.46 | 46.6d | 1 |
| 16y long-short | + 0.10 | 251.9% | 568 | 0.67 | 19.4% | **0.41** | 53.2d | 0 |

## Mechanism — why long horizons break

The 16y long-only result is the smoking gun: **MaxDD blows from 19.9% to
60.1% (+40pp)** and force-liquidations balloon from 0 to **26**. Wider
`min_correction_pct` lets positions ride down further before any stop
trigger fires. On the 5y window (no 2008 GFC, only short tail of 2022 bear)
this looked like "winners ride proportionally" — on the 16y window the same
mechanism = "losers ride catastrophically through every bear cycle".

The 10y also degrades (Calmar 0.35 → 0.31) but less catastrophically — its
universe (broad-1000) absorbs the breadth of stop-out events differently.

## Meta-lesson — 5y tuning doesn't generalize

Both stop-distance levers were 5y winners but generalized differently:

- **Axis-1** (`installed_stop_min_pct = 0.08`, PR #1079→#1081 validation):
  CONDITIONAL GO. 16y long-only ΔCalmar **+0.06**, 16y long-short **+0.04**,
  10y broad-1000 **+0.008** (in neutral band). Two of three horizons passed
  the +0.02 GO threshold; broad-1000 was inconclusive. The lever generalized
  partially. The cross-sweep (#1084) later showed axis-1 + axis-2 combined
  is destructive, but axis-1 alone was promoted with a "SP500-horizons only,
  hold on broad-1000" caveat.

- **Axis-2** (`min_correction_pct = 0.10`, this PR): STOP on all 3 long
  horizons (10y −0.04, 16y long-only **−0.24**, 16y long-short −0.05). The
  5y win does NOT generalize; the lever fails catastrophically on the 16y
  long-only window (MaxDD 19.9% → 60.1%, 0 → 26 force-liqs).

**The 5y sp500-2019-2023 window has a specific shape** (late-cycle 2019 →
COVID crash → V-shaped recovery → 2022 bear) that rewards wider stops.
Axis-1 widens the installed-stop FLOOR (the support-floor logic still
drives most stops); axis-2 widens the support-floor DETECTION threshold
itself, so on 16y bear cycles positions ride down further before any stop
triggers. Axis-2 is strictly more aggressive than axis-1 in widening
effective stop distance, which is why it breaks where axis-1 partly held.

**Implication for future tuning:** parameter sweeps that affect stop
distance MUST be validated on 10y + 16y BEFORE promotion. A 5y win is
necessary but not sufficient evidence. The validation protocol from #1064's
design plan is now load-bearing — don't skip it.

## Verdict — STOP

- Do NOT promote `min_correction_pct = 0.10` as Cell E default.
- Revert PR #1083's recommendation. Axis-2 stays at default 0.08.
- The cross-sweep finding (PR #1084) that axis-1+axis-2 was destructive
  remains valid — just both individual winners are also rejected at long
  horizons.

## Open: what does work on long horizons?

Of the stop-distance levers tested: axis-1 alone (`installed_stop_min_pct = 0.08`)
partially generalized (passed 2 of 3 long horizons per #1081) but the combined
axis-1 + axis-2 is destructive (#1084) and axis-2 alone is destructive on
long horizons (this PR). Remaining unmeasured axes from #1064:

- **axis-3** (`min_score_override` floor tightening) — targets the cascade
  gate, NOT stop distance. May behave differently. Worth a sweep.
- **E6 conditional cap on macro=Bullish** (entry-caps follow-up)
- **E7 soft-penalty refinement** (rejected by #1080 on 5y; may behave
  differently on long horizons but probably not).

## Reproduction

Cell sexp shape (rebuild from baseline + this overlay):

```sexp
;; appended to existing config_overrides
((stops_config ((min_correction_pct 0.10))))
```

Output: `dev/backtest/scenarios-2026-05-14-022331/`.
