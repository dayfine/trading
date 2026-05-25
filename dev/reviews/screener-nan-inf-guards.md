Reviewed SHA: f831b4ea202190f873c1b57f60ab0c409e56550b

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | All tests pass, including linters (fn_length, magic_numbers, nesting, etc.) |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter passed as part of H3 |
| P2 | No magic numbers — covered by language-specific linter | PASS | linter_magic_numbers passed as part of H3 |
| P3 | All configurable thresholds/periods/weights in config record | PASS | No new tunable constants added; only defensive guards for existing values |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | mli_coverage linter passed as part of H3 |
| P5 | Internal helpers prefixed per convention | PASS | All modified internal helpers already use `_` prefix (e.g., `_bucket_idx`, `_bucket_idx_below`) |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No test files modified in this PR |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No core modules modified; changes confined to `analysis/weinstein/` layer |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception surface | PASS | No dune files modified; no new cross-layer dependencies introduced |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR scope contains exactly 3 files per `gh pr view 1309 --json files`: resistance.ml, support.ml, volume.ml |

## Verdict

APPROVED

## Summary

This PR mirrors the NaN/inf guard fix from #1307 (portfolio_risk) into the screener analysis path. The fix addresses a v7 sweep crash root cause where degenerate band_size = 0 (from ATR or bollinger band calculations) or NaN price inputs would cause `Int.of_float inf` to crash.

**Changes:**
- **resistance.ml (_bucket_idx)**: Added `Float.is_finite` guard before `Int.of_float`; returns `Int.min_value` on non-finite input to yield a deeply-negative bucket that the positive-bucket filter drops naturally.
- **support.ml (_bucket_idx_below)**: Mirrored the same guard with explanation comment citing the resistance.ml path.
- **volume.ml (_result_of_volumes)**: Extended existing zero-check with guards for both `avg_vol` and `event_volume_f` to catch NaN/inf before division.

All changes are defensive (guard statements only, no logic changes). Code style, naming conventions, and test coverage remain consistent with existing patterns. Build, format, and test suite all pass cleanly.

---

# Behavioral QC — screener-nan-inf-guards
Date: 2026-05-25
Reviewer: qc-behavioral
PR: #1309

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No `.mli` files added or modified in this PR; the three module signatures are unchanged. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | NA | The PR body's "Test plan" lists only (a) `dune build` (verified by structural H2) and (b) a manual ops action ("v7 sweep attempt 4 launched 2026-05-25 with this binary"). No claim is made that a unit test was added or that an existing test pins the new guard behaviour. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | No pass-through / identity tests added or claimed. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | The new docstring in `resistance.ml` lines 97–100 makes an explicit, falsifiable behavioural claim: "Returning Int.min_value here yields a deeply-negative bucket index that the callers' positive-bucket filter drops naturally." Same claim mirrored in `support.ml` lines 32–33 and `volume.ml` lines 95–99 (`avg_vol` / `event_volume_f` non-finite → `None`). No test in `test_resistance.ml`, `test_support.ml`, or `test_volume.ml` exercises any of the three guarded scenarios: `band_size = 0.0`, `Float.nan` high/low, `Float.infinity` volume. Greps confirm zero `nan` / `inf` / `is_finite` / `min_value` references across all three test files. The guards are real fixes for an observed v7 sweep crash, but the implementation is unpinned — a future refactor (e.g. inlining `_bucket_idx`, replacing `Int.min_value` with a different sentinel) could silently regress the crash fix and no test would catch it. |

## Behavioral Checklist

Pure defensive infra fix; no Weinstein domain rule changed. All Weinstein-specific rows (A1, S*/L*/C*/T*) are NA — see authority file §"When to skip this file entirely".

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | qc-structural did not flag A1; no core module touched. |
| S1–S6 | Stage definitions / buy criteria | NA | Defensive guard only; no stage logic changed. |
| L1–L4 | Stop-loss rules | NA | Stops not in this feature. |
| C1–C3 | Screener cascade / macro / sector rules | NA | The guards live inside `_bucket_idx` / `_result_of_volumes` — pure helper functions whose contracts (resistance grading, support grading, volume confirmation classification) are unchanged for all finite inputs. No cascade ordering, macro gate, or sector RS logic touched. |
| T1–T4 | Test coverage of domain outcomes | NA | No test files modified; existing domain-outcome tests still pass per structural H3. Test-presence for the new guard claim is captured by CP4 above (the contract-pinning rubric, not a domain-outcome rubric). |

## Quality Score

3 — Defensive guard is correct and the callers' positive-bucket filter genuinely absorbs `Int.min_value` (verified at resistance.ml:145 and support.ml:55); the volume guard correctly extends the existing `avg_vol = 0.0` short-circuit. However, the new code makes an explicit, testable claim that a future refactor could silently regress — three ~5-line unit tests (one per module: `band_size = 0.0` does not raise; `event_volume_f = Float.nan` returns `None`) would have pinned the behaviour deterministically. Below "Acceptable" because the unpinned-guard pattern is exactly what the qc-behavioral protocol was designed to catch.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP4: Guard claims in docstrings are not pinned by tests
- Finding: All three modified files contain new docstrings that make explicit, falsifiable claims about how non-finite inputs are handled (`Int.min_value` sentinel; `None` from volume). None of the three test files exercise any of these guarded-against scenarios. The guard could be removed, inverted, or have its sentinel changed (e.g. to `0` instead of `Int.min_value`) and the test suite would still pass — yet the v7 sweep crash would silently return.
- Location:
  - `trading/analysis/weinstein/resistance/lib/resistance.ml` lines 96–101 (claim) vs `trading/analysis/weinstein/resistance/test/test_resistance.ml` (no NaN/inf coverage)
  - `trading/analysis/weinstein/support/lib/support.ml` lines 32–34 (claim) vs `trading/analysis/weinstein/support/test/test_support.ml` (no NaN/inf coverage)
  - `trading/analysis/weinstein/volume/lib/volume.ml` lines 95–99 (claim) vs `trading/analysis/weinstein/volume/test/test_volume.ml` (no NaN/inf coverage)
- Authority: `.claude/agents/qc-behavioral.md` §"Contract Pinning Checklist" CP4 — "Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario." Also `.claude/rules/code-health-discipline.md` §"What TO do" — fixes should not be deferred indefinitely without a tracking issue + owner.
- Required fix: Add one minimal test per module pinning the guard behaviour. Suggested shape (each ~5 lines):
  - `test_resistance.ml`: call `analyze` with `breakout_price = 0.0` (forces `band_size = 0.0`) and a non-empty `bars` list; assert no exception and that `zones_above = []` (deeply-negative buckets filtered).
  - `test_support.ml`: same shape with `breakdown_price = 0.0`; assert no exception, result returned.
  - `test_volume.ml`: build callbacks where `get_volume` returns `Some Float.nan` for the event bar; assert `analyze_breakout_with_callbacks` returns `None`. Optionally a second case with non-finite prior volumes.
- harness_gap: LINTER_CANDIDATE — these are deterministic golden-scenario tests with fully-known input and output; they fit cleanly into the existing OUnit2 + Matchers test pattern. No inferential judgment needed.

### Notes for reworker
- The structural verdict (APPROVED) and the underlying fix (correct sentinel choice, correct guard placement, mirror of merged #1307 pattern) are sound; this rework is narrowly about pinning the new behaviour, not about changing it.
- After adding the three tests, no further structural QC pass is required — the diff will only add lines under `test/` directories.
