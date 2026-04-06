# Status: data-layer

## Last updated: 2026-04-06

## Status
MERGED

## Interface stable
YES

## Completed

- `DATA_SOURCE` module type abstraction, EODHD client extensions, `Live_source`, `Historical_source` — PRs #124, #125, #127, #132
- All 5 QC follow-up items addressed — PR #192
- `Universe.load` hidden from public interface; `Universe.get_deferred` is the only public API — PR #192

## In Progress
- None

## Blocking Refactors
- None

## Follow-up

- Add `get_daily_close` to `DATA_SOURCE` interface — needed by portfolio-stops for mid-week stop checks; not yet implemented in `Live_source` or `Historical_source`
- Universe cache writer: populate `data/universe.sexp` via `get_fundamentals` + `get_index_symbols`. Required before any live run. Suggested: `analysis/scripts/fetch_universe.ml`

## Known gaps

**Macro data feeds** — required before `Macro.analyze` can run from real data (not needed for regression tests — construct `Macro.result` directly; see `docs/design/t2a-golden-scenarios.md`):

- **Primary index bars** (`Macro.analyze ~index_bars`): EODHD symbols `GSPC.INDX` or `DJI.INDX`. `GSPCX` (S&P 500 proxy, daily from 1997) is already cached at `data/G/X/GSPCX/` and usable as a stand-in.
- **NYSE A-D breadth** (`Macro.analyze ~ad_bars`): daily advancing/declining issue counts — not derivable from price bars. EODHD symbols likely `ADV.NYSE` / `DEC.NYSE`; verify. Requires a new parser (not OHLCV format).
- **Global index bars** (`Macro.analyze ~global_index_bars`): FTSE 100 (`FTSE.INDX`), DAX (`GDAXI.INDX`), Nikkei 225 (`N225.INDX`). None cached. `IWM` (Russell 2000 ETF, cached at `data/I/M/IWM/`) usable as interim US small-cap proxy.

Until the above are cached, call `Macro.analyze` with `ad_bars:[]` and `global_index_bars:[]`; it degrades gracefully.
