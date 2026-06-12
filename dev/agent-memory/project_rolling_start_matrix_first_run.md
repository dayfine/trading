---
name: project-rolling-start-matrix-first-run
description: "First full start-date edge matrix (33 starts, top-3000-2011) — no robust edge vs SPX on 2011-2026 bull; gap = 2013-2018 starts; recent MTM edge is unrealized; dot-com smoke promising"
metadata: 
  node_type: memory
  type: project
  originSessionId: 78c98b7f-b5bb-42f0-abac-d99c79b0a11d
---

Rolling-start runner v2 (#1536) first full matrix, 2026-06-11 (preliminary:
pre-policy universe, GSPC price-only benchmark). Trimmed n=30: **median edge
≈ +3.2pp/yr vs GSPC ≈ +1pp vs total-return SPX, 57% starts beat, p10 −16pp,
worst −28pp** → no robust start-date edge on the 2011-2026 bull. Negative-edge
starts cluster 2013-2018 (the gap regime / feature target). All post-2020
starts: MTM CAGR positive but realized return NEGATIVE (2024 start: +49%/yr
MTM vs −38% realized) — recent-start edge is unrealized marks, generalizing
[[project_broad_universe_790_mtm_inflated]]. Dot-com smoke (n=2 on new
snap_top3000_2000 warehouse, 2000-2005): +13/+27pp edge, MaxDD 13-23% — first
bear-regime read, promising, full 2000 matrix is the next big run.

Artifacts blocking definitive run: A1 no min-window guard (sub-year starts →
CAGR 2393% poisons raw summary); A2 impossible DD row (2023-01-26 MaxDD 190%,
underwater 156% — long-only NAV can't go negative; runner/metric bug); A3 SPY
bars absent from warehouses (benchmark price-only); A4 rerun after
composition-policy universe artifact. Analysis:
`dev/experiments/rolling-start-matrix-2026-06-11/ANALYSIS.md`. Warehouse
`snap_top3000_2000` (1999-06→2026-04, 3015 syms, verified) lives in container
/tmp — rebuildable via `/tmp/cell-e-top3000-2000-26y.sexp` spec pattern.
