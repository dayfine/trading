# Short wide-top screen — pre-registration (2026-10-13)

Option (b) of the 10-13 shorts-track decision (`dev/notes/next-session-priorities-2026-10-13.md` §3). The user chose
(b) and (c): run this one cheap screen; the track stays open (idle, flags as default-off axes) whatever it shows.

**Why this screen.** The setup map (#3286) found the book's Stage 3 → 4 short loses to an SPY short, partly because
our stage classifier's Stage-3 sliver is 1–2 weeks wide, so the "above the top" stop sits close. This screen defines
the top by price alone — a late-Stage-2 52-week high followed by a slow roll-over — so the top is wide and the stop
sits above the right shoulder, independent of our classifier.

This file is committed before any number is computed. Nothing below changes after results exist; a change is an
amendment with its own commit and reason.

## Universe, period, dedupe (identical to the setup map)

- PIT top-3000 v12 yearly lists (`dev/experiments/short-setup-map-2026-10-12/results/membership.txt`); list Y applies
  from Y-05-31. The symbol must be a member at the breakdown week.
- Raw close ≥ $5 at the breakdown week ($17 as a robustness line).
- Breakdown weeks 2000-01-07 .. 2025-12-26.
- One event per symbol per 182 days (the first kept).
- Never sp500.

## Data

- Daily bars from `data/<a>/<b>/<SYM>/data.csv`; SPY from `data/S/Y/SPY/data.csv`. Adjusted (total-return) prices
  for every level, stop and return: adjusted open/high = raw × adjusted_close / close. Raw close only for the floor.
- Weekly bars built from the daily bars, weeks ending Friday (a week = trading days Sat..Fri). Weekly close = last
  daily adjusted close of the week; weekly high = max daily adjusted high.
- 30-week MA = simple mean of the last 30 weekly adjusted closes, computed here. Our stage classifier's output is
  not used for the event definition.
- SPY phase for the split only: the index-hedge screen's committed SPY weekly stage
  (`dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv`), the row at or before the breakdown
  week: s4_early (Stage 4, run ≤ 8 weeks), s4_late, s3, s12.

## Event definition (price-defined wide top)

- **H** (the top week): a week whose weekly high is the highest weekly high of the trailing 52 weeks (including
  itself; at least 52 weeks of history), with weekly close ≥ the 30-week MA (late Stage 2).
- **Breakdown week i** for that H: the first week with H + 8 ≤ i ≤ H + 52 such that
  - weekly close at i < the lowest weekly close of weeks [H − 8, i − 1];
  - weekly close at i < the 30-week MA at i;
  - 30-week MA at i ≤ 30-week MA at i − 4.
- A later H with the same breakdown week yields the same event; the 182-day dedupe keeps the first.
- **Entry E1** = the next daily bar's adjusted open after the breakdown week's last bar.
- **Stop** = 1.01 × the highest daily adjusted high of the right shoulder, weeks [H + 1, i − 1] (skip the event if
  that range is empty). **Room** = stop / entry − 1.

## Outcomes (as `short-setup-map-2026-10-12/scripts/events.awk`)

- **O1** +20 / +60 / +120 trading days: short return minus an SPY short over the same days,
  (1 − P_t / P_e) − (1 − S_t / S_e). Past the data end, the last bar.
- **O2**: hold the short to 120 bars with the stop. If entry ≥ stop, stopped at the next open. Else the first bar
  whose high ≥ stop fills at max(open, stop) if the open ≥ stop, else at the stop. Excess vs an SPY short to the exit
  bar.

## Decision rule

1. **O1 +60 first.** If its beat rate (share > 0) < 55 % or its median ≤ 0 → **CLOSE (no-build)**.
2. Else **O2**: EDGE only if n ≥ 100, mean ≥ +2 %, median > 0, beat ≥ 55 %, halves (breakdown years 2000–2012 vs
   2013–2025) same sign of mean, and O1 +60 mean the same sign as O2 mean. Otherwise no edge → CLOSE.

## Reported (descriptive, no further decisions)

n, mean, median, p10/p25/p75/p90, beat for O1 +20/+60/+120 and O2; halves; room split (≤ 15 / 15–30 / > 30 %); SPY
phase split; bear years 2000–02, 2007–09, 2022; a ±100 % clipped line; the $17 floor.
