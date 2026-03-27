# Review: data-layer
Date: 2026-03-27
Status: APPROVED (merged — PRs #124, #125, #127, #132)

## Build / Test
- dune build: PASS
- dune runtest: PASS — 19 data_source tests (11 historical + 8 live) + 15 eodhd http_client tests; full project suite clean
- dune fmt: PASS

## Summary

The data-layer feature is merged to main across four PRs. It delivers the `DATA_SOURCE` module type abstraction, EODHD client extensions (`period`, `get_fundamentals`, `get_index_symbols`), `Live_source` (API with local CSV cache), and `Historical_source` (read-only from cache with no-lookahead guarantee). `Synthetic_source` was deferred to eng-design-4 and removed from scope. Since the original review (2026-03-24), `Live_source` gained 8 injectable-fetch tests and `Historical_source` gained 11 boundary/stepping tests; both use the project's matchers library. The architecture is clean and all analysis modules can now use `(module Data_source.DATA_SOURCE)` as a seam between live and simulation modes.

Two minor issues from the original review remain in the merged code and are tracked below.

## Findings

### Known Issues (in merged code — fix in a follow-up)

1. **Misplaced doc comment in `http_client.mli`** (`trading/analysis/data/sources/eodhd/lib/http_client.mli`): The comment `(** Cadence of price bars. Defaults to [Daily] if not specified. *)` is attached to the `end_date` field but belongs on the `period` field immediately below it. One-line fix.

2. **Cache-write error silently discarded in `Live_source`** (`trading/analysis/weinstein/data_source/lib/live_source.ml`): `ignore (_save_bars_to_cache data_dir symbol fetched)` discards the `Result.t` without logging. If the cache write fails, the caller gets data back but the cache is silently left stale. At minimum the error should be logged.

3. **Duplicated `_load_universe` implementation**: The function is copy-pasted verbatim between `live_source.ml` and `historical_source.ml`. Extract to a shared helper (e.g., in `data_source.ml`).

4. **`period` field silently ignored in `Historical_source`**: `get_bars ~query` discards `query.period` — CSV storage is keyed by symbol only. This is not documented in `historical_source.mli` or `data_source.mli`'s `get_bars` doc. A caller passing `Weekly` silently gets whatever cadence is on disk.

5. **`data_source.mli` still references `Synthetic_source`** in the module-level doc comment. Update to reflect that Synthetic_source is deferred to eng-design-4.

### Resolved since original review (2026-03-24)

- ~~`Live_source` has no unit tests~~ — fixed: `test_live_source.ml` with 8 tests (cache hit, stale refetch, cache write, date range, universe)
- ~~Tests use raw OUnit2 instead of matchers library~~ — fixed: both test files use `open Matchers`
- ~~`Breakout` pattern untested / magic numbers~~ — N/A: `Synthetic_source` removed from scope, deferred to eng-design-4
- ~~`Historical_source` no-lookahead guarantee untested~~ — fixed: 11 tests covering boundary inclusivity/exclusivity, end_date clamping, start_date filtering, missing symbol, universe, simulation stepping

## Checklist

**Correctness**
- [x] All interfaces specified in the design doc are implemented (`DATA_SOURCE`, `get_fundamentals`, `get_index_symbols`, `period` param, `Live_source`, `Historical_source`)
- [ ] No placeholder / TODO code in non-trivial paths — cache-write error silently ignored (live_source.ml)
- [x] Pure functions are actually pure (`Historical_source` has no hidden state; `Live_source` is stateful by design)
- [x] All parameters in config, nothing hardcoded (token, data_dir, max_concurrent_requests, simulation_date)

**Tests**
- [x] Tests exist for all public functions — `Historical_source` (11 tests), `Live_source` (8 tests), `DATA_SOURCE` interface exercised via both
- [x] Happy path covered
- [x] Edge cases covered (boundary dates, missing symbol, stale/fresh cache, absent universe)
- [x] Tests use the matchers library

**Code quality**
- [x] `dune fmt` clean
- [ ] `.mli` files document all exported symbols — misplaced doc comment in `http_client.mli`; `period` silent-ignore undocumented; `data_source.mli` still mentions removed `Synthetic_source`
- [x] No magic numbers
- [x] Functions under ~35 lines, modules under ~5 public methods
- [x] Internal helpers prefixed with `_`
- [x] No unnecessary modifications to existing modules

**Design adherence**
- [x] Matches the architecture described in the design doc (two live implementations, same interface, date-bounded queries)
- [x] Data flows match the component contracts (`DATA_SOURCE` seam, live/historical split)
