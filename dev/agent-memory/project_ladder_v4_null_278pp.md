---
name: project-ladder-v4-null-278pp
description: "The 26y/top-3000 noise floor is ~278pp of return, measured from ladder-v4's own duplicate cells 07/08 — only the volconf reject survives it"
metadata: 
  node_type: memory
  type: project
  originSessionId: d7d8f2bb-6b58-4fde-8e01-c50e796e5faa
  modified: 2026-08-12T09:23:43.385Z
---

Ladder-v4 cells **07 (`maxstop50-diag`) and 08 (`sizedown50-diag`) are the same
configuration expressed two ways.** `Size_down` moves the drop threshold to
`stop_width_size_down_max_pct` and leaves sizing untouched (fixed-risk sizing
keys off the installed stop either way), so `Size_down×0.50` admits and sizes
exactly like `Drop_over_max×0.50`; the flag only sets an audit tag. Verified:
at 500/5y on the fixed build the two cells' `actual.sexp` are byte-identical.

**At 26y/top-3000 they returned 726.24 vs 448.08 — 278pp apart** (Sharpe 0.612
vs 0.390; maxDD 34.72 vs 42.49; trades 1442 vs 1463). That is a free, full-scale
measurement of the pre-#2279 nondeterminism noise floor
([[project-backtest-nondeterminism-intraday-path]]).

**Consequence:** every ladder-v4 Stage-A delta except volume-confirm's is
*inside* that null. Cell 09 nearfloor (+326pp over cell 00) is 1.17× the null —
not a detection at n=1 — and a deterministic 24-cell re-run at 500/5y
**reverses** it (38.64 vs cell 00's 112.28, i.e. worst-but-one rather than
best); cell 01 anchor-w8 reverses too. Only cell 10 volconf survives, on
mechanism signature as well as magnitude (2.8× trades, holding 47.8d → 8.4d,
sign flip).

**How to apply:** do not carry "nearfloor = 670.0, the best lever in the
program" forward. Nearfloor remains a coherent book-faithful stop-placement dial
with a verified mechanism (`stop_floor_kind` 867/558 → 108/1158 Buffer_fallback/
Support_floor) and deserves a real WF-CV surface on the fixed build — but it has
no established return edge.

**Reusable practice:** put a deliberate duplicate cell in every sweep. 07/08
were an accident and became the most informative cells in the run. One repeated
cell costs 1/24 of the budget and is the only thing that says which deltas are
real. See [[feedback-run-the-null-control-first]].

Writeup: `dev/notes/ladder-v4-read-2026-08-12.md`.
