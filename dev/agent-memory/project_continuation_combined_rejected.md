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

**NOT RETIREMENT-ELIGIBLE — reclassified KEEP-AXIS 2026-08-13 (PR #2307).**
The 08-09 flag inventory listed `enable_continuation_buys` + `continuation_config`
as RETIRE and the 08-14 handoff called it "the next big retirement row". Both
were wrong, and the Rule-4 eligibility screen caught it before any deletion:

1. **The RETIRE seed was a transcription error.** It conflated the *scale-in v2
   continuation-add* item with this standalone flag. The cited ledger entry
   `2026-07-05-continuation-add-v2-surface` armed **`enable_scale_in`**, not
   `enable_continuation_buys` — that verdict was already spent retiring scale-in
   in #2299. Citing it here double-counts it.
2. **No do-not-revive is recorded anywhere.** The opposite is: this memory names
   an *uncancelled* regime-gated revival path, and the 05-14 rejection was two
   single-run windows, pre-WF-CV.
3. **It is a Weinstein-documented dial**, not an invented mechanism — the
   continuation / pullback re-breakout entry mode ("The Trader's Way", Ch. 3),
   and the config home for the Trader preset
   (`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`).

Re-enters the graveyard only when EITHER the trader-preset program is *recorded*
closed, OR a regime-gated surface runs and REJECTs. Evidence:
`dev/plans/continuation-retirement-2026-08-13.md`.

**The transferable lesson:** a retirement worklist row is a *claim about which
verdict covers which flag*, and that mapping can be wrong. Always re-read the
cited ledger entry and confirm it armed **this** field before removing anything —
the 08-12 `trigger_on_weekly_close` correction was the same class of error
(a verdict about a simulator lever, misread as covering the field).
