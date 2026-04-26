## Post-Stage-3 PR 3.2 Panel-mode RSS spike on `bull-crash-292x6y` (2026-04-25)

## Goal

Confirm the projected memory drop from
`dev/plans/columnar-data-shape-2026-04-25.md` §"Memory and CPU
expectations" (Panel mode < 800 MB at N=292 T=6y) has materialized
after Stage 3 PR 3.2 (#569) deleted `Bar_history` + the Tiered Friday
seed. Single-cell measurement spike — no full sweep.

## Setup

- Branch: `feat/panels-perf-spike-post-3.2` off `main@origin`
  (`ba2a6422`, the merge commit of #569).
- Scenario: equivalent of "bull-crash 292x6y" — same shape as the
  baseline cell in `dev/notes/bull-crash-sweep-2026-04-25.md`.
  Date range `2015-01-02..2020-12-31`, `universe_cap=292`, data
  dir `/tmp/data-small-302` (the curated 292-symbol blue-chip
  universe; same as the baseline note).
- Invocation:
  ```bash
  TRADING_DATA_DIR=/tmp/data-small-302 \
    /usr/bin/time -v _build/default/trading/backtest/bin/backtest_runner.exe \
      2015-01-02 2020-12-31 \
      --loader-strategy panel \
      --override "((universe_cap (292)))"
  ```
- Single run, no warmup, no memtrace, no trace flag (kept overhead
  minimal so peak RSS reflects real residency).
- Wall-time budget: ~6 min.

## Result

| Mode | Peak RSS | Wall time | Source |
|---|---:|---:|---|
| Pre-3.2 Legacy | 1,872 MB | n/a (not recorded) | `bull-crash-sweep-2026-04-25.md` row N=292 |
| Pre-3.2 Tiered | 3,744 MB | n/a (not recorded) | `bull-crash-sweep-2026-04-25.md` row N=292 |
| **Post-3.2 Panel** | **3,468 MB** | **6:00** | this run |
| Projected (plan §Memory targets, N=5000 T=10y) | ~1,200 MB | n/a | `columnar-data-shape-2026-04-25.md` |
| Projected scaled to N=292 T=6y (linear in N×T cells) | ~42 MB | n/a | derived from 1.05 GB total panel residency / (5000×2520) × (292×1715) |

Panel-mode peak RSS = 3,551,264 kB → 3,468 MiB (≈3.47 GiB).
Wall = 5:59.93 (359.93 s). User CPU = 352 s; system = 6.5 s; 99% CPU.

## Verdict: **way off projection**

Panel mode at N=292 T=6y is **3.47 GB** — only 7% under the pre-3.2
Tiered baseline (3.74 GB) and **1.85× the pre-3.2 Legacy baseline**
(1.87 GB). The projection (<800 MB) did not hold by a factor of
~4.4×; the 10× memory-reduction target the plan claimed at
release-gate scale is not on track.

Wall time of 6:00 is also slow for what the plan framed as the
indicator-loop-becomes-O(1) win — at this scenario shape the bottleneck
is plainly elsewhere.

## Hypotheses for the gap (NOT addressed in this PR)

The panel buffers themselves are tiny: 9 panels (5 OHLCV + 4
indicators) × 307 symbols × 1715 days × 8 bytes = **38 MB**, malloc'd
outside the OCaml heap. So 3.43 GB of the 3.47 GB total RSS is NOT
the panel store. Candidate sources, in order of likely impact:

1. **`Bar_panels` reads still materialize `Daily_price.t list`
   intermediates.** Per `dev/status/data-panels.md` Stage 2 dispatch
   deviation: "callees stay list-shaped; back the lists with
   on-the-fly panel reconstruction via `Bar_panels`." Every reader
   site (macro_inputs, stops_runner, weinstein_strategy, sector,
   stock_analysis, weinstein_stops) reconstructs `Daily_price.t list`
   per call, on every tick, for every symbol it inspects. At 1510
   trading days × 292 symbols × multiple reader sites per tick, this
   is millions of short-lived list allocations going through the
   minor heap with the major-heap promotion rate determining steady
   RSS. Stage 2 PRs B–H reshaped the callee internals to take
   callbacks but the wrappers still build lists; the callbacks aren't
   wired through Panel_runner yet.
2. **CSV parse retains intermediate `Daily_price.t list` per symbol.**
   `Ohlcv_panels.load_from_csv_calendar` parses the full per-symbol
   CSV into `Daily_price.t list`, then writes selected days into the
   panel and (presumably) drops the list — but if the parse buffer
   or the `Storage.read_csv` `String.split` allocations linger in the
   major heap as fragmented blocks, that's per-symbol overhead × 307
   symbols × ~5000-10000 bars/symbol blue-chip. Worth confirming via
   memtrace.
3. **Indicator scratch state.** `Indicator_panels` registry holds
   `avg_gain` / `avg_loss` scratches for RSI (per
   `dev/status/data-panels.md` Stage 1 entry). At 307 × 8 = 2.4 KB
   per scratch this is trivial — but if scratches are per-tick rather
   than per-symbol, that's another factor.
4. **Strategy state's residual `Hashtbl`-keyed caches.** Even with
   `Bar_history` deleted, `Tiered_strategy_wrapper` config used to
   carry warmup-window state. Worth grep-checking that
   `Panel_strategy_wrapper` doesn't accidentally re-introduce a
   parallel cache (e.g. via `Bar_reader.empty ()` materializing into
   something larger than expected).
5. **GC fragmentation / unused major heap.** Once the major heap
   grows, glibc malloc may not release pages back to the OS. RSS can
   stay high even after live-set shrinks. A `Gc.compact` before
   measurement would isolate this.

## Recommendation

**Do NOT mark Stage 3 PR 3.2 as having delivered the projected memory
win.** The structural deletion happened (Bar_history is gone), but the
RSS curve hasn't moved meaningfully because the `Daily_price.t list`
allocation pressure that Bar_history fed is now coming from
`Bar_panels` on-the-fly reconstruction instead.

Likely next investigation, when scheduling permits:

1. **Memtrace this run.** `--memtrace /tmp/panel-292x6y.ctf` and
   `memtrace_viewer` to attribute the 3.4 GB to specific allocation
   sites. Top suspect: `Bar_panels.daily_bars_for` /
   `weekly_bars_for` building lists.
2. **Land Stage 4** (port the callee internals — Stage, RS,
   Sector, Macro, Stops, Volume, Resistance — from `Daily_price.t
   list` consumers to true callback consumers via PR-H reshape, so
   the only allocation per tick is the few floats the callbacks
   read). The PR-B..G ground-work is in place; PR-H is the wiring
   PR. Plan target: reduce RSS ~5× from this measurement.
3. **Until Stage 4 lands, the +95% Tiered RSS gap framing in plan
   §"What collapses" is misleading.** The gap collapsed structurally
   (Bar_history is gone) but the absolute RSS is still in the same
   league as Tiered. Plan should be updated to reflect that the
   memory win lands in Stage 4 + Stage 3, not Stage 3 alone.

## Data points for plan revision

If the linear-in-(N×T) projection from §"Memory at the release-gate
target" held, this scenario should peak at:
- 38 MB panel store + ~10 MB scalar state + glibc slabs ≈ 80–120 MB.

Actual is 3.47 GB → **~30× over the projected lower bound**. The
projection model in the plan needs an explicit `Daily_price.t list`
intermediate-allocation term until Stage 4 wraps it up.

## Next spike (scheduled)

Re-run the same command **after Stage 4 lands** (or after the
callback-wiring sub-PR within Stage 4, whichever ships first):

- Same scenario `bull-crash-292x6y`, same invocation
  (`--loader-strategy panel`, `2015-01-02..2020-12-31`,
  `universe_cap=292`, blue-chip 292-symbol universe).
- New expected outcome: peak RSS ≤ 800 MB (the original projection),
  validating that the `Daily_price.t list` intermediate allocation
  pressure was the load-bearing source of the 3.5 GB gap.
- If the next spike is still > 1 GB: stop, memtrace, and revisit
  the plan thesis. Per `columnar-data-shape-2026-04-25.md`
  §"Risks/Decision point": "if RSS gain < 30%, abort the migration
  and revisit." Two consecutive spikes failing the gate is the
  signal to escalate.
- If the next spike passes (≤ 800 MB): proceed to Stage 4
  release-gate sweep at N=5000 T=10y; gate ≤ 8 GB.

## Artifacts

- `/tmp/panel-spike-run/panel.{time,stdout,stderr}` (in-container,
  not preserved past the docker session — only the numbers above
  matter long-term).
- This note: `dev/notes/panels-rss-spike-2026-04-25.md`.
- Cross-link from `dev/status/data-panels.md`.
