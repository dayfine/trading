---
name: project_short_realism_p0
description: "Short-realism P0 was ALREADY BUILT — 2026-06-26 reconcile found G1/G2/margin-model/Finding-A crash all merged on main (handoff was stale). Acceptance re-run: margin off-vs-on <0.06pp, NAV-safe, but shorts now sparse so weak test. Evidence says inflation is MTM/concentration NOT short leverage. Open: deep-cell acceptance + tiered FINRA maint."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6379af08-b68f-4dd7-8742-dff729a8b814
---

2026-06-26 strategic pivot (user-directed). The longshort backtest **absolute returns
are not trustworthy** — inflated by unmodeled short mechanics. The A-D grid's +3408%
deep-1999-2026 longshort cell (2026-06-23, sp500-515 NOT top-3000) is a modeling
artifact, not a real edge. KEY distinction the user surfaced: the recent **June 21-22
short work** (decline-character #1692/#1695/#1696, faithful-short gating,
neutral_blocks_shorts) improved short **SELECTION/faithfulness** (which shorts to take)
but is **default-off** and touched **NONE** of the realism MECHANICS. Faithful ≠
legible-P&L.

The realism gaps (still open; inflate the numbers):
- **G5 — no margin model** (the big one): shorts get free leverage, NAV can go negative.
  Reg T initial = 150% collateral on short entry; FINRA maintenance = ≥$5/sh max($5,30%),
  <$5 max($2.50,100%) → 30% tier only above ~$17 (keep short_min_price≈17). Regulatory
  spec researched in dev/notes/long-short-margin-mechanics-2026-06-12.md.
- **G1 — short stops fire wrong** (DIAGNOSED, DRAFT fix exists): Stops_runner stage-hardcode
  + actual_price=bar.low hardcode (should be bar.high for shorts).
- **G3 — cash floor only gates Buys** (shorts ride unbounded paper loss) — falls out of G5.
- **G4 — no margin-call force-liquidation** — the maintenance side of G5.
- **G2 — round-trip metrics blind to shorts** (legibility; shorts invisible in trades.csv).
- (later) borrow/locate/carry cost.

**2026-06-26 RECONCILE (autonomous): the P0 build is ~all already done on main.** Verified
against cc3c21f5 (handoff was stale per CLAUDE.md verify-claims discipline): G1 short-stop
(side-aware stage+fill, tests green), G2 short round-trip metrics, AND the whole margin model
(issue #859 Phase 1+2: Reg-T 150% collateral lock, sizing_cash cap, maintenance check, 50bps
borrow fee, force_liquidation; wired into simulator+panel_runner; default-off) are MERGED.
The May Finding-A crash (margin_call same-tick TriggerExit) is FIXED (#1266/#1274 dedup).
Re-ran the 4 May bear windows × off/on (never done post-fix): dot-com now completes clean,
NO margin_call exits, NAV never negative, margin Δ <0.06pp, IDENTICAL trade counts off/on.
Two reframings: (a) identical trade counts ⇒ collateral lock NOT binding capacity — the
max_long_exposure_pct=0.70 cap already prevents short-proceeds free-leverage, so G5 is
largely redundant for capacity; (b) current main shorts SPARSELY (dot-com 21→2 shorts since
A-D-live + faithful-short) so sub-windows are a weak test. Evidence is INCONSISTENT with
"inflation = free leverage"; points to terminal MTM on concentrated winners
([[project_broad_universe_790_mtm_inflated]], [[project_trade_realism_liquidity]]).
Full writeup: dev/notes/short-realism-reconcile-2026-06-26.md.
**Still genuinely open:** (1) deep-cell acceptance — reproduce the exact 3408% sp500-515
~1999-2026 longshort cell margin off/on (only thing that settles the inflation question);
(2) FINRA TIERED maintenance (current flat 25%) + short_min_price≈17; (3) decide if P0 is
effectively done.

**Concentration TABLED** until shorts are legible. The long-only 0.30 re-pin (#1753) STAYS
merged (orthogonal, long-only, aligns to the existing 0.30 default — see
[[project_deep_goldens_conservative_vs_default]]); just no further concentration follow-ups
(broad matrix, confirmation grid, goldens-small alignment) for now. Trust long-only numbers,
discount longshort. [[project_edge_is_the_fat_tail]]
