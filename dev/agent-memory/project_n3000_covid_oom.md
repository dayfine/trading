---
name: project_n3000_covid_oom
description: "N=3000 full-history backtests OOM'd the 7.75GB container — FIXED via #1481 (lazy Market_state: engine no longer eagerly builds an intraday Price_path for all 3000 symbols/tick, only the ~5 order-touched). 15y N=3000 now completes; broad-PIT re-baseline UNBLOCKED."
metadata:
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

2026-06-07. Tried to run the honest P1 baseline (Cell-E on top-3000-2011 PIT,
15y 2011-2026, snapshot mode) after shipping the P0 cache fix. Two findings:

1. **P0 cache fix (#1468) WORKS for its purpose (thrash).** N=3000 ran at
   **8-9.7 Friday-cycles/min** for ~500 cycles — no re-decode thrash (pre-#1468
   it was non-terminating at the 1GB LRU). Confirmed. (The `misses_per_symbol`
   counter couldn't be captured — OOM before the end-of-run log line — but the
   cycle rate proves no thrash.)

**✅ RESOLVED 2026-06-07 via #1481** (`fix(engine): lazy intraday-path generation`).
Root cause turned out NOT to be the audit-accumulation guess: `Engine.update_market`
eagerly built a ~19KB intraday `Price_path` for EVERY symbol with a bar EVERY tick
(~3000/day), but `market_state` is read only at order-execution sites keyed on
`ord.symbol` (~5 symbols/day) → >99% of the per-tick path allocation was churn that
dominated the major heap. Fix: new `Market_state` engine sub-module
(`trading/trading/engine/lib/market_state.{ml,mli}`) stores only the per-symbol bar;
generates the path **lazily, memoized per tick**, only for order-touched symbols.
Public `Engine` signature + abstract `Engine.t` unchanged; results **bit-identical**
(RNG is per-call — `price_path.ml` builds a fresh `Random.State` per path — so N→5
paths/tick is provably parity-preserving). Live growth 1.39→0.013 MB/cycle; 15y N=3000
completes, RSS ~5.8GB flat. **First honest full-15y top-3000 PIT Cell-E baseline:
+790.5% / Sharpe 0.712 / MaxDD 29.2% / Calmar 0.526 / 671 trades.** Both QC gates
APPROVED (A1 generalizability PASS). `Gc.compact` was tried first and REJECTED (spikes
relocating large arrays). Original diagnosis below retained for the record.

2. **[ORIGINAL DIAGNOSIS] N=3000 OOM-kills the 7.75GB container — STEADY O(cycles)
   memory ACCUMULATION, not a COVID transient (corrected 2026-06-07).**
   `OOMKilled=true`. Both full-15y runs died at ~cycle 510 (4096→516 / 2020-04;
   2048→508 / 2020-02), the SAME cycle regardless of cache → not cache-driven.
   **Decisive probe (ruled out the transient hypothesis):** a 2018-2021 N=3000
   run — same universe/config, reaches COVID by ~cycle 110 with little prior
   accumulation — **COMPLETED through COVID cleanly (RUN_EXIT=0, no OOM)**. So
   COVID is NOT a transient trigger; the 15y run simply crossed 7.75GB by
   cycle ~510 and the COVID date was coincidental. RSS was already 6.85GB by
   cycle 232 → ~8 MB/cycle growth (~2.7 KB × 3000 symbols/cycle). Distinct from
   the bar-decode thrash #1468 fixed (snapshot cache bounds bar memory ~1.5GB).
   **NOT step_history** (skinny ~5 positions/day → MBs) and **NOT trades** (only
   150 in the probe). Prime remaining suspect: **per-symbol strategy/indicator
   state growing with elapsed history** (weekly-MA buffers / stage history per
   symbol, O(symbols × elapsed_weeks)), or per-cycle audit/log accumulation.
   Honest top-3000 numbers from the probe:
   **2018-2021 (incl COVID) = +56.4% / Sharpe 0.51 / MaxDD 25.2% / Calmar 0.34,
   150 trades**; 15y runs reached +81-98% equity by early 2020 before dying.

**PINNED via Gc.stat-per-cycle instrumentation (2026-06-07, probe run):**
- `live_words` grows **~1.4 MB/cycle** (1556→1845 MB over 208 cycles) — a real
  but slow accumulation, ~+700 MB over a 15y run.
- `top_heap_words` = **4646 MB and FLAT from cycle 4** — the per-Friday screen
  over 3000 symbols allocates a **~3 GB transient** (peak heap 4.6 GB minus the
  ~1.5 GB snapshot-cache working set), and OCaml holds that mostly-free heap
  rather than returning it to the OS. So RSS sits ~6.85 GB with only ~1.6 GB
  live. OOM = (4.6 GB held heap + ~2 GB non-heap + the slow live growth) crosses
  7.75 GB around cycle ~510. Cache cap is irrelevant (working set < 2048, so
  2048 and 4096 behave identically — explains the same death cycle).
- **`Gc.compact` REJECTED as the fix** (tested): it must RELOCATE the large
  arrays (cache + transient), which spikes memory mid-compaction → OOM'd EARLIER
  at cycle 52. Wrong tool for a large-array heap. Reverted; nothing merged. GC
  tuning (space_overhead) won't help either — the killer is the PEAK transient,
  which must still be allocated.
- **The real fix = cut the per-Friday screening peak**: batch/stream the
  candidate scoring over the 3000-symbol universe so it doesn't materialize all
  candidates' intermediate bar/MA arrays at once (process symbol → keep only the
  scalar score+symbol → discard bars). Screener-path change in
  `analysis/weinstein/screener/` + the strategy's Friday entry-walk; substantial
  + needs parity tests. Secondary: trim the ~1.4 MB/cycle live accumulation.
  Until then, N=3000 full-history is blocked on the 7.75 GB container; use
  N≤1000 PIT or a >8 GB container.

**Consequence: full-history broad-PIT re-baselines are BLOCKED on the current
container.** The pre-COVID portion (2011→early-2020, ~500 cycles) runs clean;
honest top-3000 Cell-E reached +81-98% by early 2020 (~9y) — promising vs
survivorship-corrected top-1000 15y (29.6%, [[project_pit_survivorship_inflation]]),
consistent with breadth=lever ([[project_cell_e_2020_stall_regime]]) — but no
clean final scorecard (died before writing actual.sexp).

**Next-session options (priority order):** (1) fix the cascade transient — stream
/ batch liquidation events instead of one allocation; unblocks the whole agenda;
(2) re-baseline at N≤1000 PIT (top-1000-2011 15y already = 29.6%, fits memory);
(3) bump Docker memory >8GB (transient spike; ~12GB likely clears it);
(4) pre/post-COVID partial windows. Full writeup + repro:
`dev/notes/p1-pit-rebaseline-n3000-oom-2026-06-07.md`. See
[[feedback_large_n_needs_snapshot_mode]] (snapshot recipe).
