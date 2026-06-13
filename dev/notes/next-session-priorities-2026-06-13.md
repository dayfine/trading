# Next-session priorities — 2026-06-13

**Supersedes** `next-session-priorities-2026-06-12-PM.md`. Check main CI green
before dispatching.

## Done in the 2026-06-13 overnight window (autonomous)

1. **P0 RESOLVED — warmup-trading semantics.** The 06-12-PM P0 asked whether to
   suppress warmup trading (warmup = indicators only). **Answer: NO — keep
   `suppress_warmup_trading` default-off.** WF-CV (22 folds 2002-2024, top-1000,
   #1561) shows suppress FAILS the gate (9/22 Sharpe wins; baseline Sharpe 0.372
   vs suppress 0.252). Warmup-trading is a **net-beneficial "running start"**,
   not the bug #1549 assumed — the GFC-warmup depletion is the *tail cost* of an
   always-invested behavior that helps far more bull folds than the rare crash
   folds it hurts. The flag stays a searchable axis. The #1549 degenerate fold is
   correctly handled by the `Fold_health` guard (detect, not suppress). Full
   reasoning + the scenario-vs-fold estimand lesson: `dev/experiments/warmup-comparison-2026-06-12/ANALYSIS.md`,
   `project_warmup_trading_running_start`.
2. **#1556 (merged)** — exit-fill-reject zombie fix. The #1553 THM short that rode
   a 4x adverse move unstopped was NOT warmup-entry (reverses PR #1549's G2
   guess): the stop fired but the cover BUY was rejected by the portfolio cash
   floor, simulator silently dropped the fill, position stuck `Exiting` forever.
   Fix = `Exiting`→`Holding` revert + WARN on dropped fills + Fold_health
   divergence signature. `project_exit_fill_reject_zombie`.
3. **#1558 (merged)** — wired `Fold_health.check_divergence` into the runner
   (#1557 item 1). Divergence finding now fires in real runs.
4. **#1560 (open, in QC)** — short-side hardening. Investigated forensics G5
   ("shorts in a long baseline"): **no leak** — `enable_short_side=false` already
   suppresses all shorts; the forensics shorts came from an uncommitted ad-hoc
   scenario. Shipped a pinned `Short_side_gate.combine` micro-lib + regression
   tests (false→zero shorts; true→shorts after longs + $17 floor drops a $0.69
   short). Bit-identical, no goldens move.

## P0 (human decision required) — #1557 core-module items

Two A1 core-module decisions from the #1556 zombie fix, deferred for human
approval (issue #1557 items 2-3):
- A core `CancelExit` (`Exiting`→`Holding`) Position transition to replace the
  simulation-layer state reconstruction #1556 used.
- Exempting risk-reducing (closing) trades from the portfolio cash floor — a
  fired stop's cover/sell should arguably never be cash-floor-blocked. Links the
  #1546 stale-cash-floor / MaxDD>100% finding.

These touch `trading/trading/portfolio|position/` (core) — need design sign-off,
not autonomous execution.

## P1-P2 (carried from 06-12-PM, unblocked now P0 is resolved)

- **Definitive matrix + policy universe** (06-12-PM P2): emit composition-policy
  universe artifact ($-volume wired, #1542), re-run both matrices with the
  min-window guard + fold-health + (now-confirmed) honest warmup semantics — i.e.
  warmup-trading stays ON, so the existing matrices were already measuring the
  right thing; the re-run mainly adds the guards.
- Weekly >1%-ADV screener gate; factor-decomposition lens (named gap in
  `project_index_beating_structural_bar`).

## Key references

`project_warmup_trading_running_start` (P0 verdict + estimand lesson),
`project_exit_fill_reject_zombie` (#1553 root cause), `dev/experiments/warmup-comparison-2026-06-12/`,
issue #1557 (core-module decision items).
