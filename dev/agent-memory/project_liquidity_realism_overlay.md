---
name: project_liquidity_realism_overlay
description: "Liquidity-realism overlay MERGED (#1760, default-off): real-time held-position dollar-ADV degradation EXIT + entry GATE. Fixes the illiquid-delisted-microcap artifact (ELCO fake -48% day, APPB fake +$1.1M win) that corrupted broad top-3000 longshort. Broad armed +774% vs unarmed +1358% = honest tradeable number. The real broad-realism lever is liquidity+concentration, NOT short margin."
metadata:
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

2026-06-26 session. Two linked outcomes:

**(1) Short-realism P0 was already built; premise refuted.** The margin model
(issue #859: Reg-T collateral, sizing cap, maintenance, borrow fee, force-liq,
#1266 crash fix) was already merged. Deep margin off/on acceptance (sp500-515
2000-2026: +2023%→+2075%; broad top-3000 1998-2026: +1422%→+1358%) showed margin
is **non-deflating** + NAV never negative even margin-off (the
max_long_exposure_pct=0.70/min_cash_pct=0.30 caps already prevent free-leverage).
So the longshort inflation is NOT short mechanics. See [[project_short_realism_p0]].

**(2) The REAL broad artifact = illiquid delisted-microcap junk in BOTH directions.**
Forensics on the broad longshort −48% NAV day (2010-07-08) found **ELCO**, a
delisted micro-cap trading ~2 sh/day; a spurious 1-share $38.50 high-tick tripped
the short stop's worst-case cover → fake −$1.84M loss. Symmetric on the long side:
**APPB** ($0.42 penny stock, $9.5K ADV) booked a fake **+$1.1M** "win". Built
`trading/backtest/snapshot_warehouse/dump_snap` (reads a `.snap` via
`Snapshot_columnar`) to prove it. The broad top-3000 absolute return was inflated
by fake illiquid MTM on BOTH sides + terminal-MTM concentration — never bankable.

**The fix (PR #1760, MERGED, default-off):** liquidity-realism overlay in
`trading/trading/weinstein/strategy/`:
- `liquidity_metric` — trailing dollar-ADV = mean(close×volume), no lookahead.
- `liquidity_exit_runner` — **real-time held-position degradation EXIT** (the key
  piece per user: a held name whose liquidity decays → exit before untradeable;
  emits StrategySignal "liquidity_exit"). Wired in `special_exits.ml`; its skip set
  must union ALL four same-tick exit channels (stop ∪ force-liq ∪ stage3 ∪ laggard)
  or a collision yields a duplicate TriggerExit (the qc-behavioral rework caught
  this twice — `_apply_exit_channel` filters stage3/laggard OUT of force_exit_ts).
- `liquidity_gate` — entry filter, drops sub-`min_entry_dollar_adv` candidates.
- `liquidity_config { adv_lookback_days=20; min_entry_dollar_adv=0.0; min_hold_dollar_adv=0.0 }`
  default-off (no-op = bit-identical), a Variant_matrix axis.

**Validation (broad top-3000, armed min_entry 1e6 / min_hold 5e5):** ELCO gated,
6 liquidity_exits fired, worst day −48.05%→**−8.45%**, MaxDD 55.4%→**41.5%**,
return +1358%→**+773.6%** (the honest tradeable number — strips fake illiquid MTM
both directions; liquid winners AMD/LOGI/SKYW retained). It's an axis, not yet
default-on (needs WF-CV + grid per [[project_edge_is_the_fat_tail]] discipline).

**Generalizable lesson:** broad-universe deep backtests admit delisted-microcap
junk that produces fake MTM swings (both signs) the aggregate return hides. Always
NAV-over-time + worst-day forensics before banking a broad absolute. The realism
lever is liquidity (tradeability) + concentration, NOT short margin. Connects
[[project_trade_realism_liquidity]] (which said liquidity was a non-issue for
top-3000 *realized winners* — true, but the SHORT book + penny longs are a
different, real story) and [[project_broad_universe_790_mtm_inflated]].

Results-of-record: `dev/backtest/DEEP_RESULTS.md` (+ README pointer); scenarios in
`dev/experiments/short-realism-deep-2026-06-26/`. Notes:
`short-realism-reconcile-2026-06-26.md`, `short-realism-deep-broad-2026-06-26.md`,
`liquidity-realism-overlay-2026-06-26.md`.
