---
name: project_decision_walkthrough_next
description: "NEXT when container frees (user 09-26): step-by-step walkthrough of the ENTIRE decision tree over time (every weekly screen, entry, stop move, exit) to find opportunities/issues"
metadata:
  type: project
---

User 2026-09-26, after the obvious-fixes f2 s0 report (artifact AEKnAbPUqth16b1Ye7nKiA):
*"the next thing we will be doing when free is to do a step-by-step walkthrough of the
entire decision tree throughout time to inspect every decision and identify potential
opportunity / issues."*

**Why:** single-number verdicts keep reducing to "top-10 monsters decide it"
([[project_edge_is_the_fat_tail]]); the user wants to see every decision in context, not
aggregates.

**How to apply:** "when free" = after the obvious-fixes chain ends (~01:30 PT 09-27).
Inputs already exist per run: `*-trade_audit.sexp` (entry events with macro indicators,
stage, RS, volume, cascade score, cash-rejected `alternatives`; exit events),
`*-macro_trend.sexp`, `trades.csv`, equity curve; tools `backtest/decision_audit/`
(funded vs near-miss per screen, [[project_decision_audit_faithful]]),
`decision_grading/`, `review_pack.sh`. Gaps to check first: weeks with NO entry (macro
block / empty cascade) and weekly stop-raise decisions on held positions may not be
recorded -- verify before building. Directive lineage:
[[project_decision_audit_records_directive]].

**First pass 2026-09-26 (f2 s0, host-only, scratch in `.sweep-output/walk-f2s0/`):**
`trade_audit.sexp` HAS per-week `cascade_summaries` (all 1,335 weeks incl. no-entry)
+ 1,284 placements (724 filled) with cash-rejected alternatives; weekly stop raises are
NOT recorded (gap). Findings:
- Macro gate is not the main loss: 2020-26 Bullish weeks (260, 77 % invested) NAV +2 % vs
  SPY +83 %. Bearish weeks 2009-19 (133) missed SPY +65 %.
- Picks ≈ alternatives (paired per week funded beats cash-rejected 48 %, all eras).
- Loss = stop shakeouts: fallback stops (78 % of trades, 4.7 % wide) stop out 72 %,
  38 % quick-fail (≤20d, MFE<3 %); stopped names then rise +8.7 %/13w (2020-26).
  Support-floor stops (13.3 % wide): 44 % stop-out, 10 % quick-fail, +2.08 %/trade vs +1.00.
  Cohort, not causal -> test `require_structural_stop` (#2966).
- Entry tickets rest forever (`entry_order_max_rest_weeks 0` + trigger_at_suggested in the
  record spec): 202/724 fills from tickets ≥26 w old, max 885 w (17 y), decided on
  years-old stage/macro context. Stale fills were net profitable (cf.
  [[project_stale_order_fills_are_not_an_edge]]) but unfaithful.

**2021 walk (09-26, `.sweep-output/walk-f2s0/walk-2021.txt`):** 44 entries, 30 stop exits
(−$720k); 13 stopped within 7 days of fill (−$386k), 8/13 higher 13 w later. Installed
fallback stop = trigger × 0.96 (4 %) while the audit's `suggested_stop` is ~8 % (EQT,
SAIA, BEAM). All years: stop distance / ATR20 at entry → quick-fail rate: <1 ATR 48 %,
1–2 41 %, 2–3 27 %, 3+ 6 %; 58 % of trades sit inside 2 daily ATRs (median ATR20 2.9 %).
P&L not monotone (fat tail). Audit shows raw `close_at_decision` next to ADJUSTED
`ma_value` (NVDA 610 vs 13.7; adjusted close 15.2) — reporting mismatch, not a strategy
bug; normalise in any walkthrough tool. Idle cash mid-2021 (expo 29–58 %) while
placed tickets rest unfilled.

**2022–23 walk (09-26, `walk-2022.txt` / `walk-2023.txt`):** split corpus filed as #2973 (user).
2022: 39 fills, 35 stop exits (−$698k), 16 within 7 d; stops were RIGHT (stocks −3.6 %/13w
after) — the damage is entering at all: Neutral weeks (bear-market rallies Mar–Apr, Aug,
Nov) admitted ~30 buys, plus resting tickets filling in Bearish weeks. 2023: 49 fills, 37
stop exits (−$747k), 20 within 7 d, stocks +8.2 %/13w after = shakeouts; only the Nov–Dec
fully-invested stretch worked. 2022-23 stop 5.4 % ≈ 2.0 daily ATR.
All years: 103/724 fills (14 %) happen while macro is Bearish — resting tickets bypass the
macro gate (C2); net −$230k. The condition-cancel dial exists
(`enable_entry_ticket_rescreen`) but was REJECTED 08-18 on the older base
([[project_condition_vs_time_cancellation]]) — re-measure on the fixed sim before proposing.
Record spec pins `entry_order_max_rest_weeks 0` (default is 52).

**Written up 09-26:** PR #2979 — `dev/experiments/obvious-fixes-2026-09-25/salt0-analysis.md`
(22-item issue list, §3) + `walk.sh` (reproduces every table from artifacts, ~2 min).
Filed #2974 (trailing stops rarely rise — book §5.2 raises only after an 8–10 % correction +
recovery, so maybe faithful), #2975 (installed stop ≈ half `suggested_stop`), #2976 (tickets
fill in Bearish weeks), #2977 (record weekly stop decisions), #2978 (review_pack sed noise).
