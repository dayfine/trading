# Deduped 28y record re-run + first full-coverage audit (2026-07-13)

Follow-through on the C1-C4 correctness sweep (2026-07-12 PM session):
the honest-tradeable 28y record re-run on the **returns-basis twin-deduped
warehouse**, with the audit/validator stack finally at full coverage.

## What changed under the run (basis)

- Warehouse `/tmp/snap_top3000_1998_2026_dedup_v2`: rebuilt from the same
  staged scenario (`staging-honest-tradeable-ext`, window 1999-01-02 →
  2026-06-26) with `-dedupe-rename-twins -twin-basis returns` (#1940 + #1946).
- **83 duplicate-feed groups / 91 legs removed** (2999 → 2908 entries) — far
  beyond the 10 groups the trade-level audit had surfaced. All are genuine
  same-instrument feeds (AABA/YHOO, BKNG/PCLN_old, RTX/UTX, LIN/PX_old,
  TFC/BBT_old, LUMN/CTL, VTRS/MYL, the CBS/VIAC/PARA→PSKY chain, …): matching
  daily returns within 1e-3 on >95% of ≥100 shared days is statistically
  impossible for distinct companies. Both known false positives (BALL/TAP,
  ASB/CDX_old) correctly excluded. Survivors carry the full back-history
  (BALL from 1973, RTX 1984, TFC 1980) — no coverage holes.
- Report: `rename_twin_report.txt` in the warehouse dir (copy in session
  scratchpad). Level-basis v1 had caught only 15 exact-feed groups; the
  returns-basis criterion is the load-bearing fix
  (`memory/project_rename_twin_dedup_returns_basis`).

## Headline (vs the 07-11 pre-dedup record)

| | pre-dedup (07-11) | deduped (07-13) |
|---|---|---|
| MTM total return | +6885.1% | **+3407.4%** ($1M → $35.07M) |
| Realized PnL | ≈$17.7M (+1670%) | **$10.37M (+1037%)** |
| Round-trips | 1156 | 1171 |
| Sharpe | 0.768 | 0.68 |
| CAGR | — | 14.38% |
| MaxDD | — | 40.9% |
| Win rate | — | 35.6% (417/1171) |
| Open positions | AXTI + tail ($54M value / $44.9M unrealized) | 4 (AXTI, JBHT, PKG, SIRI; $32.2M value / $24.6M unrealized) |
| SPY TR comparator (2000-01→2026-06) | +700.0% (8.17%/yr) | +700.0% (unchanged window) |

Realized +1037% still beats SPY TR +700%, but the honest-tradeable headline
takes a much bigger haircut than the ~12% estimated from the 10 known groups.

## Why the drop is bigger than the 12% estimate (decomposed)

1. **The 12% was measured on 10 groups; the store has 83.** Clone-realized
   PnL beyond the audited 10 was invisible to the trade-level V6 heuristic
   (it only flags twins that BOTH traded on the same dates).
2. **MTM clones counted double too.** The pre-dedup +6885% carried duplicated
   monster legs at mark (NLS/BFX both held the same $2.19→$122 ride);
   dedup halves exactly the top-heavy part. BFX now appears once
   ($1.41M realized).
3. **Funding-path re-shuffle.** Removing 91 legs changes the candidate
   cascade and cash-boundary funding order across 26 years — the same
   path-chaos observed on every prior basis change (5th/6th confirmation).
   This is a basis change, not a strategy change; relative verdicts stand.

Fat-tail structure intact: top realized winners SKYW $2.70M, BFX $1.41M,
FARM $1.36M, LOGI $1.20M; gross +$35.6M / −$25.3M (profit factor 1.41).
AXTI branch-B still held (entry 2025-06-28 @ $2.19 × 341,779).

## First full-coverage validator run (V1-V11, post-#1942/#1947)

`post_run_validator` over the run dir (`validator_dedup.md`, scratchpad):

- **audit join: 1171/1171 rows matched** — was 0/1140 before the
  position_id join (#1947). V1/V2/V7/V8 have real coverage for the first time.
- **V5 PASS** (was 129 violations) — the #1942 export-join fix confirmed on
  a real run.
- **V6: 2** (was 12) — only the two proven false positives of V6's own
  trade-level heuristic remain (ASB/CDX_old, BALL/TAP). All real twins gone.
- **V7: 100 violations** — first real measurement of the resistance
  data-starvation defect (e.g. WAB 2005: Virgin_territory on 518 < 520 weekly
  bars). The label fix (#1941) is merged but default-off
  (`min_history_bars = 0`); arming for the record convention + live
  weekly-review is the open decision on the screener track.
- V8: 4 declining-MA entries (the #1775 gate, also default-off, would catch).
- V9 (275) / V10 (11) / V11 (265): report-only statistics per the 07-12
  visual-audit verdict (measured harmful as gates).

## Artifacts

- Run: `trading/dev/backtest/scenarios-2026-07-13-052958/top3000-2000-2026-honest-tradeable-ext/`
  (gitignored; trades.csv now carries `position_id`).
- Audit report: `trade_audit_report_bin --scenario-dir <run>` →
  `audit_report_dedup.md` (scratchpad).
- Warehouse: `/tmp/snap_top3000_1998_2026_dedup_v2` (container).
  The interim level-basis warehouse (`…_e0626_dedup`) is obsolete — delete.
- Reproduce: `build_scenario_snapshots … -dedupe-rename-twins -twin-basis returns`;
  `TRADING_DATA_DIR=/workspaces/trading-1/trading/test_data scenario_runner
  --dir <scenario-dir> --snapshot-dir <warehouse> --parallel 1
  --no-emit-all-eligible` (the env var is required or fixture resolution
  breaks against `/workspaces/trading-1/data`).

## New record convention

The deduped warehouse is the record basis going forward: realized
**$10.37M / +1037% / 14.4% CAGR** vs SPY TR +700% / 8.17%/yr; MTM +3407%
with the standing caveat that 92% of terminal NAV sits in 4 open positions
(AXTI dominant). Pre-dedup numbers are superseded — comparisons against them
must note the basis change (ledger-style: dedup-v2-basis-change).
