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

**Macro data feeds** — required before `Macro.analyze` can run from real data; not needed for regression tests (construct `Macro.result` directly — see `docs/design/t2a-golden-scenarios.md`):

- **Primary index bars** (`~index_bars`): EODHD symbols `GSPC.INDX` or `DJI.INDX`. `GSPCX` (cached at `data/G/X/GSPCX/`, daily from 1997) is a usable stand-in.
- **NYSE A-D breadth** (`~ad_bars`): daily advancing/declining counts — not derivable from price bars. EODHD symbols likely `ADV.NYSE` / `DEC.NYSE`; verify. Requires a new parser (not OHLCV format).
- **Global index bars** (`~global_index_bars`): FTSE 100 via `ISF.LSE` (iShares ETF proxy — EODHD does not carry `FTSE.INDX`), DAX (`GDAXI.INDX`), Nikkei 225 (`N225.INDX`). `IWM` (cached at `data/I/M/IWM/`) usable as interim US small-cap proxy.

Until cached: call with `ad_bars:[]` and `global_index_bars:[]`; analyzer degrades gracefully.
