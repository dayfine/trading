# Data Operations — 2026-04-10

Sector ETFs + FTSE proxy + ADL historical breadth. Three data unblocks.

## 1. SPDR sector ETFs — 11/11 cached

### Command

```bash
docker exec -e EODHD_API_KEY trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   ./_build/default/analysis/scripts/fetch_symbols/fetch_symbols.exe \
   --symbols XLK,XLF,XLE,XLV,XLI,XLP,XLY,XLU,XLB,XLRE,XLC \
   --data-dir /workspaces/trading-1/data \
   --api-key "$EODHD_API_KEY"'
```

Prerequisite: `EODHD_API_KEY` must be exported in the host shell. Put it in `~/.zshenv` (not `~/.zshrc`) so non-interactive zsh invocations pick it up.

### Coverage

| Symbol | Sector | Start | End | Bars |
|---|---|---|---|---|
| XLK | Technology | 1998-12-22 | 2026-04-10 | 6866 |
| XLF | Financials | 1998-12-22 | 2026-04-10 | 6866 |
| XLE | Energy | 1998-12-22 | 2026-04-10 | 6866 |
| XLV | Health Care | 1998-12-22 | 2026-04-10 | 6866 |
| XLI | Industrials | 1998-12-22 | 2026-04-10 | 6865 |
| XLP | Consumer Staples | 1998-12-22 | 2026-04-10 | 6866 |
| XLY | Consumer Discretionary | 1998-12-22 | 2026-04-10 | 6866 |
| XLU | Utilities | 1998-12-22 | 2026-04-10 | 6866 |
| XLB | Materials | 1998-12-22 | 2026-04-10 | 6866 |
| XLRE | Real Estate | 2015-10-08 | 2026-04-10 | 2641 |
| XLC | Communication Services | 2018-06-19 | 2026-04-10 | 1963 |

XLRE launched Oct 2015, XLC launched Jun 2018 — short histories are expected.

### Inventory refresh

```bash
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/trading && eval $(opam env) && \
   ./_build/default/analysis/scripts/build_inventory/build_inventory.exe \
   --data-dir /workspaces/trading-1/data'
```

Total after refresh: **37,421 symbols indexed**.

## 2. FTSE proxy — `ISF.LSE` wins after `UKX.INDX` fails

### Attempted primary: `UKX.INDX`

```bash
fetch_symbols.exe --symbols UKX.INDX --api-key "$EODHD_API_KEY"
```

Result: **empty bar list from EODHD**, same failure as `FTSE.INDX`. Not on our tier.

The fetch script crashed in `Metadata.generate_metadata` (`List.hd` on `[]`) — see `analysis/data/storage/metadata/lib/metadata.ml:20`. **Follow-up**: harden the script to emit a clean "no bars returned, skipping" error per symbol instead of crashing the whole run.

### Fallback: `ISF.LSE` (iShares Core FTSE 100 UCITS ETF)

```bash
fetch_symbols.exe --symbols ISF.LSE --api-key "$EODHD_API_KEY"
```

Result: **6,552 bars, 2000-05-02 → 2026-04-10**. Cached at `data/I/E/ISF.LSE/`.

Rationale for using an ETF proxy: ISF.LSE is a physical-replication tracker with a few bps of tracking error — functionally indistinguishable from the FTSE 100 index at weekly cadence. Dividend distributions cause minor gap adjustments but are irrelevant for Weinstein stage analysis.

## 3. ADL historical breadth — Phase A (Unicorn.us.com)

NYSE daily advancing/declining issue counts are not on EODHD (`ADV.NYSE` / `DEC.NYSE` return "Ticker Not Found"). Research (see `dev/status/adl-sources.md`) identified unicorn.us.com as the free historical source.

### Commands

```bash
mkdir -p /Users/difan/Projects/trading-1/data/breadth

curl -s -o /Users/difan/Projects/trading-1/data/breadth/nyse_advn.csv \
  http://unicorn.us.com/advdec/NYSE_advn.csv

curl -s -o /Users/difan/Projects/trading-1/data/breadth/nyse_decln.csv \
  http://unicorn.us.com/advdec/NYSE_decln.csv
```

HTTP 200 from both URLs, no auth, no rate limit.

### Files

| File | Size | Rows | Date range |
|---|---|---|---|
| `data/breadth/nyse_advn.csv` | 200,761 bytes | 13,873 | 1965-03-01 → 2020-02-10 |
| `data/breadth/nyse_decln.csv` | 200,480 bytes | 13,873 | 1965-03-01 → 2020-02-10 |

### Format

Two-column CSV, no header:

```
YYYYMMDD,<count>
```

**Gotcha**: The last 4 rows (2020-02-11 through 2020-02-14) are placeholder entries with `count=0`. The Unicorn maintainer stopped updating that week. The Phase C loader should skip/ignore rows with `count=0` when the surrounding context indicates placeholder data.

### Licence

No explicit licence on the Unicorn site. Cache locally, do not redistribute. Treat the data as a one-shot historical import.

### Not yet done

**Phase B** (live coverage 2020-02-11 → present): no source picked yet. Candidates in `dev/status/adl-sources.md`.

**Phase C** (OCaml loader + strategy wiring): a ~40-60 line `Ad_bars` module that parses the two CSVs, joins on date, filters placeholders, and returns `Macro.ad_bar list`. Then wire into `Weinstein_strategy.on_market_close` which currently hardcodes `~ad_bars:[]`.

## Coverage summary (post-session)

- **Total symbols in inventory**: 37,421
- **Sector ETF layer**: 11/11 fully populated
- **Global index layer**: 4/4 populated (GSPC, GDAXI, N225 previously cached; ISF.LSE added as FTSE proxy)
- **ADL breadth**: historical raw files on disk (Phase A); no loader yet (Phase C)
- **Instrument sector metadata**: blocked on EODHD fundamentals tier OR Wikipedia scrape (`feat/sectors-wikipedia` in progress)

## Reproducibility checklist

If you're re-running this from scratch:

1. `export EODHD_API_KEY=<your-key>` in `~/.zshenv` (not `.zshrc`)
2. `dune build` inside the container to rebuild fetch_symbols.exe
3. Run the three fetch commands above
4. Rebuild inventory with `build_inventory.exe`
5. Verify: `wc -l data/breadth/nyse_advn.csv data/breadth/nyse_decln.csv` should both be 13,873
6. Verify sector ETF inventory: each of the 11 symbols should show up under `data/X/<last-char>/<symbol>/data.csv`
