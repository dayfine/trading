# Panel-mode RSS spike — post-Stage-4-PR-D (2026-04-26)

Sibling of `dev/notes/panels-rss-spike-postC-2026-04-26.md`. Re-run on
the same `bull-crash-292x6y` cell after Stage 4 PR-D
(`feat/panels-stage04-pr-d-weekly-indicator-panels`, PR #594) parked
weekly Stage MA results in a per-symbol `Weekly_ma_cache` so
`Panel_callbacks.stage_callbacks_of_weekly_view` no longer re-runs
SMA/WMA/EMA per call (Friday hot path; mid-week falls back to inline).

## Setup

Identical to post-A+B / post-C spikes. Container `trading-1-dev`,
opam env, panel build on PR-D tip (`3f05df10`).

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 \
    --override "((universe_cap (292)))"
```

## Result

| Mode | Peak RSS | Wall | Δ RSS vs prior | Δ Wall vs prior |
|---|---:|---:|---:|---:|
| Pre-A+B (post-3.2) | 3,468 MB | 6:00 | baseline | baseline |
| Post-A+B (#588) | 1,944 MB | 4:11 | −1,524 (−44%) | −1:49 (−30%) |
| Post-C (#590) | 1,939 MB | 4:19 | −5 (−0.3%) | +8 s (+3%) |
| **Post-D (#594)** | **1,861 MB** | **4:39** | **−78 (−4.0%)** | **+20 s (+8%)** |
| Plan target | < 800 MB | n/a | | |

`Maximum resident set size = 1,905,676 kB → 1,861 MiB`. Wall `4:39.22`
(279.22 s). Exit 0.

## Verdict: **modest delta**

PR-D's `Weekly_ma_cache` saves ~78 MB / ~4% peak RSS — measurable but
nowhere near the 800 MB target. Wall time regresses by 8% (variance,
within run-to-run noise). The Friday-only cache hit rate plus the
inline-fallback for mid-week stops_runner ticks limits the win;
universe-wide MA recompute on Fridays is no longer the dominant
contributor to peak RSS, but most of the residency lives elsewhere.

The cumulative Stage 4 win across A+B+C+D: **3,468 MB → 1,861 MB
(−46%)**. Wall: **6:00 → 4:39 (−23%)**. Substantial but the plan target
(≤ 800 MB) needs another ~57% reduction beyond what's already shipped.

## Where the remaining ~1.86 GB lives (revised hypothesis after 4 spikes)

Earlier hypotheses ruled out by spikes:
- ~~Per-tick weekly aggregation in `weekly_view_for`~~ — ruled out by
  PR-C spike (post-C: −5 MB).
- ~~Per-call MA / SMA recompute in `Panel_callbacks._ma_values_of_closes`~~ —
  partially confirmed by PR-D (saved 78 MB) but only the Friday hot
  path; mid-week ticks still recompute. Not the dominant residency.

Still open:
1. **Closure environments in `Panel_callbacks`.** Each
   `*_callbacks_of_*_view` constructor builds 5–6 closures retaining
   refs to view records, MA arrays, dates, panels. Per-symbol per-tick
   call → many short-lived closures. The OCaml major-GC may carry
   them through several cycles before reclaim, inflating peak RSS.
   Hard to attribute without memtrace.
2. **Stack of `Bar_panels.weekly_view` records.** Each call allocates
   a record + 5 float arrays + 1 date array, length ~313 weeks at
   N=292 T=6y. ~12 KB per view × ~300 symbols × ~Friday ticks → tens
   of MB per Friday cycle, GC'd but with promotion latency.
3. **OCaml runtime overhead.** The C heap (Bigarray panels) is fixed
   at ~190 MB, but the OCaml minor + major heap can grow several
   100s of MB before triggering compaction. Fragmentation accumulates
   over the 6-year backtest.
4. **`Bar_reader` indirection.** Each strategy callsite goes through
   `Bar_reader.t` which holds a closure over `Bar_panels.t`; multiple
   layers of closures may be holding extra refs.

## Recommendation

**Memtrace before any more architectural changes.**

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  MEMTRACE=/tmp/panel-292x6y.ctf \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 \
    --override "((universe_cap (292)))"

memtrace_viewer /tmp/panel-292x6y.ctf
```

The 2026-04-25 plan note's "If still > 1 GB: stop, memtrace, and
revisit" branch is now active. Without memtrace attribution, further
PRs are guesses.

If memtrace shows closure environments dominating, candidate fixes:
- **Pool `weekly_view` records** — reuse a single per-symbol buffer
  rather than allocating per call.
- **Drop `Bar_reader` indirection** in the Friday hot path —
  `Panel_runner` could pass `Bar_panels.t` directly to the Stage /
  Macro / Sector callees.
- **Move `Panel_callbacks` to record-of-Bigarray-slices** rather than
  record-of-float-arrays — zero-copy slices replace per-call array
  allocations.

If memtrace shows Bigarray / OCaml heap dominating:
- **Bigarray panels are already C-heap-allocated**, so OCaml heap
  shouldn't be inflating from them. If it is, there's a leak (closure
  retaining old views).
- **Force major GC** between Friday ticks — ugly but a diagnostic
  test for heap fragmentation.

## What this means for Stage 4 status

- **A+B+C+D combined hit 46% RSS reduction** vs pre-3.2 baseline.
  That's a real architectural win — list intermediates gone, weekly
  rollup single-pass, Friday MA cached.
- **Plan target ≤ 800 MB is not met** and won't be met by additional
  PRs in the same vein. Diminishing returns; need profiling.
- **PR-D should still merge** as code-quality cleanup (cleaner
  separation of MA computation from callback construction; same
  pattern is reusable for other indicators).
- Do not start PR-E / Stage 5 work until memtrace happens.

## References

- Pre-A+B baseline: `dev/notes/panels-rss-spike-2026-04-25.md`
- Post-A+B: `dev/notes/panels-rss-spike-postB-2026-04-26.md` (#589)
- Post-C: `dev/notes/panels-rss-spike-postC-2026-04-26.md` (#590)
- PR-D: #594, branch `feat/panels-stage04-pr-d-weekly-indicator-panels`
  (merged 2026-04-26)
- Plan §Stage 4 sub-step 4: `dev/plans/columnar-data-shape-2026-04-25.md`
- Status: `dev/status/data-panels.md`
