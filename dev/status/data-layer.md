# Status: data-layer

## Last updated: 2026-03-26

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Completed

### 2026-03-26
- `Historical_source`: read-only from local cache, no-lookahead enforced via `simulation_date` ceiling
- 11 tests covering boundary inclusivity/exclusivity, end_date clamping, start_date filtering, missing symbol, universe loading, and step-by-step simulation semantics — all passing
- PR #132: Add Historical data source with no-lookahead guarantee

### 2026-03-24
- `Live_source`: EODHD API with local CSV cache, throttled requests (configurable), freshness check
- Universe stored as sexp file; injectable fetch function for test isolation
- PR #127: Update data-source-impl: sexp universe, injectable fetch, file-based tests
- `DataSource` module type (`DATA_SOURCE`) finalized in `analysis/weinstein/data_source/lib/data_source.mli`
- `bar_query` convenience record type with `show` and `eq` derivations
- PR #125: Add DataSource module type for Weinstein data abstraction layer
- EODHD client extended with `period` field in `historical_price_params` (Daily/Weekly/Monthly cadence)
- `Fundamentals` type added to EODHD client (symbol, name, sector, industry, market_cap, exchange)
- `get_fundamentals` and `get_index_symbols` added to EODHD HTTP client
- All existing EODHD call sites updated to include `period = Cadence.Daily`
- 4 new EODHD tests (weekly period URI, fundamentals parsing, index symbols, error case) — 15 total, all passing
- PR #124: Extend EODHD client with period, fundamentals, and index symbols

## In Progress
- None

## Blocked
- None

## Next Steps
- Review and merge `feat/data-layer` to `main`
- `Synthetic_source`: deterministic programmatic bar generation (Trending, Basing, Breakout patterns) — deferred, not needed until simulation tuning (eng-design-4)
- The screener agent can now use `(module Data_source.DATA_SOURCE)` from `weinstein.data_source`
- Universe cache writer: script/tool to populate `data/fundamentals/universe.json` via `get_fundamentals`

## Recent Commits
- PR #132: Add Historical data source with no-lookahead guarantee
- PR #127: Update data-source-impl: sexp universe, injectable fetch, file-based tests
- PR #125: Add DataSource module type for Weinstein data abstraction layer
- PR #124: Extend EODHD client with period, fundamentals, and index symbols
