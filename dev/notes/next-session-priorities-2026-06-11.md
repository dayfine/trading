# Next-session priorities — 2026-06-11

**Supersedes** `next-session-priorities-2026-06-10-PM.md`. Check main CI green
before dispatching.

## TL;DR — the 2026-06-10-PM P0 was validated and REJECTED

The P0 from the prior handoff — **harvest-and-rotate by forward expected return**
(trim a mature/extended Stage-2 winner to fund a cash-blocked fresh early-S2
candidate; the AAPL-dividend logic) — was tested **read-only before building**,
per the validate-first discipline. **It fails both required preconditions
decisively** on the Cell-E top-3000 baseline. **No build.**

- **(a) forward-return decay — FALSE.** fwd-4w return (adj_close, median, winsor)
  is flat-to-*rising* with extension above the 150d MA AND with weeks-since-entry.
  Fresh early-S2 median **+0.38%** vs mature-extended **+1.44%** — the mature
  winner earns *more*, not less.
- **(b) opportunity cost — REVERSED.** Best cash-blocked skipped candidate fwd-4w
  **+0.37%** vs the most-extended held position (the harvest target) **+2.16%**
  (~6×); win-rate ~50%. Rotating capital out of the winner destroys value.

The "declining forward rate" premise is simply false — a still-advancing Stage-2
winner's forward rate does not decline (let-winners-run / momentum, directly
measured). Consistent with the cascade-inversion (breakout earns the fat tail) and
the entry-cap probe (concentration IS the return). Full record + scripts:
`dev/experiments/harvest-rotate-validation-2026-06-10/`. Memory:
`project_harvest_rotate_rejected`.

## What this closes

- **Harvest-rotate dial — dropped.** Not built.
- **P1 partial-exit core change — no longer motivated.** It only existed to *fund*
  the harvest-rotate and the concentration trim. Both are now dominated; do not
  open the core `TriggerPartialExit` change for this purpose.
- **Concentration-TRIM direction generally — dead end on a return basis.** Trimming
  an extended winner moves capital to a lower-forward-return use. The only residual
  reason to bound single-name NAV% is **unrealised-mark / tail-RISK**
  (`project_broad_universe_790_mtm_inflated`) — a *risk* argument, not a return
  one — and prior risk-cap probes were already strictly dominated. Revive only if
  framed explicitly as tail-risk insurance with a metric that rewards it (e.g.
  capital-relative DD / Ulcer), not as a return improvement.

## Open priorities (carried, re-ranked)

**P0 — Re-weight the "top-3000 = artifact" priors (docs).** The liquidity work +
this validation both show the broad-universe edge is real on realized + liquid
trades and that the concentration *is* the return. Sweep the status/notes prose
that still treats top-3000 returns as an MTM/illiquidity artifact and reconcile.
`project_pit_survivorship_inflation` (survivorship in the SP500 composition golden)
is a *separate, still-valid* concern; keep it.

**P1 — Trade-forensics tooling (carried).** PR-3 post-exit capture ratio + PR-4
auto-`stage_chart` for top-impact trades remain open
(`dev/notes/trade-forensics-2026-06-09.md`). LOW urgency.

**P2 — (optional) Fix the MFE/MAE harness gap.**
`Trade_audit.exit_decision.max_favorable_excursion_pct` and
`max_adverse_excursion_pct` are **always 0** in every recent run — the simulator
step-stream never populates them. This blocks any audit-based give-back / capture
analysis (the validation above had to recompute forward returns from bars). Small,
well-scoped fix if MFE/MAE-based forensics is wanted.

## Where the strategic search stands

The discrete-feature / position-management levers explored over the last sessions
(cascade-reweight, laggard, force-exit, stage2-ma-hold, macro-bearish-trim,
late-flag stop-tighten, early-admission, hysteresis, continuation, **and now
harvest-rotate**) have all been REJECTED or kept default-off. The recurring lesson:
the Cell-E baseline is near-optimal on its surface, and the broad-universe edge is
the **fat-tailed let-winners-run** behaviour — mechanisms that trim, rotate, or
re-time winners keep destroying that tail. Future search should bias toward levers
that *preserve* the tail (universe breadth, entry quality, holding discipline) and
away from anything that caps or recycles a still-advancing winner.

## Infra notes

- Cell-E top-3000 single full run ≈ 30min (snapshot mode, `snap_top3000_2011`,
  fork parallel=1). Writes `trades.csv` + `trade_audit.sexp` (incl.
  `alternatives_considered` / `Insufficient_cash`). **Run via**
  `scenario_runner.exe --dir <spec-dir> --snapshot-dir /tmp/snap_top3000_2011
  --fixtures-root / --no-emit-all-eligible` — note `--fixtures-root /` is required
  because the spec's `universe_path` is repo-relative (`Filename.concat` does not
  special-case absolute paths).
- Forward-return-from-bars: **use the `adjusted_close` column (col 6), not raw
  close (col 5)** — raw close has reverse-split glitches (a fake +50,200% 4-week
  return on NDN poisoned the first pass). Always median + winsor on top-3000 bars.
