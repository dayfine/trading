# Delisted sectors backfill — P5 (2026-05-18)

P5 of the delisted-aware universe agenda (see
`memory/project_eodhd_delisted_unlock.md` and
`dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md`). Closes the
sectors gap that the post-P4 cell (`weinstein-2019-top-500.sexp`
re-pin in #1190) flagged: ~23% of entries in the new top-500-2019 had
empty sectors after the delisted-aware composition rebuild because
the famous 2010-2026 delistings (TWTR, AABA, CELG, ANTM, AGN, ATVI,
CBS, CERN, ABMD, ALXN, etc.) weren't in `data/sectors.csv`.

## TL;DR

- Hand-curated supplemental list of **40 famous delistings** appended
  to `data/sectors.csv` (one-time append, schema-compatible).
- Re-ran `build_composition_universes_runner.exe` against the
  augmented `sectors.csv`.
- 84 composition goldens updated. Empty-sector count in
  `top-500-2019.sexp` dropped **115 → 100** (15 names sectored — the
  16 that overlap with top-500-by-volume in 2019; LB_old's
  ticker-reuse adjustment is the 1 that ended up not making the cut).
- All 10 famous delistings checked now carry their canonical GICS
  sector (Communication Services / Health Care / Information
  Technology / Materials / Energy).
- Re-ran `weinstein-2019-top-500-composition` scenario against the
  new goldens: metrics are stable within the bands pinned at #1190
  (return 77.30 vs prior 78.34, MaxDD 40.28 vs 42.17, ulcer 17.20
  vs 19.01 — all within ±20%/±15% tolerances; no re-pin needed).

## Why EODHD / Finviz / Yahoo can't do this for us

Three vendor probes failed (documented at end of
`memory/project_eodhd_delisted_unlock.md`):

- **EODHD `/api/fundamentals/<sym>`** — 403 on our tier for both live
  AND delisted symbols. Tier upgrade ($59.99/mo Fundamentals Data
  Feed or €99.99/mo All-In-One) rejected per the broader-first pivot.
- **Finviz** — returns HTTP 404 on
  `https://finviz.com/quote.ashx?t=TWTR` (delisted-symbol pages
  removed).
- **Yahoo Finance `/v10/finance/quoteSummary`** — returns "Invalid
  Crumb" without a session-scraped crumb token; brittle to operate.

EODHD's own `/api/exchange-symbol-list/US?delisted=1` response (the
one we cache as `data/delisted_symbols.sexp` in #1184) contains
`Code, Name, Country, Exchange, Currency, Type, Isin` — but NOT
`Sector`. Sector data lives behind the Fundamentals tier.

## fja05680/sp500 is current-only

The `fja05680/sp500` GitHub repo (under `master` branch) ships
`sp500.csv` with `Symbol, Security, GICS Sector, GICS Sub-Industry`
— but only for CURRENTLY-LISTED SP500 members. The sibling
"Historical Components & Changes" file has ticker rosters per date
but NO sector field.

So the famous delistings (TWTR, CELG, ANTM, etc.) are not in
sp500.csv (no longer SP500 → no row).

## Solution — hand-curated supplement

A 40-entry hand-curated list of major 2010-2026 SP500 delistings +
their GICS sectors, appended to `data/sectors.csv`. Source: common
financial knowledge of the delisting context (acquisition target's
sector at the time, e.g., CELG = Health Care because Celgene was a
biotech bought by BMS in 2019).

### Selected entries

| Symbol | Sector | Context |
|--------|--------|---------|
| AABA | Communication Services | Altaba = Yahoo successor, defunct 2019 |
| TWTR | Communication Services | Twitter, acquired by Musk 2022 |
| CELG | Health Care | Celgene, acquired by BMS 2019 |
| ANTM | Health Care | Anthem, rebranded to Elevance Health 2022 |
| AGN  | Health Care | Allergan, acquired by AbbVie 2020 |
| ATVI | Communication Services | Activision, acquired by Microsoft 2023 |
| CBS  | Communication Services | CBS, merged into Paramount 2019 |
| CERN | Health Care | Cerner, acquired by Oracle 2022 |
| ABMD | Health Care | Abiomed, acquired by JNJ 2022 |
| ALXN | Health Care | Alexion, acquired by AstraZeneca 2021 |
| XLNX | Information Technology | Xilinx, acquired by AMD 2022 |
| CHK  | Energy | Chesapeake Energy |
| TWX  | Communication Services | Time Warner, AT&T era |
| FIT  | Information Technology | Fitbit, acquired by Google 2021 |
| SCTY | Industrials | SolarCity, acquired by Tesla 2016 |
| ... | ... | (plus 25 more) |

Full list at `/tmp/delisted-sectors-starter.csv` (40 entries; not
committed as a separate fixture — appended directly to
`data/sectors.csv` to use the existing first-wins-on-duplicate
hashtable loader at `composition_inputs.ml:_insert_sector`).

### One ticker-reuse adjustment

LB was in my draft (was L Brands → Bath & Body Works, Consumer
Discretionary). But `data/sectors.csv` already has `LB,Energy`
(current LB = LandBridge, oil/gas). EODHD's delisted roster uses
`LB_old` for the original L Brands. Supplemental entry is
`LB_old,Consumer Discretionary` to avoid clobbering the LandBridge
sector for the live ticker.

## Impact on top-500-2019

Empty-sector count: 115 → 100 (-15). The 25 supplemental names that
DIDN'T move the needle on top-500-2019 are either:

- In top-1000 / top-3000 but not top-500 (most)
- Different EODHD code than my supplement assumed (e.g., FB_old,
  CTRA_old, POW_old)
- Foreign ADRs with EODHD codes that don't match (KBC, SBER, ACL)

Effective traded universe in `weinstein-2019-top-500-composition`
goes from ~385 (post-P4) to ~400 names — small but real improvement.

## Scenario re-run (post-P5)

| Metric            | Pre-P5 (#1190) | Post-P5     | Δ (post − pre) |
|-------------------|----------------|-------------|----------------|
| total_return_pct  |  78.34         |   77.30     | -1.04 pp       |
| total_trades      | 263            |  258        | -5             |
| win_rate          |  31.94         |   30.23     | -1.71 pp       |
| sharpe_ratio      |   0.69         |    0.69     | flat           |
| max_drawdown_pct  |  42.17         |   40.28     | -1.89 pp       |
| avg_holding_days  |  41.99         |   40.22     | -1.77          |
| sortino_ratio_ann |   0.96         |    0.96     | flat           |
| calmar_ratio      |   0.29         |    0.30     | +0.01          |
| ulcer_index       |  19.01         |   17.20     | -1.81          |

All metrics within the ±20%/±15% bands pinned at #1190 — **no
re-pin needed**. The directional pattern is consistent: marginal
improvement on risk-adjusted metrics (DD, ulcer down) as the 15
additional sectored names introduce a slightly more diversified mix.

## Remaining gap (P5 followup, deferred)

100 empty-sector entries remain in top-500-2019:

- Foreign mega-cap ADRs (KBC Belgium, SBER Russia, ACL Switzerland)
- EODHD ticker-reuse markers (FB_old = pre-Meta Facebook, CTRA_old,
  POW_old, COMP_old) — would need name-pattern matching to map
- Less-famous delistings (units, warrants, smaller-cap names)

Could close ~30 more entries via:

- **Wikipedia scrape** for the most famous 50 names not yet in the
  supplement — ~1 hr engineering + may run into wiki rate limits
- **Sharadar via Nasdaq Data Link** ($99/mo) — would close all,
  rejected per Option B pivot
- **Manual curation extension** — add 30-50 more entries to the
  supplement; ~30 min human time

None is on the critical path for the Bayesian production sweep
(#1192) since that sweep uses `goldens-sp500-historical/sp500-2010-2026.sexp`
which doesn't depend on delisted-aware composition.

## Reproducibility

The supplemental sectors list lives at `/tmp/delisted-sectors-starter.csv`
during this session. To reproduce:

```sh
# 1. Append supplement to sectors.csv (skip header):
tail -n +2 /tmp/delisted-sectors-starter.csv >> data/sectors.csv

# 2. Re-run composition builder:
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build analysis/data/universe/bin/build_composition_universes_runner.exe -- \
    --bars-root /workspaces/trading-1/data \
    --inventory /workspaces/trading-1/data/inventory.sexp \
    --sectors-csv /workspaces/trading-1/data/sectors.csv \
    --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
    --out-dir /workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/'

# 3. Verify (optional):
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios \
    --parallel 1 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios'
```

Wall: step 2 ~40 min; step 3 ~7 min.

## Files in this PR

- `data/sectors.csv` — 40 supplemental entries appended (10,473 → 10,513 rows)
- 84 × `trading/test_data/goldens-custom-universe/composition/top-N-YYYY.sexp` — rebuilt with supplemental sectors
- `dev/notes/delisted-sectors-backfill-p5-2026-05-18.md` (this)
