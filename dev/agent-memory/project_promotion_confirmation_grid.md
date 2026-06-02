---
name: project_promotion_confirmation_grid
description: "Before flipping a mechanism's default, run a confirmation grid (>=3 independent period×universe contexts); promote only a grid-robust value, never the single-window DSR winner"
metadata: 
  node_type: memory
  type: project
  originSessionId: b9b9ed30-f921-4bfd-a0ea-792e77271fa4
---

A ledger **ACCEPT** from one walk-forward surface is necessary but NOT
sufficient to flip a mechanism's global default. The single-window DSR winner is
frequently overfit. Codified 2026-05-31 as **`.claude/rules/promotion-confirmation.md`**
+ `experiment-gap-closing` skill step 7 (PR #1384).

**The grid:** re-run the candidate surface (winner + 1-2 neighbours, not the full
axis) across **≥3 independent (period × universe) contexts** — period diversity
(full-history long window + ≥1 disjoint sub-window) AND universe diversity
(canonical + ≥1 different universe/snapshot; survivor-biased composition goldens
are OK since the bias hits baseline + candidate equally). Confirm the
index/breadth golden spans each window first ([[project_gspc_index_golden_2017_floor]]).

**Decision rule:** promote value V only if it's on the Pareto frontier (or
positive-DSR) in a strong majority of cells AND never badly dominated in any.
The single-window DSR winner is NOT automatically promotable. If no value is
grid-robust → keep ACCEPT(mechanism) but leave default off.

**First application (early-admission, [[project_early_admission_mechanism]]):**
4 post-2009 cells (15y/5y/early SP500 + top-3000) → ma=13 looked grid-robust
(4/4 frontier), ma=10 overfit. **BUT all 4 cells were post-2009.** A 5th cell —
a **27y deep window (2000-2026) covering the dot-com bust + GFC** — REVERSED it:
baseline dominated every variant. The post-2009 "robustness" was a bull-regime
artifact.

**⚠ The load-bearing refinement (2026-05-31): MACRO-regime diversity, not just
calendar diversity.** A grid whose cells all share one macro era can only
certify an artifact of that era. **Whenever data permits, one cell MUST span a
genuinely different regime — ideally a deep 2000-02 + 2008 window** (build via
the `fetch-historical-data` skill + `build_deep_universe.sh`). The rule
(`.claude/rules/promotion-confirmation.md`) now mandates this.

**Tooling note:** ranking + DSR were computed by a throwaway exe rebuilt 4×
(`Variant_ranking` + `Deflated_sharpe` have no committed CLI — open follow-up
to ship a `rank-variants` CLI). Related: [[project_experiment_platform]].