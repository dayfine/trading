---
name: project_top_n_capacity_verdict
description: "⭐ 09-22 TOP-N CAPACITY ARM (max_buy_candidates 20→40, 3 salts, PIT band): ACCEPT(mechanism) by the pre-registered rule (2/3 clear realised AND Calmar) but NOT promotable — level is a salt lottery (arm-only cohort −$0.87M / +$0.88M / +$0.85M), robust property is dispersion (arm return 237–330 % vs null 152–457 %, maxDD 43.8–44.7 vs 40.6–53.0, n=3); mechanism = SLOT re-draw, not screener capacity (46 % of arm-only entries were null-admitted-never-filled; cap binds 99 % of weeks, ~5 slots fill ~28 entries/yr). Next lever = slot-fill ordering, not cap width."
metadata:
  type: project
---

**Result (2026-09-22, `dev/experiments/top-of-funnel-2026-09-21/`, ledger `2026-09-22-top-of-funnel-capacity.sexp`):**
s0 237.4 / maxDD 44.5 / Calmar 0.106 vs null 457.0 / 40.6 / 0.165 (FAIL); s1 304.0 / 43.8 / 0.123 vs 188.0 / 53.0 / 0.077
(clear); s2 329.5 / 44.7 / 0.127 vs 152.0 / 51.3 / 0.069 (clear). ACCEPT by rule; default stays 20 (R3 + the grid).

**Why it came out this way:** the cap binds in 99.1 % of weeks and 33.8 A_plus names/week fall at it (d0 decomposition,
admitted = 94 % A_plus, score-then-alphabetical ranking), but the book fills ~28 entries/yr into ~5 slots. A 40-name
list re-draws *which resting orders trigger first* against the slots + cash floor: at s0, 46 % of the arm-only entries
were names the null had ADMITTED the Friday before and never filled, only 28 % were ranks 21–40. Cohort sizes are the
same at every salt (~36 % of each book) and the sign flips with which draw holds the year's monsters (2020/2025 in the
null at s0; ECHO +$677 k in the arm at s1). #2490's "36 % of monsters die at top-N" is mostly a SLOT loss.

**How to apply:** (1) never quote +177 pp / −220 pp — the level is a draw; (2) the one plausible robust property is a
tighter salt band (maxDD 0.9 pt vs 12.4 pt spread) — test it with the grid ({30,40,60} × 2019–2025 sub-window × top-1000
schedule) before any default change; (3) the next top-of-funnel lever is **slot-fill ordering** (score → RS → volume
ratio, never alphabetical; spine item 7 supports RS for selection), pre-registered as a screener-ordering dial;
(4) `--emit-candidates` doubles a cell (7h25m / 7.6 GB) — diagnostic cells only. Related:
[[project_monster_funnel_top_of_funnel]], [[project_screener_alphabetical_tiebreak]], [[project_edge_is_the_fat_tail]],
[[project_index_stage_veto_verdict]], [[project_concentration_deploy_probe_reject]].
