---
name: Broad universe — include incomplete-history symbols
description: Broad backtest universes (data/sectors.csv, ~10k symbols) should NOT pre-filter by bar coverage; the runner skips per-symbol when no bars exist.
type: project
originSessionId: df52077d-2210-44cb-9ffa-9aa47ab572ee
---
When building Pinned-shape sexp universes from `data/sectors.csv` (e.g. `broad-10k-2015.sexp`), do NOT pre-filter symbols by full window coverage. Include all 10k+ sectors.csv symbols and let the runner's per-symbol bar-presence checks (already wired) skip days where bars are missing.

**Why:** late-start symbols (IPO mid-window) ARE tradeable from their first bar onward. Early-termination symbols (delisted mid-window) are tradeable up to the terminus — though early-termination handling needs care (should treat the last available bar as a forced exit, not as ongoing position).

**How to apply:**
- ops-data agent's universe-build step for broad N×Yy backtests: emit ALL `data/sectors.csv` symbols, not the bar-coverage-complete subset.
- The 2026-05-04 broad-10k run used 4144 symbols (filtered) instead of ~10k — too aggressive.
- Future runs should target the full universe; if the runner crashes on a missing-bar symbol, that's a runner bug to file separately, not a reason to pre-filter the universe.
- Open question (defer until early-termination behavior verified): how should the runner handle a symbol whose CSV ends mid-window? Force-exit on last bar? Carry as held until window end with stale price? Document in a follow-up note when the broad-10k run completes.
