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

**Phase B round 1 (2026-10-10; 26y, v12, total return; v0 = all short fixes, v1 = v0 + #3221 stale-ticket cancel): FAILED, programme STOPPED.** Two independent results-analyst reads (the second blind) agree.
- A ex interest: −0.93 (v0) / −0.80 (v1) log. B: 1 of 3 bears (only 2008–09, +0.12 / +0.10). Salts are path seeds; identical trades per arm.
- **Why:** exposure timing −0.30 log (an SPY short on the book's own exposure loses too: Bearish weeks hold the V-rebounds); single names −0.49 beyond that (the shorted Stage-4 breakdowns *rose* after the fill; the whole skipped top-N candidate pool is a coin flip vs SPY at 20–250 d); costs −0.14 (88 % of borrow from the 25 %/yr sub-$17 tier). Loss = failed breakdowns at a never-moved stop (−$758k). 14 book-rule cohorts all negative; exits bounded (perfect hindsight on winners → +1–4 %).
- **How to apply:** don't propose single-name short dials or a round 2. Bear protection, if any, is index-shaped (index short at this exposure +0.30 log inside the 3 bears, −0.30 over 26y) and is judged jointly with the long book as a drawdown hedge; check the barbell/SPY-sleeve rejections first. #3221 flags stay default-off axes.
- Defects it surfaced: forced cover pre-empts the trigger-bar short stop fill (labelled stop_loss); HRC 2005-12 splice; A-D breadth fixture stuck pre-2017 (shared with the long record); foreign-currency listings (HSBA, CELSIA) in pit-v12 lists. Ledger `2026-10-10-shorts-phase-b-round1`.

**Caveat 2026-10-12:** ran on the frozen A-D input (2000–16: constant Bearish momentum vote, no A-D vote); post-2016 legs unaffected. See [[project_breadth_fix_ad_frozen]].

**Index-hedge screen 2026-10-12 (decision-10 hand-off, PR #3265): NO-BUILD** — the index-shaped short also fails (see
[[project_index_hedge_screen_no_build]]); bear protection via shorts is closed in both forms. Rule-4 recommendation (user
decides): short-only flags #3131 short_min_price_on_order_price, #3146 share_class_gate_covers_shorts, #3148
short_maintenance_finra, #3145 study arm short_tightened_ratchet_follows_decline = do-not-revive → retire after 3 unused
sessions; enable_short_side NOT eligible (default true, live weekly "Short candidates", 202 specs inherit);
tightened_can_ratchet NOT eligible (long-side stop).

**Score-threshold addendum 2026-10-12 (PR #3273, exploratory):** a stricter short score is NOT reliably better. Filled
shorts at score ≥ 100: 25 trades, win 32 %, mean −0.6 % (v0 ex-HRC) / −1.1 % (v1) vs < 100 at −4.8 / −4.9 % — a weak tilt
carried by DB/TAC/M, still negative. The 1,491-candidate pool (no stops, vs SPY short) is a coin flip at every
threshold. "Weakest stock in weakest sector" (Weak sector + RS negative-declining) is the worst filled cohort (−6.9 /
−8.9 %). Lesson (QC caught it): I first said a flat "no" — the filled split said "weakly better, unconfirmed".

**USER 2026-10-12: shorts are STILL WORTH PURSUING — "we are just not doing it very well."** Flags stay keep-as-axis
(no Rule-4 retirement). Gaps vs the book: long-designed stop room (2,024/2,184 top candidates skipped
No_structural_stop), breakdown-only entry (no half-on-pullback), macro-composite market timing (book: index early
Stage 4), no H&S detection, mirrored score that doesn't rank. Next: pre-registered short SETUP MAP over all Stage 3→4
breakdowns (dev/plans/short-setup-map-2026-10-12.md, PR #3274, held do-not-merge until the user confirms).
