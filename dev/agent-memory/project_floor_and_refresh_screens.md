---
name: project_floor_and_refresh_screens
description: 10-25 floor + refresh screens; Nearest SN NOT LIVE (#3423); monthly-refresh SM LIVE but INCONCLUSIVE 10-26 (#3446, Δ −0.19, entrant tail stops at the funnel); yearly lists stay
metadata:
  node_type: memory
  type: project
  originSessionId: 065e3ac2-f069-4230-a0ea-bd630f4c1697
  modified: 2026-10-27T02:58:00.977Z
---

Host-only screens 2026-10-25 on record N arm s0 decisions (`trade_audit.sexp`, 20,177 No_structural_stop skips / 676 placed) and the CSV store. Scripts in that session's scratchpad (floor_screen.awk, ent.awk); not committed.

**Floor screen** (stop = floor × 0.96, ≤ 15 %, fill if next 5 bars reach E = 20-bar high, exit on stop or 26 w, no trailing). Replica W90 admits 68 % of placed and 7 % of skips. Skip reasons: 67 % no ≥ 8 % correction after the 90-bar peak (peak sits at the end of the window), ~26 % floor > 15 % away.
- Placed (W90) n=138: mean +7.1 %, median +3, > +50 % 5.1 %.
- Skips admitted by `Nearest` 90 (`support_floor_anchor_scope`, existing dial) n=1,148: mean +5.0 %, median −5.9, > +50 % 6.3 %. 2020–26: +5.2 vs placed +1.8, tail 8.7 % vs 2.6 % (small n). Catches INOD, ASTS, SYRE, CENX, VKTX.
- W180 lookback n=243: mean +7.3, median +6.2, win 60 %.
- MA150-as-floor: data-error outliers; cap-100 mean +4.0 — weakest.
Nearest was not promoted 08-16 ([[project_nearfloor_is_risk_not_return]]), but that test predates `require_structural_stop`; with the gate on it converts skips into entries, which is a different mechanism. Tested as backtest arm SN 2026-10-25 (#3423, see Outcome below); after Nearest the 15 % stop gate binds (81 % of floors lie beyond it), so the remaining lever is cash allocation, not the anchor.

**Universe refresh screen** (monthly top-3000 by 60-day ADV, ranked over the union of yearly-list symbols, vs the yearly May 31 list in force): 13 % of monthly members are not in the yearly list. Entrants' 12 m forward return: mean +7.1 % vs members +10.7 %, median −0.5 vs +6.1, but > +100 % 7.8 % vs 4.6 % and > +300 % 1.43 % vs 0.54 %. Entrants carry 29 % of all > +300 % rows. AXTI enters monthly at 2025-09 (rank 2,816, $4.49, +2,000 % over the next 12 m); the yearly lists never admit it.

**Outcome (1), 2026-10-25 #3423:** Nearest arm SN ran 6 cells (2019–24, K=6 vs path-stability S): NOT LIVE as screened (NSS 0.95× vs a 0.75× bar mis-set ~4× stricter than this screen's per-decision 5.7–6.7 % conversion; observed 5 %). Conversions re-draw cash in a cash-bound book (39–58 S tickets displaced per cell, incl. APPS/MMYT/GLNG); descriptive Δ median ln(1+R) −0.41, 6/6 seeds negative. Nearest stays a default-off keep-axis; NOT escalated to 26y.

**Outcome (2), 2026-10-26 #3446:** monthly-refresh arm SM ran 6 cells (same window, null and build): LIVE (19/150 SM p0 trades outside the yearly list, all also at decision) and INCONCLUSIVE by rule (Δ median ln(1+R) −0.193 vs bar 0.211; 8/36 cross pairs; median max DD +5.5 pp). Why: ~70 % of the NAV gap is which arm's cash caught APPS/ADMA/BBWI (BBWI refused for $146) — traced path noise; ~15 % is the entrants' own trades — volume-spike names (breakout volume 4.6× vs 2.5×) that realise worse than what they displace (median −0.072 vs −0.039, 0/123 above +100 %). In 2019–24 entrants are 8.8 % of member-months and 18.3 % of > +300 % rows (not 13 % / 29 %), but the tail stops at the funnel: 45 of 60 such entrant names never reach any top-20, 14 that do skip (No_structural_stop / Sized_to_zero), 1 (BMA) is placed. Yearly May-31 lists stay the record universe.

**How to apply:** (1) is done — do not propose a 26y Nearest test. (2) is done — do not re-run a monthly refresh as a return lever; universe breadth is tail-preserving only if the shots reach a slot, and the binding gates are the top-20 cut and the structural-stop gate. Three funnel-widening reads (top-N 40, Nearest, monthly refresh) now behave alike in this cash-bound book. For any next universe/funnel arm, pre-register the leaver and cut classes beside "displaced at the decision". Set liveness bars from a screen's per-decision rate, never its headline multiplier. See [[project_2025_anatomy]], [[project_top_n_capacity_verdict]], [[project_monster_funnel_top_of_funnel]].
