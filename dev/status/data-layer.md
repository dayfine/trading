# Status: data-layer

## Last updated: 2026-04-06

## Status
MERGED

## Interface stable
YES

## Completed

- `DATA_SOURCE` module type, EODHD client extensions, `Live_source`, `Historical_source` — PRs #124, #125, #127, #132
- All 5 QC follow-up items addressed; `Universe.load` hidden from public interface — PR #192

## In Progress
- None

## Blocking Refactors
- None

## Follow-up

- Add `get_daily_close` to `DATA_SOURCE` interface — needed by portfolio-stops for mid-week stop checks
- Universe cache writer: populate `data/universe.sexp` via `get_fundamentals` + `get_index_symbols`; required before any live run; suggested `analysis/scripts/fetch_universe.ml`

## New work — eng-design-data-management.md (blocks T2-A golden scenarios)

All four items implemented on `feat/data-management` branch (see `docs/design/eng-design-data-management.md` for full spec):

1. **DONE** `Data_path.default_data_dir` — `analysis/weinstein/data_source/lib/data_path.ml/.mli`
2. **DONE** `build_inventory.exe` — `analysis/scripts/build_inventory/`; ran and generated `data/inventory.json` (37,406 symbols)
3. **DONE** `fetch_symbols.exe` — `analysis/scripts/fetch_symbols/` (not run live — requires API key)
4. **DONE** `Universe.rebuild_from_data_dir` — added to `universe.ml/.mli`

**AAPL coverage verified:** `data/inventory.json` shows AAPL from 1980-12-12 to 2025-05-16, which fully covers the 2017-01-01 to 2024-06-28 range required by T2-A golden scenarios.
## Known gaps

**Macro data feeds** — required before `Macro.analyze` can run from real data; not needed for regression tests (construct `Macro.result` directly — see `docs/design/t2a-golden-scenarios.md`):

- **Primary index bars** (`~index_bars`): EODHD symbols `GSPC.INDX` or `DJI.INDX`. `GSPCX` (cached at `data/G/X/GSPCX/`, daily from 1997) is a usable stand-in.
- **NYSE A-D breadth** (`~ad_bars`): daily advancing/declining counts — not derivable from price bars. EODHD symbols likely `ADV.NYSE` / `DEC.NYSE`; verify. Requires a new parser (not OHLCV format).
- **Global index bars** (`~global_index_bars`): FTSE 100 (`FTSE.INDX`), DAX (`GDAXI.INDX`), Nikkei 225 (`N225.INDX`). `IWM` (cached at `data/I/M/IWM/`) usable as interim US small-cap proxy.

Until cached: call with `ad_bars:[]` and `global_index_bars:[]`; analyzer degrades gracefully.
