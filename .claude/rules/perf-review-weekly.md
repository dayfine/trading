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
| local (no tier) | `dev/scripts/perf_pit_smoke.sh` (#2896) | manual, weekly review | wall + peak RSS + cache hits/misses, cap 256 vs 12,000, on the full `_v11pit` snapshot warehouse — the shape no GHA tier can run (warehouse lives in the container only). Spec: `trading/test_data/backtest_scenarios/perf-pit/pit-smoke-4mo.sexp`, untagged so every tier's discovery loop skips it. |

Peak RSS parsing is shared via `dev/lib/gnu_time_rss.sh` (#2553/#2559). The
cache diagnostics line (`Panel_runner: snapshot cache hits=… misses=…`) plus
the handle cap (`SNAPSHOT_MAX_MMAP_HANDLES`, #2839) are the per-run signals.

## The three gaps the weekly hour-pair closes

1. **No tier runs the shape that costs us — CLOSED for the PIT shape
   (#2896, 2026-09-22).** Every tier-2/3 cell is sp500 or a 1–3y synthetic
   sweep; the broad top-3000 5y gap closed via #2894/#2899. The PIT-warehouse
   shape (opens the full `_v11pit` snapshot warehouse, 9,364 symbols) now has
   a local smoke cell: `dev/scripts/perf_pit_smoke.sh` runs a 4-month 2020
   window at `SNAPSHOT_MAX_MMAP_HANDLES` 256 vs 12,000 and asserts the two
   runs are byte-identical. Measured 2026-09-22: cap=256 2,629 s / 22.8 GB
   peak RSS (heavy LRU thrash) vs cap=12,000 480 s / 4.5 GB (no thrash) — a
   5.5× wall delta from the cap alone, at smoke scale rather than the full
   PIT 26y chain (6–11 h, 118M cache misses per cell — still the only way to
   see the mechanism at full scale; the smoke cell exists so a cache
   regression is caught in minutes, not by a chain dying hours in).
2. **FAIL rows are invisible.** `perf-nightly.yml` / `perf-weekly.yml` run
   with `continue-on-error: true`; on 2026-09-14 the weekly table carried two
   FAIL rows (`sp500-2010-2026*`, ~4,750 s) and the workflow reported success.
   **Fixed 2026-09-22 (#2894, #2891):** all three perf workflows now upload
   the per-cell `.log` / `.error` / `.peak_rss` / `.wall_sec` files as a run
   artefact (`if: always()`), and FAIL rows are promoted to the job summary
   (above the full table) and to GHA `::warning::` annotations via the
   shared `dev/lib/perf_fail_rows.sh` parser — a FAIL row is now visible on
   the run page and root-causable from the artefact without re-running
   anything. `continue-on-error: true` itself is unchanged; see #2891.
3. **Nobody reads the table week to week.** Drift only surfaces when a cell
   dies.

## The weekly routine (~2 h, same day each week, logged)

1. **Read the tables** — latest `perf-nightly` and `perf-weekly` runs
   (`gh run list --workflow perf-weekly.yml --limit 1`, then `gh run view
   <id> --log | grep -E 'PASS|FAIL'`). Compare wall + peak RSS to the prior
   week's row. A FAIL row, or a > 20 % wall or RSS move on any cell, becomes a
   ticket **that week** (label `kind/harness`, name the cell and both
   numbers).
2. **Keep one cell per real workload shape — minimum catalog now complete.**
   sp500 5y/15y (pre-existing), broad top-3000 5y (#2894/#2899), and a
   PIT-warehouse smoke that opens more symbols than the default handle cap
   (`dev/scripts/perf_pit_smoke.sh`, #2896, 2026-09-22 — cache thrash shows
   in the `misses`/`evictions` line, cap 256 vs 12,000). A shape we run for
   verdicts but never time is a gap — add the cell before the next verdict
   run, not after it dies.
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
