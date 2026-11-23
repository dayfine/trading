# NAV-scaled liquidity: does account size change what the strategy can buy? (pre-registration)

User, 2026-11-22: run the record at $100k / $1M / $10M starting cash. With a liquidity rule that scales with the
**current** portfolio value, position size sets which names fit, so the three accounts should trade different sets.
Measure how much the outcomes differ. Issues #3681 (the participation gate, merged #3695), #3693 (live-size picks,
merged #3698) and #3696 (scenario `initial_cash`, #3697).

This file is committed before any cell runs. Nothing below changes after the first result.

## Arms (6 configs × K=5 seeds = 30 cells)

All arms start from the record spec `dev/experiments/record-kseed-2026-10-27/specs/rk-k{0..4}.sexp`: 26 years
(2000-01-01 → 2026-06-26), PIT top-3000 schedule, `tiebreak_seed` k, on one build (main at the commit that merges
#3697). Only two things vary.

| arm | `initial_cash` | liquidity |
|---|---|---|
| F-100k | 100,000 | record: fixed `min_entry_dollar_adv` $1M, `min_hold_dollar_adv` $500k |
| F-1M | 1,000,000 | record (this is S, the record itself) |
| F-10M | 10,000,000 | record |
| P-100k | 100,000 | `max_entry_adv_participation 0.10`, `min_entry_dollar_adv` $100k (dust floor), `min_hold_dollar_adv` $50k |
| P-1M | 1,000,000 | as P-100k |
| P-10M | 10,000,000 | as P-100k |

The P overrides are exactly `dev/weekly-picks/live-size-overrides.sexp`, so the backtest arm matches the live
profile. Sizing (`max_position_pct_long 0.14`, `min_cash_pct 0.30`) is the record's in every arm. Account size is the
only change across columns.

## Tripwire and validity

- F-1M k0 must reproduce the record's `trades.csv` md5 at the run build (the lane `TRIP_MD5`). If it does not, stop.
- V6 runs on every P arm against the F arm at the same cash and seed.
- **Liveness:** a P arm counts as live at a cash level only if its `trades.csv` differs from the F arm at the same
  cash on at least 3 of 5 seeds, and `Adv_participation_cap` appears in the trade audit. A dead arm gets no read.

## What is measured (per arm, median over seeds)

1. Final log NAV ratio, `ln(final / initial)`, so the three cash levels are comparable.
2. Max drawdown and the Ulcer index.
3. Share of entries at or below $14 (raw entry price), and the funded-doubler count among them.
4. Count of entries blocked by `Adv_participation_cap` and by the $1M floor, per year.
5. Median position as a share of 20-day dollar ADV at entry, per year. This shows the convergence: as each account
   compounds, the gate should bind harder.

Every metric is reported for three periods as well as the whole run: 2000–08, 2009–16, 2017–26.

## Decision rule (fixed now)

The paired read is P minus F at the same cash and seed, Δ = ln(P_final / F_final).

- **P-100k (the live question).** If the median Δ ≥ +0.20 with ≥ 4/5 seeds positive, and the median max-DD is not
  more than 3 pp deeper: the live-size profile earns its place, and the next step is a scope cell on top-1000
  (`universe-discipline.md`). If the median Δ is in (−0.20, +0.20): no measurable effect at live size, and the
  profile stays opt-in. If the median Δ ≤ −0.20 with ≥ 4/5 seeds negative: cheap names hurt at live size, so do not
  use the live-size profile for live picks.
- **P-1M (the #3681 verify item).** The same thresholds, read against the record. The 11-18 arithmetic predicts about
  +0.06. A result inside ±0.20 is the expected outcome and closes #3681's verify item as "no effect at backtest NAV".
- **P-10M** is descriptive only, with no decision: it shows the capacity limit.
- **F across cash levels** is descriptive: how much of any difference is account size alone (whole-share rounding,
  the $1 minimum commission) and how much is the gate.

A Δ inside the 26-year path-noise floor (0.2 log, `project_26y_path_noise_floor`) is reported as no effect, whatever
its sign.

## Known confounds, stated in advance

- **Whole-share rounding.** At $100k a 14 % position is $14k, so names above about $14k a share size to zero. This
  hits F and P equally, so it cancels in Δ, but it shapes the F-across-cash comparison.
- **The $1 minimum commission** weighs more at $100k. The cancellation is the same as above.
- **Compounding.** Each account grows, so the gate binds harder late in the run. Measure 5 tracks this. It is the
  effect under study, not a flaw.
- **One market.** The five seeds share one price history, so Δ seeds are not independent draws. A ≥ 4/5 sign count is
  a consistency check, not a significance test.

## Run plan

Cloud sessions, as for the observatory lanes. 30 cells at about 2 h each. Price-bearing outputs (`trades.csv`,
equity curves, positions) go to trading-results under this directory's name. Mark-free summaries and the read are
committed here. The read is drafted by `results-analyst`, then reviewed by `qc-results`.
