# Sector Data Plan — SPDR ETF Holdings

**Owners**: `ops-data` (Phase 0 validation + Phase 1 fetcher + Phase 3 cadence), `feat-weinstein` (Phase 2 OCaml loader + Phase 4 strategy wiring)
**Status**: ACTIVE — Phase 0 blocked on ops-data validation of SSGA URLs
**Last updated**: 2026-04-11

**Supersedes**: the Wikipedia scrape plan in `fundamentals-requirements.md` (now marked deprecated).

## Why we reconsidered

Three review points against the Wikipedia approach:

1. **Python runtime reliability**: a refresher that runs repeatedly is a maintenance commitment. Either we guarantee Python is available in the container (pinning, CI, docs) or we write the scraper in OCaml — either way, work.
2. **Refresh cadence policy should be automatic, not manual**: a point-in-time scrape needs an enforced refresh cadence, ideally as part of the ops-data pipeline rather than a human checklist.
3. **Step-back question**: what do we need composition for? Answer: **we don't**. We need `ticker → sector` mappings. Wikipedia pages are being used as a two-for-one (constituents + sector tags), but composition is incidental.

Once we accept (3), the question becomes: **where do we get ticker → sector most cleanly?**

## The new plan

**Use SPDR sector ETF holdings files from State Street (SSGA).**

### Why this source wins

