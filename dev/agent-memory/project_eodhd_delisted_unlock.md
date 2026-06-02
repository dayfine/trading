---
name: EODHD delisted-symbols endpoint unblocks PIT-universe agenda
description: `/api/exchange-symbol-list/US?delisted=1` returns 57k+ delisted symbols (31,737 Common Stock) on our existing EOD-only tier, no upgrade needed. IWV / Sharadar / fja05680 / Fundamentals-tier paths all off the critical path. Bars retention is real but imperfect.
type: project
originSessionId: a9aafef3-9945-4a99-9675-c3109601e13e
---
# EODHD Delisted Roster — PIT Universe Unblock (2026-05-18)

## Headline

The 2026-05-16 vendor sweep (`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`) missed that **our existing EOD-only EODHD subscription exposes the delisted-symbols roster** via a single `delisted=1` query parameter on the existing `/api/exchange-symbol-list/US` endpoint. The endpoint returns 57,592 entries — 31,737 Common Stock delisted across US exchanges (NASDAQ + NYSE + PINK + OTC).

This obsoletes:
- IWV scrape (Akamai-blocked, even on GHA runners — confirmed 2026-05-18)
- fja05680/sp500 fallback (SP500 only)
- EODHD Fundamentals tier upgrade ($60/mo)
- Sharadar ($99/mo)

## Bar retention — imperfect but workable

Spot-probed by both the PR (`dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md`) and qc-behavioral on #1183:

| Symbol | Outcome |
|--------|---------|
| TWTR (Musk acq 2022)   | ✓ bars present |
| FIT (Google acq 2021)  | ✓ bars present |
| GME / ADBE (still live) | ✓ bars present |
| AAAB (ancient small-cap) | ✗ 0 bars |
| **SCTY** (Tesla acq 2016) | ✗ 0 bars 2013-2015, 125 rows H1 2016 only |
| **MNK** (active trading) | ✗ 0 bars |
| **LB** (pre-BBWI rename) | ✗ 0 bars |
| **DELL** (pre-2013 private) | ✗ 0 bars (relisted same ticker; not in delisted roster) |

So the PR's framing ("EODHD retains bars for major delistings") is **more optimistic than the data justifies**. Coverage holds for some major delistings (TWTR, FIT) but not all (SCTY, MNK, LB).

Practical implication: Phase 2 of the unblock plan MUST emit a per-symbol coverage report so Phase 3 (rebuild composition goldens) can filter or flag low-coverage names.

## Unblock plan (4 phases)

Documented in `dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md`. P2 effort estimate has internal tension: 1000 req/day quota × 15 symbols/req ≈ 1054 requests = barely one day's quota, contradicting the "3-5h" estimate. The note acknowledges this under §"Risks & caveats" but the real wall could be 1-3 days at quota-limited rate.

| Phase | Actual effort | Output |
|---|---|---|
| P1 — fetch + cache roster | ~30 min OCaml (add `delisted=1` param to `_make_symbols_uri`) | `data/delisted_symbols.sexp` |
| P2 — fetch delisted bars  | ~3-5h OR 1-3 days (quota-bound) | ~3-5 GB CSVs under `data/` |
| P3 — rebuild composition goldens | ~30 min | delisted-aware `top-{500,1000,3000}-{1998..2026}.sexp` |
| P4 — re-run random-universe sweep | ~30 min wall | confirms / refines #1180's "selection-rule-dominates-strategy-alpha" claim |

## How to apply

**When deciding next-session priorities for the PIT-universe agenda:**
- This is the new P0 — do NOT pursue IWV / fja05680 / Sharadar / Fundamentals-tier paths first.
- Start with P1 (1-line code change + curl + sexp emit).
- P2 will dominate wall time; throttle politely + emit coverage report.

