---
name: Continuation-buy combined-axis tuning REJECTED on 16y validation
description: 2026-05-14 cross-window sweep — combined weeks=2+range=0.15 wins big on 5y (Sharpe 0.59→0.73) but loses on 16y (0.71→0.68). Single-window overfit.
type: project
originSessionId: 4d6537ae-8820-4dcd-bdf8-cf449e669439
---
Ran the P3-followup combined-axis continuation sweep on 2026-05-14
(weeks=2 + range=0.15, the two best single-axis movers from PR #1091).

**5y window (sp500-2019-2023):**
- combined: Sharpe 0.73, Calmar 0.52
- baseline-on (cont-buys defaults): 0.59 / 0.41
- continuation-off (Cell E): 0.56 / 0.40

**16y window:**
- combined: Sharpe 0.68, Calmar 0.49, MaxDD 15.71%, CAGR 7.63%, total 232.15%
- baseline-on: 0.69 / 0.46 / 16.99% / 7.80% / 240.76%
- continuation-off (Cell E): **0.71 / 0.45 / 19.92% / 8.98% / 307.16%**

**Why:** On 16y, continuation-buys are a NET DRAG regardless of tuning.
The continuation-off cell wins on Sharpe + CAGR + total return; combined
gets the lowest MaxDD but at significant cost. The 5y "massive win" was
a single-window artifact — exactly the failure mode `memory/project_m5-5-tuning-exhausted.md`
flags ("single-window 5y wins without 10y+16y validation gates").

**How to apply:** Continuation-buys (Interpretation B from PR #1078)
should stay default-off. Don't pursue further single-axis or combined-axis
tuning of the existing config knobs. If the mechanism is to come back,
it needs a different design (eg gated by macro regime, gated by sector
strength, etc.) — the slot-budget bind found in PR #1091 plus the long-
horizon drag found here together suggest the feature is structurally
unsuitable to Cell E's portfolio constraints.

**Data preserved:** Summary outputs under
`dev/backtest/scenarios-2026-05-14-201358/` (5y) and
`dev/backtest/scenarios-2026-05-14-201409/` (16y). The experiment
worktree was deleted before the artifacts were committed; the cell-
level scenario sexp files were lost but the summary.sexp results
survived. A PR was NOT opened.
