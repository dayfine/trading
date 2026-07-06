Reviewed SHA: 57ffa6664ecb (behavioral) / 2071c1f983a8 (structural — one commit behind current tip)

# QC — cash-reserve-pct (PR #1867)

Note: reviewed during active human iteration — tip advanced from `2071c1f9` (structural)
to `57ffa666` (behavioral) mid-review. The behavioral finding below is on the **current tip**.

## Structural QC — cash-reserve-pct
Reviewer: qc-structural (SHA 2071c1f9)
Verdict: APPROVED

All hard gates pass: `dune build @fmt`, `dune build`, scoped `dune runtest`
(weinstein/strategy/test 34 OK; backtest/test 8 OK). Structural checklist clean:

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest (scoped) | PASS | 34 + 8 tests OK |
| P1 | Functions ≤ 50 lines | PASS | new `_reserve_reduced_walk_state` = 11 lines |
| P2 | No magic numbers | PASS | |
| P3 | Config completeness | PASS | `cash_reserve_pct : float [@sexp.default 0.0]`, documented in .mli + .ml |
| P4 | Public-symbol export hygiene | PASS | |
| P5 | Internal helpers underscore-prefixed | PASS | |
| P6 | Test-pattern conformance | PASS | no sub-rule violations in either test file |
| A1 | Core module modifications | PASS | changes confined to weinstein/strategy; config additions in-scope |
| A2 | No analysis→trading imports | PASS | |
| A3 | No unnecessary modifications | PASS | |
| R1 | flag-discipline default-off | PASS | `[@sexp.default 0.0]`, 0.0 = prior no-op |
| R2 | flag-discipline searchable-as-axis | PASS | resolves via `Overlay_validator.apply_overrides` |
| R3 | flag-discipline promotion-needs-verdict | NA | no default flip |

Note: structural gates were run on 2071c1f9; the subsequent tip 57ffa666
("move entry-walk state to Screening_notional") is a refactor — CI build-and-test
re-confirms the whole-project build at the current tip.

---

# Behavioral QC — cash-reserve-pct
Reviewer: qc-behavioral (SHA 57ffa666 — current tip)
Verdict: **NEEDS_REWORK**
Quality Score: 3 — Faithful, well-documented default-off sizing dial; no-op, on-behavior
count-flip, exit-exemption, and axis-reachability all pinned. The single gap is a specific
untested `.mli` guard about the reserved-short-sleeve path that, on trace, is inaccurate.

## Spine / flag-discipline
- W1 (spine intact) PASS — buy-only-Stage-2, breakout+volume, stops-below-base, macro/sector
  gates untouched. This is a faithful capital-reserve *sizing dial*, not a spine change.
- W2 (faithful config-expressed dial) PASS. R1/R2/R3 PASS/PASS/NA.
- Domain rows S*/L*/C*/T1–T3 NA (capital/entry-funding knob, not stage/stop/cascade logic); T4 PASS.
- CP2 PASS (every advertised test exists); CP3 PASS (no-op invariant pinned via count-equality).

## NEEDS_REWORK item — CP4 / CP1: untested + inaccurate short-sleeve reserve guard

The `.mli`/`.ml` docstring claims the reserve "is taken off the top-level entry budget exactly
once (in the reserved-short-sleeve path the same reduced budget is split between the long and
short walks, so it is never charged twice)." No test exercises `short_sleeve_fraction > 0`
together with `cash_reserve_pct > 0`. Tracing `entries_from_candidates`:

- `short_budget = portfolio_value * short_sleeve_fraction` is computed from the **full**
  portfolio value, not from the reserve-reduced `spendable`.
- Only `long_cash = max 0 (spendable - short_budget)` consumes the reserve.
- When `spendable < short_budget` (large reserve + large sleeve), `long_cash = 0` but the short
  sleeve still deploys the full `short_budget`, so total deployment `= short_budget > spendable`
  — the reserve is **silently under-honored**, contradicting the docstring's "the same reduced
  budget is split between the long and short walks."

Required fix:
1. Add a combined-knob test asserting total funded notional is reduced by exactly
   `cash_reserve_pct * portfolio_value`, covering both `spendable >= short_budget` and the
   `spendable < short_budget` corner.
2. Reconcile the docstring with the actual/intended semantics (either charge the reserve against
   the combined long+short budget, or update the docstring to describe the long-only reduction).

harness_gap: LINTER_CANDIDATE — a deterministic golden entry-walk scenario with
`short_sleeve_fraction>0` + `cash_reserve_pct>0` would catch this.

## Verdict
NEEDS_REWORK (behavioral) — one real correctness/contract gap; structure and spine are clean.
