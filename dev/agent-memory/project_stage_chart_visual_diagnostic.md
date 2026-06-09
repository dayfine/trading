---
name: project_stage_chart_visual_diagnostic
description: "stage_chart tool renders a symbol's weekly close colored by programmatic Weinstein stage (owl-plplot PNG I can view) — visually validates the classifier; first finding = false Stage-3 while price still above MA → fix is price-action confirmation not weeks-hysteresis"
metadata: 
  node_type: memory
  type: project
  originSessionId: d9a90d10-0707-469f-8918-2f1f994527cf
---

I CAN render and view charts in this repo: `owl-plplot` is installed (it made the
pre-existing `segmentation.png`). Built `analysis/scripts/stage_chart/bin/stage_chart.exe
<SYM> <START> <END> <DATA_DIR> <OUT.png>` — renders a symbol's weekly close **colored by
its rolling programmatic `Stage.classify` stage** (blue=S1 green=S2 orange=S3 red=S4) over
the 30w MA, to a PNG I then Read visually. (Gotcha: the classifier's MA is on
**adjusted_close**; plot the dots on adjusted_close too or they sit ~30% above the MA.
macOS has no gnuplot/imagemagick and Python is banned — owl-plplot is the renderer.)

**Purpose:** compare the programmatic stage classification to an empirical/visual
Weinstein read, to diagnose the Stage-4-exit whipsaw / late-reentry the autopsy flagged.

**First finding (SPY 2005-2010, n=1):** the chart **visually confirms the autopsy** — the
classifier sprinkles **false Stage-3 ("topping") flags mid-advance while price is still
clearly above a RISING MA** (the `stage3_false_positive` mode), and mis-reads a 2008
bear-rally as Stage 2 (a buy mid-GFC). KEY REDIRECT: because the false Stage-3 flips happen
*while price is still above the MA*, the principled fix is **price-action confirmation —
don't call Stage 3 until price actually crosses below the MA**, NOT the weeks-based
hysteresis that walk-forward CV already rejected (`project_stage3_hysteresis_rejected_wfcv`).
Calibrating to the chart (visual ground truth) sidesteps the return-overfit that killed the
blind tuning — the whole point of using charts.

This is a less-overfittable revival of the rejected exit-timing fix. Next: scan more
symbols/eras to confirm the pattern generalizes, then implement a default-off
price-below-MA confirmation gate on the Stage-2→3 transition. See
`next-session-priorities-2026-06-03.md` P2. Related: [[project_sector_rotation_layer_attribution]].

---
**WF-CV outcome (2026-06-09, top-3000 2x2, #1500):** the chart-derived refinements
went to walk-forward CV. **`enable_stage2_ma_hold` REJECTED** — it collapses the
chart oscillation visually (KO 2010-13 -> one S2x160) but DEGRADES the strategy
(Sharpe 0.643->0.486, off-frontier). **Visual stage-coherence != better returns.**
**`enable_stage3_force_exit=false` INCONCLUSIVE-POSITIVE** — deferring exits to the
trailing stop is the SOLE Pareto-frontier cell (Sharpe 0.679/Calmar 1.631/DSR
0.9977 vs baseline 0.643/1.382/0.9964); confirms the S3 force-exit adds whipsaw
(likely why the 6 S3-exit dials were rejected). First net-positive broad-universe
mechanism change, and it's a REMOVAL. Modest/concentrated edge (1/15 fold-wins) ->
needs a confirmation grid before promotion. Note: stage-2x2-2026-06-09.

---
**Confirmation grid -> REJECT for promotion (2026-06-09).** Ran the on/off surface
across 3 cells: A=top-3000 2011-26 (the source surface), B=sp500-510 deep 2000-10
(dot-com+GFC, CSV mode), C=top-1000 2011-26 (same period, narrower breadth).
**force_exit_off wins only 1/3 cells** (needs >=2/3): A it dominates but on ~1/15
folds; **B it is a complete NO-OP** (bit-identical across all 11 folds — the S3
force-exit never fires differently in a bear-heavy regime, trailing stop + macro
gate exit first); **C it REVERSES** (Sharpe 0.394<0.418, DSR 0.9268<0.9378, 0/15
wins, only 2/15 folds differ). The Cell-A win is top-3000-breadth-specific +
fat-tail-concentrated — same breadth-reversal signature as
[[project_laggard_broad_recheck]]. **`enable_stage3_force_exit` stays DEFAULT-ON**;
force_exit_off remains a default-off axis (never *badly* dominated — on the
frontier in all 3 — but not grid-robust). The 2x2's "first net-positive broad
change" headline was a single-surface artifact. Ledger:
2026-06-09-stage3-force-exit-off-confirmation-grid (Reject). Note:
stage3-force-exit-grid-2026-06-09.
