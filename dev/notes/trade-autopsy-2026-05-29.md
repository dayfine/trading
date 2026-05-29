# Trade autopsy — gain-capture failure-mode breakdown (2026-05-29)

## TL;DR

**Late re-entry dominates** the gain-capture loss in the per-symbol Weinstein
stage strategy: **+1557.83% total missed gain** across 48 trades, averaging
**+32.45%** per flagged trade. Stage-3 false-positives are a clear second
(+1176.23% across 71 trades, +16.57%/trade). Late Stage-2 admission is high
frequency but low magnitude (+505.01% across 100 trades, +5.05%/trade —
many trades enter late but the lateness isn't catastrophic on its own).
Stop-out whipsaw is **inert** (the per-symbol stage strategy has no stops).

### Headline ranking (priority candidates for the targeted fix)

| Rank | Failure mode | # trades flagged | Total missed gain | Avg / trade |
|---|---|---|---|---|
| 1 | **late_reentry** | 48 | **+1557.83%** | +32.45% |
| 2 | **stage3_false_positive** | 71 | **+1176.23%** | +16.57% |
| 3 | late_stage2_admission | 100 | +505.01% | +5.05% |
| 4 | stop_out_whipsaw | 0 | +0.00% | +0.00% (inert) |

Modes are NOT mutually exclusive — a single trade can match multiple modes,
e.g. an early Stage-3 exit that is FOLLOWED BY a long wait for the next
Stage-1→2 cycle counts toward both `stage3_false_positive` and
`late_reentry`. The recommended fix targets the shared root cause that
spans both #1 and #2 (see § Recommended targeted fix).

## How the autopsy works

Source: per-symbol Weinstein stage strategy (PR #1353), Long-only variant,
SPY + 11 SPDR sector ETFs, 1998-01-01 → 2025-12-31. The strategy has
exactly one position-management mechanic: enter long on Stage1→Stage2,
exit on Stage2→Stage3, force-close at end-of-window.

For each of the 196 closed trades, the autopsy tool:

1. **Derives the exit reason** from trade position. 190 trades exit via
   `Stage3_exit`; 6 trades are `End_of_period` (one per symbol whose
   window closes with an open position). 0 trades are `Stop_out` (none
   exist in this strategy), 0 are `Stage4_decline` (canonical
   Stage1→2→3 mapping never skips), and 0 are `Laggard_rotation`
   (per-symbol strategy doesn't run rotation). Schema is wider than
   needed to keep the same tool usable on rotation-aware strategies.
2. **Computes missed_gain_pct** = (next_same_side_entry_price −
   exit_price) / exit_price, or against the end-of-window close if no
   re-entry occurs. Positive = strategy exited and missed upside.
   Negative = strategy successfully avoided a loss.
3. **Classifies against the four failure modes** independently against
   the thresholds in `Trade_autopsy_config.default`:
   - `Stage3_false_positive`: exit on Stage3 AND price ≥ exit × 1.05
     within 12 weeks.
   - `Late_reentry`: weeks-to-next-same-side-entry > 8 AND
     missed_gain_pct ≥ 10%.
   - `Late_stage2_admission`: weeks_since_cyclical_low > 8 (lowest close
     in 12-week lookback before entry). Long entries only.
   - `Stop_out_whipsaw`: exit_reason = Stop_out (always false here).

All thresholds live in
`trading/analysis/scripts/trade_autopsy/lib/trade_autopsy_config.ml` and
are exposed in the config record so the same tool can sweep them later.

## Per-symbol failure-mode breakdown

| Symbol | # trades | Stage3 false-positive total | Late re-entry total | Late Stage2 admission total | Stop-out whipsaw total |
|---|---|---|---|---|---|
| SPY  | 13 |  +81.03% | +146.79% |  +63.92% | +0.00% |
| XLK  | 17 | +118.69% | +230.29% |  +26.81% | +0.00% |
| XLF  | 16 |  -11.43% |  +60.21% |  -27.12% | +0.00% |
| XLI  | 21 | +128.90% | +126.31% |  +37.87% | +0.00% |
| XLV  | 21 |  +99.81% |  +74.32% |  +54.80% | +0.00% |
| XLE  | 22 | +301.27% | +309.57% |  +95.32% | +0.00% |
| XLP  | 15 |  +29.31% | +120.91% |  +82.90% | +0.00% |
| XLY  | 17 | +147.42% | +200.36% | +104.11% | +0.00% |
| XLU  | 17 | +117.85% | +131.92% |  +24.40% | +0.00% |
| XLB  | 23 | +129.19% | +127.55% |  +53.00% | +0.00% |
| XLRE | 10 |  +10.27% |  +29.59% |   +7.50% | +0.00% |
| XLC  |  4 |  +23.94% |   +0.00% |  -18.51% | +0.00% |

XLF is the only symbol with a NEGATIVE stage3_false_positive missed-gain
total (-11.43%): on net, the Stage-3 exits on XLF were correct (price kept
declining after exit). XLC is too short a series (only 4 trades) to draw
conclusions. Every other symbol contributes positively to all three
non-inert failure-mode totals.

## Concrete examples of each failure mode

Drawn directly from the autopsy.sexp output. Each example is one row of
the 196-trade dataset.

### Late re-entry — SPY 2012-2016 (+58.5%)

```
entry_date 2012-01-06  exit_date 2012-06-01  exit_price ~127.72
next_entry_date 2016-03-24                  next_entry_price ~203.13
weeks_to_reentry = ~221  missed_gain_pct = +0.585 (+58.5%)
```

The 2012 mid-year exit on Stage3 was correct in the immediate window —
but the next Stage1→Stage2 transition didn't fire until 2016. SPY ran
+58.5% during the wait, all captured by buy-and-hold.

### Late re-entry — SPY 2022-12-16 → 2025-06-06 (+56.3%)

```
entry_date 2022-12-02  exit_date 2022-12-16  exit_price ~406.93
next_entry_date 2025-06-06                   next_entry_price ~599.17
weeks_to_reentry = ~131  missed_gain_pct = +0.563 (+56.3%)
```

A 2-week stage-2 admission that immediately got Stage3'd; then no
re-entry for 2.5 years while SPY ran +56%.

### Stage-3 false positive — XLE 2020 onwards

XLE alone contributes +301.27% to the stage3_false_positive bucket
across its 22 trades. The energy sector's sustained 2020-2022 rally was
interrupted by short Stage-3 false-positive exits that all recovered.

### Late Stage 2 admission — XLY (104.11% total)

100 trades panel-wide flagged late_stage2_admission with an average
missed-gain of only 5.05% — a high-frequency low-magnitude mode. Most
late admissions are not catastrophic because Stage-2 trends typically
continue for many weeks beyond the admission point. But the volume of
flagged trades (~51% of all 196) suggests the 30-week WMA admission
criterion systematically lags V-shaped recoveries.

## Recommended targeted fix

**Rank 1 (late_reentry) and Rank 2 (stage3_false_positive) share a common
mechanism: false Stage 3 transitions that immediately resolve back to
Stage 2.** The strategy exits on what looks like a Stage-2→3 transition,
but the price doesn't actually decline — instead it consolidates briefly,
the MA flattens for a few weeks (triggering Stage 3 by classifier rule),
and then the symbol resumes uptrend. The naive cost of one false-positive
exit is the missed gain until the next Stage1→2 transition, which can be
months or years away (per the SPY 2012-2016 and 2022-2025 examples).

**Proposed mechanism: a Stage 3 confirmation / hysteresis filter.** Before
firing `Exit_long` on a Stage2→Stage3 transition, require either:

1. **Persistence**: the classification has been Stage 3 for at least
   `stage3_confirmation_weeks` consecutive weekly bars (e.g. 2-4 weeks).
   Today's strategy exits the first week Stage 3 is detected, so it is
   maximally sensitive to false positives.
2. **Price-action confirmation**: price has actually declined below the
   30w MA by some minimum amount (e.g. `stage3_exit_margin_pct = 2%`),
   not just touched it. Today's classifier transitions to Stage 3 based
   on MA slope flattening even when price is still above the MA.

Both knobs are well-scoped, parameterizable, and testable against the
existing per-symbol stage strategy harness. Either alone could
substantially reduce the +1176% Stage3 false-positive bucket; in
combination they should also collapse the +1557% late_reentry bucket
(since fewer false exits = fewer dead waits for Stage1→2 cycles).

**Late Stage 2 admission (rank 3)** is high-frequency but low-magnitude.
Worth addressing AFTER the Stage 3 fix lands — the targeted fix likely
needs a different mechanic (e.g. a "recent breakout" override that admits
Stage 2 even when the 30w MA is still flat, conditional on a strong
recent up-move). Don't bundle it with the Stage 3 fix.

## Follow-up PRs (proposed sequence)

1. **PR-A: Strategy mechanism — Stage 3 hysteresis** (~300 LOC).
   - Add `stage3_confirmation_weeks` and `stage3_exit_margin_pct` knobs
     to the per-symbol stage strategy's exit-decision path (or to a new
     wrapper module that consumes `Stage_signal.action_of_transition`
     and applies the persistence filter — preserve the original module
     as-is per the `feedback_strategy_mechanic_changes_too_explorative`
     discipline).
   - Re-run the per-symbol diagnostic. Expect total `stage3_false_positive`
     missed-gain to drop by >50% and `late_reentry` to drop alongside.
   - Re-run autopsy and compare deltas in `dev/notes/trade-autopsy-fix-<date>.md`.
2. **PR-B: Sweep the new Stage-3 knobs** on the per-symbol harness to
   pick a CAGR-vs-Sharpe optimum (~200 LOC of sweep config + report).
3. **PR-C: Apply the winning Stage-3 hysteresis to the production
   strategy** (`weinstein_strategy.ml`) and re-run promote_config.sh
   gate against the 2-scenario panel — but ONLY after PR-A's autopsy
   re-run confirms the fix actually works on the diagnostic harness.
4. **(Deferred) PR-D: Late Stage 2 admission fix.** Likely needs a
   different mechanic (breakout-override admission). Defer until after
   the Stage 3 fix lands and the panel re-test confirms residual gain
   left to capture.

## Caveats

1. **N=12 symbols × 27y; 196 trades.** Statistically meaningful for
   "which mode dominates" ranking but small for fine-grained per-symbol
   conclusions. XLC (4 trades) and XLRE (10 trades) are too short to
   read individually.
2. **Missed-gain attribution is per-trade, not per-dollar-of-CAGR.** The
   conversion from "this mode caused +X% missed gain on N flagged trades"
   to "this mode costs Y pp of CAGR per year" is non-trivial (compounding,
   position sizing, overlap between modes). Use the ranking for
   prioritization, not for projecting fix-impact.
3. **Modes overlap.** A trade can flag multiple modes; the +1557 +1176
   +505 = +3238% sum across modes is NOT a panel-total missed gain. It is
   the sum of per-mode totals, and each trade contributes to every mode
   it matches.
4. **Stop-out whipsaw is inert here.** The per-symbol stage strategy
   intentionally has no stops. The mode is part of the schema so the same
   tool can score the production strategy (which does have stops). When
   the autopsy is re-run against the production strategy, expect this
   bucket to populate.
5. **Late Stage-2 admission counts late_stage2_lookback_weeks = 12 as
   the window for the cyclical low.** A longer lookback (e.g. 26 weeks)
   might re-rank this mode upward. The config knob is exposed for the
   sweep.

## Build / verify

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune build && dune runtest analysis/scripts/trade_autopsy/'
```

Tests: 14 cases pass against synthetic bar series — one per failure-mode
edge case (positive + negative), one for `Missed_gain` close-lookup,
one for cyclical-low detection, one for the aggregation pipeline.

To regenerate this report:

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   dune exec analysis/scripts/trade_autopsy/bin/autopsy_runner.exe -- \
     -data-dir /workspaces/trading-1/data \
     -out-sexp /tmp/autopsy.sexp'
```

The full per-trade autopsy.sexp (1849 lines) lives in `/tmp/autopsy.sexp`
during the runner's session. Not committed to the repo — derived data.
