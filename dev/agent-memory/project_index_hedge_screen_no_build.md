---
name: project_index_hedge_screen_no_build
description: "Index-short overlay 10-12 (pre-reg 776e8d355, PR #3265): NO-BUILD 0/9 cells; c2 (DD -3 pp) unreachable — record's binding DD = 2024-26 picks DD (SPY +24.6 %); bear gains land where macro gate already holds cash"
metadata:
  type: project
---
**Result (2026-10-12, `dev/experiments/index-hedge-screen-2026-10-12/`):** offline SPY-short overlay on record N, 3 salts;
G1 SPY Stage 4 / G2 G1+macro Bearish / G3 macro Bearish; h 0.25/0.5/1.0 × NAV, weekly lagged. No cell escalates: c1 fails
everywhere (best G2 h .25 −0.079), c2 fails everywhere — combined max DD WORSE in every cell (G2 h .25 23.70 vs 22.52 %),
c3 holds. No sensitivity passes c2; c1 passes only G2 h .25 as a held short (−0.041) or lag+credit (−0.034).

**Why:** (1) c2 is bounded by the base max-DD window 2024-11-26→2026-06-24, SPY +24.6 % (picks DD): any bear-gated short
adds loss; only the 2007-07 → 2010-02 DD improves. (2) Late: first on with 16/6/94/31 % of the 2000-02/08-09/2020/2022 declines
done. (3) Rebound bleed: post-trough −0.245 vs bear-leg +0.188 (G1 h .25); 2020 = 42 % of G1's cost. (4) Daily-rebalance
variance 0.06–0.07 + dividends ~0.017 at h .25. A lagged MA regime has no next-week predictive power.

**How to apply:** don't propose SPY-short / index-hedge overlays on lagged Stage-4 or macro gates as drawdown levers on the
record — its binding DDs are long-book lags in rising markets, not bears. A new index-hedge question needs a new objective,
a held short, a faster cover with a book basis (user's call). Single-name and index shorts stay off; Rule-4 recommendation
in ledger `2026-10-12-index-hedge-screen` awaits the user.

Links: [[project_shorts_liveness_dead]], [[project_barbell_on_stocks]], [[project_regime_barbell_direction]],
[[project_breadth_fix_ad_frozen]], [[project_index_stage_veto_verdict]], [[project_investor_preset_broad]].
