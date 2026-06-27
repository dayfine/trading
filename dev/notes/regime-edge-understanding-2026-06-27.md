# Regime-edge understanding + options menu — 2026-06-27

**Mode:** understanding-first (per `next-session-priorities-2026-06-27.md`). This
is **analysis + an options menu, NOT a build**. No config flag, no WF-CV, no
goldens change here. Every number below is computed from the **committed**
long-only deep run; nothing was re-run.

**Data of record (all committed, no warehouse needed):**
- Long-only deep equity/trades/audit/macro:
  `dev/backtest/scenarios-2026-06-27-034110/sr-broad-top3000-1998-longonly/`
  (broad top-3000 PIT-1998, 1998-2026, Cell-E **0.14** concentration,
  `min_cash 0.30`, `max_long_exposure 0.70`, stage3-force-exit on, laggard on).
- SPY dividend-adjusted: `data/S/Y/SPY/data.csv` (`adjusted_close`).
- Headlines: `dev/backtest/DEEP_RESULTS.md`.

**Scope caveat carried from DEEP_RESULTS:** broad-universe absolutes are
MTM-heavy on a few fat-tail names; the honest read is *relative to SPY over the
same window*. This note works entirely in **per-year LO − SPY** terms, which is
the relative frame, so the MTM-inflation caveat bites less here — but the
absolute LO total (+721%) is still below same-window SPY (+1089% div-adj).

---

## Thread A — characterize the regime edge (the linchpin)

### A.0 The full per-year table (extends the doc's highlight rows to all 28 years)

Per-year LO return vs SPY div-adjusted return; "edge" = LO − SPY (pp). Trade
column keyed by **exit** year: stop% = share of exits that were `stop_loss`,
win% = share of round-trips with pnl>0, avgpnl% = mean realized pnl per trade.

```
year   LO%    SPY%    edge   | exits stop% win% avgdays avgpnl%
1999  +47.5  +20.4  +27.1   |  36   53   39    61    -1.2
2000  +26.3   -9.7  +36.0   |  34   82   38    76   +34.9   <- bear, big win
2001   +6.3  -11.8  +18.0   |  11   55   45   117   +10.1   <- bear
2002   -3.1  -21.6  +18.5   |  17  100   12    51    -1.4   <- bear
2003  +14.1  +28.2  -14.1   |  32   69   50    44    +0.4   <- overstay (recovery)
2004  +29.3  +10.7  +18.6   |  39   67   41    54    +4.1   <- post-bear dawn win
2005  -11.3   +4.8  -16.2   |  65   62   26    46    +0.4
2006   +6.6  +15.8   -9.3   |  62   76   27    38    +0.1
2007  +13.7   +5.1   +8.5   |  54   63   39    42    +2.1
2008  -11.6  -36.8  +25.2   |  30   87   17    33    -2.1   <- bear, big win
2009  +42.9  +26.4  +16.5   |  30   70   50    43    +5.5   <- post-bear dawn win
2010   -8.7  +15.1  -23.8   |  51   65   39    45    +1.3   <- mature-bull lag
2011   +2.0   +1.9   +0.1   |  31   48   32    67    +4.6
2012   +1.5  +16.0  -14.5   |  52   62   40    35    -1.0
2013  +39.6  +32.3   +7.3   |  43   49   56    68    +4.4
2014   +6.7  +13.5   -6.8   |  46   67   48    66    +3.9
2015  +11.3   +1.2  +10.1   |  43   72   19    53    +2.0
2016  -14.8  +12.0  -26.8   |  46   54   28    52    +3.4   <- mature-bull lag
2017  +10.2  +21.7  -11.5   |  55   56   40    51    +2.1
2018   +1.8   -4.6   +6.3   |  60   72   32    52    +2.6   <- mild bear, small win
2019  +15.0  +31.2  -16.2   |  68   68   40    40    +0.8
2020  +21.3  +18.3   +3.0   |  63   76   35    31    +0.8
2021  +13.7  +28.7  -15.0   |  54   61   35    53    +9.4
2022   +2.4  -18.2  +20.6   |  34   76   26    54    -0.5   <- bear, big win
2023   -1.5  +26.2  -27.7   |  59   76   27    39    +0.8   <- mature-bull lag
2024  -18.7  +24.9  -43.6   |  79   66   37   118    +1.1   <- worst lag
2025   -0.1  +17.7  -17.8   |  61   77   23    28    -2.7
2026   -3.2   +9.7  -12.9   |  17   88   35    31    +1.8   (partial, to Apr)
```

