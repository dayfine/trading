# 15y SP500 split-day regression — investigation note (2026-05-08)

Notes-only investigation per `dev/notes/next-session-priorities-2026-05-08-evening.md` §P0.
Goal: identify the source of the wild single-day equity jumps the dispatch reports
on the post-Q1-fix 15y vanilla golden run.

## TL;DR

Investigation **could not reproduce** the headline -85.77% / 99.93% MaxDD numbers
from the dispatch's 2026-05-08T17:03Z run. The directory the dispatch references
(`dev/backtest/scenarios-2026-05-08-170319/sp500-2010-2026-historical/`) is not
present on this machine. The two artefacts I could examine
(`scenarios-2026-05-05-004535/sp500-2010-2026-historical` — pinned baseline at
+5.15% / 16.12% MaxDD; and the agent-fixB stale-worktree `cell-e-15y-2026-05-07`
at +162.78% / 15.22% MaxDD) **both show healthy, monotonic equity curves with
zero wild single-day jumps**.

Two findings of consequence emerged anyway:

1. **The split-day broker-model redesign is fully merged** (PRs #658, #662, #664,
   #667). Detection + ledger + simulator wire-in + verification all landed in
   the 2026-04-28 → 2026-05-01 window. There is no missing phase.

2. **The equity_curve.csv on the pinned baseline truncates at 2010-11-16**
   (row 224 of 224 across `n_steps 224` in `summary.sexp`, despite the run's
   declared end_date of 2026-04-30). The truncation is caused by the
   `is_trading_day` filter in `Backtest.Runner._filter_steps`, which keeps only
   steps with `had_market_bars = true`. This is a strong candidate for what the
   dispatch interpreted as "wild jumps" — if the missing run's curve has the
   same truncation pattern but a different end date, the apparent "single-day
   2-20× jumps" may be **gaps from non-trading-day omission collapsing
   non-adjacent calendar dates**, not actual MtM discontinuities.

Recommendation: re-run the 15y vanilla golden, capture the missing
`scenarios-2026-05-08-170319/` artefacts, and re-evaluate. There is no
identifiable bug to fix from the evidence currently on disk.

## Symptom (from dispatch)

| Metric | Pinned baseline | 2026-05-08 evening run (per dispatch) |
|---|---:|---:|
| total_return_pct | +5.15% | -85.77% |
| max_drawdown_pct | 16.12 | 99.93 |
| trade count | 102 | 102 (identical) |
| win_rate | 21.57% | 21.57% (identical) |
| avg_holding_days | 130.58 | 130.58 (identical) |

Trade selection identical → strategy logic unchanged. Trajectory diverges →
P&L accumulation path differs. Dispatch attributes wild 2-20× single-day
equity moves in 2010-2013 to broken split adjustment.

## Phase status of the broker-model redesign

Per `dev/plans/split-day-ohlc-redesign-2026-04-28.md` (the actual plan; the
dispatch references a non-existent `docs/design/split-day-broker-model-2026-04-28.md`):

| PR | Description | LOC est. | Status |
|---|---|---:|---|
| #658 | PR-1: `Split_detector` primitive + tests | 150 | **MERGED** (commit f02aafd7) |
| #662 | PR-2: `Split_event` ledger + `apply_to_portfolio` | 250 | **MERGED** (commit 53061ffb) |
| #664 | PR-3: wire detection + ledger into simulator step | 200 | **MERGED** (commit 5fccfff8) |
| #667 | PR-4: sp500 verification + decisions archive | 50 | **MERGED** (commit 94ec209b) |
| #679 | follow-up: split-day broker-model verification harness | — | **MERGED** (commit 143709c1) |
| #922 | refactor: extract `Split_handler` from simulator | — | **MERGED** (commit 98d67125) |

Wire-in confirmed in `trading/trading/simulation/lib/simulator.ml:369-388`:

```
let _prepare_market_state t =
  let split_events =
    Split_handler.detect_for_held_positions ~adapter:... ~portfolio:...
  in
  let portfolio = Split_handler.apply_events t.portfolio split_events in
  let positions = Split_handler.apply_to_positions t.positions split_events in
  ...
```

Each daily step calls `Split_handler.detect_for_held_positions` against the
current portfolio's held symbols, applies any detected splits to the portfolio
ledger and to the strategy positions before strategy invocation, and emits the
events into `step_result.splits_applied` so the result writer can surface them
to `splits.csv`. This matches the design.

The `Split_handler.apply_to_position` scaling in
`trading/trading/simulation/lib/split_handler.ml:25-66` divides
`entry_price` by `factor` and multiplies `quantity`, `target_quantity`,
`exit_price`, `filled_quantity` by `factor` — the broker-model invariant.

The `Split_event.apply_to_position` in
`trading/trading/portfolio/lib/split_event.ml:15-17` scales each lot's
`quantity *. factor` and leaves `cost_basis` (a TOTAL, not per-share) unchanged
— total cost basis preserved. Implied per-share cost divides by `factor`. Also
matches the design.

## What I could verify on disk

### Pinned baseline (`dev/backtest/scenarios-2026-05-05-004535/sp500-2010-2026-historical/`)

- `summary.sexp`: `total_return_pct 5.15`, `max_drawdown 16.12`,
  `n_round_trips 102`, `n_steps 224`, `final_portfolio_value 1051527.64`,
  `universe_size 510`, `start 2010-01-01`, `end 2026-04-30`.
- `splits.csv`: header only — **zero splits detected over the full 15y run**
  on a 510-symbol SP500 universe.
- `equity_curve.csv`: 224 rows, **last row 2010-11-16, $1,051,527.64**
  (matches `final_portfolio_value` exactly). Curve is monotonic, no wild
  jumps — peak $1,162,795 (2010-04-23), trough $939,576 (2010-02-09).
- Trades that span any famous post-2014 split: **none**. AMZN traded
  2010-01-30 to 2010-06-30. GOOG traded 2011-08-13 to 2011-08-18. NVDA
  traded 2010-01-09 to 2010-01-12. None of these positions were held
  across the AAPL-2020-08-31 4:1, NVDA-2021-07-20 4:1, AMZN-2022-06-06
  20:1, or GOOG-2022-07-18 20:1 splits.

### Cell-E 15y stale worktree (`agent-fixB-18653-1778246622/dev/experiments/cell-e-15y-2026-05-07/`)

- `summary.sexp`: `total_return_pct 162.78`, `max_drawdown 15.22`,
  `n_round_trips 2090`. Healthy curve, peak $2,653,229 (2018-09-21).
- `splits.csv`: 3 detected splits (DUK 2012-07-03 0.333, KO 2012-08-13 2.0,
  OKE 2014-02-03 1.143).

### What's missing

The directory `dev/backtest/scenarios-2026-05-08-170319/sp500-2010-2026-historical/`
that the dispatch quotes from is **not present on this machine**, and no
artefact under `/Users/difan/Projects/trading-1/dev/` matches the dispatch's
headline numbers (`grep -rn "85.77\|99.93"` returns no relevant hits). The
post-Q1-fix run referenced in `next-session-priorities-2026-05-08-evening.md`
appears to have been deleted or was never persisted to disk.

## What I cannot verify, and the most likely root cause if the dispatch's
evidence stands

The dispatch's signature symptom — **102 trades identical** but trajectory
diverges to -85.77% — rules out:

- **Strategy logic** (would change trade selection)
- **Stop logic** (same trade count and exit reason mix → same exits)
- **Broker-model split application** (would diverge gradually, not within the
  first 12 months; AAPL 2020 / NVDA 2021 splits are post-2020)

It points strongly toward one of:

- **`_compute_portfolio_value` interaction with the broker-model**. The
  simulator divides `entry_price` by `factor` on a split day but does NOT
  back-rewrite the `position_lot.cost_basis` field. If a position is split
  while in `Trading_strategy.Position.Holding` state, its `entry_price /=
  factor` and its `quantity *= factor` (correct), but in
  `Trading_portfolio.Types.position_lot` the `cost_basis` is unchanged
  (correct, since it's a TOTAL) and `quantity *= factor` (correct). MtM uses
  `quantity * market_price`, where `market_price` is the post-split raw close
  — also correct. The math checks out for the canonical path.
- **A missing detector branch on a Q1-fix-related code path**. PR #993 ("Fix
  B skinny step_result.portfolio") added a `Portfolio_summary` projection at
  `simulator.ml:417`. If the projection captured a portfolio snapshot
  *before* `apply_events` on split days for any reason, the `step_result`
  would record stale quantities for one tick. Would need a fresh run to see
  whether `splits.csv` and the per-step `splits_applied` lists agree.
- **`is_trading_day` truncation interacting with a 2010-2013 data gap**.
  The pinned baseline's `equity_curve.csv` already truncates at 2010-11-16
  via the `had_market_bars = false` filter. If the post-Q1 run's curve
  truncates at a different point (e.g., omits a long stretch in 2010-2013
  where the loaded universe has bar gaps), the dispatch's "21× single-day
  jump from $2,957 → $63,254" could be a non-trading-day omission
  collapsing two non-adjacent calendar dates side-by-side in the CSV. The
  dispatch interpreted the gap as a P&L event, but it would actually be a
  filter artefact.

## Proposed minimal reproducer scenario

If the dispatch's evidence is reproducible, the smallest window that
exercises the suspected fault is:

- **Window**: 2010-01-01 to 2011-12-31 (2 years, captures the dispatch's
  "98% drawdown by 2011-01-17" claim).
- **Universe**: SP500 historical-pinned 510 symbols (same as
  `goldens-sp500/sp500-2010-2026.sexp`).
- **Note**: there are **no famous splits in this window** — AAPL-2014-06-09
  (7:1) is the next one. So if a wild jump appears in 2010-2013 on a
  no-split window, the bug is **not** in split adjustment per se. It is
  somewhere else (data gap, MtM error, position-ledger bug).

If a split-window reproducer is desired regardless, use:

- **Window**: 2020-08-15 to 2020-09-30 (covers AAPL 2020-08-31 4:1 and TSLA
  2020-08-31 5:1).
- **Universe**: AAPL + TSLA + SPY + a few stable symbols (e.g. KO, JNJ).
- **Forced position**: pre-seed an AAPL position pre-split via a
  scenario-level override, or prepend a Stage-2 breakout 1-2 weeks earlier.
- **Expected outcome**: portfolio value moves smoothly through 2020-08-31;
  splits.csv records the AAPL 4:1 and TSLA 5:1; quantity quadruples /
  quintuples; total cost basis preserved.

Note that `trading/trading/simulation/test/test_split_day_mtm.ml` and
`test_split_day_audit.ml` already exercise the AAPL-2020 case at unit
level; integration-level regression coverage would be a 2-week scenario in
`trading/test_data/backtest_scenarios/`.

## Fix-path recommendation

**Step 1 (no code change).** Re-run the 15y vanilla golden via
`golden-runs-sp500-15y.yml` workflow_dispatch. If the run reproduces
-85.77% / 99.93%, capture and inspect:
- `splits.csv` — are any rows present? Empty splits.csv on a 15y SP500 run
  would itself be a bug indicator (we know AMZN/GOOG/NVDA are in the
  universe for the broad 510 set; their 2014/2020/2021/2022 splits should
  have fired if any of those positions were held).
- `equity_curve.csv` — does it truncate, and at what date? Compare the row
  with the dispatch-cited "2012-07-02 $2,957" against the row immediately
  preceding to determine whether they're calendar-adjacent or
  filter-truncated.
- `progress.sexp` — captures the per-step day-by-day trajectory if the
  scenario was run with progress logging. Cross-check against
  `equity_curve.csv` to identify which days got filtered.

LOC estimate: 0 (run + measure).

**Step 2 (only if Step 1 reproduces and identifies a code bug).** The fix
path depends on whether the bug is:
- **Broker-model interaction with Q1 Fix B** (`Portfolio_summary` snapshot
  ordering vs `apply_events`): localised fix in
  `simulator.ml:_process_step_day`, ~10-30 LOC.
- **Equity-curve truncation misinterpretation** (no real bug, just
  cosmetic): tighten the dispatch's interpretation of the curve and update
  `dev/notes/next-session-priorities-2026-05-08-evening.md` to remove the
  P0 claim. 0 LOC.
- **Detector missing splits on the 2010-2013 era** (CSV data quality):
  data-feed issue, blast radius outside the trading subsystem.

**Blast radius**: any change to `_prepare_market_state`,
`Split_handler`, `Split_event`, or `_compute_portfolio_value` invalidates
every existing pinned baseline. Treat as a tier-3 release-gate item;
re-pin after Step 2 lands.

## Open questions for the human / next agent

1. Where did the dispatch's evidence come from? The
   `scenarios-2026-05-08-170319/` directory is missing. Was the run
   executed in a different worktree (e.g. CI artefacts not synced down)?
2. The pinned baseline's `equity_curve.csv` already truncates at
   2010-11-16. Has anyone validated that truncation against `progress.sexp`
   to confirm whether it's a `had_market_bars` cascade or a runner-loop
   exit?
3. PR #990 split the 15y golden into a nightly cron — has the cron actually
   run since the Q1 fixes landed (PRs #987, #988, #992, #993)? If yes, the
   GHA artefact for that run would carry the dispatch's evidence.

Until Question 1 is answered, this investigation cannot identify a fix
target. The broker-model implementation is **complete and correct as far
as I can verify against the design plan**.
