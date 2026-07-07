# RS warmup gap — root cause of the ~77% `rs_value=None` audit finding (2026-07-07)

**Status: DECISION ITEM (human approval needed for the fix).** The diagnosis is
complete and verified; the fix changes every backtest result and therefore
re-pins goldens, so per the "propose, don't execute" rule for cross-cutting
changes it is parked here.

## The finding

`project_decision_audit_faithful` (2026-07-01) flagged ~77% of sp500 audit
candidates carrying `rs_value=None` and scoped a "fix the RS-coverage gap"
harness task (P0a of `next-session-priorities-2026-07-07.md`).

## Root cause — warmup is 22 weeks too short for RS, everywhere

- `Rs.analyze` returns `None` below `rs_ma_period = 52` aligned weekly bars
  (`rs.ml:89`, default 52 — the Mansfield zero-line MA).
- The strategy's weekly views are built with `lookback_bars = 52`
  (`weinstein_strategy_config.ml:178`), so RS needs the **full** 52-week view
  populated.
- But `warmup_days_for Weinstein = 210` (~30 weeks — sized for the stage MA,
  `runner.ml:22`), and both CSV mode (`Csv_snapshot_builder.build
  ~start_date:warmup_start`, `panel_runner.ml:106`) and snapshot mode
  (`build_scenario_snapshots` derives the window from the same warmup) clip the
  panel at `warmup_start`. **No bar before `start_date − 210d` exists in the
  panel**, so for the first `52 − 30 = 22` weeks of every backtest window, the
  52-week view cannot fill and `analysis.rs = None` for **every symbol**.
- The irony: `warmup_days_for Sector_rotation_weinstein = 364` exists for
  exactly this reason — its doc comment says "the RS analyzer needs
  rs_ma_period (52wk default) aligned weekly bars". The main Weinstein arm was
  never given the same treatment.

Verified empirically: weekly-bucket date alignment between sp500 stocks and
GSPC.INDX is perfect in the CSV store (52/52 for AAPL/MSFT/JNJ/XOM/WMT/KO/PG/
GE/INTC/CSCO at 2012-12-28) — the None-ness is not a data/alignment artifact,
it is purely the missing history at window start.

Why 77%: the decision-audit run used short smoke windows. A ~28-week window
has RS available only in its last ~6 weeks → ~79% of screens lack RS ≈ the
observed 77%. On a contiguous 26y window the same artifact is only the first
22 weeks ≈ 1.6% of screens (plus genuinely-young IPOs, which are legitimate
`None`s).

## What the gap does (severity)

When `rs = None`, `_rs_long_signal` contributes **zero** score (silent no-op,
up to `w_positive_rs = 20` + crossover points), and the ranked-mode Quality
tiebreak sorts the name last (`screener_ranking.ml:23`). So:

1. **Every WF-CV fold** (2y folds, 210d warmup) runs its first ~22 weeks
   (~21% of the fold) with RS absent for ALL names — the screener scores
   without spine item 7 for a fifth of every fold. Baseline and variant are
   hit equally, so *relative* experiment verdicts are largely unaffected, but
   absolute levels and any RS-interacting axis are distorted.
2. **Live/sim divergence**: the live weekly-picks generator fetches full
   history (RS present); backtests suppress RS at window starts. Violates the
   same-pipeline principle at the margin.
3. **Score-tie pile-ups**: RS-less scores compress toward the tie plateau
   (interacts with the known alphabetical-tiebreak skew,
   `project_screener_alphabetical_tiebreak`).

## The fix (small) and its blast radius (large)

Fix: `warmup_days_for Weinstein/Spy_only_weinstein : 210 → 364` (one constant,
matching Sector_rotation) so the panel carries 52 weeks of pre-window history.

Blast radius:
- **Every backtest result shifts** (RS points now present in early-window
  screens → different candidates admitted/ranked) → **all goldens re-pin**.
- Snapshot warehouses are warmup-windowed: existing warehouses lack the extra
  154 days and must be **rebuilt** (or the runner must tolerate the shortfall
  for old warehouses — it does not: the manifest range check will fail or the
  early screens will still see NaN).
- Panel memory/CPU cost: +154 calendar days of daily bars per symbol
  (~+6% of a 26y window; ~+21% of a 2y fold window).
- Not a strategy-mechanism change (no new flag; it is a harness-faithfulness
  fix — the strategy already *wants* the 52 weeks), but by
  experiment-discipline standards it changes measured behaviour, so it should
  land as its own PR with goldens re-pinned in the same change and a ledger
  note, after a before/after sanity diff on one golden.

## Decision options

- **A (recommended): bump to 364 + re-pin goldens.** Honest fix; aligns sim
  with live; removes a systematic 21%-of-every-fold screener degradation.
- **B: leave as-is, document.** Cheapest; relative experiment verdicts stay
  valid; but every future absolute number keeps the artifact, and P0b's
  feature-coverage on fold-shaped runs stays degraded.
- **C: bump only for specific runs** (config knob) — worst option: two
  incomparable result families.

## Relation to P0 (multivariate screen)

P0b generation uses one contiguous 26y window → artifact ≈ 1.6% of screens →
**P0b does NOT block on this decision.** The P0a feature-capture PR records
`rs_value` as `option` faithfully either way; rows from the first 22 weeks
just carry `None` and the multivariate pass drops/flags them.
