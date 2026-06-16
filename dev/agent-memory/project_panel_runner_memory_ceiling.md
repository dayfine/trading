---
name: project_panel_runner_memory_ceiling
description: "top-3000 26y rolling-start backtest can't fit the 7.8GB container; cache window-prune is format-blocked. Real fixes = more Docker RAM, Phase-C mmap format, or read precomputed snapshot scalars."
metadata: 
  node_type: memory
  type: project
  originSessionId: b7df10ed-d46a-4d6b-a9b7-31437a8b7311
---

The top-3000 26y rolling-start matrix OOMs / thrashes the 7.8GB dev container.
Root-caused 2026-06-16. Writeups: `dev/experiments/panel-runner-perf-2026-06-16/`
(ANALYSIS.md + WINDOW-PRUNE-FINDINGS.md).

**Mechanism:** `Daily_panels._load_symbol_file` decodes each symbol's **entire
file** and caches the full row array (~2.95GB working set for top-3000 × 26y,
**window-independent** — a 1.3y probe used the same ~3.6GB as 26y). The weekly
full-universe screen keeps all 3015 symbols hot → at `cache=1024` the working set
is evicted+re-decoded every scan → 98% CPU thrash (the ~50× slowdown).

**Why a cache window-prune does NOT work:** the snapshot format
(`snapshot_format.ml`) is **whole-file sexp** (`input_all` + `Sexp.of_string |>
[%of_sexp: Row.t list]`) — **no seek/index/range/partial decode**. So a windowed
cache is a catch-22: keep future rows → no early-peak win (first start spans 26y
→ OOM); drop them → re-decode the whole file every tick → worse thrash. Column-
prune only buys ~1.5× (per-row OCaml overhead dominates, not the 13 schema
fields). **No in-container cache both holds the working set and fits** (max safe
cache ~1280-1536 with Gc.compact holds <1.5GB of 2.95GB → still thrashes; cache=3072
OOM'd even post-compact).

**Shipped:** PR #1614 — `Gc.compact ()` in `Rolling_start_runner.run` before the
`Fork_pool` per-start fan-out. The parent holds ~3GB of freed-but-not-returned
factor-precompute memory; each fork COW-inherits it → ~2× peak → OOM at the fork.
Gc.compact returns it to the OS so children fork lean. Necessary (prerequisite for
the RAM fix to fit) but not sufficient alone.

**Real fixes (ranked):**
1. **Docker RAM → 12-16GB** (immediate, no code): cache=4096 holds the working
   set → no thrash → top-3000 26y matrix in ~2-6h.
2. **Phase-C snapshot format** (`Bigarray.map_file` / indexed-by-date, on the
   roadmap per snapshot_format.mli): enables partial/range decode → cache holds
   only the hot window → fits 7.8GB + speeds every run. The *real* window-prune,
   at the format layer.
3. **Read precomputed snapshot scalars** (Stage/RS/MA already stored per row)
   instead of recomputing from raw history → collapses the per-symbol read. Biggest
   structural win; compute-path change, golden-gated.

`_bar_list_history_days = 3653` (10y, in `snapshot_bar_views.ml`) is the max read
lookback — over-provisioned (Weinstein needs ≤1y) but reducing it doesn't help
memory under whole-file-load; only matters under fix #2/#3.

**In-container progress path:** run **top-1000** (working set ~1GB → fits
cache=1280 no-thrash → completes ~4.8h). Used for the factor-lens
([[project_factor_lens_regime_governs_edge]]). top-3000 awaits fix #1/#2.
