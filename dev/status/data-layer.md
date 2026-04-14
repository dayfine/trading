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

### Sector coverage expansion

EODHD's fundamentals endpoint (which populates sector/industry) requires a
higher API tier we're not on. The sector field is blank for most symbols in
the inventory — only the manually-populated SPDR sector ETFs have labels,
which is why `Sector_map` currently resolves via a composite key (see
`dev/status/screener.md` §Followup — "Sector map key resolution").

Alternatives worth evaluating:

1. **Scrape Yahoo Finance** — the `summaryProfile` module on
   `https://finance.yahoo.com/quote/<SYM>/profile/` has sector + industry.
   Free, but rate-limited and terms-of-service grey-area.
2. **Scrape Finviz** — `finviz.com/quote.ashx?t=<SYM>` has a compact stats
   table including sector + industry + country. Historically stable layout.
3. **Scrape Google Finance** — less structured; often pulls from Yahoo.
4. **Paid tier on EODHD** — simplest; unclear cost vs value.
5. **Upgrade to Polygon or IEX Cloud** for sector data — bigger migration.

Recommended first pass: one-time Finviz scrape, cache the sector+industry
mapping into `data/sectors.csv`, update `Sector_map.load` to use it. About
8,000 common stocks; at 1 req/sec that's ~2 hours. Treat as a harness /
ops-data task, not a runtime dependency.

**Potential trading-behaviour impact.** Wider sector coverage changes which
symbols pass the `Sector` screener filter. See
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