- **Same provider as our price bars.** We already cache XL* daily bars via EODHD. State Street (SSGA) is the ETF issuer; they publish daily holdings files directly. One less data-provider in the dependency graph.
- **Authoritative.** The holdings are regulatory compliance disclosures — they're the source of truth for what each ETF holds, including each holding's GICS sector. Wikipedia lags official committee decisions by days/weeks; SSGA does not.
- **Daily refresh is free.** The holdings files update every market day. Cadence automation collapses into "fetch holdings whenever you fetch ETF bars." No separate policy.
- **Coverage matches our screener universe.** Union of holdings across all 11 SPDR sector ETFs is ~500 names — essentially the S&P 500, which is the liquid Weinstein-relevant universe. Long-tail names fall into the "unknown sector" bucket handled by `Portfolio_risk.max_unknown_sector_positions` (already merged in #250).
- **No Python dependency.** SSGA holdings are delivered as Excel or CSV. Excel → CSV conversion is a one-time concern (done offline if needed); runtime OCaml only needs to read CSV.

### Data source details (to validate)

Each SPDR sector ETF has a holdings page. Pattern:

```
https://www.ssga.com/us/en/individual/etfs/library-content/products/fund-data/etfs/us/holdings-daily-us-en-{symbol}.xlsx
```

Where `{symbol}` is `xlk`, `xlf`, `xle`, etc. The format and stability of these URLs are **unverified** — this is the first thing to confirm.

Possible alternatives if SSGA URLs are unstable:
- **iShares holdings** (BlackRock) — iShares sector ETFs like `IYW` (Technology) publish holdings. Different URL pattern.
- **Invesco / Vanguard** — similar for their sector ETF families.
- **Direct index provider** — S&P Dow Jones Indices publishes constituents, but typically behind login.

### Coverage analysis

Holdings across the 11 SPDR ETFs (XLK/XLF/XLE/XLV/XLI/XLP/XLY/XLU/XLB/XLRE/XLC) are **close to the S&P 500**. Approximate counts:
- XLK (Technology): ~70
- XLF (Financials): ~70
- XLE (Energy): ~23
- XLV (Health Care): ~62
- XLI (Industrials): ~77
- XLP (Consumer Staples): ~38
- XLY (Consumer Discretionary): ~53
- XLU (Utilities): ~30
- XLB (Materials): ~28
- XLRE (Real Estate): ~31
- XLC (Communication Services): ~23

Total: ~505 unique tickers (some overlap between GICS sectors is handled by the fund selector).

**What this covers**: the S&P 500.
**What this misses**: S&P 400 (mid-cap), S&P 600 (small-cap), Russell 1000 names outside the S&P 500. ~1000 additional tickers.

For the missed names, the fallback is the **"unknown sector" bucket** (already implemented in #250): those positions are capped at 2 simultaneous holdings via `max_unknown_sector_positions`. This is a deliberate design choice — unknown-sector names are treated as higher-risk concentration-wise, so we hold fewer of them.

## Engineering plan

### Phase 0: Validation (ops-data, one-shot, no code)

Before writing any code, ops-data needs to confirm the SSGA URLs work and the format is usable:

1. `curl` one of the SSGA holdings URLs (e.g. XLK) and inspect the response
2. Confirm: (a) CSV or Excel, (b) how to extract the "Ticker" and "Sector" columns, (c) whether a simple daily refresh is feasible without auth
3. Document findings in this doc under a "Validation" section
4. If SSGA URLs don't work, fall back to iShares and try again

**Owner**: ops-data
**Input**: this doc
**Output**: updated plan with confirmed URLs + response format, or a rejection of the SSGA approach with reasons.

### Phase 1: Holdings fetcher (ops-data + feat)

Add a new `fetch_sector_holdings` script under `analysis/scripts/`. Input: list of SPDR ETF symbols (hardcoded or configurable). Output: `data/sectors.csv` with columns `symbol,sector,etf,fetched_at`.

- Uses `cohttp` to download the URL for each ETF (same HTTP stack as `fetch_universe.exe`)
- Parses CSV (or converts Excel → CSV offline and commits the converter as a separate tool)
- Deduplicates tickers (a ticker should only appear once even if it's a member of multiple overlapping groups — sector assignment is a function of the ticker, not the ETF)
- Writes `data/sectors.csv` + `data/sectors.csv.manifest` (JSON: `last_refreshed`, `etf_urls`, `row_count`)

**Owner**: feat agent (new branch `data/sector-holdings`)
**LOC estimate**: ~200 lines OCaml + ~30 lines dune/tests

### Phase 2: OCaml `Sector_map` loader (feat)

Replaces the Wikipedia `Sector_map` from PR #251. Reads `data/sectors.csv` and produces a `string → string` map (ticker → sector name).

- `Sector_map.load : data_dir:Fpath.t -> (string, string) Hashtbl.t`
- Missing file returns empty map (graceful degradation — strategy runs without sector info)
- Used by `enrich_universe_sectors.exe` to populate `Instrument_info.sector`
- Used eventually by `Weinstein_strategy` to build the ticker-keyed sector_map that `Screener.screen` consumes

**Owner**: feat agent
**LOC estimate**: ~50 lines

### Phase 3: Refresh cadence in ops-data preflight

Update the ops-data agent definition to:

1. Read `data/sectors.csv.manifest` at session start
2. If `last_refreshed` is more than 30 days old, warn and offer to refresh as part of the session
3. Record outcomes in the usual ops-data report

**Owner**: documentation update to `.claude/agents/ops-data.md`
**LOC estimate**: ~20 lines of agent-def edits

### Phase 4: Strategy wiring (later, after #260 lands)

Once `Sector_map` exists and populates `Instrument_info.sector`, `Weinstein_strategy` can build the ticker-keyed sector_map that `Screener.screen` actually consumes:

```ocaml
(* Build: ticker -> sector_context *)
let ticker_sector_map =
  Hashtbl.filter_map ticker_to_sector ~f:(fun sector_name ->
    (* lookup ETF for this sector name, read its sector_context
       from the etf_sector_map *)
    Hashtbl.find etf_sector_map sector_name)
```

This closes the `ticker → sector → ETF context` join that's currently missing (noted in #260's caveat).

**Owner**: feat-weinstein agent (new branch)
**LOC estimate**: ~50 lines + tests

## Action items (on merge of #258 stack)

1. **Close #251, #252, #253**: the Wikipedia sector-map stack. #250 (unknown-sector bucket in Portfolio_risk) is already merged and stays.
2. **Kick off ops-data Phase 0**: validate SSGA URLs.
3. On Phase 0 success: open feat branch for Phase 1 (fetcher).
4. On Phase 1 merge: open feat branch for Phase 2 (OCaml loader).
5. Phase 3 agent-def update: small PR.
6. Phase 4 strategy wiring: after #260 lands and Phase 2 is merged.

## Fallback options

If SSGA holdings prove unusable:

1. **iShares holdings** — same idea, different provider
2. **EODHD Fundamentals upgrade** ($59.99/mo) — covers the full 24k universe directly, one API call per symbol. Preserves optionality even if we never upgrade now.
3. **OCaml-native Wikipedia scraper** — revive the deprecated plan but in OCaml with `cohttp` + a small HTML parser. Keeps the Wikipedia dependency but eliminates the Python concern.

## Open questions

1. Does the SSGA holdings URL pattern above actually return CSV-parseable data without auth? (Phase 0 validation)
2. How many tickers appear in multiple SPDR sector ETFs? (Affects dedup logic in Phase 1)
3. Is ETF selection expressed per-ticker or per-holding-row in the SSGA file? (Affects parser)
4. Do we care about Russell 2000 small-caps right now? If yes, we need more ETFs (VB, IWM constituents). If no, the 11 SPDR ETFs are sufficient.
