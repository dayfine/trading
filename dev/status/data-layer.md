# Status: data-layer

## Last updated: 2026-03-27

## Status
MERGED

## Review
See dev/reviews/data-layer.md — APPROVED (merged PRs #124, #125, #127, #132)

## Review
See dev/reviews/data-layer.md — NEEDS_REWORK

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

## Follow-up
Post-merge issues found in QC review (see dev/reviews/data-layer.md). Address before starting new work:
1. Fix misplaced doc comment in `http_client.mli` — comment for `period` is on `end_date` field
2. Log (don't ignore) cache-write error in `live_source.ml` — `ignore (_save_bars_to_cache ...)` silently drops failures
3. Extract duplicated `_load_universe` — identical copy in `live_source.ml` and `historical_source.ml`
4. Document that `period` is silently ignored in `Historical_source` — note it in both `historical_source.mli` and `data_source.mli` `get_bars` doc
5. Remove `Synthetic_source` reference from `data_source.mli` module doc — deferred to eng-design-4

## Next Steps
- `Synthetic_source`: deterministic programmatic bar generation (Trending, Basing, Breakout patterns) — deferred, not needed until simulation tuning (eng-design-4)
- Universe cache writer: script/tool to populate `data/fundamentals/universe.json` via `get_fundamentals`

## Recent Commits
- PR #132: Add Historical data source with no-lookahead guarantee
- PR #127: Update data-source-impl: sexp universe, injectable fetch, file-based tests
- PR #125: Add DataSource module type for Weinstein data abstraction layer
- PR #124: Extend EODHD client with period, fundamentals, and index symbols
