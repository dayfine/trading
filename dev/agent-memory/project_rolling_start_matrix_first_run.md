---
name: project-rolling-start-matrix-first-run
description: "Start-date edge matrices BOTH regimes (2011-2026 bull n=30 + 2000-2011 bear-decade n=21) — same ~+3pp median edge everywhere, but bear decade chops the left tail (worst −4.9 vs −28pp, DD halved): strategy = distribution compressor"
metadata: 
  node_type: memory
  type: project
  originSessionId: 78c98b7f-b5bb-42f0-abac-d99c79b0a11d
---

**⚠ STALE SEMANTICS (flagged 2026-06-13):** these numbers were measured under
`suppress_warmup_trading=false` (warmup-trades ON), the OLD default. #1566
flipped the default to `true` (suppress) on correctness grounds. The matrix's
**interior** starts (2013/2015/2017…) have WARM warmups (warmup_start =
start−210d sits mid-warehouse, snap floor 2010-06) so the flip BITES — verified
materially: a 2015 interior probe gave OFF 24.9% vs ON 12.6% return (~2×, the
running-start effect, [[project-warmup-trading-running-start]]). Do NOT re-cite
these OFF-semantics numbers as current.

**✅ HONEST RE-RUN COMPLETE (2026-06-14, same surface, suppress=ON default),
`dev/experiments/warmup-matrix-rerun-2026-06-13/ANALYSIS.md`:** median edge
**−2.76 pp/yr** (was +3.2), beat-rate **35.5%** (was 57%), p10 −24.2 (was −16),
worst −49.5 (was −28); CAGR median 8.45%, MaxDD median 35.9%. **The warmup
running-start was ~all the apparent edge** — removing it swung the median ~6pp
negative. Dividend-adjusted (GSPC price-only) honest edge vs total-return SPX
≈ **−4.8 pp/yr → NO bull-regime start-date return edge**, confirming
[[project-index-beating-structural-bar]] cleanly. The +107% max start (2025-01)
is MTM-inflated (realized −21%); all post-2020 starts have deeply negative
realized despite positive MTM ([[project-broad-universe-790-mtm-inflated]]).
Strategic read: long-only profit is NOT recoverable by tuning bull-window long
entries; it's on the short/bear side → motivates the margin/long-short build.
Original (OFF, stale) numbers below for reference:

Rolling-start runner v2 (#1536) first full matrix, 2026-06-11 (preliminary:
pre-policy universe, GSPC price-only benchmark). Trimmed n=30: **median edge
≈ +3.2pp/yr vs GSPC ≈ +1pp vs total-return SPX, 57% starts beat, p10 −16pp,
worst −28pp** → no robust start-date edge on the 2011-2026 bull. Negative-edge
starts cluster 2013-2018 (the gap regime / feature target). All post-2020
starts: MTM CAGR positive but realized return NEGATIVE (2024 start: +49%/yr
MTM vs −38% realized) — recent-start edge is unrealized marks, generalizing
[[project_broad_universe_790_mtm_inflated]].

**Part 2 (same day): 2000-2011 bear-decade matrix (25 starts, trimmed n=21):
median edge +2.96pp (SAME ~+3pp as bull — no CAGR win anywhere, per
[[project_index_beating_structural_bar]]), but worst start −4.9pp (vs −28),
edge IQR 4.9 (vs 17.9), median MaxDD 26% through two −50%+ index crashes →
the strategy is a DISTRIBUTION COMPRESSOR: Stage-4 exits chop the left tail
(pays in bears), winner-touching chops the right (costs in bulls).** Alpha
clusters at post-bear bull-leg dawns (2003-04 starts +9-12pp, mirroring
2011-12). 2006-08 starts: protection without profit (dodged GFC, realized
negative). Regime-conditional confirmation of [[project_barbell_on_stocks]].

Artifacts blocking definitive run: A1 no min-window guard (sub-year starts →
CAGR 2393% poisons raw summary); A2 corrupt per-start summary rows — TWO
specimens now (2023-01-26: MaxDD 190%/underwater 156%; 2009-06-26: CAGR −40%
w/ MaxDD 0.00 + TimeUnderwater 0.00) — fold-summary projection bug, TOP of
the A-list, treat per-start DD columns as suspect until fixed; A3 SPY
bars absent from warehouses (benchmark price-only); A4 rerun after
composition-policy universe artifact. Analysis:
`dev/experiments/rolling-start-matrix-2026-06-11/ANALYSIS.md`. Warehouse
`snap_top3000_2000` (1999-06→2026-04, 3015 syms, verified) lives in container
/tmp — rebuildable via `/tmp/cell-e-top3000-2000-26y.sexp` spec pattern.
