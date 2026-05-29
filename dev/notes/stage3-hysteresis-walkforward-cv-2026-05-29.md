# Stage3 hysteresis — 30-fold walk-forward CV CONFIRMS rejection (2026-05-29 PM)

**Decision:** REJECTION of `(hysteresis_weeks=2, stage3_exit_margin_pct=0.02)`
is now confirmed by 30-fold walk-forward cross-validation. This is the
rigorous corroboration of the 2-panel rejection recorded in
[`stage3-hysteresis-panel-rejected-2026-05-29.md`](stage3-hysteresis-panel-rejected-2026-05-29.md).

**Status:** PR-A (#1362, code knob plumbing) stays on main; defaults
(`hysteresis_weeks=2`, `stage3_exit_margin_pct=0.0`) preserve panel
behavior. No production parameter flip. The WF spec fixture + parser
tests landed via #1365.

Full per-fold report: [`stage3-hysteresis-walkforward-cv-report-2026-05-29.md`](stage3-hysteresis-walkforward-cv-report-2026-05-29.md).

## Why this run matters

The panel rejection rested on exactly **two** observation windows — 5y
(`sp500-2019-2023`, improved) and 15y (`sp500-2010-2026`, regressed).
Two windows is enough to spot a single-window overfit but not enough to
quantify how the knob behaves across the regime distribution. This run
re-tests the same knob change over **31 sequential walk-forward folds**
spanning 2010→2026, giving a per-fold win/loss distribution instead of
two point estimates.

This is the walk-forward-CV discipline the project pivoted to (see
`memory/project_strategic_pivot_broader_first.md`): decide knob changes
on a fold distribution, not a single backtest.

- Spec: `trading/test_data/walk_forward/hysteresis_30fold_2026_05_29.sexp`
- Runner: `walk_forward_runner.exe`, `--parallel 4`, 525-symbol panel,
  wall ~24 min inside `trading-1-dev`.
- Variants: baseline `h1-m0` (`hysteresis_weeks=1`, margin=0.0) vs
  `h2-m02` (`hysteresis_weeks=2`, `stage3_exit_margin_pct=0.02`).

## Result — h2-m02 loses on every aggregate axis

| Variant | Return % (μ ± σ) | Sharpe (μ ± σ) | MaxDD % (μ ± σ) | Calmar (μ ± σ) |
|---------|-----------------:|---------------:|----------------:|---------------:|
| `h1-m0` (baseline) | **8.17 ± 16.70** | **0.540 ± 1.038** | **12.28 ± 5.09** | **1.249 ± 2.125** |
| `h2-m02` (variant)  | 7.88 ± 16.59 | 0.519 ± 1.033 | 12.34 ± 5.10 | 1.185 ± 1.991 |

Variant is worse on mean return, mean Sharpe, mean drawdown, and mean
Calmar. The two variants are **identical on 19 of 31 folds** (the knob
only bites when a Stage 2→3→2 whipsaw occurs in the fold window); of the
12 folds where they differ, the variant wins a minority.

### Cross-fold win count (vs baseline, gate metric = Sharpe)

| Variant | Sharpe wins | Calmar wins | Return wins | MaxDD wins | of |
|---------|------------:|------------:|------------:|-----------:|---:|
| `h2-m02` | **4** | 4 | 4 | 2 | 31 |

The go/no-go gate required **≥17 of 30** Sharpe wins with no fold worse
by Δ>0.20. The variant wins **4**. Decisive NO-GO.

## Gate computed SKIPPED — off-by-one in fixture `n`

The verdict line reads:

```
h2-m02: SKIPPED — fold-pair count mismatch: measured 31, gate expects 30
```

The fixture declares `gate.n=30` but the fold schedule yields 31 folds
(`fold-000`…`fold-030`). The gate guard refuses to evaluate on a count
mismatch, so the formal verdict is SKIPPED rather than NO-GO. **This does
not change the conclusion** — the aggregate stats and 4/31 win count
favor the baseline regardless of whether the gate fires.

**Follow-up fix (trivial):** bump the fixture's `gate.n` 30 → 31 (or
trim the fold schedule to 30) so the gate evaluates cleanly on the next
run of this spec. Tracked as a one-line fixture correction; not blocking
this rejection.

## Verdict

`(hysteresis_weeks=2, stage3_exit_margin_pct=0.02)` is **rejected** as a
production default. The mechanism is a net drag across the 2010→2026
fold distribution — consistent with the 15y panel regression and the
project's recurring single-window-overfit pattern
(`memory/project_continuation_combined_rejected.md`,
`memory/feedback_strategy_mechanic_changes_too_explorative.md`).

The autopsy hypothesis (gating false Stage 2→3 transitions recovers
missed gain) was directionally sound on the 5y window but does not
survive walk-forward CV. The per-symbol autopsy remains useful as a
failure-mode *labeller*; it is not a reliable *knob-recommendation*
engine without WF-CV confirmation.
