---
name: snapshot-cache-handle-cap-thrash
description: "⭐ Every 26y cell re-decodes each symbol ~450×/sim-year (65–74 % miss rate, evictions ≈ misses) because the v2 columnar warehouse binds on the HARD-CODED `_max_open_mmap_handles = 256` in daily_panels.ml, not on SNAPSHOT_CACHE_MB (v2 entries charge only the date array to the byte budget). Misses are linear in symbols and years; per-miss cost (page cache vs disk) is what moves a PIT cell 6 h → 8.5 h. Fix = env knob for the handle cap set ≥ n_symbols (fd 269/1,048,576, maps 54,667/262,144, ~0.3 GB heap for 10k readers), bit-identical; #2839. Track occupancy first: #2878. (09-20)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7f480942-60b9-4474-bfe2-8afe9239b92b
  modified: 2026-09-20T21:48:53.054Z
---

**Measured 2026-09-20** from `Panel_runner: snapshot cache hits=… misses=… evictions=… n_symbols=…` end-of-run lines
(the only cache telemetry that exists), all at `SNAPSHOT_CACHE_MB=1024`:

| cell | n_symbols | misses | evictions | misses/symbol/sim-year |
|---|---:|---:|---:|---:|
| 5y, 2000-vintage warehouse (6 sim-years) | 3,015 | 8.1M | 6.1M | 446 |
| 26y, 2000-vintage (27 sim-years) | 3,015 | 36.8M | 35.6M | 452 |
| 26y PIT `_v11pit` (null and veto arm identical) | 9,915 | 118.5M | 112.2M | 443 |

**Why:** `_v11pit` and the dedup warehouses are v2 (`SNAPCOL1`). `Daily_panels.Backing.estimate_bytes` charges an mmap
entry only its int32 date array + a constant, so the MB budget never binds; the LRU is evicted by the handle cap. A
weekly pass over N symbols cycles a 256-entry LRU → almost every read = `openfile` + `fstat` + whole-file `map_file` +
header parse; every eviction = `close` + munmap. The heap does NOT hold history (anon 2.2–3.5 GB flat on a 27y PIT
cell) — the streaming design works; the cap is just 40× too small for the universe.

**Consequences for reads:**
- The PIT cell's 6–7 h (#2839) is a cache-size effect, linear in symbols × years, not an algorithm; membership pruning
  was the wrong first lever (and was rejected 09-15 for breaking prior-stage continuity anyway).
- Wall-time variance between identical-work cells (null 5h58m vs veto arm 8h33m at salt 0; same-list 5y 3.6 vs 26y
  5.6 min/sim-year with identical misses/year) is per-miss cost: VM page cache vs disk. Never read wall time as a
  strategy signal.
- Raising `SNAPSHOT_CACHE_MB` does nothing on a v2 warehouse (an earlier headline said so — wrong knob).

**How to apply:** land #2878 (occupancy max/avg + `top_heap_words` + `maxrss` on the cache line, `Gc_trace` samples)
first, then the #2839 knob `SNAPSHOT_MAX_MMAP_HANDLES` (default 256 = unchanged) set to 12,000 in chain scripts;
prove on the 4-month smoke (`index-stage-veto-2026-09-16/specs`, `end_date 2000-04-28`): expect misses ≈ 1/symbol and
a PIT cell well under 3 h. Never edit a running chain script; never launch the smoke beside a live cell (memory).
Related: [[snapshot-format-v2]], [[pit-universe-migration]], [[backgrounded-docker-build-hangs]].
