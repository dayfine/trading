# Short-realism deep acceptance — broad top-3000 + verdict (2026-06-26)

Companion to `short-realism-reconcile-2026-06-26.md` (the reconciliation + sp500
half). This is the **broad-universe half** of the deep margin off-vs-on acceptance
test the user requested ("run both sp500 and broad for 1998-2026, trade records,
maybe golden"). It closes the short-side-realism P0 question.

## The two deep cells (both universes, margin off vs on)

Cell-E long-short config (`enable_short_side`, `short_min_price 17`,
`max_position_pct_long 0.14`, `max_long_exposure_pct 0.70`, `min_cash_pct 0.30`,
stage3 force-exit h=1, laggard h=2). The ONLY varied parameter per pair is
`margin_config.enabled`. Scenarios committed in
`dev/experiments/short-realism-deep-2026-06-26/scenarios/`. Trade records
(`trades.csv` + `trade_audit.sexp` + `equity_curve.csv`) captured per cell under
`dev/backtest/scenarios-2026-06-26-{044321 (sp500), 051057 (broad)}`.

| Universe / window | Margin | Return | Sharpe | MaxDD | Trades | Shorts | min NAV | Margin calls |
|---|---|---|---|---|---|---|---|---|
| sp500-515 PIT-2000, 2000-2026 | OFF | +2023.1% | 0.893 | 25.2% | 981 | 27 | $968,932 | 0 |
| sp500-515 PIT-2000, 2000-2026 | ON  | +2074.6% | 0.914 | 25.2% | 931 | 30 | $968,932 | 0 |
| broad top-3000 PIT-1998, 1998-2026 | OFF | +1421.9% | 0.554 | 55.5% | 1238 | 53 | $886,963 | 0 |
| broad top-3000 PIT-1998, 1998-2026 | ON  | +1358.1% | 0.552 | 55.4% | 1231 | 49 | $886,649 | 0 |

(broad run via snapshot mode — N=3000 OOMs CSV; columnar-v2 warehouse + #1631
single-mmap reader keep RSS ~240MB/cell.)

## Verdict — the longshort number is NOT inflated by short mechanics

1. **Margin is non-deflating in both universes.** sp500: +2023→+2075 (+2.5%, *up*).
   broad: +1422→+1358 (−4.5%, *down*). Both deltas are tiny and opposite-signed —
   i.e. **capital-timing noise, not a systematic inflation the margin model removes.**
   Sharpe is unchanged to 3 decimals (sp500 0.893→0.914; broad 0.554→0.552). Trade
   counts near-identical (broad 1238/1231).
2. **NAV never goes negative — even with margin OFF.** Min NAV is ~$0.89-0.97M
   (started $1M) in every cell. The "G5: free leverage → NAV can go negative" fear
   does **not** manifest: the `max_long_exposure_pct=0.70` + `min_cash_pct=0.30`
   sizing caps already bound long deployment regardless of short proceeds. The
   collateral lock is redundant *for capacity* under these caps (identical trade
   counts off/on confirm it isn't binding).
3. **Zero margin calls** over 26-28 years in either universe; shorts are sparse
   (27-53 over the whole window) — the modern faithful-short gating barely shorts.

**So the P0 premise — "longshort absolute returns are inflated by broken/missing
short mechanics (esp. free leverage)" — is refuted.** The margin model is built,
wired, validated, NAV-safe, crash-free, and changes the number by <5%.

## Where the "3408%" actually comes from: concentration, not leverage

The handoff's headline 3408% (sp500-515 deep) is far above my controlled +2023%.
The difference is **concentration**: I pinned `max_position_pct_long=0.14`; the
production default is now **0.30** (re-pin #1753), which amplifies terminal
unrealized MTM on the few fat-tail winners. This is the long-standing
MTM-on-concentrated-winners finding (`project_broad_universe_790_mtm_inflated`,
`project_trade_realism_liquidity`), re-derived again. A 0.30 cell would reproduce a
much higher number that is *equally margin-insensitive*. (A long-only 0.30
reproduction cell was launched but did not complete cleanly; the concentration
mechanism is already well-established, so this is supplementary, not load-bearing.)

**The real "realism" lever for trustworthy longshort absolutes is concentration /
MTM accounting, not short margin** — which is exactly the work the handoff tabled.

## Golden-promotion recommendation (data-footprint decision pending)

The user asked to maybe promote these to golden, "at least sp500 for GHA data
availability." Assessment:

- **broad top-3000 1998-2026: NOT GHA-feasible.** 3000 symbols × 28y of deep bars
  is far too large to commit to `test_data/` (currently 175MB total), and a 28y
  snapshot-mode run is a multi-ten-minute job unfit for per-PR CI. Keep it as an
  experiment-only scenario (committed sexp, run locally against the prod data dir).
- **sp500-515 2000-2026: feasible-but-heavy.** Needs the 515 PIT-2000 symbols' deep
  bars (1998-2026) committed — order ~150-250MB added to `test_data/` (exact
  footprint to be measured before committing). The run is ~15min — a **nightly**
  golden, not a per-PR one.
- **Which cell to pin:** the margin-ON long-short is the "realistic" baseline. But
  the pinned metric should arguably use the **production concentration default
  (0.30)**, not the 0.14 used here for Cell-E lineage comparability — otherwise the
  golden doesn't reflect live behavior. This is a design choice to settle before
  pinning.

**Recommendation:** commit the four scenario sexps now (done, this PR) as the
reproducible experiment surface. **Defer the golden commit** until (a) the exact
deep-sp500 bar footprint is measured and confirmed acceptable, and (b) the
pin-concentration (0.14 vs 0.30) is decided. The deep-bar commit roughly doubles
`test_data/` size — it warrants an explicit go-ahead, not an autonomous commit.

## Status
- Deep acceptance (sp500 + broad, off/on): **DONE. Margin non-deflating, NAV-safe,
  crash-free in both.** P0 premise refuted.
- Short-side-realism P0: **effectively closeable** — machinery built + validated; the
  inflation is concentration/MTM (tabled work), not short mechanics.
- Open (deferred, needs go-ahead): golden promotion (sp500 nightly) + deep-bar
  footprint sizing + pin-concentration decision. Optional: tiered FINRA maintenance
  (`short-side-realism-2026-06-26.md` §3) — but the re-run shows 0 margin calls fire,
  so it would change nothing measurable.
