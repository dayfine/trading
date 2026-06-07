---
name: project_macro_bearish_trim_lever
description: "Macro-bearish held-exposure trim: BUILT (#1464, default-off) + gridded → REJECT for promotion. cap=0 (full-flat) trades a consistent avoided-loss benefit for a regime-dependent missed-V-recovery cost; net positive ONLY when no sharp V to miss. Not robust across breadth/horizon."
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

**Status: BUILT (#1464, default-off) + GRIDDED → REJECT for promotion (2026-06-07).**
Full writeup: `dev/notes/macro-bearish-trim-grid-2026-06-07.md`.

**Results:**
- SP500 grid: cap=0 looked like a deep Pareto win (918→1234%, DD 37→27%) — but this was
  a no-V window + survivorship inflation (see below).
- **Cap surface is jagged/non-robust** — force-liquidation RESONANCE at intermediate caps:
  0.175 → **70 force-liqs / 64% DD** on BOTH windows (the trim holds just enough residual to
  keep breaching the 60%-DD circuit breaker → liquidate → rebuild → breach). Only cap≈0
  (clean full exit) is internally stable.
- **top-1000 PIT (survivorship-correct): cap=0 NOT robust** — 15y huge win (29.6→730.9%),
  20y return HALVED (228.7→111.2%). Three universes/windows gave three different answers.

**Mechanism (trade-by-trade, definitive):** cap=0 = consistent **avoided-loss benefit**
(cuts the bear-tape stop-loss cohort every window) MINUS a regime-dependent
**missed-V-recovery cost**. Smoking gun (20y): cap=0 went to cash into 2008 correctly but
sat flat through the Mar-2009 V (+37% baseline captured, cap=0 $1.07M→$1.08M) — re-entry is
a fresh Stage-2 breakout, which structurally lags V-bottoms. Net = avoided-loss − missed-V;
positive only when no sharp V exists to miss. Can't know that ex-ante → not a promotable
global default. **Stays default-off as a Variant_matrix axis.**

**Possible faithful refinement (future, not built):** faster re-admission after the macro
gate flips Bullish (shorter cooldown / re-admit names still in Stage-2) to recover the
missed V — keeps the Stage-2 spine. Speculative; would need its own experiment.

See also: [[feedback_large_n_needs_snapshot_mode]] (the breadth runs),
[[project_pit_survivorship_inflation]] (the bigger finding),
[[project_evaluation_methodology_reframe]] (MaxDD misled the read).
