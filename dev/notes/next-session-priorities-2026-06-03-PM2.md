# Next-session priorities — 2026-06-03 (PM2)

**Supersedes:** `next-session-priorities-2026-06-03-PM.md`. Session pivoted (per
user) from the portfolio-blend layer to **stage-analysis accuracy**, driven by the
question: *at pivots like early 2020, were our decisions sensitive to stage
lifecycle, and were they maximizing upside?* Answer + a full diagnosis are now on
main. This doc sets the forward plan.

## What shipped this session

- **P0 barbell-on-stocks (#1434/#1435)** — DONE. Floor+engine NAV blend dominates
  both legs on Calmar in both regimes; 70/30 robust. Stale golden re-pinned to
  ground-truth 237.6%. (See `project_barbell_on_stocks`.)
- **Stage-lifecycle diagnosis (#1441/#1442)** — DONE. The lifecycle IS encoded
  (`Stage2 {weeks_advancing; late}`) and the `late` MA-deceleration flag (earliest
  top-warning) is computed every week — but consumed **only at entry**, never for
  held-position exposure/exit. The Stage-4 exit lags every top by 5–29 wk (price
  already −5% to −44%); `late` warned 7–26 wk before the peak in **6 of 7** episodes
  (SPY + CSCO/INTC/GE/NKE/AIG), persisting to the top on single names. At the 2020
  pivot: long-only, still buying fresh breakouts through Feb-29, held through the
  crash, exited late, re-entered higher. (See `project_stage_late_flag_discarded`.)
  `stage_chart` now emits a per-week CSV sidecar (stage + weeks-in-stage + `late`).
- **Split-artifact diagnosis (#1443)** — DONE. Returns are SAFE (split_handler
  scales held positions; barbell + golden numbers stand) but `_make_trade_metric`
  (`metrics.ml:74-92`) pairs pre-split entry with post-split exit → per-trade pnl +
  win_rate/profit_factor/avg_loss + the autopsy harness are contaminated for
  split-straddling trades. Fix spec in `dev/notes/split-artifact-trade-record-2026-06-03.md`.

## Next session — P0 → P1 (both are CODE changes; deferred from this session
because rushing simulation/strategy core late-night invites real bugs)

### P0 · Fix split-straddling trade metrics (prerequisite, small)
Per `dev/notes/split-artifact-trade-record-2026-06-03.md`: adjust the entry leg by
the cumulative split factor over the hold in `_make_trade_metric` (option 1 — the
local change). TDD: unit test a position held across a 2:1 split → trade pnl uses
adjusted basis (NKE shape → ~+20.7%, not −39.6%). Re-run production-deep; confirm
win_rate / profit_factor rise and the fake −40%/−60% trades vanish. **Returns don't
move → no golden re-pin.** `trading/trading/simulation` core → proper TDD + QC.
Do this FIRST so the autopsy harness the dial is tested against is clean.

### P1 · Default-off `late`-driven held-exposure dial (the lever)
The highest-leverage, lowest-risk stage-accuracy change (reuses an existing,
discarded signal — respects the over-exploration guardrail; Weinstein-faithful
"late Stage 2 → take partial profits"). On `Stage2 {late=true}` (and/or
`weeks_advancing` beyond a threshold), **trim the held position toward a
configurable fraction and/or tighten the trailing stop** — keep the daily gap stop
for fast crashes (2020 blow-off resets `late`; only the gap stop catches it).
- Land default-off per flag-discipline; expressible as a `Variant_matrix` axis.
- Test: visually (`stage_chart`), via the (now-clean) per-symbol autopsy harness,
  and a deep+bull backtest (does it cut 37%/17.5% DD without killing 918%/237%?).
- Promote only through the confirmation grid (`.claude/rules/promotion-confirmation.md`).
- Dispatch to **feat-weinstein** with the diagnosis notes as context.

### P2 (carried) · Few-feature carrier on stocks; widen mid/small-cap
Unchanged from -PM; lower priority than the stage-accuracy lever now that the
diagnosis points squarely at `late`-exposure.

## Tooling / data state
- `stage_chart` CSV sidecar: `<out>.png.csv` (week,date,close,ma,stage,weeks_in_stage,late).
- Pivot CSVs this session: `/tmp/spy_*.csv`, `/tmp/nm_*.csv` (regenerable).
- Fresh deep/bull production + SPY curves: `dev/backtest/scenarios-2026-06-02-14*/`,
  `-15*/`; barbell scenarios `dev/backtest/p0-barbell-*`.

## Ramp-up reminders
- Print current wall-clock time on EVERY pause (user feedback 2026-06-03).
- Strategy-mechanic changes need TDD + the confirmation grid; don't rush them.
- Zero-code PRs (docs / data-golden) → admin-merge on CI green; simulation/strategy
  code → full 3-gate (CI + qc-structural + qc-behavioral).
