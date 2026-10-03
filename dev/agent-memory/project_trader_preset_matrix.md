---
name: project_trader_preset_matrix
description: "#3038 trader-preset matrix 10-01 (PR #3061): investor first in 6/6 cells; continuation buys never fire (#3056); 10wk trail dilutes via turnover; 10wk stage 'adds' at 5r, flagged"
metadata:
  node_type: memory
  type: project
  originSessionId: 13438ee6-bde6-4f74-839d-eef43a46dd35
  modified: 2026-10-01T18:02:52.409Z
---

30 cells, 5r (2021-06→2026-06) + 5d (2007-06→2012-06, GFC), salts 0–2, arms I/H/T1/T0/T2, one build 6bcefc0c8. Writeup `dev/experiments/trader-presets-2026-09-29/results-2026-10-01.md`, PR #3061.

- **Investor first in all 6 cells**: median Calmar 0.240 (5r) / 0.233 (5d), DD ~22 % / ~14 % vs hybrid ~40 % / ~30 %. 5d investor salt-stable (0.232–0.235).
- **T1 (continuation buys) = H trade-for-trade in all 6 cells** → NOT tested. Cause (#3056): candidate ticket anchored at old base top (`breakout_price×1.005`), hybrid's StopLimit cap 2 % never fills a name already above it; mature Stage 2 scores 0 stage points. Fix = anchor at `continuation.consolidation_high` behind the flag.
- **T2 (10wk trailing stop) "dilutes" at 5r 3/3**: shared trades small (net +13k / +19k / −21k; cuts some winners, e.g. ON +23.5→−3.3 %); loss = turnover — freed cash recycled into 82–85 T2-only entries/salt, 62–67 % on <4.5 % fallback stops, −$129–274k. At 5d the trail almost never binds (2 trades/salt; hybrid holds ~14–18 days median).
- **T0 (10wk stage MA) "adds" at 5r** (Calmar 3/3, DD ≤ +3.8 pp) → flagged per book prior. Shares only 25–33 entries with H; its edge = profitable stop exits (21–28/salt, +$350–530k vs H's 7, +$50–80k). T2 trails same MA and loses → T0's win = different entries + trail, not separable. 5d unreadable: V6 fails on CMN/CMD rename twin (#3057).
- **Why:** trader dials can't be judged on the hybrid base — its 4 % fallback-stop entries are the loss engine; exit dials that shorten holds raise turnover into them. Fits [[project_edge_is_the_fat_tail]], [[project_investor_preset_broad]].
- **Next:** #3056 then rerun T1/T2; T0 investigation (pin stop MA back to 30 with 10wk stages); #3057 then T0 5d.
- **10-02 rerun launched** (`dev/experiments/trader-presets-rerun-2026-10-02/`, pre-reg commit 61dfc6db2, build f86d38f54 = #3067 merged): H/T1/T2 × 5r/5d × s0–2 + T0S (10wk stages, `trailing_stop_ma_period (30)`) at 5r; 21 cells ~14 h, chain `/tmp/trader-rerun/chain-N.log`, artifacts `/tmp/sweeps/trader-presets-rerun`. ~~Continuation-entry classifier = entry `weeks_advancing > 4`~~ VOID (see the 10-02 result below). Same-build anchor: rerun H must match 09-29 H.
- **#3057 root cause:** CMN/CMD = Cantel rename; CMD file has another instrument's 2016 junk (189/252 zero-vol) → twin match 0.933 < 0.95, never detected. Fix proposal on the issue (longest-matching-run knob, default off).
- **10-02 RERUN RESULT (PR #3081, ledger `2026-10-02-continuation-buys-trader-rerun`):** H anchors byte-identical, V6 0 everywhere. **T1 "adds" by rule in BOTH windows (5r 2/3, 5d 3/3, 5d DD −12 pp) but each window = ONE ticket the old anchor couldn't fill**: FNSR 2009-08 +$153k all salts (T1 entry 0.80 = consolidation_high vs H 1.51 on a 0.72 close), ADMA 2023-12 +$230k s0/s2 (17-wk resting ticket H never placed; losing s1 has none). Without them T1-only trades lose 5/6 cells; shared trades lose to smaller sizing 6/6 → Accept-by-rule, NOT promotable (tail lottery, [[project_clock26_is_a_tail_lottery]]). T2 dilutes 5r 0/3 / adds 5d 2/3 → regime-dependent. T0S adds vs H 2/3 (DD 5–11 pp better), not separable from T0; its profitable stops (19–21) match T0 with stop MA pinned at 30 → T0's stop "edge" is the 10-wk stage clock, not `trailing_stop_ma_period`. Rule-9 classifier VOID (H has 6–14 entries N>4; continuation tickets can be N=1) → need #3074 anchor tag before any grid. Every 5r cell loses on closed trades; returns rest on open positions (BELFB +233 %).
