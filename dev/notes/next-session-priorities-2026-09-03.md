# Next-session priorities — 2026-09-03 (post arc-rerun session 09-01/02)

Supersedes `next-session-priorities-2026-09-01.md` (whose P0, the #2408
stop-anchor read, is untouched and still open — see P2).

## What landed (all merged, main green at `7da7f249c`)

- **#2645** the arc-rerun record (D1–D5 dissection) and **#2647** its
  follow-up (ladder, fix-armed cells, 3-window grid, splice phantom,
  warehouse-vintage caveat) — #2647 is open, needs QC + merge.
- **#2644** `sim_exit_fill_next_open` (D1: Friday-tick exits were filling at
  Friday's OPEN on the Saturday calendar step) and **#2642**
  `stops_config.stop_skip_entry_bar` (D2: a fresh position's stop judged on
  its own entry bar's pre-fill low). Both default-off; both verified absent
  at 5y and 26y with the flags armed.
- **#2641** validator V13 (fill date has a bar, price inside its range) and
  V14 (entry-bar stop-out), 47 tests, every Skip branch mutation-caught.

## P0 — decide the D1/D2 default flip (user decision, then paired goldens)

The two fixes are correctness fixes, not strategy mechanisms, but they move
every golden (the record's Friday stop/laggard triggers were filled at
Friday's open: −$0.6M first-order on the 26y record). Flipping them on by
default needs the `config-default-blast-radius` protocol: paired goldens
(base vs flag) for every golden that arms Friday-tick exits, i.e. all of
them; a `promotion` PR with the table; the `paired-run-done` label. Until
then every new experiment must ARM both flags explicitly
(`((sim_exit_fill_next_open true)) ((stops_config ((stop_skip_entry_bar true))))`)
or its exit-lever reads are contaminated (`project_lever_reads_invert_on_fixed_sim`).

## P1 — data integrity: ticker splices in the warehouse (#2646)

`CHS` 2004-12-20 is a different security under the same symbol (adj_close
4.07→15.88, volume 5M→1M) and produced a +$513,550 phantom trade the moment
the Monday-open fill hit that bar. 184 tradeable splices / 145 symbols in
`/tmp/snap_top3000_dedup_v5thin_adj`; 10 trades across this session's runs
were affected, both signs (ICT −$169k in the unfixed 26y arc, AGR −$220k,
STMP −$200k). Build-time continuity gate + a V15 post-run check (|pnl| >
100% with days_held ≤ 5 and an adj_close jump on the entry/exit bar). Any
2004/2006/2014/2021-window number read before this is suspect at the
±$0.1–0.5M scale.

## P1 — warehouse vintage (`project_warehouse_vintage_coverage`)

The warehouse is the 2000-vintage composition: 94% of top-3000-2000, 32% of
top-3000-2019. Every "broad-5y cell B" result to date ran on ~980 survivor
names. Within-cell A/B is valid; levels and cross-window comparisons are
not. Build vintage-specific warehouses (2009, 2019) before any level claim
on a post-2005 window.

## P2 — carried

- #2408 stop-anchor surface read (sa2408 results on `wip/sa2408-specs`,
  never PR'd; now also suspect under P0's caveat since the anchor moves
  exits).
- The arc's structural deficit (D3/D5): what the ticket buys and when. The
  grid says neither the eject gate nor the fallback-stop width is the lever
  on the fixed simulator. Next candidates are entry-side: trigger the
  ticket off the weekly bar (confirm on the weekly close, not the first
  intraday touch), and the anchor as a base top rather than a 4-week high
  (26-week anchor moved little). Per the user (09-02): iterate on 1y/3y/5y
  broad windows first; 26y is confirmation-only.
- Ops: two unexplained multi-hour stalls this session (an 11h gap inside
  the first 26y run, a 2h15m gap between two tool calls) — host awake, VM
  clock skipped. Check the clock on every resume
  (`feedback_two_stall_classes_check_clock`).
- Agent hygiene: 4 of 7 dispatches parked on a backgrounded dune despite
  the NO-WAITING header; scoped targets + a pid-specific nudge recovered
  them (`feedback_agents_background_wait_stall`).

## Do not

- Do not compare warehouse-basis numbers to CSV-basis goldens.
- Do not quote any g19 (2019–23) level as "broad".
- Do not cite the unfixed-simulator exit-lever verdicts (eject on/off, stop
  width, TTL/clock, laggard timing) without re-measuring with the flags armed.
