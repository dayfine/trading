# Next-session priorities — 2026-06-13

**Supersedes** `next-session-priorities-2026-06-12.md`. Check main CI green
before dispatching.

## Done in the 2026-06-12 overnight window (12h autonomous, user's 4-task brief)

1. **Trade-level forensics, both regimes** —
   `dev/experiments/trade-forensics-2026-06-12/ANALYSIS.md` (#1548). Headlines:
   laggard_rotation is the de-facto profit channel (+$11.0M bull) vs stops the
   loss-eater (−$7.0M); the two NET TO ZERO in the bear decade; top-5 trades =
   165% of realized P&L; AXTI ≈ 100% of terminal bull NAV; entry-type edge
   REGIME-FLIPS (early-Stage2 +34.6%/trade post-2011, −1.9% in 2000-11);
   give-back measured for the first time (laggard exits 30pp, MFE>20% cohort
   82pp); macro-gate protection = entry suppression (n=8 in 2002, n=11 in 2008).
2. **Changeable-vs-structural synthesis** —
   `dev/notes/changeable-vs-structural-2026-06-12.md` (#1548): 6 structural
   facts to stop re-testing (skewness tax, concentration-is-the-return,
   give-back-as-COGS, gap risk, regime-dependence, compression-is-the-product)
   + 6 actionable levers with priors + the operating thesis.
3. **Process fixes from the forensics, all merged:**
   - **#1546** (orchestrator, parallel): A1 min-window guard for the matrix +
     MaxDD>100% investigation (verdict: real negative-NAV math, not a layer
     bug; root in stale cash-floor — handed to portfolio owners).
   - **#1549**: A2 ROOT CAUSE — **the strategy trades during the 210-day
     warmup**; the 2009-06-26 fold's warmup spans the GFC bottom → portfolio
     depleted to 35% before measurement; in-window curve frozen,
     round-trips unpairable. Fix: additive `Backtest.Fold_health` guard
     (3 degenerate signatures, config thresholds, loud stderr +
     `fold_health.sexp`); G1 fixed at root (`Fill_date_stamp` re-stamps fills
     with simulated date — open_positions entry_date was wall-clock); G2
     explained (same warmup-leak class: warmup-entered positions split
     accounting between trades.csv and the audit).
4. **Long-short margin research** —
   `dev/notes/long-short-margin-mechanics-2026-06-12.md` (#1548): FINRA 4210
   tiers verbatim, Reg-T 150% initial, Schwab/IBKR house layers + portfolio
   margin, borrow/rebate/dividend carry, and a backtest margin-model spec.
   Key actionable: **sub-$17 shorts are uneconomic** (83-362% maintenance) —
   and forensics G5 found the Cell-E "long" baseline DOES trade shorts
   (net-negative, margin-free, incl. an unstopped THM zombie at −240%).

## P0 — Act on the warmup-trading discovery (the deepest finding)

A2's root cause is bigger than one fold: **every backtest trades for 210 days
before its measurement window and inherits the resulting portfolio.** Decide
the intended semantics — (a) warmup = indicators only, no trading (likely the
design intent; needs a config flag + comparison run to quantify how every
baseline shifts), or (b) warmup trading is intentional "running start" (then
in-window metrics must segregate inherited positions honestly). Either way:
test the flag as a surface (experiment-flag-discipline), expect EVERY pinned
baseline to move if (a) wins, and re-pin goldens behind the flag. This blocks
the definitive matrix re-run (the matrices' per-start rows all carry warmup
inheritance).

## P1 — Short-side hygiene (cheap, high-confidence)

Default-off flag to disable Stage4-breakdown short entries in long presets
(forensics: net-negative + margin-unrealistic), or gate shorts on price ≥ $17 +
margin-aware sizing per the margin spec §4. Then the long-short track can build
the real margin model on the researched formulas.

## P2 — Definitive matrix + policy universe (carried)

After P0's flag decision: emit composition-policy universe artifact
($-volume now wired, #1542), rebuild warehouses if needed, re-run both matrices
(now with min-window guard + fold-health + honest warmup semantics).
Candidate axis from forensics: laggard-rotation trigger latency (rs_neg_weeks)
— laggard-touching, eligible; skeptical prior.

## Carried

Weekly >1%-ADV screener gate (weinstein-side); factor-decomposition lens
(named gap in `project_index_beating_structural_bar`); trade-forensics LOW
items (post-exit capture, auto-stage_chart).

## Key references

`project_trade_forensics_2026_06_12`, `project_rolling_start_matrix_first_run`,
`project_index_beating_structural_bar`, `dev/notes/changeable-vs-structural-2026-06-12.md`,
fold_health.mli (the three degenerate signatures), PR #1549 body (warmup-leak
mechanics).
