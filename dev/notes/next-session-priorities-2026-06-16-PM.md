# Next-session priorities — 2026-06-16 PM (overnight handoff)

**Supersedes** `next-session-priorities-2026-06-16.md`. Written during the
autonomous overnight session (user away ~8-10h). Check main CI green first.

---

## Window-prune: investigated end-to-end → NOT viable at the cache level

You asked me to fix the matrix slowness via window-prune. I traced the full read
path + the snapshot format and **proved a cache-level window-prune can't work
with the current format** — full writeup:
`dev/experiments/panel-runner-perf-2026-06-16/WINDOW-PRUNE-FINDINGS.md`. The short
version:

- Snapshot files are **whole-file sexp** (no seek/index/partial decode). The
  cache loads the *entire* file per symbol; the read range only slices the
  returned rows. So a windowed cache is a catch-22: keep future rows → no
  early-peak win (first start still spans 26y → OOM); drop them → re-decode the
  whole file every tick → worse thrash.
- Column-prune (cache fewer of the 13 schema fields) only buys ~1.5× (per-row
  overhead dominates) — insufficient.
- **Top-3000 (26y, ~2.95 GB working set) cannot fit the 7.8 GB container at any
  cache size** (max safe cache ~1280-1536 holds < 1.5 GB → still thrashes).
  Confirmed empirically (cache=3072 OOM'd even after the Gc.compact fix).

**The real fixes (your decision):**
1. **Docker RAM → 12-16 GB** (immediate, no code): cache=4096 holds the working
   set → ~50× → top-3000 26y matrix in ~2-6 h. The #1614 `Gc.compact` fix is the
   prerequisite that makes it fit.
2. **Phase-C snapshot format** (`Bigarray.map_file` / indexed-by-date, already on
   the roadmap): enables partial/range decode → cache holds only the hot window
   → fits the current 7.8 GB AND speeds every run. Durable fix, bigger project.
3. **Consume precomputed snapshot scalars** (Stage/MA/RS are already stored
   per-row) instead of recomputing from raw history — your "summary numbers"
   instinct. Biggest structural win, but a compute-path change (golden-gated).

Your **10-year window** instinct was right: `_bar_list_history_days = 3653` is
over-provisioned (Weinstein needs ≤1y), but reducing it doesn't help memory under
whole-file-load — it only matters under fix #2/#3.

## Meaningful progress shipped instead: the top-1000 matrix (so the lens gets done)

Since top-3000 can't fit without RAM, I launched the **top-1000 2000-26 matrix**
(working set ~1 GB → fits cache=1280 no-thrash → completes). It runs the same
Cell-E + #1607 factor columns over a valid PIT top-1000 regime sample, unblocking
the factor-lens **H1/H2/H3 causal analysis** (the actual goal the matrix serves).

- Scenario: `/tmp/cell-e-top1000-2000-26y.sexp` (universe `top-1000-1999.sexp`,
  over the existing `snap_top3000_2000` warehouse — no rebuild needed).
- Run: `rolling_start_eval`, stride 255 (~37 starts), `SNAPSHOT_CACHE_MB=1280`,
  `--parallel 1`, end 2026-04-30. Log `/tmp/rolling-factor-matrix-t1k.log`, out
  `/tmp/rolling-factor-matrix/matrix-t1k-2000-26.md` (written at the end; copy to
  `dev/experiments/` on completion — container /tmp is not bind-mounted).
- **[STATUS: running as of handoff — see the log / monitor for completion. If the
  matrix-t1k file is non-empty, the causal analysis is the next read-only step:
  correlate the #1607 factor columns with `realized_edge_pct` for H1/H2/H3.]**

Note: top-1000 is the in-container-feasible universe; the top-3000 multi-regime
matrix you originally wanted still needs RAM (#1) or the format upgrade (#2).

## Also shipped overnight
- **#1614** — `Gc.compact` before the per-start fork (merged; prevents the
  fork-doubling OOM, lets larger caches fit).
- **#1617** — README top-line numbers via a regenerable `readme_toplines` module
  (testing period 1998-12-22 → 2026-06-12; SPY BAH +888.9%/8.7%yr, BRK-B
  +1132.4%/9.6%yr, SPY-Weinstein +408%/6.1%yr, Sector-ETF-Weinstein
  +528.9%/6.9%yr — both Weinstein legs trail B&H on this bull window, expected).
  **[STATUS: open PR, needs 3-gate merge — QC was deferred because the container
  is busy with the matrix. Merge it when the container frees.]** Regenerate:
  `dune exec backtest/readme_toplines/bin/readme_toplines.exe -- --readme README.md`.
- Branch cleanup, #1601/#1604/#1612/#1615 merged (earlier in the session).

## What to do on return
1. **Decide the top-3000 path**: bump Docker RAM to 12-16 GB (fastest) or commit
   to the Phase-C format / summary-scalars project. Then rerun top-3000 2000-26.
2. **If the top-1000 matrix finished**: read its output, run the H1/H2/H3 causal
   analysis (the deploy-when lens). If not, let it finish or re-launch.
3. **Merge #1617** (README) — needs QC once the container is free.
