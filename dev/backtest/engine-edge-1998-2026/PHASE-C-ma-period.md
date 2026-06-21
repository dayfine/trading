# Phase C — MA-period dial (30wk → 10wk) probe — NO-BUILD

**Motivation:** Phase A/B found the engine badly lags S&P in the 2009-26 bull
(+130% vs +631%). Weinstein's own *trader* MA is 10wk (vs 30wk investor). Does the
faithful 10wk dial reduce the bull-lag? (`stage_config.ma_period 30 → 10`, otherwise
identical Cell-E, top-3000 1998-26, reuse `/tmp/snap_top3000_1998_ls`.)

**Verdict: NO-BUILD decision** (per `mechanism-validation-rigor.md` — a screen, so a
no-build *decision*, calibrated on the Sharpe + MTM/capacity evidence, not a
mechanism "rejection"). The 10wk return is a fat-tail compounding / capacity mirage,
not a robust edge.

## Numbers (engine standalone, w=0)

| window | 10wk return | 10wk Sharpe | 30wk return | 30wk Sharpe |
|---|---|---|---|---|
| FULL 1998-26 | **+25,602%** | **0.213** | +1100% | 0.537 |
| 1998-2008 (crash) | +497% | 0.869 | +421% | 0.771 |
| 2009-2026 (bull) | **+4207%** | 0.249 | +130% | 0.354 |
| MaxDD (full) | 40.9% | | 48.3% | |

## Why it's a mirage, not a win

- **Sharpe COLLAPSED 0.54 → 0.21** despite a 23× larger return → the return is
  wildly lumpy, not a smooth edge.
- **One trade realized +\$209,448,770**; next four +\$30.7M / +\$25.4M / +\$16.3M /
  +\$15.8M. Terminal NAV ≈ \$257M from \$1M, with **\$195M (76%) in open positions**.
  These position sizes are **capacity-infeasible** (a \$209M single-name win violates
  the liquidity-realism that held for the 30wk book, `project_trade_realism_liquidity`).
- The 10wk MA fragments Stage-2 into more, faster entries → catches more fat-tail
  monsters → **unconstrained compounding into a few names** produces the absurd
  terminal number. This is the exact MTM-concentration artifact flagged in
  `project_broad_universe_790_mtm_inflated`, here amplified by the faster MA.

## Transferable takeaway

- **MA period is the single most impactful dial, but faster ≠ better.** The 10wk's
  bull "outperformance" is concentration/MTM, not realizable alpha; its Sharpe is a
  third of the 30wk's. The 30wk's bull-lag is partly the *price of a
  capacity-realistic, lower-concentration book* — a feature, not just a bug.
- **The realistic edge is bounded by position capacity, not by the MA dial.** Any
  "maximize the edge" lever that works by catching more fat-tail names runs into the
  same capacity wall (`edge_is_the_fat_tail`). Do not promote 10wk.
- The bull-lag is therefore **structural** (a slow-MA, crash-defensive strategy
  underperforms in trending bulls) and not cheaply dialable away. The honest
  positioning stands: full-cycle outperformance via crash-protection; expect
  bull underperformance. The barbell floor (bull participation) remains the
  faithful, capacity-safe way to address the bull-lag — not a faster MA.

A proper test (if ever revisited) would impose a per-name capacity cap (% ADV) and
re-measure — the 10wk edge almost certainly evaporates once position sizes are
realistic. Not worth prioritizing; the 30wk + light-floor barbell is the
deployable answer.
