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
