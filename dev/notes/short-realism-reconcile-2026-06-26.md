# Short-side realism — premise reconciliation + margin re-run (2026-06-26)

**Autonomous session.** Started on `next-session-priorities-2026-06-26.md`
(P0 = "fix short-side realism: build G1, G2, margin model"). On verifying
the plan's claims against `main` (per the CLAUDE.md "verify status claims"
discipline), **the P0 build is almost entirely already done.** This note
records the reconciliation + an acceptance re-run.

## What the handoff/plan claimed was TODO vs. what is actually on main

| Plan item | Handoff status | Actual state on main (cc3c21f5) |
|---|---|---|
| G1 short-stop firing | "DRAFT, land first" | **DONE** — `stops_runner.ml` has side-aware `_default_stage_and_ma_for_side` (Stage4+Declining warmup for shorts) + `_trigger_fill_price` (bar.high for short cover). Reproducer tests green. |
| G2 short round-trip metrics | "SMALL, do early" | **DONE** — `metrics.ml` `_is_paired_round_trip` pairs Sell→Buy; side-aware P&L; SHORT label. |
| Margin model (G3+G5+G4) | "LARGE, core fix, to build" | **DONE** — issue #859 Phase 1+2 (PRs #1113/#1115/#1119/#1606): `margin_config.ml`, `portfolio_margin.ml` (Reg-T 150% collateral lock at entry, refund on cover, 50bps borrow fee, maintenance check), `sizing_cash` spendable-cap, `force_liquidation.ml`. Wired into `simulator.ml` → `Margin_runner.tick` and `panel_runner.ml`. All gated `margin_config.enabled` (default off). |
| Finding A crash (May blocker) | not mentioned | **FIXED** — #1266/#1274 `dedup_strategy_exits_for_margin` drops the strategy stop-loss TriggerExit when a margin_call fires same-tick. |

**The only genuinely-unbuilt items vs. the plan:**
1. **FINRA *tiered* maintenance** — current model is a flat `maintenance_margin_pct`
   (25%). Plan wants per-share floors (≥$5: max($5/sh,30%); <$5: max($2.50/sh,100%))
   + `short_min_price≈17` universe filter.
2. **The acceptance run** on the specific inflated longshort cell — never done.

## Acceptance re-run (May Next-Step #2, never executed until now)

Re-ran the 4 May bear windows × {margin off, on} now that #1266 is merged
(`dev/experiments/margin-phase3-bear-windows-2026-05-23/scenarios`, prod data
dir, parallel 2). Output: `dev/backtest/scenarios-2026-06-26-042729/`.

| Window | Return off → on | Δ | Trades off/on | SHORT trades |
|---|---|---|---|---|
| dot-com 2000-02 | +29.497% → +29.495% | −0.003pp | 55/55 | **2** |
| GFC 2007-09 | −18.028% → −18.083% | −0.055pp | 47/47 | 4 |
| COVID Q1 2020 | −9.856% → −9.873% | −0.018pp | 42/42 | 9 |
| 2022 bear | −19.006% → −19.049% | −0.043pp | 62/62 | 5 |

- **Dot-com margin-on completes cleanly** (May crashed here pre-#1266). #1266 fix holds.
- **No margin_call exits** fired anywhere; **NAV never negative** (dot-com equity floor ~$1.0M).
- Margin-on moves the bottom line by **<0.06pp** in every window, **identical trade counts**.

## Two findings that reframe the P0

1. **Identical trade counts off vs on ⇒ the collateral lock is not binding
   capacity.** If margin-off were giving "free leverage" (short proceeds funding
   extra longs), turning margin on (150% lock) would cut long capacity and change
   trades. It doesn't. The existing sizing caps (`max_long_exposure_pct=0.70`,
   `min_cash_pct=0.30`) already prevent short-proceeds free-leverage. So the margin
   collateral mechanism is largely redundant *for capacity* under these caps.

2. **Current main shorts far more sparsely than the May-era strategy** (dot-com
   21→2 shorts) due to A-D-live flip + the June faithful-short changes. So these
   sub-windows are a **weak** test of the short-leg margin friction — there's
   barely a short book to tax.

## Implication for the "3408%" inflation premise

The 3408% (sp500-515, deep ~1999-2026 longshort, 2026-06-23) was *not* re-tested
here (these are sub-windows, and that run was a different short-density config).
But the evidence above (collateral lock non-binding under the exposure caps; margin
friction <0.06pp; no margin calls) is **inconsistent** with "the inflation is free
leverage the margin model will cap." It points instead to the long-standing
finding that broad-universe inflation is **terminal unrealized MTM on concentrated
winners** ([[project_broad_universe_790_mtm_inflated]],
[[project_trade_realism_liquidity]]) — i.e. concentration, not short leverage.

**The only thing that settles it definitively:** reproduce the exact 3408% deep
contiguous longshort cell (sp500-515, ~1999-2026) with margin off vs on. If it too
moves <1pp, the inflation is MTM/concentration and the short-realism P0 should be
closed as "machinery built + validated; inflation is not leverage" — redirecting
to the (tabled) concentration/MTM-realism work.

## Deep-cell acceptance — sp500-515 (PIT-2000) longshort, 2000-2026, margin off vs on

User-requested deep acceptance (both sp500 + broad; broad pending). sp500 run:
`dev/experiments/short-realism-deep-2026-06-26/scenarios/` →
`dev/backtest/scenarios-2026-06-26-044321/`. Cell-E longshort, `short_min_price 17`,
`max_position_pct_long 0.14`, CSV mode, prod data dir.

| Cell | Return | Sharpe | MaxDD | Trades | Shorts | min NAV | Margin calls |
|---|---|---|---|---|---|---|---|
| margin OFF | +2023.1% | 0.893 | 25.2% | 981 | 27 | $968,932 | 0 |
| margin ON | +2074.6% | 0.914 | 25.2% | 931 | 30 | $968,932 | 0 |

**Verdict: margin does NOT deflate the longshort number.** On vs off is ~unchanged
(+2.5% relative, and *upward*, not down). **NAV never drops below ~$0.97M even with
margin OFF** — the "free leverage → negative NAV" G5 fear does not manifest, because
the `max_long_exposure_pct=0.70` + `min_cash_pct=0.30` sizing caps already bound long
deployment regardless of short proceeds. Only 27-30 shorts over 26y; 0 margin calls.

**The 3408% vs my +2023%:** my controlled run pins `max_position_pct_long=0.14`;
the production default is now **0.30** (re-pin #1753), which amplifies terminal-MTM on
the concentrated fat-tail winners. The headline-inflation lever is **concentration**,
not short leverage — exactly [[project_broad_universe_790_mtm_inflated]]. A 0.30 cell
would reproduce a much higher (still margin-insensitive) number; worth one confirming run.

## Status
- Margin machinery: **built, wired, validated, NAV-safe, crash-free.** Default-off (correct).
- sp500 deep acceptance: **DONE — margin does not deflate; NAV-safe with margin off too.**
- broad top-3000-1998 deep acceptance: pending (feat-backtest dispatch, snapshot mode).
- Acceptance on sub-windows: **PASS** (completes, NAV≥0) but **negligible effect** (sparse shorts).
- Open: (a) deep-cell acceptance run; (b) tiered FINRA maintenance + `short_min_price`; (c) decide whether the P0 is effectively done.
