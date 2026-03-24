# Status: data-layer

## Last updated: 2026-03-24

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Completed
- EODHD client extended with `period` field in `historical_price_params` (Daily/Weekly/Monthly cadence)
- `Fundamentals` type added to EODHD client (symbol, name, sector, industry, market_cap, exchange)
- `get_fundamentals` and `get_index_symbols` added to EODHD HTTP client
- All existing EODHD call sites updated to include `period = Cadence.Daily`
- 4 new EODHD tests (weekly period URI, fundamentals parsing, index symbols, error case) — 15 total, all passing
- `DataSource` module type (`DATA_SOURCE`) finalized in `analysis/weinstein/data_source/lib/data_source.mli`
- `bar_query` convenience record type with `show` and `eq` derivations
- `Live_source`: EODHD API with local CSV cache, throttled requests (configurable), freshness check
- `Historical_source`: read-only from local cache, no-lookahead enforced via `simulation_date` ceiling
- `Synthetic_source`: deterministic programmatic bar generation (Trending, Basing, Breakout patterns)
- 8 data source tests covering all three implementations — all passing
- Full test suite (all existing + new): clean pass on `feat/data-layer`

## In Progress
- None

## Blocked
- None

## Next Steps
- Review and merge `feat/data-layer` to `main`
- The screener agent can now use `(module Data_source.DATA_SOURCE)` from `weinstein.data_source`
- Universe cache writer: script/tool to populate `data/fundamentals/universe.json` via `get_fundamentals`

## Recent Commits
- 1f19ea1 Implement DataSource implementations: Live, Historical, Synthetic
- 3212342 Add DataSource module type for Weinstein data abstraction layer
- ffb9eab Extend EODHD client with period, fundamentals, and index symbols