**When pinning baselines on composition goldens:**
- Until delisted-aware goldens land, the existing `top-500-2019` baseline (+174.69% Cell-E) is still **bridge-smoke-test only**, NOT strategy alpha (per #1180).
- After delisted-aware goldens land, re-run and compare. Expect random-sample mean to drift closer to a market-neutral baseline; top-500-2019 to drift lower (toward ~+50-100% range, closer to current-SP500's +50% baseline).

**When extending the vendor docs:**
- Update `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` to demote IWV from PRIMARY to fallback once P1/P2 land. Add a §EODHD-delisted as new primary.

## Files

- `dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md` — the full plan (#1183, merged)
- `trading/analysis/data/sources/eodhd/lib/http_client.ml` — `get_delisted_symbols` shipped in #1184
- `data/delisted_symbols.sexp` — 5.6 MB roster snapshot from #1184 (57,592 entries)
- `trading/analysis/scripts/fetch_delisted_bars/bin/main.ml` — P2 bulk-fetcher (#1185)
- `trading/analysis/scripts/asset_type_enrichment/bin/main.ml` — `-include-delisted` flag (#1186, P3)
- `dev/notes/iwv-scrape-akamai-block-2026-05-16.md` — IWV alternative, now demoted
- `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` — the prior vendor sweep that missed this

## Status — 2026-05-18 session COMPLETE

- P1 (delisted endpoint + cached roster) — DONE (#1184)
- P2 (bulk-fetch binary) — code DONE (#1185), parallel fetcher in #1187, full-run completed (15,766 targets, 13,810 fresh fetches, 0 errors, ~2.5 hr wall via parallel=5)
- P3 (asset_type_enrichment `-include-delisted` flag) — DONE (#1186)
- P3.5 (orchestrator + ergonomics) — DONE (#1187)
- P4 (delisted-aware composition rebuild + headline measurement) — DONE (#1190)

**P4 result**: top-500-2019 dropped from +174.69% to **+78.34%** (-55%). 8σ gap to random-sample mean narrowed to ~3σ. Risk metrics IMPROVED (MaxDD -29%, Ulcer -29%, Sortino +31%, Sharpe +11%). Selection-bias hypothesis from #1180 confirmed.

See `dev/notes/delisted-aware-p4-result-2026-05-18.md` for full writeup. The new top-500-2019 has 115/500 entries with empty sectors (delisted-aware additions lack sector data in `data/sectors.csv` — P5 follow-up).

## Status — full agenda complete

- **P6** (#1191, merged) — re-ran #1180's sweep with seeds 53-57 on new delisted-aware pool. Mean +145% vs #1180's +13%, but pool was ~96% identical (only 6 net new sectored names). **The +132pp delta is dominated by sampling noise at N=5, not pool composition.** N≥30 needed for stable distribution. #1180 "8σ outlier" claim overstated; should be "modestly above mean; magnitude TBD".
- **P5** (#1194, merged) — hand-curated 40 famous 2010-2026 delistings (TWTR/AABA/CELG/ANTM/AGN/ATVI/CBS/CERN/ABMD/ALXN/XLNX/CHK/etc.) appended to data/sectors.csv. Composition goldens rebuilt. Empty-sector count in top-500-2019: 115 → 100 (-15). All 10 famous delistings now sectored. weinstein-2019-top-500 metrics within #1190 bands — no re-pin needed (return 78.34 → 77.30, MaxDD 42.17 → 40.28, ulcer 19.01 → 17.20; directional improvement on risk). 100 empty-sector entries remain (foreign ADRs + EODHD ticker-reuse markers); closing the full gap needs Wikipedia scrape / Sharadar / manual extension — deferred.
- **P7** (N=30+ random samples) — defer. With P5 closing only 15 of 115 empty-sector entries on top-500-2019 (most empty are foreign ADRs / ticker-reuse markers our hand-curation didn't cover), the famous-delistings-in-pool subset doesn't grow enough to make N=30 obviously useful. The Bayesian production sweep (#1192) uses sp500-2010-2026 anyway, so P7 isn't on the critical path.

## Strategic state of the delisted-aware substrate (as-of 2026-05-18)

The agenda's CODE is shipped end-to-end. The substrate works:
- P1/P2/P3 pipeline produces inventory + symbol_types + composition goldens that include delisted symbols at construction time.
- Orchestrator (`dev/scripts/run_delisted_pipeline.sh`) re-runs the chain on demand.
- 84 composition goldens × 28 years × 3 sizes are now delisted-aware.

The agenda's DATA QUALITY is partial:
- 100 of 500 top-500-2019 entries have empty sectors (down from 115 pre-P5). The famous delistings ARE sectored; foreign ADRs and ticker-reuse markers are not.
- Strategy filters empty-sector names at the sector-RS stage — they're in the universe but don't trade.
- Effective traded universe in top-500-2019 is ~400 (was ~385 pre-P5, vs 500 ideal).

The agenda's ALPHA-MEASUREMENT VALUE:
- The #1180 selection-bias finding (top-500-2019 +175% return) was real but partially over-stated. After P4 (delisted-aware rebuild), top-500-2019 dropped to +78% — selection bias confirmed.
- P6 revealed the σ on N=5 random-sample distributions is huge (~100pp). The "8σ outlier" claim was sampling noise.
- True alpha measurement against a calibrated random-universe distribution would require N≥30 samples on a fully-sectored delisted-aware pool. Not done. Not on critical path.

## Recommended next session priority

**Bayesian production sweep (#1192 plan, runnable now).** Per the plan,
the run uses sp500-2010-2026 (survivor-aware, doesn't depend on P5/P7).
Phase A (~2 hr) sets up spec.sexp + Cell-E baseline measurement.
Phase B (24-48 hr) runs the BO loop. Phase C (~1 hr) checks promote
gates and either promotes a winner config to a private repo or
writes a follow-up explaining why no config qualified.

## Net takeaway from full delisted-aware agenda

1. EODHD's `?delisted=1` endpoint genuinely unlocks the inventory side (#1184/#1185).
2. The dollar-volume-ranked composition rebuild adds ~32% turnover at top-3000 cut (#1190).
3. Headline measurement of top-500-2019 dropped +175% → +78% — selection-bias DIRECTIONALLY confirmed.
4. **BUT** N=5 random sampling overstated the magnitude. The selection-bias gap is real but ~1σ, not 8σ.
5. **AND** the famous delistings (TWTR/AABA/CELG/ANTM/etc.) still have empty sectors → get filtered out at the strategy's sector-RS stage. So even after the delisted-aware rebuild, those names don't fully participate in backtests.
6. Real PIT-universe alpha measurement needs P5 (sector data) + P7 (N≥30) before the "Weinstein has alpha" claim can be honestly tested.
