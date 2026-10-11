---
name: project_total_return_shorts_b_plan
description: "10-05 USER decisions: total-return becomes record basis (T-bill−0.10 %, EODHD dividends), #3136 = split-only-adj close×vol, shorts Phase B 26y pair, stop rule A∧B, ≤2 rounds"
metadata:
  node_type: memory
  type: project
  originSessionId: 0bdb1704-90a7-4760-bb6e-40335d5259c0
  modified: 2026-10-05T20:06:38.724Z
---

Plan: `dev/plans/total-return-and-shorts-phase-b-2026-10-05.md` (PR #3152). Decided with the user 2026-10-05.

- **#3137:** EODHD dividend files (not adj/raw inference); shorts pay dividends; cash = daily 3-mo T-bill − 0.10 %/yr (knob), floor 0; default-off on merge, default-on after the combined re-run passes the implementation check (≈ +0.24 log interest, +0.13 dividends). Sharpe on excess return.
- **Past verdicts:** no pre-set cash-gap cutoff (user: "I would not pre-define a 10% cut") — per-verdict analyst diagnostics, qualitative + quantitative, then decide re-runs.
- **#3136:** split-only-adjusted close × split-adjusted volume; splits fetched with dividends; measure PIT membership + liquidity-gate flips before any rebuild.
- **Queue:** #3136 measure → combined long baseline re-run (3 salts) → 26y shorts pair → verdict diagnostics.
- **Shorts:** v0 fixes (#3131/#3145/#3146) vs v1 + cancel-on-non-Bearish + short TTL. Stop: 26y TR > 0 AND ≥ 2/3 bear periods positive, cash interest excluded; per-position anatomy diagnostic only. ≤ 2 rounds, then index-hedge decision.

**Why:** price-only sim biased verdicts toward full investment ([[project_sim_price_only_accounting]]); shorts Phase A contaminated by bugs ([[project_shorts_liveness_dead]]).
**How to apply:** user wants every gap/constraint/remaining area documented in the plan and each writeup; conclusions must carry constructive "why → next lever" feedback, not bare verdicts.

**Progress 2026-10-07:** cash_yield default-ON merged (#3184; 19 regression goldens pin `No_yield`, re-pin deferred to after #3138 + v12 re-baseline). `split_dividend_guard` merged default-off (#3181, fixes #3173). `dividend_crediting` still default-off: flip needs guard on + the 26y TR check re-run (dividends were outside band: specials/ADR gross). v12 lists merged (#3182): inventory fix found the old tool saw only 5,734 of 11,888 symbols, so v12 moves basis AND candidate set (do not attribute v11→v12 deltas to basis alone). v12 warehouse build launched 17:45 PT from pinned `sweep-pit-v12` @ ccf1befbb → `/tmp/snap_top3000_pit_v12pit`, log `/tmp/pit-v12-work/build.log`. Next: v12 null (V6 = 0 required) + TR re-baseline (doubles as dividend check) → Phase B on v12.

**2026-10-09:**
- **Phase B design defaults confirmed by the user at 11:00 PT.** The 7 choices left open in the plan stand: v1 rest limit 4 weeks; S&P close-high-to-low bear periods; pass on ≥ 2 of 3 valid salts; interest rebuilt-and-scaled, with both the log and the dollar reading > 0; v0 uses the structural stop; FINRA maintenance; Phase B = round 1.
- **First v0 launch stopped.** AIG/AIG-WS was shorted twice, so V6 = 1. A vendor warrant series that copies its parent was fixed by #3227: 12 groups added to share_classes.sexp.
- **v0 relaunched 09:30 PT at 10f725ffe.** #3218 v1 flags merged as #3221.

- 2026-10-10: Phase B round 1 FAILED (both arms 0/3 salts; A −0.9/−0.8 log; B 1/3); round-2 condition not met by two reads → single-name shorts stopped; index-hedge is the next shorts-side question. See [[project_shorts_liveness_dead]].
