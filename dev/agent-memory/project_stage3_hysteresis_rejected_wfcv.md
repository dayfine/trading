---
name: project_stage3_hysteresis_rejected_wfcv
description: Stage3 hysteresis knob (h=2 + exit_margin=0.02) rejected by 30-fold walk-forward CV; autopsy is a labeller not a knob-recommender
metadata: 
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

Stage3 hysteresis change `(hysteresis_weeks=2, stage3_exit_margin_pct=0.02)`
— recommended by the trade-autopsy tool (#1360) — is REJECTED as a
production default. Two-stage evidence (2026-05-29):

1. **2-panel** (#1364 note `stage3-hysteresis-panel-rejected-2026-05-29.md`):
   5y `sp500-2019-2023` improved (Sharpe 0.56→0.61), 15y `sp500-2010-2026`
   regressed hard (Sharpe 0.78→0.62, return 341%→228%). Single-window overfit.
2. **30-fold walk-forward CV** (#1366 note `stage3-hysteresis-walkforward-cv-2026-05-29.md`):
   variant loses on every aggregate axis (Sharpe μ 0.519 vs 0.540 baseline;
   Calmar 1.185 vs 1.249), wins only 4/31 folds on Sharpe (gate needs 17/30).
   Decisive NO-GO. Identical to baseline on 19/31 folds (knob only bites on
   a Stage 2→3→2 whipsaw).

**Why:** same single-window-overfit signature as [[project_continuation_combined_rejected]]
— wins on a 5y window, loses long-horizon. Per [[feedback_strategy_mechanic_changes_too_explorative]].

**How to apply:** PR-A code plumbing (#1362) stays on main with knob
defaults that preserve panel behavior (`hysteresis_weeks=2` default but
panels override to 1; `stage3_exit_margin_pct=0.0`). Do NOT flip the
production default. The trade-autopsy tool is a useful failure-mode
*labeller* but NOT a reliable knob-recommendation engine — its
suggestions must pass walk-forward CV before adoption. The
`walk_forward_runner.exe` + spec fixture (#1365) is now the preferred
go/no-go method for this class of knob decision.

Minor open bug: WF spec fixtures need `gate.n` to match the fold-schedule
count exactly (off-by-one → gate computes SKIPPED instead of NO-GO; the
30-fold spec declared n=30 but yields 31 folds `fold-000`..`fold-030`).
