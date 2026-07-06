---
name: project_early_stage2_window_validated
description: "early_stage2_max_weeks surface {2,4,6,8} broad WF-CV 2026-07-06: REJECT alternatives, default ≤4 empirically VALIDATED; widening = stale-entry admission (bear-fold tax, monotonic); entry-breadth ≠ universe-breadth"
metadata: 
  node_type: memory
  type: project
  originSessionId: a4913a17-4c87-4fe1-a48a-94a54200cdb5
---

**Early-Stage2 admission window VALIDATED at 4 (2026-07-06, ledger
`2026-07-06-early-stage2-window-surface`):** knob #1862
(`screening_config.early_stage2_max_weeks`, default 4), broad top-3000 13×2y
WF-CV, variants {2,6,8} ALL gate-FAIL; no variant beats baseline raw mean
Sharpe (0.597 vs 0.565/0.588/0.405) → no DSR candidate. Rare POSITIVE shape:
probe validated the incumbent book dial (2nd consecutive after volume-1.5×).

**WHYs (transferable):**
1. Widening = STALE-ENTRY admission; damage regime-concentrated + monotonic
   (f011 2022: −0.42 → w6 −0.94 → w8 −1.36). Bull folds gain return (w6 21.6
   vs 19.9) but bear tax dominates risk-adjusted.
2. **Entry-breadth ≠ universe-breadth** — sharpens
   [[project_edge_is_the_fat_tail]]: ask "does the lever add FRESH
   opportunities or STALE entries?" Stale-entry breadth = late-chasing in a
   breadth costume.
3. Tightening (2) starves: weeks-3–4 admissions carry real edge (f000 dot-com
   +5.4→−7.9); freshest-only raises dispersion.

**Forward:** stays 4; axis only for coherent trader/investor PRESET bundles
([[project_capital_mgmt_scale_in_design]] class lessons apply — no standalone
re-sweep; no "w6 + bear gate" grafts). Harness gap: `write_ledger_entry.exe`
doesn't regen index.sexp (hand-append). Ops gotcha: pass TRADING_DATA_DIR via
`docker exec -e` for walk_forward_runner or universe_path resolves wrong.
Writeup: `dev/notes/early-stage2-window-wfcv-2026-07-06.md`.
