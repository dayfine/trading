---
name: project_recovery_reentry_gap
description: "Recovery re-entry gap 10-02/03: local-range anchor (ia4/13/26) DILUTES 6/6 (5d + 5r, every salt); investor 2009 gap = No_structural_stop skips, not unfilled tickets; filled recovery entries whipsaw; far graded tops exist in every year (base-bounded anchor = global lever, do not build); 2025 lag = picks not cash"
metadata:
  node_type: memory
  type: project
  originSessionId: 13438ee6-bde6-4f74-839d-eef43a46dd35
  modified: 2026-10-03T09:33:03.665Z
---

**Problem (user 10-02, T1 5d pack "amazingly flat"):** 2008–09 equity flat; gate reopened 2009-05-08; T1 placed 116 tickets May–Aug 2009, none filled (median 60 % above close, anchor = 8–60-week max high = pre-crash peak). Investor preset (`tp-i-5d`) 0 entries May–Aug 2009 at every salt.

**Experiment `dev/experiments/entry-anchor-recovery-2026-10-02/`** (pre-reg b0025fff1, rules 1–8; `entry_anchor_local_range_weeks` 4/13/26 vs investor null, 5d + 5r, 3 salts, build main 10-02, pinned `sweep-anchor`). **Dilutes 6/6 (final 01:57 PT 10-03).** 5d: null Calmar 0.23 / DD 14; ia4 −0.11 / 25; ia13 −0.13 / 25; ia26 −0.02…−0.06 / 20. 5r: null 0.241 / 0.095 / 0.240 (DD 22); ia4 −0.03 / DD 41; ia13 0.01–0.03 / 33–34; ia26 0.02 / 29. V6 exit 0 on all 18 pairs; nulls byte-identical to 09-29 at all 6 cells. Trades +25…+57 %, stop share flat, median hold 41→55–66 d. Rule 6 → **no phase 2, no ledger entry** (rule 8).

**Why (transferable):**
1. The lever is global, the problem post-crash: nearer highs trigger in every market; 5d ia4 pre-2009 24 entries −$140k vs null 15 for −$32k (−$84k in Jun–Jul 2007 with the gate Bullish); 5r ia4 194 trades vs 126.
2. **Investor preset mechanism ≠ T1's.** Investor placed 2 tickets May–Aug 2009; the cascade admitted top-20 weekly, then `require_structural_stop` skipped them (`No_structural_stop`: no correction low within 15 % below a ticket sitting at the pre-crash high → fallback stop → skip). ia4 moved the ticket down, floor came in range, 25 tickets. Funnel: 599 entries of ~10,900 top-20 candidates over 26y (5.5 %); 10,263 structural-stop skips vs 231 cash skips.
3. **Filled recovery entries whipsaw:** ia4 s0 25 entries May–Sep 2009, 11 stop exits, 10 losers at −13.8…−16.4 % (6 in the Jun–Jul 2009 pullback, 2 in mid-May, 2 in October; 13–15 % structural stops); winners (EBAY +32, AWI +31) left by laggard rotation; net ≈ 0. Caps any anchor fix.
4. **Per-episode (26y investor s0, 19 reopens after ≥ 8 closed weeks):** caught 2003 (+21.6 vs SPY +13.8, 15 entries/26w), 2012-08, 2020 (+25.2 vs +16.8); missed 2009 (0 entries/13w, −1.5 vs +16.4), 2019 (2, −0.5 vs +5.1), 2022-11 (0, −1.3 vs +5.3); 2010-10 lagged; **2025-05 invested and lagged** (12 entries/13w, −8.0 vs +14.5, −$379k). Now a pack signal (PR #3086 "Gate reopen episodes").
5. **Base-bounded anchor screen (`anchor-position-screen.md`): do not build.** Skipped candidates' graded top / close ≥ 1.20 in 9–47 % of cases in EVERY year (2017 9 %, 2009 44 %, 2000 47 %); ~half of structural-stop skips are within 10 % of the top. Far anchors are not post-crash-specific → any anchor move is global.
6. **2025 = picks, not cash, not path:** 21 of 22 entries identical in s1/s2; picks' 26-wk forward return median +4.7 % (10/22 negative) vs SPY +14.5 %; stops mostly right (TNXP/APPF/WBTN/UPWK/BALY kept falling), two cut names rallied (AIP +122 %, AD +15 %). Same shape as 2018–23 melt-up lag.
7. Narrow structural stops (< 6 %) net +$598k/+$562k (s0/s1, 67–69 trades): NOT a lever.

**Forward:** entry-timing levers for the recovery are exhausted at the ticket level (N-week high dilutes; base-bounded is global; the faithful rule "prefer other candidates" is what sits out). Remaining directions need a user decision: `entry_ticket_macro_suspend` arm (free, small expected effect), shorts liveness pair (prior record negative), selection in narrow rallies (2025 shape). SPY sleeve stays user-declined.

Links: [[project_investor_preset_broad]], [[project_trader_preset_matrix]], [[feedback_exposure_vs_market_condition]], [[feedback_render_and_look_at_review_pack]], [[project_melt_up_lag_anatomy]], [[project_barbell_on_stocks]].

**Record (10-03 02:40 PT):** results PR #3091 (results-only, qc-results); pack signal PR #3086 (rebased on #3088, `reopenFlag` + node pins). Packs: null 5d NYShFM3TRXvyegVTauQn6v, ia4 5d PzeAqL84oVE2RpT34qUfmm, null 5r KwEZgHBhucZTNcLWGLAq5W, ia4 5r M99rgdTgY1JDEfGeGyRJy8. The ia4 5d pack reads "invested and lagged 2009-05 (19 entries, −0.2 % vs +16.4 %)": live in the recovery and still 16.6 pp behind.
