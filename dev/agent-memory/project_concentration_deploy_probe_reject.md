---
name: project_concentration_deploy_probe_reject
description: "09-14 probe on the 26y _v10dedup record (ledger 2026-09-14-concentration-deploy-probe): c2 (exposure 0.85 + cash floor 0.15) is BIT-IDENTICAL to the null — neither knob binds at 0.14/position; c1 (per-position 0.25) fails realised+Calmar at 2/2 salts (−$421k / −$892k; maxDD 32.8→46.7 at s1) because a fuller-per-name book holds fewer names when the 2020 monsters screen in (NVDA/BBWI null-only at both salts). Recovering-week cohort (11–20 trades) flips sign with the salt. Item-6 'deployment ramp' = NO-BUILD; the entry gap is top-of-funnel, not funding/sizing."
metadata:
  type: project
---

**Result** (`dev/experiments/concentration-deploy-2026-09-13/`, pre-registered #2796): both arms fail the
pre-registered rule (realised AND Calmar at ≥ 2 of 3 salts). c2 was stopped after salt 0 (identical trades.csv
and metrics to the null); c1 lost at both salts read, with the drawdown side unambiguous (rides 2018 + 2020 deeper).

**Why it transfers:** the shared-trade term is positive (+$574k / +$311k — the same trades earn more at the wider
cap) but concentration cuts the trade count by a third and the concurrent-name count (4–6 vs 5–9 in 2020), so the
book is emptier per slot exactly when the recovery monsters screen in. This is the 06-25 "knife-edge at 0.25"
([[project_capacity_concentration_surface]]) reproduced with salts on the broad record: the 0.25 cell is a lottery.
[[project_edge_is_the_fat_tail]] from the other side — a bigger ticket in fewer names buys less breadth in the weeks
the tail is caught.

**Forward guidance:** stop resizing the ticket; drop `max_long_exposure_pct` / `min_cash_pct` from capacity surfaces
on this base (inert); the next entry-side screens widen the funnel (breakout-gate width, top-N —
[[project_monster_funnel_top_of_funnel]]). Cohorts of 10–20 trades cannot carry a verdict
([[feedback_perturb_before_believing_a_cohort_split]]).
