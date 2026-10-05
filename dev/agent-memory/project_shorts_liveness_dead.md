---
name: project_shorts_liveness_dead
description: "Shorts liveness 10-03 (PR #3110): investor + faithful shorts on 5d = 0 fills; slow-grind gate closed 117/138 Bearish weeks; 174 admitted → 2 tickets, both above market, never filled"
metadata:
  node_type: memory
  type: project
  originSessionId: 0bdb1704-90a7-4760-bb6e-40335d5259c0
  modified: 2026-10-04T06:47:18.751Z
---

**Result (2026-10-03, `dev/experiments/shorts-liveness-2026-10-03/`, PR #3110, build 29e81f888, salt 0, 5d 2007-06 → 2012-06):** investor preset + `enable_short_side`, `neutral_blocks_shorts`, `enable_slow_grind_short_gate`, `short_min_price 17`, borrow ADV 1M, margin model on → **0 short fills**. Arms byte-identical except `position_id` (V6 exit 0).

Funnel (trade-audit cascade diagnostics): Bearish 138 weeks, all with graded Stage-4 short candidates; `short_top_n_admitted > 0` in only **21** (slow-grind gate shut the rest, incl. all of Sep–Nov 2008); 174 admitted → 2 tickets (entry-week skips: 12 `No_structural_stop`, 5 `Sized_to_zero`; other weeks' skip reasons not audited). Both tickets (RMD 2008-02, GFI 2011-10) sat 21–34 % above close because the short ticket is priced at `breakout_price` = the TOP of the prior base (screener.ml:145-161, screener_entry_anchor.ml `choose ~is_short:true` → Breakout; `breakdown_price` is never used) — corrected 10-04 by the short-only design read; the 10-03 README wording "transition-week breakdown level" is wrong; the stop-limit 2 % band never traded (GFI missed by 2 cents). Short-side mirror of the long far-anchor problem ([[project_recovery_reentry_gap]]).

**Why:** gates compound. The grind gate closes in fast declines, where breakdowns cluster; the long-designed structural-stop and stop-limit rules then reject the rest. A shorts test with these gates measures nothing.

**How to apply:** any further shorts work opens gates one at a time, grind gate first (user decision). Review pack has no short-side read → issue #3111. Pack: https://claude.ai/artifact/BoYPmkotZjNQZbCMWRWKv7.

Links: [[project_p0_levers_no_build_2026_06_20]], [[project_p1a_deep_short_screens]], [[project_short_realism_p0]].

**Phase A (10-05, PR #3135, short-only, slow-grind gate off, tickets at close, 5d salt 0):** LIVE (181 / 123 fills) but −8.4 % / −9.5 %, and that headline is contaminated: `short_min_price` gates the base-top price (#3131) so 60/40 sub-$17 shorts were margin-called within 1–4 days (+$96k/+$73k = all 2008 profit). Clean remainder ≈ −22 % / −17 %, win rate 16–18 %. Loses on the EXIT side: short Tightened stop never moves down (#3145; ADSK frozen 137 decisions, soTs open +$305k at the 2009-03 peak realised +$42k) and rally-day squeezes. Pack reads shorts long-side (#3149). Next: fix #3131 (+#3145 as its own study) before any money read.
