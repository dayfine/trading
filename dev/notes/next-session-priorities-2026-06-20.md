# Next-session priorities — 2026-06-20

**Supersedes** `next-session-priorities-2026-06-18.md`. Check main CI green first
(`.claude/rules/session-rampup.md`). This was an autonomous overnight run
(2026-06-18/19) per `dev/notes/overnight-plan-2026-06-19.md` — user AFK.

## What shipped overnight (all merged, main green)

The **decision-grading lens** is complete and was used end-to-end to judge three
strategy questions at the decision level (not by aggregate Sharpe). PRs this run:
#1649 (lens Phases 3-4), #1650 (MFE-join fix), #1652 (insurance decomposition +
deep stop read), #1653 (Phase-5 laggard counterfactual), #1654 (docs), #1655
(weekly-close stop flag, default-off).

### The a→b→c arc + the stop lever — all answered

1. **(a) Stops are whipsaw-dominated** — forgo more upside (+30-33%) than disaster
   dodged (−19%), net per-decision negative even through dot-com+GFC.
2. **(b) Laggard-rotation swap is a coin flip** (~50%, ≈+1%); its value is
   capital-recycling/freshness, not selection. Keep on, don't tune selection.
3. **(c) Long-short short leg is anemic** (37 trades/28y, ~breakeven) — weak/
   confounded DD diversifier → no-build; barbell remains the DD lever.
4. **Weekly-close stop (the (a) follow-up lever) — BUILT + REJECTED.** Decisively
   worse in BOTH regimes (deep −457pp; bull return halved + DD up). The whipsaw is
   real but NOT recapturable by a looser trigger: the strategy already re-enters
   recoverers, and weekly-close just holds genuine breakdowns deeper. **Closes the
   stop-tuning thread.** `dev/experiments/weekly-close-screen-2026-06-19/`,
   `project_weekly_close_stop_lever`.

### The compounding meta-finding (drives the next lever)

Every **selection / holding-discipline tweak** screened this month is a dead end:
entry-selection (coin flip), cascade-reweight (WF-CV rejected), laggard swap (coin
flip), short-pick (anemic), weekly-close stop (worse). The edge is the let-winners-
run fat tail; mechanisms that touch *which names* or *cut-losers-fast* either
coin-flip or backfire (`project_edge_is_the_fat_tail`,
`project_accuracy_is_unreachable_diversify_instead`). **The only live levers are
structural diversification (barbell: SPY-floor + engine, `project_barbell_on_stocks`)
and possibly breadth/universe** — NOT selection or exit tuning.

## P0 NEXT — pick a STRUCTURAL lever, not another selection/exit tweak

The decision-grading lens has now exhausted the per-decision selection/exit
questions with consistent dead-ends. The evidence points to **structural
diversification** as the next lever:

- **Barbell promotion path** (`project_barbell_on_stocks`): SPY-timing floor +
  Cell-E engine NAV blend beat both legs on Calmar in deep AND bull. This is the
  best-validated DD diversifier and has NOT been pushed to a promotion grid. P0
  candidate: run the barbell through the WF-CV + `promotion-confirmation.md` grid
  → if it holds, it's the first promotable structural change.
- Do NOT start another entry/exit/rotation/short-selection screen — the lens has
  shown that class is a dead end five times over.

## P1 — lens as standing instrument
The `decision_grading` + `laggard_cf` bins are the repeatable instrument; grade any
future candidate at the decision level before/after. Harness gap (non-blocking,
carried): the bins' I/O glue (`_mfe_index`/`_find_mfe`, csv/forward extraction) is
untested over the pinned libs — factor into a tested shared helper if the lens
becomes more load-bearing.

## State
- All PRs merged, main green, 0 open PRs (verify at session start).
- v2 warehouses at `/tmp/snap_top3000_{2000,2011,1998_2026}_v2`; backtests run
  clean at `SNAPSHOT_CACHE_MB=1024`. Scenario-runner gotcha: `universe_path` is
  resolved relative to `--fixtures-root`; use the leading-slash-stripped path +
  `--fixtures-root /`.
- Lens lives at `trading/trading/backtest/decision_grading/` (libs Post_exit /
  Grade / Aggregate / Laggard_cf + bins decision_grading, laggard_cf).
