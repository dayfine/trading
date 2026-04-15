# Status: data-layer

## Last updated: 2026-04-14

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
- ~~Universe cache writer~~: DONE — `analysis/scripts/fetch_universe/fetch_universe.exe` fetches from EODHD exchange-symbol-list, populates name/exchange. Sector/industry empty (fundamentals endpoint requires higher API tier). 24,529 Common Stock + ETF instruments.

### Sector coverage expansion — tracked in dev/status/sector-data.md

Expanding `data/sectors.csv` from 1,654 rows to ~5,000–8,000 is its own
tracked unit. Owner: `ops-data`. Chosen path: Finviz scrape. Paid EODHD
fundamentals and Yahoo summaryProfile remain fallbacks. SSGA SPDR holdings
(`dev/notes/sector-data-plan.md`) is retained as an authoritative backup
for S&P 500 validation but is too narrow to drive primary coverage.

**Potential trading-behaviour impact.** Wider sector coverage changes
which symbols pass the `Sector` screener filter. See
`dev/status/backtest-infra.md` §Potential experiments.

### Universe composition cleanup

Today's universe is `analysis/scripts/fetch_universe/` output — 24,529
instruments (Common Stock + ETF from exchange-symbol-list). Many are
irrelevant to the Weinstein strategy:

- **Mutual funds**: most have no daily intraday bars; tracking them wastes
  fetch budget + memory. Drop unless explicitly requested.
- **Low-volume ETFs**: ETFs with average dollar volume < some threshold
  (e.g. $1M/day) shouldn't pass the volume-confirmation filter anyway —
  drop to shrink the universe.
- **Selected funds only**: keep a hand-picked list of widely-held Vanguard
  / Fidelity / Schwab ETFs (VTI, VOO, VXUS, SPY, QQQ, FXAIX, SWPPX, etc.)
  plus sector ETFs and large leveraged/inverse (TQQQ, SQQQ, SOXL, etc.)
  for completeness.

Implementation: a `universe_filter.ml` pass between `fetch_universe` output
and `Universe.load` that applies type + volume + whitelist rules. Configurable
so experiments can pin the pre-filter rules.

**Potential trading-behaviour impact.** Changes which symbols the screener
scans every Friday. See `dev/status/backtest-infra.md` §Potential experiments.

## Data management — MERGED (PR #209)

All four items from `docs/design/eng-design-data-management.md` are implemented and merged:

1. `Data_path.default_data_dir` — `analysis/weinstein/data_source/lib/data_path.ml/.mli`; hardcoded to `/workspaces/trading-1/data` (Docker workspace root set in `.devcontainer/Dockerfile`)
2. `build_inventory.exe` — `analysis/scripts/build_inventory/`; writes `data/inventory.sexp`
3. `fetch_symbols.exe` — `analysis/scripts/fetch_symbols/`; requires `--api-key`
4. `bootstrap_universe.exe` — `analysis/scripts/bootstrap_universe/`; builds `universe.sexp` from local inventory (replaces `Universe.rebuild_from_data_dir`)

**AAPL coverage verified:** inventory shows AAPL from 1980-12-12 to 2025-05-16, covering the 2017–2024 range required by T2-A golden scenarios.
## Known gaps

**Macro data feeds** — required before `Macro.analyze` can run from real data; not needed for regression tests (construct `Macro.result` directly — see `docs/design/t2a-golden-scenarios.md`):

- **Primary index bars** (`~index_bars`): EODHD symbols `GSPC.INDX` or `DJI.INDX`. `GSPCX` (cached at `data/G/X/GSPCX/`, daily from 1997) is a usable stand-in.
- **NYSE A-D breadth** (`~ad_bars`): daily advancing/declining counts — not derivable from price bars. EODHD symbols likely `ADV.NYSE` / `DEC.NYSE`; verify. Requires a new parser (not OHLCV format).
- **Global index bars** (`~global_index_bars`): FTSE 100 via `ISF.LSE` (iShares ETF proxy — EODHD does not carry `FTSE.INDX`), DAX (`GDAXI.INDX`), Nikkei 225 (`N225.INDX`). `IWM` (cached at `data/I/M/IWM/`) usable as interim US small-cap proxy.

Until cached: call with `ad_bars:[]` and `global_index_bars:[]`; analyzer degrades gracefully.
