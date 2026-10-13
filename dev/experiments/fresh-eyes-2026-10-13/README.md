# Fresh-eyes study — step 1: the sample and the charts

Plan: `dev/plans/fresh-eyes-weinstein-2026-10-13.md` (PR #3298). This directory holds step 1 of its build order (§7):
the sample, the weekly series, the market series and the chart renderer. Nothing here reads our strategy code; the
fresh agent will only ever see the PNGs and the last-bar JSON these scripts write.

## Run (repo root, host only: awk, sh, headless Chrome; no container)

```sh
E=dev/experiments/fresh-eyes-2026-10-13
DATA=data sh $E/scripts/sample.sh          # results/pool.txt, results/sample.txt   (~4 min)
DATA=data sh $E/scripts/market.sh          # results/market/*.csv                  (~10 min)
DATA=data sh $E/scripts/render.sh AAPL 2008-06-27 .sweep-output/fresh-eyes/demo    # stock: 2 PNG + JSON
DATA=data sh $E/scripts/render.sh MARKET 2008-06-27 .sweep-output/fresh-eyes/demo  # market pack: 2 PNG
DATA=data sh $E/scripts/causality_check.sh # must print "causality check: PASS"
```

`DATA` is the daily store (`data/<first char>/<last char>/<SYM>/data.csv`). In a worktree without the store, point
it at the main checkout's `data/`. PNGs go to `.sweep-output/` and are not committed.

## What is committed

| file | what |
|---|---|
| `results/pool.txt` | `symbol first_list_year weeks`: every PIT top-3000 list member with >= 156 weekly bars in 2000-01..2026-06 (7,998) |
| `results/sample.txt` | `stratum symbol first_list_year`: 20 per first-list-year stratum, seed 20261013 (100) |
| `results/market/spy-weekly.csv` | SPY weekly bars, 30-week MA (`weekly.sh SPY`) |
| `results/market/ad-weekly.csv` | cumulative A-D line, weekly, with its source per week |
| `results/market/sector-strength.csv` | per (week, sector): median 26-week return of the PIT list members, n, SPY's 26-week return, rel = median - SPY |

**Stratum fold.** The lists start in 1998, so the first stratum, "2000-04", is first list year <= 2004 and includes
1998-99 ("already a member when the lists begin"): 2,845 of the 7,998 pool members, and 16 of the 20 drawn in that
stratum.

The draw uses the macOS `awk` `rand()` sequence; `sample.txt` is the record, so a different awk only matters for a
re-draw.

## Scripts

| script | does |
|---|---|
| `days.awk` | calendar helpers (civil days, the Friday of a week) |
| `sample.sh` | pool + stratified seeded draw (plan §2) |
| `weekly.awk`, `weekly.sh` | daily -> weekly bars keyed by Friday; 30-week MA; Mansfield RS vs SPY (52-week); volume in base shares. `weekly.sh SYM <date>` truncates the daily input at a date first |
| `ad.awk` | the A-D line (see the splice below) |
| `sector.awk`, `fridays.awk`, `market.sh` | sector strength over every Friday 2000-01-07..2026-06-26 (sector.awk is the setup map's, with the symbol taken from the path's parent dir) |
| `chartlib.awk`, `chart.awk`, `market.awk` | SVG: frames, scales, panels, the grey future block |
| `lastbar.awk`, `render.sh` | SVG -> PNG via headless Chrome; the last bar as JSON |
| `causality_check.sh` | truncated-input vs full-input SVGs must be byte-identical |

## How the charts avoid the future

- **Every cut is rendered fresh from bars <= the cut.** Covering the future on a finished image would leak it through
  the y-axis, which would already span later highs and lows. So each cut gets its own scales, and the area to the
  right of the cut is a grey block labelled "future (hidden)".
- **The full frame has a fixed x-axis, 2000-01..2026-06,** for every symbol and cut, so its width says nothing about
  when the data ends. The 5-year frame is the 260 weeks to the cut plus 26 grey weeks.
- **Price level.** The vendor's adjusted close is back-adjusted from the data end, so its level encodes later splits
  and dividends (AAPL in 2000 would show about $0.80). The chart rescales the whole series so the cut week's close is
  that day's raw close; ratios between bars, and so the shape, the MA and RS, are unchanged, and only actions up to
  the cut remain in the numbers.
- **Volume.** The vendor's volume is already split-adjusted to the data end (AAPL 2014-06-06: 349.9M, about 28x the
  raw count: 7:1 in 2014 x 4:1 in 2020). `weekly.awk` stores it in base shares (divided by the product of all split factors) and the chart
  multiplies by the split index at the cut, so volume reads in that date's shares. If `splits.csv` misses a split,
  volume shows a step there.
- **The check.** `causality_check.sh` draws each test chart twice, from the full data and from data cut at `t`, and
  requires identical bytes.

## Two things on the page that would leak the future, and what the renderer does

- **Reused-ticker names.** The store names reused tickers `DO_old`, `INFO_old1`, `SDS1`, which says the company
  later lost the ticker. The page shows the ticker as traded (`_old[N]` or trailing digits removed), and the output
  files are named by that display ticker too (`render.sh` refuses if two sampled symbols share one display name).
- **Missing sectors.** `data/sectors.csv` is survivor-only: 44 of the 100 sampled symbols have no row (1 of 20 in the
  2020-25 stratum, 9 to 12 of 20 in each older one), so a missing sector is mostly a sign of a name that did not
  survive. Printing "sector unknown" would tell the reader the stock dies, so the stock page
  hides the sector for every symbol ("sector not shown"); `SHOW_SECTOR=1` shows it. **Open decision for the plan:**
  the reader then cannot place a stock in its group from the page; a non-survivor sector source would fix both.

## Known data caveats (the chart states the first one)

- **A-D splice.** NYSE advances and declines (`trading/test_data/breadth/nyse_*.csv`) run to 2020-02-14, but the last real day is 2020-02-10 (02-11..14 and later rows are
  zero placeholders, skipped). After 2020-02-14 the line uses the universe-computed synthetic counts, whose mean |net| is 4.5x smaller
  (`ad.awk` prints the ratio: 4.5262 over 1999-01-01..2020-02-14). `ad.awk` scales their net by that ratio, a
  constant fixed from data before every post-splice date. The chart draws a dashed line at the splice and says so in the panel label.
  There is no level jump (the line is cumulative), but the synthetic breadth is a different population (the stock
  universe, not NYSE issues incl. closed-end funds and preferreds).
- **Sector strength ends 2026-05-29.** The PIT lists end with list year 2025, which applies until 2026-05-30; later
  weeks have no members. Cuts after that show the 2026-05-29 sector values.
- **Sector medians use the survivor-only map**, so early-year medians rest on fewer members; `n` is in the CSV and
  on each panel.
- **Shared sector y-range** is capped at +-40 % and lines clip there, so one outlier sector (Energy 2021) does not
  flatten the others.
- **The causality check cannot see the vendor adjustment.** Truncating the daily file leaves the vendor's
  `adjusted_close` column as it was, so the check proves the series and scales are trailing but not that the price
  level is; the rescale to the cut's raw close is what removes later actions from the level (argued above).

`demo.sh` renders the step-1 demo set (RMD 2002-10-11 and 2008-10-10, TWTR 2015-06-26 and 2021-12-31, MP 2021-12-31
and 2024-06-28, the market pack at 2008-10-10 and 2021-12-31) into `.sweep-output/fresh-eyes/demo/`.
