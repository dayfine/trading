---
name: project-barbell-on-stocks
description: Barbell (SPY-timing floor + Cell-E stock-selection engine) NAV blend dominates both standalone legs on Calmar in BOTH regimes; 70/30 regime-robust. Resolves the 918%-vs-drawdown tension.
metadata: 
  node_type: memory
  type: project
  originSessionId: ca50bd58-52e8-4bfa-b1b2-6e777091a945
---

P0 of the 2026-06-03 arc, DONE 2026-06-02 (PRs #1434/#1435). Post-hoc
constant-weight daily-return NAV blend of two legs, both re-run fresh on deep
(2000-2026) and bull (2010-2026): FLOOR = `Spy_only_weinstein` SPY 30wk
long/flat (index-timing); ENGINE = full Cell E production strategy on clean PIT
S&P 500 (`universes/sp500-historical/sp500-2000-01-01.sexp`).

**Result — the barbell strictly dominates BOTH pure legs on Calmar in BOTH
regimes; diversification pushes blended DD *below the floor leg itself*.**

| | pure floor | 70/30 | pure engine |
|---|---|---|---|
| deep 2000-26 | 387%/18.8%/0.32 | **534%/17.8%/0.39** | 918%/37.3%/0.24 |
| bull 2010-26 | 239%/18.8%/0.40 | **247%/16.4%/0.47** | 238%/17.5%/0.43 |

- Deep: return trades monotonically for DD; Calmar-max at defensive **80/20**
  (0.414, DD 16.2% < floor's 18.8%). Bull: legs ~equal return → blend is pure DD
  reduction; Calmar-max at **50/50** (0.479). **70/30 beats both pure legs in
  each regime → regime-robust.** Matches ETF-lab barbell's 70/30 (#1426).
- 70/30 ≈ raw BAH-SPY return at HALF the drawdown.
- Deep engine reproduced doc's 918%/37.3%/0.25 exactly; bull engine 237.6%.

**Why:** resolves the 918%-vs-DD tension — you trade return for DD along the
frontier but never pick between the two pure strategies. The mandate picks the
point (drawdown-defense → 80/20; return-respecting-risk → 70/30).

Tool: `/tmp/blendw.awk` (`awk -v w=<floor-weight> -f blendw.awk floor.csv engine.csv`).
Writeup: `dev/notes/barbell-on-stocks-2026-06-02.md`. Extends
[[project_sector_rotation_layer_attribution]] (ETF lab) onto individual stocks;
relates to [[project_cell_e_2020_stall_regime]] (breadth is the lever for the
engine leg). Next: few-feature carrier as a better engine leg (lighter machinery
→ engine return at lower DD?).
