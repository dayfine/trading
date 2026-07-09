# catstop deep WF-CV — findings (2026-07-09)

- **Spec:** `test_data/walk_forward/catstop-deep-2000-2026.sexp` — axis
  `stops_config.catastrophic_stop_pct {0.0, 0.10}` (nested key-path), base
  `sp500-2000-2026-catstop` (catstop 0.10 ON), 26 rolling annual folds,
  2000-2026, 364 basis, CSV mode vs deep `data/` store.
- **Motivation:** catstop never had its own fold-distribution evidence (the
  06-22 arming-speed WF-CV had catstop ON in both arms); the 2026-07-09 P1a
  deep screen showed +15.2pp path-compounded value.

## Parity check PASSED

The `catastrophic_stop_pct=0.10` axis cell is **identical to baseline in all
26 folds** (0 wins, worst_gap 0) — the nested `stops_config.*` key-path
override resolves correctly through `Overlay_validator`. First use of a
nested key-path axis; it works.

## Result: fold-honest, catstop 0.10 is a WASH (insurance with offsetting premium)

Aggregate (26 folds): catstop ON vs OFF — return mean 7.77 vs 7.89 (−0.12pp/yr
premium), Sharpe 0.492 vs 0.494, MaxDD mean 12.11 vs 12.31 (−0.20pp). All
three variants on the Pareto frontier; DSR ≈ tied (0.9973 vs 0.9969). Gate:
FAIL both directions (ties dominate — the stop only fires in 7 of 26 folds).

Per-fold effect of catstop ON (the 7 folds where it fires):

| fold | year | Δreturn (ON−OFF) | ΔMaxDD | read |
|---|---|---|---|---|
| 001 | 2001 | −0.43pp | +0.14 | small whipsaw |
| 002 | 2002 | **+3.15pp** | **−2.66** | PAYS — grinding bear that keeps falling |
| 003 | 2003 | −2.44pp | −0.07 | COSTS — V-recovery year, stopped out of rebounders |
| 008 | 2008 | **+2.11pp** | **−2.49** | PAYS — cascade that keeps falling |
| 011 | 2011 | −0.65pp | 0 | small whipsaw |
| 020 | 2020 | **−5.24pp** | 0 | COSTS — the COVID fast-V; stop fires, market V-recovers |
| 022 | 2022 | +0.34pp | −0.01 | small pay |

Net ≈ −3.2pp over 26y. **The worst folds (2025 fold-025 −16.6%, 2021 fold-021
DD 24.0) are untouched** — catstop does NOT cut the left tail at fold level.

## The why (transferable)

catstop pays when the decline **keeps going** (2002, 2008) and costs when it
**V-recovers** (2003, 2020) — the same continue-vs-recover discrimination
problem as the arming-speed whipsaw (06-22) and the fast-v-min-rate surface
REJECT. A per-position absolute stop keyed to a fast-decline classifier
cannot tell the two apart; only a breadth/A-D-lead style signal claims to
(untested at this seam). Three consequences:

1. **The P1a screen's +15.2pp "distributed deep value" was path-compounding**
   (better 2002/2008 exits compound through the survivor path); independent
   annual folds price the same mechanism at ≈ −0.12pp/yr. Screens on
   compounded paths systematically flatter crash-exit mechanisms — same
   lesson as the armon 2010-single-event correction, one level subtler.
2. **No promotion basis** for catstop=0.10 as a default: mean-neutral, tail
   not cut, gate FAIL. It stays a default-off tail-insurance dial. Its honest
   use-case is preset-level (a trader-preset that accepts −0.12pp/yr for
   −2.5pp DD in grinding-bear years), not a global default.
3. **Feeds P1b directly:** the circuit-breaker design's asymmetric re-entry
   (fast re-entry after fast-V exits) is aimed at exactly the 2020-shaped
   cost; the slow-grind exit at exactly the 2002/2008-shaped pay. This WF-CV
   is the quantified statement of why the breaker must discriminate the two.

## Ledger

`dev/experiments/_ledger/2026-07-09-catstop-deep-wfcv.sexp` — verdict
Reject (promotion); mechanism keeps its default-off axis status.
