Reviewed SHA: d1ba8ba5cb37cb5b17121f88175568aba8f2cc37

# QC Review — screener-tiebreak-controls (PR #1795)

PR #1795 — `experiment(candidate-ranking): noise-floor control tiebreaks (default-off, diagnostic)`
Branch: `feat/screener-tiebreak-controls` (merged squash → main `8bb0af20`, branch deleted)
Reviewed by: lead-orchestrator GHA run 28472005371 (2026-06-30 run 2)

The full structural and behavioral checklists were delivered as **GitHub PR
review comments** (the QC agents checked out the PR branch, which is now
deleted; the verdicts live on the PR and in the audit JSON). This file
records the verdicts + Reviewed SHA for next-run idempotency.

## Structural QC — APPROVED (PR review id 4603815028)

- H1–H3 (dune build @fmt / build / runtest): all exit 0; 42 tests pass; all
  linters (fn_length, nesting, mli_coverage, fmt, magic-numbers) pass.
- P1–P6: PASS. P6 — the 4 new tests use Matchers correctly (one `assert_that`
  per value, `elements_are` for orderings).
- A1: NA — `screener_ranking` is an analysis library, not a core module
  (Portfolio/Orders/Position/Strategy/Engine).
- A2: PASS — no `analysis/` → `trading/trading/` cross-imports; 3 code files
  touched (screener_ranking.ml/.mli + test_screener.ml).
- A3: PASS — no scope drift; the other 24 files are experiment artifacts/docs.
- experiment-flag-discipline R1/R2/R3: PASS — new modes default-off
  (`candidate_ranking [@sexp.default Alphabetical]`), config-expressed/searchable,
  no default flip (diagnostic/REJECT PR).

## Behavioral QC — APPROVED, quality score 5 (PR review id 4603834563)

- CP1–CP4: PASS — each of the 3 new modes (`Reverse_alphabetical`,
  `Symbol_length`, `Hash_order`) is pinned by a concrete `elements_are`
  ordering test; FNV-1a determinism pinned by a fixture (`[ZZ; AAA; M]`)
  provably distinct from alphabetical and length order.
- W1 (spine) PASS — diff confined to screener ranking + tests + experiment
  artifacts; admission/scoring/cascade untouched. Tiebreak runs after the
  cascade and reorders strictly within equal-score ties.
- C1/C3 PASS — cascade order untouched; tiebreak does not change which
  candidates pass, only ordering among ties.
- R1/R3 + promotion-confirmation PASS — ledger
  `2026-06-30-tiebreak-noise-floor.sexp` records `(verdict Reject)`; FINDINGS
  verdict is distribution-aware and cross-cell-calibrated (informative sorts
  sit inside the arbitrary-control noise band; "best" sort flips by cell =
  variance, not signal). No default flip.

## Overall

overall_qc: APPROVED
quality_score: 5

3-gate merge: CI green (build-and-test + perf-tier1-smoke SUCCESS) +
structural APPROVED + behavioral APPROVED → auto-merged squash → main
`8bb0af20`. Audit: `dev/audit/2026-06-30-screener-tiebreak-controls.json`.
