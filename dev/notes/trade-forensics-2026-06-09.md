# Trade-forensics workstream — status + handoff — 2026-06-09

Goal (user direction): move beyond aggregate metrics (Sharpe/MaxDD) to
**trade-level forensics** — most-impactful trades, capture ratio vs the chart,
entry/exit stage-timing, loss anatomy, misstep taxonomy — and grow it into a
durable skill. The loop should invert from "guess a dial → blind WF-test →
reject" to "diagnose where the strategy bleeds → targeted fix".

## Key discovery
The forensics layer **mostly already existed** (`trade_audit_report` +
`trade_audit_ratings`: R-multiple, MFE/MAE, hold-time anomalies, 4 behavioural
metrics — over-trading / exit-too-early / exit-too-late / entering-losers — and
Weinstein R1–R8 conformance). It was **unusable** due to bit-rot, which is why
we'd been stuck on aggregate metrics.

Running it (once resurrected) immediately surfaced a real lead:
**cascade selection looks anti-predictive** on Cell-E top-3000 — Q1 (best-rated)
win-rate 29.3% < Q4 (worst-rated) 38.7%. The score we rank/select on rates the
eventual losers highest. Mild (167 trades/bucket) but it's a selection-quality
signal worth a dedicated investigation (selection ≫ timing, per the breadth
findings).

## PR status

| PR | What | Status |
|---|---|---|
| **#1504** | Resurrect `trade_audit_report` — blob-load + tolerant audit join (4 exact-date join sites → ±7d nearest). 3 regression tests. | **MERGED** (3 gates green) |
| **#1506** | Compute MFE/MAE at exit-capture + audit ALL exit paths. | **MERGED** (3 gates green) |
| PR-3 | Post-exit capture-ratio (did the stock keep ripping after we sold?) | not started — **unblocked** (PR-2 done) |
| PR-4 | Auto-render `stage_chart` for top-impact trades + wrap workflow as a skill | not started |

### PR-2 (#1506) — DONE. The two real bugs behind the undercounting:
1. The excursion math used `daily_bars_for` (bounded resident window) → switched to `weekly_bars_for ~n` (controlled lookback).
2. **The real one:** `emit_exit_audit` was only wired into the stops pass; **stage3 / laggard / force-liq exits (all `TriggerExit`) were never audited** → ~60% of exits (70/112 winners) had no `exit_decision` → MFE defaulted to 0.0 → `avg left on the table` went provably-impossibly negative (−7.66pp). Fixed by emitting exit audit on all exit paths in `_run_special_exits`.

Verified: avg-left-on-table **−7.66 → +7.05** (correct sign for longs), max MFE **0.49 → 1.74** (matches BA's true ~1.76). The original WIP-bug section below is retained for the record.

## PR-2 bug to fix (branch `wip/trade-audit-mfe-mae`, commit c8f2c8c1)
MFE/MAE are now wired end-to-end and non-zero, but **severely undercounted**.

Repro (regenerate a run with the branch, then run the report):
```
# build the branch, then:
scenario_runner --goldens-small --parallel 3       # regenerates trade_audit.sexp
trade_audit_report_bin --scenario-dir <out>/bull-crash-2015-2020
```
Symptoms on `bull-crash-2015-2020`:
- **Max MFE across the whole run = 0.49**, yet winner **BA** (entry 134.79, exit
  343.60, realized **+154.9%**) has raw daily bars reaching **high 371.6 in-hold**
  → true MFE ≈ **+1.76**. The measured hold window is far too short (e.g. AXP
  MFE 0.018).
- `(b) Exit-winners-too-early → avg pp left on the table: -7.66` — **provably
  impossible** for longs: weekly high ≥ exit close ⇒ MFE ≥ realized ⇒ gap ≥ 0.
  A negative average means MFE < realized, i.e. undercounting.

Two-step history (both in the commit message):
1. First used `daily_bars_for ~as_of` → returns only a bounded **resident
   window** near the exit → all-tiny/negative MFE.
2. Switched to `weekly_bars_for ~n` (n = hold_weeks + 5) → mostly-positive but
   **still undercounts** (max 0.49).

**Next step (do this first next session):** add a temporary `eprintf` in
`exit_audit_capture._excursions` printing `symbol, entry_price, entry_date,
exit_date, n, #bars_returned, max_high, min_low`, rerun one scenario, and
determine which of these is true:
- `weekly_bars_for ~n` is itself **resident-window-bounded** in CSV mode (so a
  large `n` still can't reach back the full hold) → need a different full-history
  bar accessor; OR
- the `entry_price`/`entry_date` taken from `Position.state` is wrong (e.g. a
  recent re-entry, or a basis/scale mismatch vs the bars).
Then fix and re-verify the invariant **avg(mfe − realized) ≥ 0 for long
winners** before shipping. Watch the split-adjustment basis (raw bar high vs
raw entry — cf. the G14 split-adjustment work) as a secondary suspect.

## Why this matters
Three straight broad-universe single-dial experiments (laggard-disable,
stage2-ma-hold, stage3-force-exit-off) all failed to promote — the dial surface
is mined out. Trade-level forensics is the lever to find *where the strategy
actually bleeds* (e.g. the cascade-selection inversion) instead of guessing
dials. Resurrecting the tool (PR #1504) was step 1; trustworthy MFE/MAE +
post-exit capture + chart-link are the remaining build.
