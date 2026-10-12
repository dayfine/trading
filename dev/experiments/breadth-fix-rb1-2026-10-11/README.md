# breadth-fix-rb1-2026-10-11: the record with and without the NYSE A-D breadth gap (#3238)

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

## Why

Until #3252, `trading/test_data/breadth/nyse_{advn,decln}.csv` held one 1965 row, then 2017-01-02 onward.
`Ad_bars.load` filled only the tail from Synthetic, so every 26-year run had no A-D breadth from 2000 to 2016.
The A-D inputs to the macro composite sat at a constant over those 17 years. The macro composite gates every long
entry (spine rule 6).

#3252 commits the full Unicorn archive and fills interior holes from Synthetic. On CI goldens it moved
`bull-crash-2015-2020` from −9.9 % to +36.4 % and `sp500-2010-2026-longshort` from 406 % to 675 %. Those are
small-universe cells, though, not the record. This experiment is the [after-merge] item of #3238: does the record
move?

## Design

- **Spec:** `specs/rb1-26.sexp`, the record spec from `rebaseline-v12-2026-10-08`, unchanged byte for byte below
  its header line.
  - Investor preset, 2000-01-01 → 2026-06-26.
  - Top-3000 PIT v12 schedule, total return (interest + dividends).
  - Warehouse `/tmp/snap_top3000_pit_v12pit`. Salts 0, 1, 2.
- **Arms** differ only by run tree. Both trees are pinned worktrees.
  - **O:** main just before the #3252 squash, with the old fixture.
  - **N:** the #3252 squash, with the full fixture and the interior-gap fill.
  - `launch.sh` aborts unless O's `nyse_advn.csv` has < 1,000 rows and N's has > 13,000.
  - It also aborts unless the schedule lists hash the same in both trees.
- **Same build:** lane O re-runs s0 first, and the driver compares it with `rebaseline-v12`'s `rb1-26-s0`
  (`trades.csv`, `actual.sexp`, `equity_curve.csv`).
  - If they are identical, the old rb1 s1/s2 cells stand as O's partners.
  - If not, lane O runs s1 and s2 too, and only lane O's cells pair with N.
- **Order:** one 26-year cell at a time, so 4 to 6 cells at about 3 h each (rb1 cells took 10,091–11,881 s).
  `CELL_TIMEOUT` is 36,000 s.

## What is read (per salt, then across salts)

1. **V6 gate.** Each N cell runs `validator_diff -check V6` against its same-salt O partner, and must exit 0. A
   V6 mismatch means that salt yields no delta.
2. **Macro change.** From `macro_trend.sexp`, the number of weekly readings whose `trend` or `breadth_state`
   differs between O and N, by year. They should concentrate in 2000–2020.
   - 2017–2020 can move too: the A-D momentum average spans about 200 weeks.
   - Any change after 2021 is a flag to trace.
3. **Record delta.** N − O on:
   - total return (log and %), CAGR, max drawdown, Sharpe, Calmar, trades;
   - the bear periods 2000-03-24 → 2002-10-09, 2007-10-09 → 2009-03-09 and 2022-01-03 → 2022-10-12;
   - the year table vs SPY total return.
4. **Where it comes from.**
   - Entries gained and lost (joined on `symbol|entry_date`), and the P&L of each set.
   - The weeks whose macro reading flipped and what was bought in them.
   - The largest contributors, traced end to end.

## Decision (fixed now)

This is a data correction, not a mechanism, so there is no accept/reject.

- **The N arm replaces rb1 as the record** whatever the direction of the delta: `project_investor_preset_broad` and
  the ledger are updated, and every later 26-year comparison pairs against N.
- **If any salt fails V6,** that salt is excluded. If two salts fail, the record is not replaced, and an issue is
  filed with the specimen.
- **Earlier 26-year verdicts** ran on the frozen A-D input. The writeup lists those that rest on a macro-gate effect,
  any of which could read differently on N:
  - macro-suspend (#3123);
  - the index-stage veto;
  - the shorts Phase B exposure path;
  - the D1/D2 and A-D default flips.
  Re-running them is not part of this experiment.

## Review

- A review pack for N s0–s2, rendered and looked at (`backtest-result-review.md`).
- The reading goes to `results-analyst`. The results PR goes to `qc-results`.

## Files

- `results/launch.sh`: run trees, input checks, staging, starts the driver.
- `results/driver-bp.sh`: lane order and the replay check.
- `results/chain-bp.sh`: a copy of `chain-rb12.sh` with paths moved and a cross-lane `PAIR_ART`.

## Log

- 2026-10-11: pre-registered. Sequencing per the user (2026-10-11): this experiment runs before the index-short
  overlay screen (`dev/plans/index-hedge-screen-2026-10-11.md`), whose base is the N arm.
