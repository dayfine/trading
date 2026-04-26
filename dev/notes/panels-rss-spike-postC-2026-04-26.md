# Panel-mode RSS spike — post-Stage-4-PR-C (2026-04-26)

Sibling of `dev/notes/panels-rss-spike-postB-2026-04-26.md`. Re-run on
the same `bull-crash-292x6y` cell after Stage 4 PR-C
(`feat/panels-stage04-pr-c-single-pass-weekly`, PR #590) collapsed the
two-pass weekly aggregation in `Bar_panels.weekly_view_for` into a
single panel→weekly walk.

## Setup

Identical to the post-B spike. Container `trading-1-dev`, opam env,
panel build on PR-C tip (`d8085314`).

```bash
TRADING_DATA_DIR=/tmp/data-small-302 \
  /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
    2015-01-02 2020-12-31 \
    --override "((universe_cap (292)))"
```

## Result

| Mode | Peak RSS | Wall | Δ vs prior |
|---|---:|---:|---|
| Pre-A+B (post-3.2) | 3,468 MB | 6:00 | baseline |
| Post-A+B (#588) | 1,944 MB | 4:11 | −44% / −30% |
| **Post-C (#590)** | **1,939 MB** | **4:19** | **−0.3% / +3%** |
| Plan target | < 800 MB | n/a | |

`Maximum resident set size = 1,985,656 kB → 1,939 MiB`. Wall `4:18.97`
(258.97 s). Exit 0.

## Verdict: **negligible RSS / wall delta**

PR-C's single-pass weekly aggregation produced **no measurable RSS
win** at this cell. The 5 MB delta is within run-to-run noise; wall
is +3% (also noise). Conclusion: the per-call two-pass weekly
aggregation in `weekly_view_for` was **not** a dominant residency
contributor. The 6 daily-prefix arrays + 5 weekly arrays per call
were short-lived enough that the GC reclaimed them promptly; their
peak coexistence was small relative to the surviving working set.

PR-C remains worth keeping as a code-quality cleanup (one fewer
intermediate, slightly cleaner control flow) but it is **not the
memory wedge** for Stage 4.

## Where the remaining ~1.94 GB lives (revised hypothesis)

Three candidates from `panels-rss-spike-postB-2026-04-26.md`:

1. ~~Per-call weekly rollup~~ — **ruled out by this spike (PR-C)**.
2. **MA/SMA precompute per call** in
   `Panel_callbacks._ma_values_of_closes` — every
   `stage_callbacks_of_weekly_view` invocation re-runs `Sma /
   calculate_weighted_ma / calculate_ema` over the symbol's weekly
   closes. **This is now the strongest remaining suspect.** PR-D's
   indicator-kernel ports park the result in resident
   `Indicator_panels` so reads become O(1) and per-call recompute
   vanishes.
3. **`Indicator_panels` / `Ohlcv_panels` resident size** — the
   pre-allocated daily panels for 307 symbols × 1,715 days × 5
   OHLCV fields × 8 bytes ≈ 21 MB per field, total ~105 MB just
   for OHLCV. Plus 4 indicator panels (EMA-50 / SMA-50 / ATR-14 /
   RSI-14 daily) — another ~84 MB. ~190 MB resident floor before
   any per-tick allocation. Not a leak; this is the panel's
   designed residency. Does not explain the gap to 800 MB.
4. **Closure environments** in the `Panel_callbacks` constructors
   — each `*_callbacks_of_*_view` builds a closure bundle holding
   references to MA arrays, dates, view records. Per-symbol per-tick
   call → many short-lived closures. Allocation pressure rather
   than long-lived residency, but the GC's old-generation may carry
   them over major-GC cycles. Could be measured via `memtrace`.

## Recommendation

**PR-D is required** for the Stage 4 ≤ 800 MB gate. Scope:

- Port stage classifier weekly MA / SMA reads to indicator kernels
  with output panels in `Indicator_panels` (the existing daily
  EMA/SMA/ATR/RSI panels are a precedent).
- Add weekly cadence to `Indicator_panels` (or sister
  `Indicator_weekly_panels`) so per-tick reads become panel-cell
  lookups, no Sma/Ema recompute.
- Once PR-D lands, re-run this spike. If still > 800 MB, memtrace
  the run to attribute the residency. The 800 MB target depends on
  the kernel ports; defer further sweeps until PR-D is in.

**PR-C is OK to merge as-is** — code cleanup, not memory cleanup.
PR #590 stays open for review on its own terms.

## References

- Pre-A+B baseline: `dev/notes/panels-rss-spike-2026-04-25.md`
- Post-A+B baseline: `dev/notes/panels-rss-spike-postB-2026-04-26.md` (#589)
- Plan §Stage 4 sub-step 4 (PR-D — indicator kernel ports):
  `dev/plans/columnar-data-shape-2026-04-25.md`
- PR-C: #590, branch `feat/panels-stage04-pr-c-single-pass-weekly`
- Status: `dev/status/data-panels.md`
