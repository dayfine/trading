---
name: project_p0_levers_no_build_2026_06_20
description: Both 06-19 P0 levers (reserved short sleeve
metadata: 
  node_type: memory
  type: project
  originSessionId: 7e8137e4-f01c-4146-b122-3f9446246c39
---

Deep 1998-2026 top-3000 Cell-E decision-grading lens screen (06-20) of the two
default-off flags landed 06-19. **Both NO-BUILD, kept default-off as axes.** Full
record: `dev/experiments/p0-screens-2026-06-20/FINDINGS.md`.

**P0a reserved short sleeve** (`short_sleeve_fraction` {0.1,0.2,0.3} vs OFF):
non-monotonic return 1663→1478→2019→**375**; shorts **lose every fraction**
(−$424k…−$676k) and **never unlocked** (36-44≈37 baseline). → (1) crowd-out is
**supply-gated not cash-gated** (Stage-4 signal count + `short_min_price 17`),
correcting [[project_short_funnel_crowded_out]]; (2) no offsetting leg to fund;
(3) reserved cash taxes the fat-tail long engine (0.30 craters return).

**P0b vol-scaled stop** (`vol_scaled_stop_atr_mult` {1.0,1.5,2.0} vs OFF):
every mult cuts return (1934→820/1206/242) + lowers Sharpe (0.61→0.47/0.56/0.34),
non-monotonic. Floor fires fewer stops (746→643→527→465, mechanic works) but
**per-decision stop net-VA got WORSE** (−6.2→−7.6) — whipsaw NOT fixed. mult=1.5
DD "win" (Calmar0.29/Ulcer13.6) is just less risk-taking (−38% return, lower
Sharpe). Stop cost is **structural not tunable** — weekly-close (#1655) +
vol-scaled both fail; foregone upside IS the fat-tail recovery. Corrects
[[project_weekly_close_stop_lever]].

Both are winner/loser-touching → [[project_edge_is_the_fat_tail]] (7th/8th
rejection). **Next lever = P1 barbell promotion grid** ([[project_barbell_on_stocks]],
a tail-non-touching diversification layer). Guardrail hardened: stop screening
capital-reservation + stop-widening knobs.
