# `fast_v_min_rate_pct` threshold SURFACE WF-CV — FINDINGS (2026-06-22)

The arming-speed WF-CV (`dev/backtest/arming-speed-wfcv-2026-06-22/`) found
`fast_v_arm_on_rate_alone=true` wins the fast-V crashes (2020, 2018-Q4) but
**whipsaws** choppy corrections (2010, 2011). Hypothesis: raise the arming RATE
threshold so moderate dips no longer arm `Fast_v` (kill the whipsaw) **while
keeping** the genuine crash catch (the V-crashes are steeper). This surface tests
that — enabled by #1716 exposing `fast_v_min_rate_pct` as an axis.

- **Spec:** `test_data/walk_forward/fast-v-min-rate-surface-2000-2026.sexp`.
- **Base:** `sp500-2000-2026-catstop-armon` (deep long-only, catastrophic_stop_pct
  =0.10, **fast_v_arm_on_rate_alone=true**). Axis `fast_v_min_rate_pct ∈ {0.08,
  0.12, 0.16}`. Rolling 2000-2026, 26 folds.

## Result — the default 0.08 is Pareto-optimal; raising the threshold HURTS

| `fast_v_min_rate_pct` | Sharpe | Calmar | MaxDD % | Pareto |
|---|---|---|---|---|
| 0.08 (default) | **0.699** | **1.348** | **10.60** | **yes** |
| 0.12 | 0.666 | 1.332 | 11.06 | no (dominated) |
| 0.16 | 0.664 | 1.331 | 11.10 | no (dominated) |

Higher thresholds are strictly dominated. **Tuning does not help — 0.08 (the
existing default) is already optimal.**

## Per-fold — the whipsaw and the catch are COUPLED (the key finding)

| fold | regime | 0.08 | 0.12 / 0.16 | effect of raising |
|---|---|---|---|---|
| fold-010 | 2010 chop | 11.35% | **12.12%** | whipsaw SUPPRESSED ✓ |
| fold-011 | 2011 Euro chop | −9.80% | **−8.61%** | whipsaw SUPPRESSED ✓ |
| fold-018 | 2018-Q4 sharp correction | 9.84% | **8.62%** | catch LOST ✗ |
| fold-020 | 2020 COVID fast-V | 9.96% | **6.93%** | catch LOST ✗ (reverts to gap-down) |

Raising the threshold does exactly what we hoped on the whipsaw folds (2010/2011
improve) — **but it kills the crash catches** (2018-Q4 and 2020 revert to the
un-armed gap-down outcome), and the catches are worth more than the whipsaw costs.
Net: worse.

## The transferable WHY (load-bearing)

**The whipsaw and the catch ride the SAME signal, so a single threshold cannot
separate them.** Both are "the 4-week rate-of-decline crossed a bar." Arming
*early* (low threshold) is what catches the 2020-V before its gap-down — and it is
*also* what fires on a sharp-but-recovering 2010/2011 dip. Raising the bar delays
arming uniformly: it skips the false-positive dips **and** arrives too late for the
real crash (by the time a 2020 4-week rate exceeds 16%, the gap-down has already
happened, so you get the un-armed outcome). **Catch-speed and whipsaw-immunity are
the same dial pulled in opposite directions.** No value of `fast_v_min_rate_pct`
gives both.

To separate "crash that keeps falling" from "sharp dip that recovers" you need a
signal *other than* the rate magnitude — the **Advance-Decline breadth lead**
(`Decline_character`'s A-D leg, currently inert at `~ad_bars:[]`; **Build 0**). In
a genuine distribution top the A-D line rolls over *before* price; a recovering
dip has no such breadth lead. That is precisely the leg the classifier was
designed around but cannot use until Build 0 wires real A-D data. **This surface is
the concrete evidence that Build 0 is the unlock for separating the arming-speed
catch from its whipsaw.**

## Verdict: NO TUNING GAIN — keep default 0.08; arming-speed value is fixed-small

- `fast_v_min_rate_pct` tuning is **rejected** as an improvement lever — 0.08 is
  Pareto-optimal; the knob's catch/whipsaw tradeoff is structural, not tunable.
- `fast_v_arm_on_rate_alone=true` at 0.08 stays a **weak default-off ACCEPT**
  (frontier-dominant but small, per the arming-speed WF-CV) — unchanged by this
  surface. No promotion.
- **The real next lever for arming-speed is Build 0** (A-D wiring), not threshold
  tuning. Recorded so a future session does not re-attempt the threshold sweep.

Recorded: `dev/experiments/_ledger/2026-06-22-fast-v-min-rate-surface.sexp`.

## Caveats
- Long-only base, single `catastrophic_stop_pct=0.10`, static sp500-as-of-2000.
  The catch/whipsaw coupling is a property of the rate signal, robust to these.
- Evidence: `walk_forward_report.md` + `ranking.md`. Deep `data/` gitignored.
