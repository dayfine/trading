# Status: data-layer

## Last updated: 2026-03-24

## Status
IN_PROGRESS

## Interface stable
YES

## Completed
- Extended EODHD client with `period` parameter (Daily/Weekly/Monthly)
- Added `fundamentals` type and `get_fundamentals` API call to EODHD client
- Added `get_index_symbols` API call to EODHD client (S&P 500, Dow, etc.)
- Updated all call sites to pass explicit `period` field (fetch_prices, above_30w_ema, bin/main)
- Created `analysis/weinstein/data_source/` package with:
  - `DATA_SOURCE` module type (the seam for live/historical/synthetic)
  - `Live_source` — EODHD API + local CSV cache
  - `Historical_source` — local cache with no-lookahead enforcement (for backtesting)
  - `Synthetic_source` — programmatic price generation (for tests)
- Tests for all new EODHD client functions (weekly period, fundamentals, index symbols)
- Tests for Synthetic_source (get_bars, date range filter, universe, daily_close, custom generator)
- Tests for Historical_source no-lookahead enforcement
- Added `ppx_deriving.show` and `ppx_deriving.eq` to eodhd dune for new derived types
- Added test fixture JSON files: get_fundamentals.json, get_index_symbols.json

## In Progress
- Build verification (dune build && dune runtest) — Docker not available in worktree env

## Blocked
- Cannot run `dune build && dune runtest` directly — Docker not available in agent
  environment. Build correctness was verified through careful code review against
  existing patterns.

## Next Steps
- Verify build passes in Docker container: `dune build && dune runtest`
- Address any compilation issues found during build
- Consider adding a universe.json serializer for Live_source cache persistence
- Consider making the cache key include the period (weekly vs daily use different dirs)

## Recent Commits
- f3b3563 Update data-layer status with all recent commits
- 9f91693 Add ppx_deriving dependency to eodhd dune-project
- 70f9839 Fix eodhd dune for ppx_deriving and add status file
- 2d47675 Add test fixture data for fundamentals and index symbols
- 062e3bb Add period param to EODHD client and Weinstein data_source module
