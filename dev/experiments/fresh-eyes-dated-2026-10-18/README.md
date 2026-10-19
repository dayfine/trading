# Fresh-eyes, dated picks: the scripts

Plan: `dev/plans/fresh-eyes-dated-picks-2026-10-18.md` (PR #3326). On each of 24 decision Fridays a reader that knows
only the book's rules (the 2026-10-13 rule card) and sees only charts up to that day reads the market, screens a
pool, places up to 5 orders and manages them to the exit (at most 104 weeks). The same dates are read from the
record run. This is a screen, not a verdict (plan §1).

Host only (awk, sh, jq, headless Chrome, `claude -p`); no container. The scripts reuse the 2026-10-13 study's
renderers and stepper unchanged (`render.sh`, `composite.sh`, `weekly.sh`, `step.sh` / `sim.awk`, `limit.sh`,
`dummy_agent.awk`, `results/rulecard.md`, `results/market/*`). Outputs go to `.sweep-output/fresh-eyes-dated/` and
are not committed.

## Run (repo root)

```sh
S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
sh $S/dates.sh --pilot                       # 2002-02-22 2009-01-16 2017-07-14 (no draw falls in calendar 2008)
sh $S/run.sh --pilot                         # the 3-date pilot, live (Opus A/D/follow, Sonnet C), guarded
REP=r1 sh $S/run.sh 2017-07-14               # a self-consistency repeat (plan §6 read 5) -> 2017-07-14-r1
sh $S/run.sh --all                           # all 24 dates (results/dates.txt)
sh $S/compare_dates.sh .sweep-output/fresh-eyes-dated/run   # the §6 reads again (run.sh calls it at the end)
AGENT_STUB=1 OUT=.sweep-output/fresh-eyes-dated/dry-run sh $S/run.sh 2017-07-14   # dry run: no model calls
sh $S/causality_check.sh                     # the new thumbnail renderer: "causality check (thumb): PASS"
```

Before the pilot, read `sh dev/scripts/quota_status.sh` (and again after it: the delta is the dollar-to-quota
conversion the plan asks the pilot to measure).

Env: `DATA` (daily store, default the parent repo's `data/`), `REC` (the record's artifacts, default the parent
repo's `.sweep-output/breadth-pair-N`, not committed), `OUT`, `JOBS` (1 or 2), `MODEL_A/C/D/F`, `GUARD` (0.85),
`QUOTA_CMD`, `BOOKDIR` (a folder outside the repo holding only `book.txt`; never committed or printed),
`MARKET_PAGES` (the pre-rendered market pack of the 2026-10-13 pilot).

## Scripts

| script | plan | does |
|---|---|---|
| `dates.sh`, `dates.awk` | §2 | the stratified draw (24 blocks, seed 20261018); `--pilot` the date nearest 1 July of 2002 / 2008 / 2017. `results/dates.txt` is the committed draw |
| `ours.sh`, `ours_top.awk` | §5 | from the record (rb1 + full NYSE A-D, 26y, salts 0-2): the week's cascade header, the screener's decision list (outcome or skip reason), and our entries in the 4 weeks after the date with their exit, total return, SPY leg and 104-week path |
| `pool.sh`, `pool_scan.awk`, `pool_pick.awk` | §3 B | PIT top-3000 members alive on the date, in the favoured groups, close within 25 % of the 52-week high, 20-day dollar volume >= $1M; our list always added; capped at 120; pseudonyms and the pseudonym store |
| `thumb.awk`, `sheets.sh`, `shot.sh` | §3 C | 5-year thumbnails under pseudonyms, 20 to a sheet (2400 x 2000 px) |
| `ask.sh` | §8 | one fresh reader call (or the stub); stops on a limit reply (exit 7), never retries; reuses an existing answer |
| `day.sh`, `stub.awk` | §3 A-D | market + groups, pool, screen, close look, orders |
| `follow.sh`, `weeks.awk`, `plus.awk` | §4 | each order in the stepper: fill or expiry at 8 weeks, stop run daily, looks at the fill and every 8 weeks, end at the exit or 104 weeks |
| `path.awk` | §4, §5 | a trade on the adjusted basis plus its path to 104 weeks after entry |
| `compare_dates.sh`, `compare.awk`, `overlap.awk`, `consist.awk` | §6 | reads 1-5 |
| `run.sh` | §8 | the driver: quota guard per date, `STOP` file, at most 2 dates in flight, restartable |
| `causality_check.sh` | — | thumbnails drawn from data cut at t equal those drawn from the full data |

## Blinding and what the reader sees

- **Pseudonyms everywhere.** `pool.sh` gives each pool name four random capitals and builds a store of symlinks
  under them, so the 2026-10-13 renderers draw every page, thumbnail, last-bar JSON and file name under the
  pseudonym. Sector stays hidden ("sector not shown"). Real price levels are kept. Our names are mixed into the pool
  in a random order and are not labelled.
- **Fresh context per call.** Each call is a new headless `claude -p` from an empty folder outside the repo, with
  Grep reaching only `BOOKDIR`. A follow-up look sees the status block (position, entry, stop), not its earlier
  reasoning.
- **Not built:** the plan's two-call date-axis test (§3: the same chart with and without the calendar axis). The
  thumbnails and composites show years.

## Choices made in the build (open to change before the pilot)

- **No drawn date is in calendar 2008.** Blocks 8 and 9 drew 2007-12-14 and 2009-01-16. The pilot takes the one
  nearer 2008-07-01, 2009-01-16, which is inside the 2007-09 bear market. On it the record's macro gate was Bearish,
  so our decision list is empty (`ours/week.csv` records it). The plan's "covers 2008 by construction" holds for the
  bear market, not for the calendar year.
- **Unknown-sector members stay in the pool** (`POOL_UNKNOWN=1`). `data/sectors.csv` is survivor-only, and dropping
  those members would leave mostly survivors. The cost is that they pass the group filter whatever the groups: on
  2017-07-14, 51 of 120 pool names had no sector.
- **Our list is the union over the three salts** (19 names on 2017-07-14; the cascade's decision list, which is at
  most the top 20 after the held names).
- **Over 120 filter passers:** a seeded random draw, not a ranking, so the pool is neutral.
- **Shortlist and order caps across calls.** Each sheet call returns at most 5 scored picks, and the 10 best scores
  over all sheets make the shortlist. Each close look rates conviction, and the 5 highest-conviction orders on the
  step-A side are placed.
- **Orders the stepper rejects** (for example a stop above the trigger) are recorded as `rejected`, with no re-ask.
- **Not built:** the plan §5 off-diagonal cells (the reader's entries run under our stops, which needs the OCaml
  stop machine; our entries under the reader's looks). The trades and paths are recorded so these can be added.

## Dry run (2026-10-18, no model quota spent)

- **Run:** `AGENT_STUB=1 run.sh 2017-07-14`, plus 2009-01-16 and a repeat `REP=r1`. The stub is `stub.awk` for
  steps A and C and the 2026-10-13 `dummy_agent.awk` for D and the looks.
- **2017-07-14, 159 s wall.** Steps:
  - ours: 57 decision rows, 6 entries;
  - pool: 120 names (19 ours), 60 s;
  - sheets: 6, 30 s;
  - calls: 17 stand-in calls for A, C and D, then 14 look calls;
  - result: 5 orders, all filled and stopped, 1 to 5 looks each.
- **2009-01-16:** side neither, so no orders.
- **r1 repeat:** pick Jaccard 1.00. The stub is deterministic, so this checks only the plumbing.
- **compare_dates.sh** printed reads 1 to 5. Read 4 was checked separately with a synthetic shared trade.
- **follow.sh endings**, checked on hand-made orders: `cap104` (a 104-week hold, MSFT) and `expired` (an order that
  never filled).
- **Guards:**
  - the quota guard, faked to exit 3, stopped the run before the first date, wrote `STOP` and started no date;
  - a fake `claude` that returned a session-limit reply made `ask.sh` exit 7, so `STOP` was written and nothing
    retried;
  - a fake `claude` with a valid answer exercised the live call path: the arguments, the empty working folder, two
    inline images plus text, and the `calls.csv` row;
  - a rerun with the `done` marker removed made no new calls.
- **Blinding:** no real ticker appears in any prompt, answer, page JSON or SVG under the date dir (grep). Real
  tickers appear only in `pool.csv`, `orders.csv` and the results.
- **Causality:** `causality_check.sh` passes for the thumbnails (3 symbols x 4 cuts), and the 2026-10-13
  `causality_check.sh` passes for the reused renderers.