### A.1 Why does the strategy lose in bulls? (mechanism decomposition)

The bull-lag is **under-participation, not losses**. In the worst lag years the
average trade was still *positive or flat* while SPY ran double digits:
2024 avgpnl +1.1% vs SPY +24.9%; 2023 +0.8 vs +26.2; 2016 +3.4 vs +12.0;
2010 +1.3 vs +15.1. The strategy isn't bleeding in melt-ups — it simply fails to
keep pace. Three reinforcing causes, in order of how confidently the committed
data pins them:

1. **Structural cash/exposure cap (config-forced, regime-independent).**
   `min_cash 0.30` + `max_long_exposure 0.70` mean **≤70% of NAV is ever in
   equities**. In a +25% SPY year the idle ≥30% alone costs ≈ **7.5pp** of
   relative return *before any selection effect*. This is the single most
   confident, quantifiable bull-lag mechanism and it is present every bull year.
   (Note: per-day cash series is **not** in the committed artifacts — only
   `portfolio_value`. The 7.5pp is the floor implied by the config, not a
   measured average cash %. Measuring the realized average cash drag needs a
   re-run that emits a cash series — see "harness gap" below.)

2. **Whipsaw churn (stops dominate exits).** Overall exit mix: **876 stop_loss
   (68%)**, 386 laggard_rotation (30%), 16 stage3_force_exit. In lag years
   stop% sits 54-77%. The strategy repeatedly enters breakouts that chop out and
   re-cycles capital (avgpnl ≈ 0-3% per trade) instead of riding a position. This
   is the let-the-stop-do-its-job tax in a choppy-but-rising tape — consistent
   with `project_weekly_close_stop_lever` (intraday stop forgoes more upside than
   disaster it dodges) and `project_edge_is_the_fat_tail` (stops are premium paid).

3. **Breakout-with-stop caps per-position upside vs buy-and-hold.** Even in won
   years the avg winning trade is bounded by the discipline; you don't get SPY's
   full compounding on the names you do hold because you rotate/stop out.

