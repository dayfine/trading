# Stage-lifecycle accuracy at major pivots — cross-regime diagnosis

**Date:** 2026-06-03 · **Driver:** user question — "is the trade decision sensitive
to the stage lifecycle (e.g. exposure in late Stage 2)? At pivots like early 2020,
were we buying / shorting / flat, and were the decisions maximizing upside?"

## TL;DR

The stage **lifecycle is fully encoded and computed** (`Stage2 {weeks_advancing;
late}`, etc.), and the `late` flag (MA-slope deceleration — the earliest
top-warning the machinery produces) **fires weeks-to-months before 3 of the last
4 major tops**. But it is consumed **only to gate new entries** — never to trim a
**held** position, scale **sizing**, or drive an **exit**. The strategy's actual
de-risk trigger is the Stage-4 flip, which **lags each top by 5–29 weeks**, by
which point price is already down **5–32%**. We rode every top at full exposure.

## How lifecycle is (and isn't) wired

| concern | lifecycle-aware? | where |
|---|---|---|
| Production entry | **Yes** | `stock_analysis.ml:419` — buy needs `Stage2 {late=false}` AND `weeks_advancing ≤ 4` (fresh breakouts only) |
| Production scoring | **Yes** | `screener_scoring.ml:56` — Stage2 scored only when `weeks_advancing ≤ 4` |
| SPY-only entry | **No** | `spy_only_signals.ml` — matches `Stage2 _`, ignores `late`/`weeks_advancing` |
| Held-position exposure | **No** | `late`'s own contract = *"still hold, no longer a new buy"* |
| Position sizing | **No** | sizing ignores maturity |
| Exit | **No** | only Stage-3/4 roll or trailing stop |

The earliest computed warning (`late`) is thrown away exactly where it would help
most — managing exposure of names already held into a top.

## The 2020 pivot, concretely

- **Long-only** (short disabled in Cell E) → never short, regardless of stage.
- **Production**: still opening *fresh* Stage-2 breakouts through **2020-02-29**
  (SJM, GILD — days before the crash accelerated); individual names broke out even
  as the index topped. Held most positions through March (only 2 exits). The macro
  gate can't help — it fires only once SPY *itself* is Stage 4, weeks into the crash.
- **SPY-only**: fully long into the crash, exited **2020-03-10 @ 284.64** on a
  `gap_down` stop (~15% off the peak), sat flat through the V-recovery, **re-entered
  @ 314.31 — 10% higher than it sold**. Classic slow-MA whipsaw.

## Cross-regime lead-time battery (SPY, `stage_chart` CSV sidecar)

For each top: when did the strategy's Stage-4 exit signal fire vs the price peak,
and did the `late` flag warn earlier?

| pivot | price peak | Stage-4 exit signal | price already | `late=true` warning |
|---|---|---|---|---|
| **2000 dot-com** | 2000-03-24 | +29 wk (2000-10-13) | **−10%** | fired ~8 wk **before** peak ✓ |
| **2008 GFC** | 2007-10-12 | +7 wk (2007-11-30) | −4.9% | fired through Aug-2007 (~10 wk pre-peak) ✓ |
| **2020 COVID** | 2020-02-14 | +5 wk (2020-03-20) | **−31.8%** | fired Aug–Oct 2019 then **RESET** before the blow-off top ✗ |
| **2022 bear** | 2021-12-31 | +8 wk (2022-02-25) | −7.8% | fired through Dec-2021 (~3 wk pre-peak) ✓ |

(Charts: `/tmp/spy_{2000top,2008gfc,2020covid_fix,2022bear_fix}.png`; per-week CSVs
alongside. The 2000 chart shows sporadic orange Stage-3 dots near the top but no
clean call — solid red Stage-4 only well into the decline; MA peaks weeks after price.)

## Verdict — evidence for the mechanic choice

1. **The Stage-4 exit lags badly and uniformly** (5–29 wk, −5% to −32%). It is a
   *confirmation* signal, not a *timing* signal. Any de-risking that waits for it
   gives back a large chunk of every top.
2. **`late` is a real earlier warning in the slow/normal-top majority** (2000,
   2008, 2022) — it would have started de-risking weeks-to-months ahead. It is
   computed every week and currently discarded for held positions. **Wiring `late`
   (and/or `weeks_advancing`, distance-above-MA) into held-position exposure
   trimming / stop-tightening is the highest-leverage, lowest-risk stage-accuracy
   change** — it reuses an existing signal (not a new mechanism), is Weinstein-
   faithful ("late Stage 2 → take partial profits / raise stops"), and directly
   attacks the deep-window 37% drawdown that comes from riding mature names into
   rollovers.
3. **Fast blow-off crashes (2020) defeat any weekly signal.** `late` reset into the
   Feb-2020 acceleration; only the daily `gap_down` stop caught it (and still −15%).
   A `late`-exposure mechanism must be paired with — not a replacement for — a fast
   daily/volatility guard for the rare vertical crash.

## Recommended next step

Implement a **default-off `late`-driven held-exposure dial**: on `Stage2
{late=true}` (or `weeks_advancing` beyond a threshold), trim the position toward a
configurable fraction and/or tighten the trailing stop, instead of holding full
size to the Stage-4 roll. Test:
- **Visually** via `stage_chart` (does it de-risk in the orange/late zone?).
- **Quantitatively** via the per-symbol autopsy harness (missed-gain / given-back
  buckets) AND a deep + bull backtest (does it cut the 37% / 17.5% DD without
  killing the 918% / 237% return?).
- Promote only through the confirmation grid (`.claude/rules/promotion-confirmation.md`).

## Tooling note

`stage_chart` now emits a per-week CSV sidecar (`<out>.png.csv`:
`week,date,close,ma,stage,weeks_in_stage,late`) so the invisible Stage-2 `late`
sub-flag and stage maturity are inspectable, not just the four-colour chart.
