---
name: project-candidate-universe-payoff
description: Candidate-universe fixtures are CORRECT at 10.8x compression but only 21% faster — universe size is not what dominates scenario cost; break-even is ~54 re-runs.
metadata: 
  node_type: memory
  type: project
  originSessionId: f38d1024-5259-467e-95cf-9aa2c8fe4ddb
  modified: 2026-08-14T07:48:06.741Z
---

Top-3000 × 2018-2023 payoff run (PR #2319,
`dev/experiments/candidate-universe-payoff-2026-08-13/`), one variable changed
from the 302-symbol acceptance run: universe breadth 302 → 3000.

**Correctness: PASS at a real ratio.** 3000 → **277** symbols, and all six
artefacts (`actual.sexp`, `trades.csv`, `equity_curve.csv`, `trade_audit.sexp`,
`macro_trend.sexp`, `open_positions.csv`) byte-identical. 2,723 dropped symbols
changed nothing. The acceptance run could only show this at 1.04×.

**The finding: compression ≠ payoff.** 10.8× fewer symbols bought **1.26×** less
wall time — 1020s → 808s, a 21% saving. Dropping 91% of the universe removed 21%
of the work, so **universe size is not what dominates a scenario's cost** at a 6y
window. The residual ~808s (simulation over 313 weeks, position management,
warehouse access) is near-invariant to universe size.

**Break-even ≈ 54 runs.** Capture cost 3h09m (11,340s) vs 212s saved per re-run.
A fixture must be re-used ~54 times on the same (window × config family) to pay
for itself. One-off scenario = large net loss; a full ladder sweep (24 cells × 3
salts ≈ 72 runs) wins by ~25%. The baseline is 17 min, not hours — scenarios at
this window were not obviously unaffordable to begin with.

**So the builder's stated motivation — "makes per-mechanism scenarios
affordable" — is NOT established.** If that is the goal, profile the 808s floor;
do not shrink the universe further. Does not generalise to 26y: only universe
size was varied, so do not assume the 21% carries.

Related: [[project_snapshot_format_v2]],
[[feedback_large_n_needs_snapshot_mode]],
[[feedback_container_capacity_scheduling]].
