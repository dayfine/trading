Reviewed SHA: 20f07fbf55f6702654b32728a98f7cc4d141d774

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | FAIL | Record type definition must be single-line per ocamlformat. Current: multi-line type _scored at lines 120–124 |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests pass (exit 0) |
| P1 | Functions ≤ 50 lines (linter) | PASS | fn_length_linter passed as part of H3 |
| P2 | No magic numbers (linter) | PASS | magic_numbers linter passed as part of H3 |
| P3 | Config completeness | PASS | No new config fields or hardcoded thresholds |
| P4 | Public-symbol export hygiene (linter) | PASS | mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | All internal helpers prefixed with `_` |
| P6 | Tests conform to test-patterns | NA | No test files modified in this PR |
| A1 | Core module modifications | NA | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No new analysis→trading/trading imports | NA | File is in trading/analysis/; no new cross-layer imports |
| A3 | No unnecessary existing-module modifications | PASS | Single file touched; no cross-feature drift |

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### H1: Format check failure — record type needs single-line format
- Finding: `type _scored` definition spans lines 120–124 with each field on its own line; `dune build @fmt` reformats this to a single line
- Location: trading/analysis/data/universe/lib/build_from_individuals.ml, lines 120–124
- Required fix: Reformat record type to single line: `type _scored = { symbol : string; score : float; forward_return : float option }`
- harness_gap: LINTER_CANDIDATE — ocamlformat enforcement via `dune build @fmt` is deterministic; this could be caught automatically in pre-push CI

### Rework verification (SHA 685eea28205e)

Confirmed via `gh pr view 1175 --json files,headRefOid`:
- headRefOid = `685eea28205e0b4b5cb8aaebb886583bed76b5b8`
- files = `trading/analysis/data/universe/lib/build_from_individuals.ml` only (+17/-5)

Re-ran `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && dune build @fmt'` on the detached PR SHA: no diff produced (H1 PASS). `dune build` and `dune runtest analysis/data/universe` both clean (40 tests across 6 suites, all OK). Structural checklist now PASS overall.

---

# Behavioral QC — perf-universe-individuals-drop-bars
Date: 2026-05-17
Reviewer: qc-behavioral
Reviewed SHA: 685eea28205e0b4b5cb8aaebb886583bed76b5b8

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | This PR modifies an `.ml` only (private `_scored` type); no `.mli` changes. The public surface (`build`, `config`, `default_config`) is unchanged. |
| CP2 | Each claim in PR body "Test plan" / "Test coverage" sections has a corresponding test in the committed test file | PASS | PR body claims: (1) `dune runtest analysis/data/universe` passes — verified, 40 tests across 6 suites all OK; (2) covers `aggregate_period_return` mean-of-forward-returns — pinned by `test_aggregate_period_return_matches_forward_window` (test_build_from_individuals.ml:337-344, asserts exact 0.20 via `float_equal ~epsilon:0.001`); (3) covers inactive/synthetic-filter regressions — pinned by `test_inactive_symbol_is_filtered`, `test_non_equity_like_is_filtered`. Minor wording discrepancy: PR body says "13 cases" but the file has 10 cases; "13" is consistent with neither the file in isolation nor any obvious 13-test subset. Not a behavioral defect (all named regressions are covered) — flag as wording cleanup, does not warrant NEEDS_REWORK. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | This refactor's "output unchanged" claim is pinned by `test_determinism_two_builds_identical` (test_build_from_individuals.ml:379-384, asserts `s2 (equal_to s1)` — full snapshot equality, not size). The aggregate-return test pins the exact float value. Both pin identity-level invariants, not cardinality. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | The new docstring on `_scored` (build_from_individuals.ml:110-119) claims: "Both the dollar-volume score (trailing window) and the forward-return (forward window) read disjoint slices of the same [bars] list". Verified by code inspection: `_in_trailing_window` filters to `[date - trailing_window_days, date]` (lines 65-67); `_forward_return` reads `_first_on_or_after ~date` and `_last_on_or_before ~date:(date + 365d)` (lines 88-104). The only shared boundary is `date` itself, but `_forward_return` requires `p_end.date > p_start.date` (strict, line 102) so a bar at exactly `date` cannot affect both score and forward return. The eager-computation invariant ("forward_return is deterministic given the same bars used for score") is pinned by `test_determinism_two_builds_identical` plus the exact-value `test_aggregate_period_return_matches_forward_window`. |

## Behavioral Checklist

Pure infra / perf refactor PR; domain checklist (S*/L*/C*/T*) not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". No Weinstein domain logic, no core-module modifications.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core-module modification. qc-structural marked A1 NA. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure perf refactor in `trading/analysis/data/universe/lib/`; no domain logic touched. |

## Additional correctness reasoning

The refactor's semantic invariant: `_aggregate_period_return kept` must produce the same value before and after the change for the same input `kept` and `date`.

Before: `List.filter_map kept ~f:(fun s -> _forward_return ~date s.bars)` — reads `bars` per kept symbol, computes forward-return.
After: `List.filter_map kept ~f:(fun s -> s.forward_return)` — reads precomputed value populated in `_score_symbol`.

For each symbol that survives ranking + take:
- `_score_symbol` populates `forward_return = _forward_return ~date bars` where `bars = BR.read_bars ~bars_root:config.bars_root symbol` (build_from_individuals_pr.ml:123-130).
- `BR.read_bars` is invoked once per symbol with the same arguments in both implementations.
- `_forward_return` is a pure function of `(date, bars)`.

Therefore `s.forward_return` for any kept `s` is byte-identical to the old `_forward_return ~date s.bars`. Iteration order is preserved (kept = `List.take ranked size` in both; ranked = `_rank_desc scored` with deterministic comparator). The `List.filter_map` + `List.fold ~init:0.0 ~f:(+.)` sequence is identical, so float-rounding order is unchanged. Output is exactly equivalent. ✓

The `_scored` record is private (no `.mli` exposure) and used only within `build_from_individuals.ml` — verified via `grep -rn "_scored\|\.bars" trading/analysis/data/universe/`. No downstream consumer of the dropped `bars` field. ✓

## Quality Score

4 — Clean, well-motivated perf refactor with a thorough docstring explaining the memory invariant. The eager-compute-then-drop pattern is exactly the right shape for this scale. Minor PR-body wording slip ("13 cases" vs actual 10) is the only nit.

## Verdict

APPROVED
