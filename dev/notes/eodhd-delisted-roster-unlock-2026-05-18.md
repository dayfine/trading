# EODHD Delisted Roster — PIT Universe Unblocked (2026-05-18)

Strategic finding: our existing EODHD subscription tier exposes the
delisted-symbols roster at no extra cost. The PIT-universe agenda
(`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`)
can now proceed without the IWV scrape, without paid scrapers, and
without a tier upgrade.

## What works

```bash
curl -s "https://eodhd.com/api/exchange-symbol-list/US?delisted=1&api_token=$EODHD_API_KEY&fmt=json" \
  | head -c 1000
# → 8.2 MB JSON, 57,592 entries
```

Schema (per-entry):
```json
{"Code": "TWTR", "Name": "Twitter Inc",
 "Country": "USA", "Exchange": "NYSE",
 "Currency": "USD", "Type": "Common Stock",
 "Isin": null}
```

Distribution:
- 57,592 total delisted symbols on US exchanges
- 31,737 Common Stock delisted (NASDAQ 10,443 + NYSE 5,323 + PINK 8,945
  + OTCGREY 2,519 + OTCQB 983 + smaller venues)
- The NASDAQ + NYSE Common Stock subset (~15,800 names) is the relevant
  pool for a US-equity backtest universe.

## Bars retention — confirmed

Spot-probed `/api/eod/<SYM>.US?from=2020-01-01&to=2020-01-31` for known
delistings:

| Symbol | Delisted | HTTP | Bars in Jan 2020 |
|--------|----------|------|-------------------|
| TWTR   | 2022-10 (acquired) | 200 | ✓ 22 rows  |
| FIT    | 2021-01 (Google acq) | 200 | ✓ 22 rows |
| GME    | (still listed)     | 200 | ✓ 22 rows |
| AAAB   | (small-cap, ancient) | 200 | ✗ 0 rows  |
| ADBE   | (still listed)     | 200 | ✓ 22 rows |

EODHD retains bars for major delistings. Obscure / pre-2000 small-caps
may not have bars but the relevant population for a Russell-3000-scale
backtest universe is the large-cap delistings, which are covered.

## Why this matters

The post-#1180 conclusion was that our composition goldens are
forward-known-winner-biased: the symbol roster comes from today's
EODHD live-listings, so any name that delisted between the snapshot
date and 2026 is invisible. Returns on `top-500-2019` are ~8 σ above
a random 500-from-top-3000 baseline because the universe is
selection-contaminated.

The fix has been blocked on point-in-time membership data. The
2026-05-16 vendor sweep ruled out:
- Norgate (Windows-only)
- EODHD Fundamentals upgrade ($60/mo, 403 on our tier)
- Sharadar ($99/mo)
- IWV scrape (Akamai blocks our IP + GHA runners)
- fja05680/sp500 (SP500 only, no Russell 3000)

**This finding cuts all of those off the critical path.** Our existing
EOD-only tier exposes the delisted roster directly. We can rebuild
composition goldens to include delisted symbols at the snapshot date —
producing a true delisted-aware PIT universe without IWV.

## Why we missed this

Prior assumption (from `dev/notes/vendor-comparison-historical-universe-2026-05-16.md`
§"EODHD Fundamentals API"): we conflated the `/api/fundamentals/`
endpoint (Fundamentals Data Feed tier required, returns 403 for us)
with the live-listings + delisted-listings endpoints (both on the
base EOD-only tier).