**Verdict for A.1:** the bull-lag is *primarily structural* (cash cap #1 +
whipsaw #2), not a fixable "bad picks" problem. This is the same dead-end flagged
by `project_accuracy_is_unreachable_diversify_instead` — the answer is a
diversifying *layer* (the barbell), not entry/exit tuning.

### A.2 Is the bear-edge broad or 2008-dependent? → **BROAD.**

Bear years (SPY div-adj < 0), edge = LO − SPY:

```
2000 +36.0 | 2001 +18.0 | 2002 +18.5 | 2008 +25.2 | 2018 +6.3 | 2022 +20.6
n=6, mean edge = +20.8pp, ALL SIX POSITIVE
```

Every single down-SPY year the strategy outperformed — including the *mild,
non-GFC* bears (2018 −4.6% SPY → +6.3pp edge). So the **sign** of the bear-edge
is universal across the four distinct bear types in-sample (rolling top 2000-02,
GFC 2008, fast crash 2018, slow grind 2022). The doc's worry that it's
"2008/dot-com-dependent" is **refuted for sign**.

The **magnitude**, however, scales with bear depth: deep bears 2000/2008/2022
give +20-36pp, the shallow 2018 gives +6.3pp. The edge ≈ "how much of the index
decline the strategy sidesteps by being in cash/stage-4-exited," so a bigger
decline mechanically produces a bigger relative edge. Caveat: this is the **broad
top-3000** universe only. The doc asked for an sp500-515 re-derivation as an
independent check — **not done** (would need a CSV-mode long-only sp500 run; the
committed sp500 scenarios are long-short only). The broad-universe answer is
strong enough to treat "bear-edge is broad" as the working understanding, pending
that confirm.

### A.2b Bull-year structure is bimodal (a refinement the doc didn't have)

Bull years (n=22) mean edge = **−7.5pp**, but it is **not** "loses in all bulls":
- **WINS** at post-bear dawns / early recoveries: 1999 +27, 2004 +19, 2009 +16,
  2013 +7, 2015 +10, 2020 +3 — fresh Stage-2 breakouts en masse after a washout.
- **LOSES** in sustained/mature melt-ups: 2010 −24, 2012 −15, 2016 −27, 2017 −12,
  2019 −16, 2021 −15, 2023 −28, 2024 −44, 2025 −18.

So the regime axis isn't binary bull/bear — it's closer to **{bear, recovery,
mature-bull}**, where the strategy wins the first two and lags the third.

### A.0/A.2 quantified: edge is regime-conditional

`corr(LO−SPY , SPY return)` across 28 years = **r = −0.589**. Lower SPY return →
higher strategy relative edge. This is the statistical statement of "the edge is
regime-conditional," and it's the precondition for *any* macro-allocation idea.

### A.3 Real-time regime detectability — the strategy already has a detector

The strategy contains an **endogenous** regime signal: its own macro gate
(`macro_trend.sexp`, weekly Bearish/Neutral/Bullish from index-stage + A-D +
momentum + NH-NL + global). Per-year share of weeks it flagged **Bearish**:

```
deep bears   : 2001 96%  2002 92%  2008 92%          <- nails deep bears
mild/fast/slow bears: 2000 39%  2018 12%  2022 41%   <- MISSES fast/mild, partial on slow
clean melt-ups: 2017 0%  2020 0%  2021 0%  2023 0%  2024 0%  <- correctly quiet
false-positive chop: 1998 51%  2011 61%  2015 41%    <- over-cautious in flat years
```

Reading:
- The endogenous gate is a **good deep-bear detector** and is **correctly silent
  in clean melt-ups** (so the melt-up lag in A.1 is *not* the macro gate
  over-blocking — it's the cash cap + whipsaw).
- It **misses fast/mild bears** (2018 Q4 crash too quick for a weekly signal;
  2022 slow grind only half-caught) and **false-positives in flat chop**
  (1998/2011/2015), where being defensive cost relative return.
- The doc's barbell uses a **different, coarser** detector — the *annual* SPY
  30-week-MA state at last year-end. That lag explains its known error-cells:
  overstay into recoveries (2003/2019/2023 — the endogenous gate is actually
  *quiet* those years, 0-32%, so the annual-MA lag, not the strategy, causes the
  overstay) and missed first bear year (2000/2022 — where the endogenous gate is
  *also* weak, 39%/41%).

**Detectability ceiling:** deep bears are highly detectable by *either* signal
(huge, slow, broad). Fast/mild bears (2018) and regime *turns* (2000, 2022 onset;
2003/2009 recovery) are the hard, low-detectability cells for both signals — and
those are exactly the barbell's error cells. No real-time signal in hand
cleanly catches them.

---

## Options menu — macro-regime allocation (for review; NOT a committed build)

The barbell hypothesis = blend "the Weinstein strategy" with "SPY/cash" by a
real-time regime signal. The design space, with what the analysis above implies:

| Axis | Options | What A-thread evidence says |
|---|---|---|
| **Bull leg** | (a) SPY, (b) long-only strategy, (c) cash | (a) SPY — the lag is structural under-participation, and "regime-gating to cash is dead" (`project_next_lever_decision_grading`). Bull leg = SPY is what makes the barbell coherent. |
| **Bear leg** | (a) strategy long-only, (b) cash/short | (a) strategy — it actively *wins* +20.8pp avg in bears, beats cash. |
| **Switch signal** | (a) annual SPY 30wk-MA (doc), (b) monthly/weekly SPY MA, (c) endogenous macro gate / cash level, (d) A-D breadth | Deep bears detectable by all; turns + fast bears by none cleanly. (c) is already real-time and faithful (it's in the spine). (a) is coarse/laggy. A *monthly* MA likely dominates annual on the overstay cells. |
| **Switch cadence** | annual / monthly / weekly | Annual overstays a full recovery year (2003/2019/2023 = −14 to −28pp cost). Finer cadence trades overstay-cost for whipsaw-cost. |
| **Allocation** | binary switch / continuous tilt by signal strength | Continuous (e.g. equity weight ∝ breadth) avoids the all-or-nothing turn error; harder to validate. |

**Three-regime refinement (from A.2b):** the cleanest framing may be
**{mature-bull → SPY, recovery → strategy, bear → strategy(+maybe short)}** —
i.e. the strategy runs through the *whole* bear-to-recovery arc and only hands
off to SPY once a bull is *established*. A simple binary bull/bear switch loses
the recovery wins (2009/2004) if it flips back to SPY too eagerly.

**Promotion bar (unchanged, when/if this graduates):** any such mechanism is
default-off → WF-CV → **macro-diverse confirmation grid** that *must* include a
deep window spanning 2000-02 + 2008 (`promotion-confirmation.md`). The whole edge
lives in the bears, so a grid that never sees a bear can only certify a bull
artifact. The +1295% barbell number is **one path**, not a result.

---

## Thread B — decision quality (where is alpha lost?)

### B.1 MFE/MAE harness gap — **RESOLVED in this run.** ✅
`trade_audit.sexp` populates **`max_favorable_excursion_pct`** and
**`max_adverse_excursion_pct`** on all **1288** records with real nonzero spread.
Consistent with `project_harvest_rotate_rejected` (already records the fix as
RESOLVED 2026-06-12 via #1525/#1528) — give-back / left-on-table analysis is
unblocked here.

### B.2 Missed/late/early + scoring near-misses — **partially blocked.**
- Give-back analysis (MFE − realized) needs a **join** of audit records to
  trades; the two files are in *different orders* (trades.csv sorted by symbol
  desc, audit ascending), so an index-pair hack is unsafe. Proper analysis wants
  a small join exe keyed by `position_id` — a harness task, not a hack.
- Cash-rejected near-miss scoring (B.3 in the doc) needs the **rejected-fill**
  log, which is *not* in the committed artifacts (the run wasn't launched with a
  rejection emitter). Needs a re-run.
- **Directional read available now:** A.1 already shows the bull-lag is
  structural (cash cap + whipsaw), and `project_accuracy_is_unreachable...` +
  `project_cascade_selection_inversion` already establish entry-selection is a
  dead lever. So the working answer to the doc's Thread-B question — *"is
  decision-timing a real lever or is regime-allocation the only one?"* — leans
  **regime-allocation is the lever; entry/exit timing is largely structural and
  not separately tunable.** Confirming via give-back/near-miss is a nice-to-have,
  not a blocker.

---

## Thread C — short leg under the regime lens — **BLOCKED (needs a run).**
The open precondition is "does the short leg pay specifically in bears?" Answering
it needs short **trade-level** records by year. The committed long-short artifacts
are **summary `.sexp` only** (no per-trade trades.csv), so a regime decomposition
of short P&L can't be done from committed data. Requires re-running the
liquidity-armed long-short with trades.csv emitted, then keying short-side pnl by
exit year against the A.0 bear/bull split. *Until then, Thread C is unanswerable.*
Note the long-only↔armed-long-short convergence (+721% ≈ +774%, DEEP_RESULTS)
already says the short leg adds ~nothing *on net across the full window*; the only
live question is whether it's net-positive *in bears specifically* (which the
barbell would exploit) — worth one run, low priority.

---

## Thread D — operational/docs (concrete, unblocked, not done here)
- **#7 margin-safety doc** — pure docs, ready to write whenever greenlit
  (`docs/design/margin-safety.md` + README summary). Not started; out of scope
  for this understanding pass.
- **#6 PIT-vs-live liquidity consistency audit** — read-only audit of
  `analysis/data/universe/` vs the overlay's `min_entry_dollar_adv`. Not started.

---

## Bottom line (one paragraph)
The strategy's edge is **regime-conditional and structural, not a selection
skill**: it beats SPY in *every* down year (mean +20.8pp, broad across all four
bear types) and in post-bear recoveries, and lags in *mature melt-ups* purely by
**under-participating** (≤70% equity cap + 68%-stop whipsaw), not by losing money
(corr(edge, SPY) = −0.59). A macro-barbell that runs the strategy through
bears+recoveries and holds SPY in established bulls is the **coherent** option,
because it targets the structural lag with a diversifying layer rather than the
dead-end of entry tuning. The binding uncertainty is **real-time regime
detection at turns and fast/mild bears** — the hardest cells for both the
endogenous macro gate and any SPY-MA signal — which is what a confirmation grid
must stress, not the deep bears (already easy). This remains a **direction to
validate**, not a result: next step is the user's call on which switch
signal/cadence to take into the default-off → WF-CV → bear-inclusive grid pipeline.
```
