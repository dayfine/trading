---
name: project_macro_bearish_trim_lever
description: "The deep-window drawdown lever is bearish-macro-driven HELD-exposure reduction (not the rejected per-stock late-dial, not reaction speed). Macro gate fires early on slow tops but only blocks entries. Scoped experiment, default-off, awaits build+grid."
metadata: 
  node_type: memory
  type: project
  originSessionId: aa2adf7e-e475-44dd-8bb7-1dc413997573
---

The 2026-06-06 crash autopsy (after the late-Stage2 stop-tighten dial REJECT,
[[project_stage_late_flag_discarded]]) found the **real** deep-window drawdown lever.

**Two settled facts:**
1. **Reaction speed is NOT the problem.** Production runs `stop_update_cadence = Daily`
   (`weinstein_strategy_config.ml:113`): stops re-evaluate daily and trigger every day
   against the bar's intraday low (fill at low). The Friday/weekly cadence governs only
   entries + macro re-eval + stage reclassification — never stops. DD is structural: the
   Weinstein stop sits below the base by design (ride-down) + gap-fill on vertical days.
2. **Slow tops are callable; vertical shocks are not.** Macro-gate (breadth/AD) timing
   from `dev/backtest/scenarios-2026-06-02-145506/production-deep/macro_trend.sexp`:
   2008 GFC → **Bearish from Jan-2008, ~10mo before** the Sep-Oct waterfall; 2000 dot-com
   → Bearish around/before the Mar-2000 top; **2020 COVID → never Bearish pre-crash**
   (Bullish through −13%, Neutral only 3wks in) = uncallable vertical shock. Both 2000/2008
   gates whipsaw (false Bullish in bear rallies).

**The gap / lever:** `weinstein_strategy_macro.ml` uses Bearish macro to BLOCK ENTRIES only;
held longs exit just via their own stops / Stage-4 / reactive 60%-DD force-liquidation. So
in 2008 we stopped buying in January but rode existing longs down all year. The lever =
**bearish-macro-driven HELD-exposure trim** (cap long exposure tighter when macro Bearish,
sell weakest-RS first; re-entry stays gated by the Stage-2 screen = anti-whipsaw). It keys
on the index/breadth level (fires early + persists on 2000/2008 = bulk of deep MaxDD), NOT
the per-stock `late` flag (reset by fast crashes). Cannot help 2020 — nothing can but the
daily stop. Weinstein-faithful (book §Macro/§Stage4 "raise cash when the tape turns";
spine item #6 extended from block-buys to raise-cash).

**Status: SCOPED, not built.** Plan: `dev/plans/macro-bearish-exposure-trim-2026-06-06.md`
(#1461). Default-off config (`enable_macro_bearish_exposure_trim` +
`macro_bearish_max_long_exposure_pct`), model on `force_liquidation`, axis
`{0.0,0.175,0.35,0.525}`, deep+bull confirmation grid. **Honest prediction: WILL move DD
(unlike the late-dial which moved nothing), but at a return cost (whipsaw + missed rebound)
— could still REJECT; the grid prices the DD-vs-return trade.** Build = strategy-core →
TDD + 3-gate QC → dispatch feat-weinstein, then dispatcher runs the grid.
