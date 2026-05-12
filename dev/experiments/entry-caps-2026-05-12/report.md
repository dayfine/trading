# Entry-caps 3-arm sweep — 15y Cell E

## TL;DR

**`max_score_override=79` improves WR but inverts the risk profile.** The Q5
hypothesis (top-quintile score is over-confident) is mechanically confirmed
on win-rate, but the strategy's reaction to capping the top quintile is to
fill those slots with shorter-holding-period candidates, doubling trade
count while collapsing average hold from 46 days to 20 days. Net Sharpe
0.85 → 0.59, MaxDD 18.4% → 52.1%.

The cap is **NOT a clean lever in isolation**. The `Q5 has 28.6% WR` finding
from the rolling-5y entry-signal note remains true, but using it as a hard
score cap shifts the strategy out of "let winners ride" regime into
"high-frequency rotation on lower-quality candidates" regime.

## Method

15y Cell E default (`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`, MaSlope, short side off, stage3_h=1, laggard_h=2) on
sp500-historical 510 symbols 2010-01-01 → 2024-12-31.

3 arms:
| Arm | Override delta |
|---|---|
| A | (baseline) |
| B | `screening_config.max_score_override = 79` |
| C | B + `screening_config.candidate_params.initial_stop_pct = 0.10` |

Wall: ~50 min, parallel-3 on clean memory.

## Results

| Arm | Return | Trades | WR | Sharpe | MaxDD | AvgHold | PF |
|---|---:|---:|---:|---:|---:|---:|---:|
| A baseline | 374.21% | 768 | 39.45% | **0.85** | **18.36%** | 46.0d | 1.62 |
| B max_score=79 | 404.85% | 1504 | **48.14%** | 0.59 | 52.12% | 20.0d | 1.60 |
| C max_score=79 + stop=0.10 | 404.85% | 1504 | 48.14% | 0.59 | 52.12% | 20.0d | 1.60 |

### B vs A — the Q5 cap effect

| Metric | A → B | Δ | Verdict |
|---|---|---|---|
| Total return | 374% → 405% | +30 pp | mild positive |
| Win rate | 39.5% → 48.1% | **+8.7 pp** | confirms Q5 ≥80 hypothesis |
| Trade count | 768 → 1504 | **+96%** | cascade fall-through works |
| Avg hold | 46 → 20 days | **−57%** | regime shift |
| Sharpe | 0.85 → 0.59 | **−0.26** | bad |
| MaxDD | 18.4% → 52.1% | **+33.8 pp** | catastrophic |
| Profit factor | 1.62 → 1.60 | flat | unchanged |

**Mechanism:** Capping at 79 prevents the strategy from sitting in the
top-confidence trades (Q5 score ≥80). It fills the freed slots with
next-best candidates (Q4 score 75-79), but those candidates have a
materially shorter holding-period profile. The strategy now cycles ~3× more
positions per year with much shorter average hold.

The headline WR boost is real but misleading: per-trade profit factor is
flat at 1.60 (vs 1.62 baseline). All the WR gain is offset by smaller
average-win and more frequent transitions (entry/exit churn).

### C vs B — broken override (knob-not-applied)

C and B produced **byte-identical trades.csv** (md5-equal). The second
`screening_config` overlay
`((screening_config ((candidate_params ((initial_stop_pct 0.10))))))` does
not deep-merge into the first `screening_config` overlay
`((screening_config ((max_score_override (79)))))`. Per-trade
`stop_initial_distance_pct` mean is 0.1623 in BOTH arms (computed off
default 0.08, not 0.10).

This is a runner-side `_apply_overrides` bug specific to multiple overlays
targeting the same top-level field. Filing as a follow-up — the workaround
is to bundle the two screening_config overrides into one overlay sexp
(`((screening_config ((max_score_override (79)) (candidate_params ((initial_stop_pct 0.10))))))`)
and re-run.

## Exit-trigger breakdown (arm-b)

```
stop_loss          1288  (85.6%)
laggard_rotation    189  (12.6%)
stage3_force_exit    26  (1.7%)
[blank]               1
```

86% of exits are stop_loss in arm-b vs the baseline pattern where
laggard_rotation drives ~half. The Q5 cap forces the strategy out of its
"ride winners until laggard rotation" mode and into "stop out fast" mode.
This explains the DD spike — many small losses compound during chop.

## Verdict — DO NOT promote `max_score_override=79`

The Q5-quintile finding from `dev/notes/entry-signal-quintiles-2026-05-11.md`
is correct in isolation, but the corrective action (hard score cap) destroys
more value than it creates. **Three plausible refinements** worth testing
separately:

1. **Soft penalty rather than hard cap.** Reduce score weight on Q5 features
   (high RS, extreme volume, late-Stage-2 timing) within the scoring rubric,
   so Q5 candidates get downgraded but not removed. Preserves the long-hold
   compounding regime.

2. **Pair Q5 cap with WIDER initial_stop_pct.** The Q5 trades hold longer
   because their stops are wider in absolute terms. Capping Q5 + widening
   stops on Q3/Q4 (e.g. `initial_stop_pct=0.12`) might stabilize hold
   periods. Arm C was supposed to test this but the override didn't apply
   (see runner bug above).

3. **Cap Q5 only on macro=Bullish.** Q5's regime-dependence may differ —
   late-Stage-2 high-volume breakouts perform differently in late bull vs
   neutral macro. Conditional cap could keep the Q5 alpha when it's worth
   it.

## Bug filed

`Backtest.Runner._apply_overrides` does not correctly deep-merge multiple
overlays targeting the same top-level config field. Reproduction:

```
dune exec backtest_runner.exe -- \
  --override '((screening_config ((max_score_override (79)))))' \
  --override '((screening_config ((candidate_params ((initial_stop_pct 0.10))))))'
```

Expected: both knobs apply.
Actual: second overlay's effect is silent — `initial_stop_pct` stays at
default 0.08.

Workaround: bundle into a single overlay:
```
--override '((screening_config ((max_score_override (79)) (candidate_params ((initial_stop_pct 0.10))))))'
```

Adds a follow-up TODO: `_apply_overrides` should preserve sequential overlay
semantics where each overlay deep-merges INTO the running result. Inspect
the `is_record` heuristic — likely tripping on a sub-record shape and
falling through to overlay-replacement at the inner level.

## Implications

The `max_score_override=79` knob (PR #1034) is a useful diagnostic surface
but should not be promoted as a default. Q5-cap refinement work moves to
the `experiments` track:

- E5 — soft Q5 penalty in `Screener.scoring_weights`
- E6 — Q5 cap × initial_stop_pct grid (after runner bug fixed or via
  bundled overlay)
- E7 — Q5 cap conditional on macro_trend = Bullish

PR #1043 (`volume_ratio_exclude_range`) is the other entry-signal lever —
mid-volume bucket [2.5, 3.0) is the only negative-$/trade bucket per the
quintile note; capping it has the same risk as Q5 cap (regime shift via
candidate substitution). Recommend testing volume cap with the same 3-arm
template once #1043 merges.
