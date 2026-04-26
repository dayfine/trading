# Panel-mode RSS spike — post-Stage-4-PR-B (2026-04-26)

Sibling of `dev/notes/panels-rss-spike-2026-04-25.md`. Re-run on the
same `bull-crash-292x6y` cell after Stage 4 PR-A (#584) + PR-B (#588)
landed on `main`.

## Setup

Identical to the 2026-04-25 spike, except `--loader-strategy panel`
removed (Stage 3 PR 3.4 deleted the flag; panel mode is the only path).

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 \
    --override "((universe_cap (292)))"
```

Single run, no warmup, no memtrace, no trace flag. Container
`trading-1-dev`, opam env, panel build on commit
`spwwlqzt f072dad1` (`feat(data-panels): Stage 4 PR-B (#588)`).

## Result

| Mode | Peak RSS | Wall | Source |
|---|---:|---:|---|
| Pre-3.2 Legacy | 1,872 MB | n/a | bull-crash sweep 2026-04-25 |
| Pre-3.2 Tiered | 3,744 MB | n/a | bull-crash sweep 2026-04-25 |
| Post-3.2 Panel (pre-A+B) | 3,468 MB | 6:00 | spike 2026-04-25 |
| **Post-PR-B Panel** | **1,944 MB** | **4:11** | **this run** |
| Plan target | < 800 MB | n/a | columnar plan §Memory targets |

`Maximum resident set size = 1,991,280 kB → 1,944 MiB`. Wall
`4:10.77` (250.77 s). User CPU 248.43 s; system 2.00 s; 99% CPU.
Exit 0.

## Verdict

**PRs A+B drop peak RSS by 44%** (3,468 → 1,944 MB) and wall by 30%
(6:00 → 4:11) on the same cell. The dominant `Daily_price.t list`
allocation at every reader site (the wedge identified in the
2026-04-25 note) is now gone — strategy callees consume callbacks
into panel cells directly, no list ever materialised.

Still **~2.4× the 800 MB target**. The remaining ~1.94 GB is not
list intermediates; the next suspects are:

1. **No `Ohlcv_weekly_panels`** — every weekly read still rolls up
   on the fly from the daily panel via `_aggregate_weekly` in
   `Bar_panels`, allocating fresh float arrays per call. Stage 4 PR-C
   addresses this with a Friday-rollup weekly panel.
2. **MA precompute per call** — `Stage._ma_values_of_closes` /
   `Panel_callbacks` recomputes the SMA/EMA over closes every time
   `stage_callbacks_of_weekly_view` is called. Stage 4 PR-D ports the
   stage classifier / volume / resistance to indicator kernels with
   panel-resident output, eliminating the per-call recompute.
3. **Float-array buffers per `weekly_view_for`** — each call
   `Array.create_len:n_max` for highs/lows/closes/volumes. Could be
   pooled or flipped to `Bigarray` slices for zero-copy. Probably
   PR-D-adjacent cleanup.

## Recommendation

PR-C is the next memory-critical step (eliminates per-tick weekly
rollup). PR-D follows. After both, re-run this spike; if still
> 800 MB, memtrace per the 2026-04-25 note's "If the next spike is
still > 1 GB" branch.

A+B alone are the load-bearing wins (44% RSS, 30% wall). The
projection error in the original plan was treating "drop list
intermediates" as the whole story when it's roughly half of it.

## References

- Pre-A+B baseline: `dev/notes/panels-rss-spike-2026-04-25.md`
- Plan §Stage 4: `dev/plans/columnar-data-shape-2026-04-25.md`
- Status: `dev/status/data-panels.md`
