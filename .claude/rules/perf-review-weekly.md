# Weekly perf review — ~2 h every week, runtime AND peak RAM, per workload shape

User instruction 2026-09-20: *"we should have performance test if we don't yet
(to measure runtime and peak RAM) — and we should dedicate ~2h every week doing
so."* Said after salt 1 of the index-veto arm died on the chain's 36,000 s
cell guard at 92.5 % done (last completed date 2024-05-31, ~10 h wall) — the
arm runs ~43 % slower than its null, nobody had measured that, and the guard
had been sized off the null.

## What already exists (do not rebuild it)

| tier | script | trigger | measures |
|---|---|---|---|
| 1 | `dev/scripts/perf_tier1_smoke.sh` | `perf-tier1.yml`, REQUIRED PR check | wall + peak RSS (GNU time) |
| 2 | `dev/scripts/perf_tier2_nightly.sh` | `perf-nightly.yml`, 05:00 UTC daily | same, `;; perf-tier: 2` cells |
| 3 | `dev/scripts/perf_tier3_weekly.sh` | `perf-weekly.yml`, Monday 07:00 UTC | same, `;; perf-tier: 3` cells |
| 4 | `dev/scripts/perf_tier4_release_gate.sh` | manual / local | same |

Peak RSS parsing is shared via `dev/lib/gnu_time_rss.sh` (#2553/#2559). The
cache diagnostics line (`Panel_runner: snapshot cache hits=… misses=…`) plus
the handle cap (`SNAPSHOT_MAX_MMAP_HANDLES`, #2839) are the per-run signals.

## The three gaps the weekly hour-pair closes

1. **No tier runs the shape that costs us.** Every tier-2/3 cell is sp500 or
   a 1–3y synthetic sweep. The workloads that actually burn the container —
   broad top-3000 5y, and the PIT 26y cell (6–11 h, 118M cache misses per
   cell) — have never been in a table. The mmap-handle thrash was found by
   hand four months after the v2 warehouse shipped.
2. **FAIL rows are invisible.** `perf-nightly.yml` / `perf-weekly.yml` run
   with `continue-on-error: true`; on 2026-09-14 the weekly table carried two
   FAIL rows (`sp500-2010-2026*`, ~4,750 s) and the workflow reported success.
3. **Nobody reads the table week to week.** Drift only surfaces when a cell
   dies.

## The weekly routine (~2 h, same day each week, logged)

1. **Read the tables** — latest `perf-nightly` and `perf-weekly` runs
   (`gh run list --workflow perf-weekly.yml --limit 1`, then `gh run view
   <id> --log | grep -E 'PASS|FAIL'`). Compare wall + peak RSS to the prior
   week's row. A FAIL row, or a > 20 % wall or RSS move on any cell, becomes a
   ticket **that week** (label `kind/harness`, name the cell and both
   numbers).
2. **Keep one cell per real workload shape.** Minimum catalog: sp500 5y
   (exists), broad top-3000 5y, and a PIT-warehouse smoke that opens more
   symbols than the default handle cap (so cache thrash shows in the
   `misses` line). A shape we run for verdicts but never time is a gap —
   add the cell before the next verdict run, not after it dies.
3. **Local long cells carry their own numbers.** Every chain script logs the
   cache line and GNU-time peak RSS per cell (`sweep-hygiene.md` preamble),
   and the cell guard is set from the **measured arm**, not the null:
   guard ≥ 1.5 × the slowest observed cell of that arm.
4. **Write it down** in `dev/status/backtest-perf.md` §Weekly review — date,
   the rows compared, deltas, tickets opened. Two lines is enough; zero lines
   means the review did not happen.

## What QC can check

- A PR that adds a new warehouse format, cache, or run mode adds or updates
  a tier-2/3 cell for it (or says in the body why the existing catalog
  already covers the shape).
- A chain script's `CELL_TIMEOUT` cites the measurement it was sized from.

Related: `container-capacity-scheduling.md` (measure with `docker stats`, not
RSS, for container headroom — peak RSS is still the right per-cell trend
number), `sweep-hygiene.md`, `memory/feedback_weekly_perf_review_budget`,
`memory/project_snapshot_cache_handle_cap_thrash`.