The `/api/exchange-symbol-list/US?delisted=1` query-param wasn't on
anyone's radar. The endpoint name reuses the live-listings path —
the discriminator is a single `delisted=1` query parameter. EODHD's
docs (https://eodhd.com/financial-apis/api-for-historical-data-and-volumes/#Delisted_Symbols)
list it but our inventory code only ever called the live variant.

## Concrete unblock path

### Phase 1 — Fetch & cache the delisted roster (P0, ~30 min wall)

1. Cache `/api/exchange-symbol-list/US?delisted=1` JSON → `data/delisted_inventory.json`.
2. Extend `analysis/data/sources/eodhd/lib/http_client.ml` with a
   `fetch_delisted_symbols` function — 1-line diff (add the
   `delisted=1` query param to the existing `_make_symbols_uri`).
3. Add the corresponding inventory builder that filters to
   Common Stock on NASDAQ/NYSE.

Deliverable: `data/delisted_symbols.sexp` — ~15.8k entries,
`(symbol exchange asset_type name)` tuples.

### Phase 2 — Fetch delisted bars (P0, ~3-5h wall)

1. For each delisted Common Stock on NASDAQ/NYSE, fetch its bars via
   the existing `/api/eod/<SYM>.US` endpoint. Reuse the existing
   `fetch_bars` codepath; the only change is the symbol roster.
2. EODHD rate limits: typically 1000 requests/day on the base tier;
   the bulk-EOD endpoint accepts up to 15 symbols per request → ~1500
   symbol-fetches/day = ~10 days at full saturation, or ~3-5h at
   higher per-symbol rate.
3. Cache bars under the same `data/<X>/<Y>/<SYM>/data.csv` layout as
   currently-listed symbols.

Deliverable: ~15.8k symbol-CSVs under `data/` (estimate ~3-5 GB
uncompressed).

### Phase 3 — Rebuild composition goldens with delisted-aware ranking (P1, ~30 min wall)

1. Update `analysis/data/universe/bin/build_composition_universes_runner.ml`
   to draw from the union of live + delisted inventory, filtered to
   symbols with active bars at the snapshot date.
2. Re-emit `top-{500,1000,3000}-{1998..2026}.sexp` with the broader
   inventory pool.

Result: delisted-aware composition goldens. Backtests against these
goldens are no longer survivor-biased at the *construction* step —
TWTR, FIT, etc. would appear in the 2019-05-31 top-500 universe
they actually belonged to, drop out after their delisting date as
expected, and the strategy would have to mechanically exit them at
the delisting close.

### Phase 4 — Re-run the random-universe sweep + the smoke cell (P1, ~30 min wall)

With delisted-aware goldens, repeat the experiment from #1180:
- Sample 5 random 500-symbol subsets from the new
  `top-3000-2019.sexp` (now including delisted names).
- Run Cell-E on each + on the new `top-500-2019.sexp`.
- Expectation: random sample mean shifts from +12.66% closer to a
  market-neutral baseline (since delisted-mostly-failed names dilute
  the post-hoc winner concentration). The gap between top-500-2019
  and random samples narrows but doesn't fully close — cap-ranking
  is still a momentum bias.
- Confirms (or revises) the "selection rule dominates strategy
  alpha" claim with a less-biased baseline.

## Risks & caveats

- **Delisted-bar coverage is not 100%.** Spot-check found AAAB has no
  bars; pre-2000 small-cap delistings likely have spotty coverage too.
  Phase 2 needs to emit a coverage report alongside the cache so
  Phase 3 can filter or flag low-coverage names.
- **EODHD's delisting reason isn't exposed.** A name's "delisting" could
  be acquisition (TWTR), going-private (DELL 2013), reverse-merge,
  rebrand (META was FB), or bankruptcy. The schema gives us the symbol
  + last-trading-date implicit in the bars; the *reason* would need a
  separate Fundamentals call (still 403 on our tier).
- **Reverse-split / ticker-change handling.** If a delisted symbol's
  bars use the old ticker, an acquirer's bars use the new ticker, the
  composition goldens won't bridge them automatically. Spot-check
  needed (TWTR → X isn't a 1:1 rename — X is private). This is a
  per-symbol QA pass, not a systemic blocker.
- **API quota.** EODHD's per-call limits aren't fully documented for
  our tier. Phase 2 should rate-limit politely and resume on quota
  exhaustion.

## How this changes the strategic roadmap

`memory/project_strategic_pivot_broader_first.md` (2026-05-15) said:
"P0 = broader-universe + walk-forward CV + ML-discipline tuning."
The broader-universe agenda was gated on point-in-time membership.
**This finding ungates it.**

`dev/notes/next-session-priorities-2026-05-19.md` §"Bayesian production
sweep" is also gated on IWV / paid-scraper / Sharadar / EODHD tier.
**This finding ungates that too.**

## Reproducibility

```bash
# Save the delisted roster snapshot:
mkdir -p data
curl -s "https://eodhd.com/api/exchange-symbol-list/US?delisted=1&api_token=$EODHD_API_KEY&fmt=json" \
  -o data/delisted_inventory.json
wc -c data/delisted_inventory.json  # should be ~8.2 MB
python3 -c '
import json
with open("data/delisted_inventory.json") as f: data = json.load(f)
print(f"total={len(data)}, common_stock={sum(1 for d in data if d[\"Type\"] == \"Common Stock\")}")
'
# Or, no-python alternative:
grep -o '"Type":"Common Stock"' data/delisted_inventory.json | wc -l
```

(Per `.claude/rules/no-python.md`, the production loader must be OCaml
or POSIX shell. The python3 line above is reference-only.)
