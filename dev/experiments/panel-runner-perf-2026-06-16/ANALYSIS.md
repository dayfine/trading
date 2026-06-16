# Rolling-start / panel_runner perf diagnosis — 2026-06-16

**Trigger:** the 2000-2026 (26y) top-3000 rolling-start factor matrix projected
**~60-108h** at `SNAPSHOT_CACHE_MB=1024` and OOM'd the 7.8 GB dev container at any
larger cache. Rather than blind-rerun, measured the bottleneck first (user
directive: "measure performance and optimize first").

## TL;DR

- **Root cause (measured + code-confirmed):** the snapshot LRU
  (`Daily_panels`, `analysis/weinstein/snapshot_runtime/lib/daily_panels.ml`)
  caches each symbol's **entire history file** (`_load_symbol_file` →
  `Snapshot_format.read_with_expected_schema` reads the whole file; the
  `cache_entry.rows` is the full row array). For top-3000 × 26y that is a
  **~2.95 GB working set, independent of the backtest window**.
- The Weinstein strategy screens the **full universe every week**, so all ~3015
  symbols' panels are "hot" each weekly tick. At `cache=1024` the working set
  doesn't fit → constant eviction → **re-decode every scan → 98% CPU thrash**
  (the ~50× slowdown; 26y first start alone ran >3.7 h, the 1.3y probe ran
  >10 min — both unfinished).
- **Window-independence proof:** a **1.3y** probe used the **same ~3.6 GB RSS**
  and thrashed identically to the 26y run — confirming the cost is the
  full-history load, not the backtest span.
- **Fork-doubling OOM:** `Rolling_start_runner.run` does the factor precompute
  in the parent (builds a `Daily_panels` handle, ~3 GB), then forks one backtest
  child per start. OCaml does not return the freed precompute memory to the OS,
  so the parent stays ~3 GB resident; each `Fork_pool` child COW-inherits it →
  peak ≈ 2× → `cache>=2048` OOM'd at the fork before any backtest finished.

## What shipped (safe, behavior-preserving)

**PR #1614 — `Gc.compact ()` before the fork.** Returns the parent's freed
factor-precompute memory to the OS so children fork from a lean parent.
Validated: with the fix a `cache=3072` probe forked and ran the backtest **past
the exact point an unpatched `cache=3072` run OOM'd** (parent dropped to ~1.3 GB
post-compact). Memory-only; 23 rolling_start tests pass unchanged. This is
necessary but **not sufficient** on its own (see below).

## Why it still doesn't fit in 7.8 GB

- The snapshot cache **byte-estimate undercounts actual RSS ~1.6×**
  (`_per_row_overhead_bytes = 64` underestimates the real OCaml `Snapshot.t`
  record + array footprint). So `cache=3072` budget → **~5 GB actual** child.
- Even post-`Gc.compact` (lean ~1.3 GB parent), a `cache=3072` child climbed to
  ~5.6 GB + parent + the 1.9 GB `.snap` OS page cache → OOM at avail≈0.
- **In a 7.8 GB container there is no cache that both holds the 2.95 GB working
  set AND fits the parent+child fork model.** A cache small enough to fit two
  procs (≤~2048 budget → ~3.3 GB actual) is smaller than the 2.95 GB working set
  → still partially thrashes.

## Recommended fixes (need your decision — NOT done autonomously)

1. **Immediate, no code — bump Docker RAM to 12-16 GB.** Then `cache=3072-4096`
   holds the working set and the fork fits → eliminates thrash → ~50× faster →
   the 26y matrix drops from ~60-108h to **~2-6h**. (`Gc.compact` from #1614 is
   what makes this actually fit once RAM is available.) Set in Docker Desktop →
   Settings → Resources → Apply & restart, then relaunch at `cache=4096`.

2. **Proper code fix — window-prune the `Daily_panels` cache.** Cap each
   symbol's cached rows to a sliding retention window (≥ the max strategy
   lookback, ~35 weeks) relative to the backtest's advancing frontier. Shrinks
   the per-symbol entry from full-history (~980 KB) to ~30 KB → working set
   **2.95 GB → ~90 MB** → fits `cache=1024` in the existing 7.8 GB → no thrash,
   no RAM bump, **helps every broad-universe run**. Caveats: it is shared
   backtest infra; the retention window must cover the longest indicator
   lookback, and it must apply ONLY to the strategy's forward-advancing handle,
   NOT the factor-precompute handle (which reads arbitrary as-of dates). Must be
   verified bit-identical against the goldens. Flagged for review — not landed
   autonomously because silent row-pruning errors would drift backtest results.

3. **Stopgap, in-container — `cache=2048` + #1614.** Now fits post-compact;
   holds ~2/2.95 GB of the working set → ~2-3× faster than `cache=1024`
   (~20-40h). Better than nothing, far short of option 1/2. Only if you want a
   result without touching RAM or infra.

**Recommendation:** do not rerun the 26y matrix until option 1 (RAM) or option 2
(window-prune) is in. Option 1 is the fastest unblock; option 2 is the durable
fix. #1614 lands regardless (it is the prerequisite for option 1 fitting).

## Secondary finding (lower priority — ~2% of total)

The #1607 factor precompute (`resolve_per_start`) is **date-outer / symbol-inner**:
for each of ~52 starts it scans all 3015 symbols, so each symbol is re-decoded
~52× (the working set exceeds cache during the scan too). This is the ~86-min
pre-fork phase observed on the 26y run (1-start probe forked in ~95s; 95s × 52 ≈
82 min). A symbol-outer restructure (decode each symbol once, extract all 52
as-of rows) would cut it to a few minutes — but it is one-time and only ~2% of
the ~60-108h total, so it is not the lever. Worth doing alongside option 2.

## Repro / artifacts

- Probe scenario: `/tmp/probe-1start.sexp` (2000 warehouse, start 2025-01-03,
  1 start via `--stride-days 9999`).
- `cache=1024`: 1.3y backtest >10 min unfinished, 98% CPU, child ~3.66 GB.
- `cache=3072` (unpatched): OOM at fork ~108s.
- `cache=3072` (+#1614): forked + ran the backtest past 108s; parent lean
  ~1.3 GB; still eventually too big for 7.8 GB (cache undercount).
