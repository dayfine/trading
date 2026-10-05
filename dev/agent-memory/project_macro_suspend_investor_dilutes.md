---
name: project_macro_suspend_investor_dilutes
description: "Macro-suspend 10-04 (PR #3123 + second read): live but DILUTES 5d+5r; removes ORDINARY fills near turns (tail lottery); 5d = ONXX alone; re-issues fill as dip-buys (#3126); keep as axis"
metadata:
  node_type: memory
  type: project
  originSessionId: 0bdb1704-90a7-4760-bb6e-40335d5259c0
  modified: 2026-10-05T02:37:09.020Z
---

**Result (2026-10-04, `dev/experiments/macro-suspend-investor-2026-10-04/`, PR #3123, build 81da500d5, salts 0–2):** msB (`entry_ticket_macro_suspend On_bearish_macro`) vs investor null. V6 exit 0 all pairs; ms0 = 10-02 ia0 on metrics (3 stop-column rows per pair differ: #3100). Live: null 9 Bearish-week fills/salt at 5d (6 closed + 3 open), 3 at 5r; msB 0. Calmar lower 3/3 both windows → **dilutes**; no phase 2; default Off; no ledger entry. Classification: REJECT-as-default, keep as book-faithful axis.

**Why (results-analyst second read; corrects my first writeup):**
1. Bearish-week fills are TIMED at turns (median 3 wk before reopen vs 9 for a random Bearish week) but are ORDINARY in quality (same median as Bullish-week fills at 26y). Their sum is a tail lottery: +$44k for ms0 over 5d+5r, −$30k without ONXX/STN/AIT. Removing ordinary fills on a fat-tailed positive-expectancy book = negative EV ([[project_edge_is_the_fat_tail]]).
2. 5d is decided by ONE position: ONXX +$31.8k open at the end (1.9–2.2× the gap). NOT a window artefact — msB's ticket could never have filled (gate Bearish to 07-27, ONXX never back to the trigger).
3. Cash chain: STN suspension → msB placed ATMU → ATMU blocked MPC (s0/s2, `Insufficient_cash`) or SARO (s1): knock-on −$26k/+$29k/−$13k by salt.
4. Re-issues fill FROM ABOVE as dip-buys with stale stops (STN 2026-02-12 opened 99.75 vs trigger 88.86) → #3126. Opposite of the far-anchor shape in [[project_recovery_reentry_gap]].

**How to apply:** don't propose cancel-and-re-screen as an improvement (shares the dominant term; max gain = re-issue term −$4–6k). Fix #3126 only as axis correctness. Few-fill levers: 5y×3-salt Calmar ≈ one draw per window (same fill set every salt) → need a paired per-event estimand or 26y + truncation check. Count Bearish-week fills over trades.csv AND open_positions.csv. Pack exposure omits open positions → #3125. My first look missed that; the analyst caught it ([[feedback_results_analyst_when_absent]]). Packs: 5d TdVJjCRWwHPmkG9xQsUtvY, 5r FTqbLrE4S1HDCuXfK6PyNf.
