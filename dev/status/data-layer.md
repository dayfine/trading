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

**Macro data feeds** — data presence status as of 2026-04-14. Strategy-wiring track (`dev/status/strategy-wiring.md`) covers the remaining runtime composition work; data layer itself is complete for these feeds.

- **Primary index bars** (`~index_bars`): `GSPCX` cached at `data/G/X/GSPCX/` (daily from 1997). Wired via `runner.ml`. ✓
- **NYSE A-D breadth** (`~ad_bars`): CACHED in two sources.
  - Unicorn historical: `data/breadth/nyse_{advn,decln}.csv` (1965-03-01 → 2020-02-10). Wired via `Ad_bars.Unicorn.load`. ✓
  - Synthetic post-2020: computed by `Synthetic_adl` module + `compute_synthetic_adl.exe` script; output convention `data/breadth/synthetic_nyse_{advn,decln}.csv`. Façade composition into `Ad_bars.load` is pending — tracked in `dev/status/strategy-wiring.md` Item 1.
  - EODHD verified NOT a source: `ADV.NYSE`/`DEC.NYSE` return Ticker Not Found. Pinnacle Data evaluated ($39 one-time, 1940-present) but declined — synthetic-only chosen for live coverage.
- **Sector ETF bars**: all 11 SPDRs cached. Wired via `Macro_inputs.spdr_sector_etfs` in `runner.ml`. ✓
- **Global index bars** (`~global_index_bars`): FTSE proxy (`ISF.LSE`), DAX (`GDAXI.INDX`), Nikkei (`N225.INDX`) — data status per symbol needs to be re-checked at wiring time. Wiring is pending — tracked in `dev/status/strategy-wiring.md` Item 2 (needs `default_global_indices` constant + runner override).
