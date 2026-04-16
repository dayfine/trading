# Status: sector-data

## Last updated: 2026-04-15

## Status
IN_PROGRESS

Item 1 merged (#349), Items 2-3 pending.

## Ownership
`ops-data` agent — see `.claude/agents/ops-data.md`. Scope is data
infrastructure (fetch script, parser, output CSV). The `Sector_map`
OCaml loader already exists at
`trading/analysis/weinstein/data_source/lib/sector_map.{ml,mli}` and
consumes `data/sectors.csv` — it is format-agnostic and works with any
row count, so no feature-code work is required to absorb a larger file.

## Interface stable
YES

Output file schema is fixed: `data/sectors.csv` with header
`symbol,sector` and GICS sector names. New fetcher must write this exact
schema so `Sector_map.load` keeps working unchanged.

## Blocked on
- None.

## Problem

Current `data/sectors.csv` = **1,654 symbols** (static, pre-committed, no
fetcher code in the repo). This caps the backtest universe at 1,654 since
`runner.ml:89-91` derives the universe from `Hashtbl.keys ticker_sectors`.
Total EODHD inventory is 24,529 instruments; the active target is
~5,000–8,000 common-stock tickers with sector tags.

Prior attempt — `dev/notes/sector-data-plan.md` §SSGA — validated a
holdings-file fetcher (Phase 0 done 2026-04-11) but only covers ~492
S&P 500 names. Insufficient for this goal. SSGA remains a potential
authoritative source for S&P 500 sector labels in a later validation
pass but is not the primary coverage path.

## Chosen approach — Finviz scrape

Finviz (`finviz.com/quote.ashx?t=<SYM>`) serves a compact stats table
per ticker that includes `Sector`, `Industry`, and `Country`. Historical
layout is stable enough for a one-shot HTML scrape. Coverage for
US-listed common stocks: ~8,000 names at 1 req/sec → ~2.2 hours
one-shot. No auth required. Terms-of-service grey area acceptable for
internal, non-redistributed use.

### Why Finviz over alternatives

| Source | Coverage | Cost | Integration effort |
|---|---|---|---|
| **Finviz** (chosen) | ~8,000 US common stocks | free | HTML scrape (~250 lines OCaml) |
| SSGA holdings | ~492 (S&P 500) | free | XLSX parser (~200 lines) — in the repo plan but coverage too narrow |
| EODHD fundamentals | full 24k inventory | $59.99/mo | one API call per symbol, standard JSON |
| Yahoo summaryProfile | varies, flaky | free | scraping, rate-limited |

Finviz is the only free option that covers the desired scope. Paid
EODHD stays available as a drop-in upgrade if Finviz becomes unstable.

## Completed
- Phase 0 validation on SSGA (2026-04-11) — confirmed the XLSX
  endpoint works but limited coverage. Kept as a backup source.
- Existing `Sector_map.load` handles arbitrary-sized `sectors.csv`.
- **Item 1 — `fetch_finviz_sectors.exe`** (2026-04-15) — implemented
  and tested. 7 files, ~250 lines OCaml + ~170 lines tests. Uses
  `cohttp-async` + `re` (regex) for HTML parsing. Builds and all 10
  unit tests pass. Branch: `ops/sector-finviz-scraper`.
- **Item 4 — universe_filter library + binary** (2026-04-14) —
  `trading/analysis/scripts/universe_filter/` with
  `Symbol_pattern` / `Keep_allowlist` rules loaded from
  `dev/config/universe_filter/<name>.sexp`. 10 unit tests pass.
  Branch: `ops/universe-filter`.

  Dry-run against `data/sectors.csv` (8,255 rows as of 2026-04-14):

  | rule | raw hits |
  |---|---:|
  | `suffix_units_.U` | 0 |
  | `suffix_warrant_.W` | 0 |
  | `suffix_warrant_.WS` | 0 |
  | `preferred_-P` | 0 |
  | `index_.INDX` | 0 |
  | `warrant_len>3_endsW` | 12 |
  | **total dropped** | **12** |

  Sector breakdown before → after:

  | sector | before | after | Δ |
  |---|---:|---:|---:|
  | Financials | 4,585 | 4,582 | -3 |
  | Health Care | 886 | 886 | 0 |
  | Information Technology | 593 | 590 | -3 |
  | Industrials | 579 | 575 | -4 |
  | Consumer Discretionary | 457 | 456 | -1 |
  | Energy | 197 | 196 | -1 |
  | others | unchanged | | |

  **Finding — the default rule-set barely dents Financials.** The
  exchange-suffix rules (`.U`, `.W`, `.WS`, `-P*`, `.INDX`) match
  zero rows because Finviz already strips those forms before we
  ingest. The `warrant_len>3_endsW` rule fires 12 times but on
  legitimate common stocks (SCHW, PANW, SNOW, TROW, ACIW, CHRW,
  DNOW, EZPW, HAYW, INSW, MATW, SKYW) — all real tickers, no
  warrants. In the current source, that rule is a false-positive
  trap rather than a useful filter.

  The Financials bloat (4,585 rows, 55%) is almost entirely
  **bond / fixed-income ETFs, leveraged / inverse ETFs, trust
  preferreds, and closed-end funds** that Finviz classifies under
  "Financial Services" → normalized to Financials. None of those
  carry distinctive symbol-suffix markers; they look like ordinary
  4-letter tickers (AAAU, AACB, AADR, ACEP, ACES, …).

  **Follow-up items (new, add to "Next Steps"):**

  - Item 5 — add an `Industry_pattern` rule variant so we can drop
    e.g. "Exchange Traded Fund", "Shell Companies", "Asset
    Management" subsets directly, using the Finviz industry cell
    (requires extending the scrape to capture industry and
    plumbing it through the CSV — currently we only store sector).
  - Item 6 — optional volume / market-cap gate: drop symbols whose
    cached bars show `avg_dollar_volume < $1M/day` or
    `market_cap < $100M`. Needs the bars cache populated first.
  - Item 7 — reconsider `warrant_len>3_endsW` — either remove it
    or tighten to "ends-in-W AND not-in-known-common-stock-list".
    Keeping it as-is would silently drop SCHW, SNOW, PANW from the
    universe.

## In Progress
- None — waiting for Item 1 PR merge before Item 2 (one-shot run).

## Next Steps (work items — ops-data)

### Item 1 — `fetch_finviz_sectors.exe`

Scope: `trading/analysis/scripts/fetch_finviz_sectors/`.

- Reads the universe list (default: `data/universe.sexp` — all 24,529,
  filtered to Common Stock) and fetches `finviz.com/quote.ashx?t=<SYM>`
  per ticker.
- Rate-limits at 1 req/sec (configurable via `--rate-limit`).
- Uses `cohttp-lwt-unix` with a benign `Mozilla/5.0` User-Agent and
  redirect-following.
- Parser extracts `Sector` cell from the snapshot table. Use `lambdasoup`
  (already available) or a small regex — the table is server-rendered
  HTML, not JS-rendered.
- Writes `data/sectors.csv` (header `symbol,sector`) atomically via a
  tempfile + rename. Also writes `data/sectors.csv.manifest` (sexp):
  `{ fetched_at; source = "finviz"; row_count; rate_limit_rps; errors }`.
- Idempotent resume: if the manifest is fresh (<30 days old) and a
  symbol already has a row, skip it unless `--force`.
- Graceful degradation: on HTTP errors for a single symbol, log + skip;
  continue the batch. Success criterion: ≥80% of symbols parsed.

Estimate: ~250 lines OCaml + ~40 lines dune/tests.

### Item 2 — one-shot run + commit the expanded file

- Run the fetcher against the current universe.
- Target: 5,000+ symbols with valid sector assignments.
- Commit resulting `data/sectors.csv` + `data/sectors.csv.manifest`.
- Run the existing backtest smoke test to confirm universe size bumps
  from 1,654 to ≥5,000 and nothing breaks downstream.

### Item 3 — refresh cadence hook

- Update `.claude/agents/ops-data.md` preflight: read
  `data/sectors.csv.manifest` at session start; warn + offer refresh if
  `fetched_at` is more than 30 days stale.

Estimate: ~20 lines of agent-def edits.

### Item 4 — universe composition cleanup (drop mutual funds + noise)

The current universe (derived from `sectors.csv` keys) carries symbols
the Weinstein strategy will never trade: mutual funds (no intraday
bars), extremely-low-volume ETFs (won't pass the volume filter
anyway), ADRs / preferreds / warrants / units that are noise for a
stage-analysis strategy. They inflate fetch / memory budgets and slow
every simulation step linearly.

Scope:
- New `trading/analysis/scripts/universe_filter/universe_filter.ml`:
  pure function `filter : Instrument_info.t list -> Instrument_info.t list`
  applying rules by instrument type + exchange + symbol suffix +
  (optional) average dollar-volume threshold.
- Rule set (configurable, not hardcoded):
  - Drop instrument types containing "Mutual Fund" / "Open-End Fund"
  - Drop symbols matching patterns already in
    `_is_likely_etf_or_index` in `fetch_finviz_sectors_lib` (suffixes
    `.INDX`, `W`, `WS`, `-P*`, `.U`). Reuse or factor out shared logic.
  - Optional: drop symbols with `avg_dollar_volume < $1M/day` when the
    bars cache has enough history to compute it.
- Wire into the `sectors.csv` rebuild path: filter the universe list
  *before* passing it to the scraper, so we don't spend 1 req/sec on
  tickers we'll throw away.
- Hand-picked ETF allow-list kept outside the filter (SPY, QQQ, XL*
  sector ETFs, a few large VTI/VOO/QQQ variants) so we don't lose the
  sector-ETF inputs the strategy needs.

Estimate: ~200 lines OCaml + ~60 lines tests + universe regen.

Acceptance: rerunning the Finviz scraper on the filtered universe
yields fewer errors (no more of the OTC "A*" junk that can't parse)
and the resulting `sectors.csv` is smaller but still ≥5,000 rows of
real common stock + ETFs.

## Not in scope
- `Sector_map` loader changes — already works generically.
- Weinstein strategy wiring — already consumes `ticker_sectors` via
  `runner.ml` and `Macro_inputs.build_sector_map`.
- Paid EODHD upgrade — available as a fallback but not the chosen path.
- SSGA XLSX fetcher — superseded by Finviz for coverage reasons; kept
  optional for S&P 500 validation cross-check.

## QC
overall_qc: NOT_STARTED
structural_qc: NOT_STARTED
behavioral_qc: NOT_STARTED

Reviewers when work lands:
- qc-structural — HTTP client patterns, error handling, atomic file
  write, idempotency.
- qc-behavioral — manual spot-check on 20-30 random sector assignments
  vs authoritative source (e.g. SSGA holdings, Yahoo profile). Assert
  coverage goal (≥5,000 rows) and no schema drift in `sectors.csv`.

## References
- `dev/notes/sector-data-plan.md` — original SSGA plan (now backup)
- `trading/analysis/weinstein/data_source/lib/sector_map.mli` — loader
- `trading/trading/backtest/lib/runner.ml:85-95` — universe derivation
- `dev/status/data-layer.md` §Sector coverage expansion — stale,
  superseded by this file
