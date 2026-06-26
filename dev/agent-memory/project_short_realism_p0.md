---
name: project_short_realism_p0
description: "Longshort backtest absolute returns are INFLATED by broken/missing short mechanics (G1-G5, esp G5 no margin model = free leverage); fix realism before banking any longshort number. Next-session P0; concentration tabled. Plan short-side-realism-2026-06-26"
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

**P0 next session:** implement these — plan `dev/plans/short-side-realism-2026-06-26.md`,
PR sequence G1 → G2 → margin model (G3+G5+G4) → re-pin longshort goldens. Acceptance:
re-run an inflated longshort number before/after the margin model; expect substantial
DROP + NAV never negative → longshort absolutes become trustworthy.

**Concentration TABLED** until shorts are legible. The long-only 0.30 re-pin (#1753) STAYS
merged (orthogonal, long-only, aligns to the existing 0.30 default — see
[[project_deep_goldens_conservative_vs_default]]); just no further concentration follow-ups
(broad matrix, confirmation grid, goldens-small alignment) for now. Trust long-only numbers,
discount longshort. [[project_edge_is_the_fat_tail]]
