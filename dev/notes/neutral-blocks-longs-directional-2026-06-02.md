# neutral_blocks_longs — directional single-backtest read (lever #2)

The `neutral_blocks_longs` axis (#1410, default-off) is the diagnosis's lever #2:
block new longs in a macro-`Neutral` tape (only `Bullish` admits), to cut the
2022-style bear-rally whipsaw the Cell E stall diagnosis pinned. This is a **cheap
directional read** (single backtests, NOT walk-forward CV) to decide whether the
mechanism is worth the full gap-closing gauntlet.

**Verdict: FRAGILE / INCONCLUSIVE — do NOT promote. The sign flips by universe
vintage and starting book.** It is not the clean win the chop-regime framing first
suggested.

## The runs (canonical Cell E config ± `neutral_blocks_longs=true`)

### Fresh 2020-2026, sp500-2020 PIT universe (506 sym), $1M start

| metric | baseline | neutral-ON | Δ |
|---|--:|--:|---|
| profit factor | 0.96 | **1.12** | **+0.16 ✓** |
| MaxDD | 32.3% | **25.0%** | **−7.3pp ✓** |
| Calmar | 0.18 | **0.24** | +0.06 ✓ |
| total return | 44.3% | 43.4% | ≈flat |
| Sharpe | 0.49 | 0.47 | ≈flat |
| trades | 300 | 322 | +22 |

On the **fresh** chop window this looks like exactly what the diagnosis ordered:
realized PF crosses above 1.0, MaxDD drops 7pp, at ~no return cost.

### Full 2010-2026, sp500-2010 PIT universe (510 sym) — by-era split

| era | baseline PF | neutral-ON PF | baseline net | neutral-ON net |
|---|--:|--:|--:|--:|
| 2010-2019 | 1.78 | 1.77 | +$1.62M | +$1.46M |
| **2020-2026 segment** | **0.88** | **0.74** | −$264k | **−$595k** |
| full-window MaxDD | 17.5% | **20.4%** | | |
| full-window PF | 1.31 | 1.21 | | |

On the **full run**, the 2020-2026 *segment* gets **worse** with the flag on
(PF 0.88 → 0.74) — the **opposite sign** from the fresh run. 2010-2019 is ~neutral
(PF 1.78 → 1.77, slightly lower net). Full-window MaxDD actually *rises* 17.5 → 20.4%.

## Why the contradiction (the load-bearing lesson)

The two "2020-2026" measurements disagree because they are **not the same
experiment**:
- **Universe vintage differs** — fresh uses the sp500-2020 PIT snapshot; the full
  run uses sp500-2010. Different constituents → different Neutral-period entries get
  blocked.
- **Starting book differs** — fresh starts flat at $1M on 2020-01-01; the full run
  enters 2020 carrying a large legacy book from 2010-2019. Blocking new Neutral
  longs interacts with the legacy positions + cash redeployment timing differently.

The flag's effect is **path-, universe-, and capital-state-dependent**, not a clean
regime property. A throttle that helps a flat-start 2020 book *hurts* a legacy-laden
one. This is precisely the single-window/single-path fragility the experiment
program has been burned by (continuation #1366, hysteresis, early-admission). A
cheap directional read that flips sign across two reasonable framings is a **red
flag, not a green light**.

## Decision

- **Keep `neutral_blocks_longs` default-off** (it already is; #1410 changed no
  default). No promotion.
- **Do NOT escalate to the full WF-CV + confirmation grid yet on this evidence
  alone.** The directional read is contradictory; spending the multi-hour
  walk-forward + deep-cell + grid budget is only warranted if a cleaner motivating
  signal appears. If it is run, it MUST use the regime battery (a sustained-trend
  cell + a chop cell + a deep cell) AND test multiple universe vintages — the
  sign-flip above shows a single universe would mislead.
- **The deeper takeaway reinforces the diagnosis:** even the "tension-free" entry
  throttle does not cleanly fix the post-2020 regime. The stall is a genuine
  regime property (shorter/shallower trends + deeper failed-breakout drawdowns);
  the more promising lever remains **broader universe** (knob-free, data-gated),
  which attacks the cause (too few real trends in the SP500 post-2020) rather than
  rationing entries into a low-trend-quality tape.

## Reproduce
```
# baselines: dev/backtest/scenarios-2026-06-01-023445/{cell-e-2010-2026-diag,cell-e-2020-2026-fresh-diag}
# flag-on:   Cell E config (= goldens-sp500-historical/sp500-2010-2026.sexp overrides)
#            + one extra override ((neutral_blocks_longs true)); periods 2010-2026 (sp500-2010 PIT)
#            and 2020-2026 (sp500-2020 PIT).
scenario_runner --dir <dir-with-those-2-scenarios> --parallel 2 --no-emit-all-eligible
```
