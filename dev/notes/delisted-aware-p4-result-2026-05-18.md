# Delisted-aware composition rebuild — P4 result (2026-05-18)

End-to-end result from the delisted-aware universe agenda. Ran the
post-P2 pipeline (`dev/scripts/run_delisted_pipeline.sh` modulo the
`--out-dir` bug, see below) and re-ran the `weinstein-2019-top-500-composition`
scenario against the rebuilt composition goldens.

## TL;DR

**Top-500-2019's headline return dropped from +174.69% to +78.34%** —
a 55% drop — once we stop excluding names that delisted between 2019
and 2026. The 8σ gap to the random-sample mean (+12.66%, #1180)
narrows from ~8σ to ~3σ. **The selection-bias hypothesis from #1180
is borne out.**

Counter-intuitively, **risk-adjusted metrics IMPROVED**: MaxDD -29%,
Ulcer -29%, Sortino +31%, Sharpe +11%. The new universe includes
more mid/large-cap names (AABA / CELG / ANTM / AGN / ATVI / CBS /
CERN / ABMD / etc.) and proportionally less AMZN / NVDA / TSLA
domination — so returns are more moderate but also more stable.

## Pipeline steps run

```sh
# 1. Refresh inventory: 14k → 56,652 symbols (delisted bars from P2 now visible)
build_inventory.exe -data-dir data
# 2. Re-enrich symbol_types: 41,575 → 56,652 entries with -include-delisted
asset_type_enrichment.exe ... -include-delisted
# 3. Rebuild composition goldens (84 files written, 3 skipped for 2026 missing-bars)
build_composition_universes_runner.exe \
  --bars-root data --inventory data/inventory.sexp \
  --sectors-csv data/sectors.csv --symbol-types data/symbol_types.sexp \
  --out-dir trading/test_data/goldens-custom-universe/composition/
# 4. Re-run weinstein-2019-top-500-composition (~5 min wall)
scenario_runner.exe --dir goldens-custom-universe-scenarios/ ...
```

## Bug found in run_delisted_pipeline.sh

Step 3 first ran with the runner's DEFAULT `--out-dir` which is the
relative path `trading/test_data/goldens-custom-universe/composition/`.
Under `dune exec` from the workspace root `/workspaces/trading-1/trading/`,
that resolves to `trading/trading/test_data/...` — the WRONG location
(the canonical path is `trading/test_data/...` from the host).

Fix: pass `--out-dir /workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/`
explicitly. Already updated in the orchestrator script in this PR.

## Universe diff (new top-500-2019 vs prior)

- Prior committed: 500 names, 100% sectored, +174.69% return.
- New (delisted-aware): 500 names, 77% sectored, +78.34% return.
- Diff: 101 names changed (101 added, 101 dropped).
- Added names (delisted between 2019-05-31 and 2026): AABA, ABC, ABMD,
  ACL, AGN, ALXN, ANTM, ASMI, ATVI, BDO, BLL, BRK-B, CBS, CELG, CERN,
  CELSIA, CHK, CMA, BOUBYAN, ...

For top-3000-2019 the diff is 965 in / 965 out (32% turnover).

## Sectors gap (P5 follow-up)

`data/sectors.csv` only has sectors for currently-listed symbols. The
delisted-aware additions (AABA, TWTR, CELG, ATVI, etc.) have empty
sectors in the new top-500-2019 — 115 of 500 entries (23%) carry
`(sector "")`. The strategy's screener will filter these out at the
sector-RS stage, so the EFFECTIVE traded universe is closer to 385
than 500.

To close this gap (P5):
- Option A — backfill `sectors.csv` from EODHD `/api/fundamentals/`
  for delisted symbols (still 403 on our tier).
- Option B — use Finviz / Stooq / hardcoded historical-SP500 sectors
  as a fallback.
- Option C — accept the partial coverage; the 385 sectored names are
  already representative.

Defer for now — the headline P4 result is clear enough without sector
backfill.

## Comparison table

| Metric            | OLD (live-only) | NEW (delisted-aware) | Δ      |
|-------------------|-----------------|----------------------|--------|
| total_return_pct  |   174.69        |     78.34            | -55%   |
| total_trades      |   248           |    263               | +6%    |
| win_rate          |    30.65        |     31.94            | flat   |
| sharpe_ratio      |     0.62        |      0.69            | +11%   |
| max_drawdown_pct  |    59.06        |     42.17            | -29%   |
| avg_holding_days  |    40.85        |     41.99            | flat   |
| open_positions_value | 2,263,365    |  1,424,418           | -37%   |
| sortino_ratio_ann |     0.73        |      0.96            | +31%   |
| calmar_ratio      |     0.38        |      0.29            | -23%   |
| ulcer_index       |    26.89        |     19.01            | -29%   |

## Random-sample baseline (#1180) for context

5 random 500-symbol subsets of the prior (live-only) top-3000-2019
returned -10% to +30%, mean +12.66%, σ ≈ 20pp. Top-500-by-volume sat
at +174.69%, ~8σ above the random mean.

After the delisted-aware rebuild, top-500-by-volume sits at +78.34%,
still ~3σ above that random mean. So:

- ~62% of the original gap (175 - 13 = 162 pp) closes via the
  delisted-aware fix.
- ~38% of the gap (78 - 13 = 65 pp) remains — likely real
  cap/liquidity bias (top-volume names trend more, trigger more
  Weinstein stage-2 entries), or residual selection bias still present
  in the 2026-built top-3000 pool.

## What this changes upstream

- The `weinstein-2019-top-500-composition` cell's pinned bands are
  re-pinned to ±20% around the new measurement (and the sexp header
  carries the before/after narrative). This PR includes both.
- The 84 rebuilt composition goldens go into the diff. Downstream
  consumers (`cross_validation_runner`, the universe-snapshot bridge
  consumers) see different inputs but no signature changes.
- The "BRIDGE SMOKE TEST" warning in the cell sexp is downgraded: with
  delisted-aware coverage the cell is closer to a fair-but-still-cap-
  ranked benchmark. NOT a pure-PIT alpha test (cap-ranking still
  introduces selection); the disclaimer remains but is softer.

## Strategic next step

**P5 (sectors backfill for delisted names)** — see options A/B/C
above. Smallest delta is Option C (accept partial coverage); Option B
(Finviz scrape) is a ~2 hr engineering task that closes the gap fully.

**P6 (random-universe sweep against new top-3000-2019)** — re-do the
#1180 experiment with the delisted-aware pool. The new pool's
non-empty-sector subset is ~1956 names (was 2549 in old). 5 random
samples + the comparison cell + writeup. Same shape as #1180.
Expected: random mean drifts toward market-neutral (~0% to +10%); the
3σ gap narrows further to perhaps ~1-2σ.

Both are deferred to next session given the size of THIS PR.

## Files in this PR

- `dev/notes/delisted-aware-p4-result-2026-05-18.md` (this)
- `dev/scripts/run_delisted_pipeline.sh` — `--out-dir` fix
- `trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-top-500.sexp` — re-pinned bands + header narrative
- `data/symbol_types.sexp` — refreshed (41,575 → 56,652 entries) by `asset_type_enrichment -include-delisted`
- `trading/test_data/goldens-custom-universe/composition/*.sexp` — 84 files rebuilt with delisted-aware inventory pool
