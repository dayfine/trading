Reviewed SHA: c37ffbacd9d26d2c39b82aca661215ca381fdc72

## Structural QC — readme-toplines (PR #1617) — RE-REVIEW after behavioral rework

### Hard Deterministic Gates

| Gate | Status | Exit Code | Notes |
|------|--------|-----------|-------|
| `dune build @fmt` | PASS | 0 | Format check clean |
| `dune build` | PASS | 0 | Build successful |
| `dune runtest` | PASS | 0 | All tests pass; nesting linter: OK (3475 functions scanned, all within limits) |

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | |
| H2 | dune build | PASS | |
| H3 | dune runtest | PASS | 13 coverage tests + 5 readme_block tests = 18 total; nesting linter clean; all pass at tip SHA |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | PASS | fn_length_linter passed as part of H3; coverage.ml is 46 lines, all functions well under 50-line limit |
| P2 | No magic numbers — covered by language-specific linter | PASS | linter_magic_numbers.sh passed; no magic numbers in rework |
| P3 | All configurable thresholds/periods/weights in config record | PASS | Module is reporting-only; no new configurables; all parameters flow from callers |
| P4 | Public-symbol export hygiene — covered by language-specific linter | PASS | linter_mli_coverage passed; coverage.mli documents all public functions |
| P5 | Internal helpers prefixed per project convention | PASS | Internal helpers like `let entry` and `let exit_` are local bindings (not top-level), so `_` prefix not required per rule |
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS | test_coverage.ml: (1) opens Matchers, (2) all 13 assertions via `assert_that` + matchers, (3) no `List.exists...equal_to` patterns, (4) no dropped assertions; three new tests added (test_bah_single_bar_window, test_inclusive_days_end_before_start, renamed test_bah_unpriceable_window → test_bah_empty_window) all follow pattern |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS | No modifications to core modules; changes only to readme_toplines feature module |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | NA | No dune files changed in rework; A2 status unchanged from prior review |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only three files modified: coverage.ml, coverage.mli, test_coverage.ml — all within readme_toplines feature scope |

## Verdict

**APPROVED**

All hard gates pass; all structural checks clean. The rework commit (c37ffbac) addresses the behavioral CP1/CP4 findings by: (1) tightening the `bah_total_return_pct` guard from `Date.(<=)` to `Date.(<)` to reject single-bar windows as unpriceable, (2) adding test_bah_single_bar_window to pin the fixed behavior, (3) adding test_inclusive_days_end_before_start to pin the prior-unpinned branch, and (4) clarifying docstrings in .mli/.ml. No structural issues introduced; no format/build/test regressions.

---

## Behavioral QC — readme-toplines (PR #1617)

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | FAIL | Most claims pinned (see mapping below). One docstring claim is BOTH unpinned AND false: `coverage.mli` `bah_total_return_pct` states "Returns [Float.nan] when ... only one bar". The implementation returns **0.0** for a single in-window bar (entry==exit, `entry_date <= exit_date` holds, `entry_close > 0.0` → `total_return_pct ~initial:c ~final:c` = 0.0). No test pins the single-bar case; `test_bah_unpriceable_window` only exercises the *empty-window* path (its own comment at test_coverage.ml:88-90 admits "still entry=exit -> 0.0; but an empty window yields nan"). Secondary minor gap: `inclusive_days` `end_date < start_date -> 0` branch (coverage.ml:43) is unpinned (only the main path and single-day=1 are tested). |
| CP2 | Each claim in PR body "Test plan" has a corresponding committed test | PASS | All nine PR-body Test-plan claims map to a committed, passing test: intersection staggered (test_intersection_staggered_starts/ends), disjoint (test_intersection_disjoint), empty (test_intersection_empty_list), total-return (test_total_return_positive/negative/nonpositive_base), BAH math (test_bah_uses_first_and_last_in_window, test_bah_unpriceable_window), Readme_block insert/replace/idempotency/raise. 16 tests, all green at tip SHA. |
| CP3 | Pass-through / identity / invariant tests pin identity (whole-value equality), not just size_is | PASS | The idempotency invariant (`upsert ~document:(upsert …) ~block = upsert … ~block`) is pinned by `test_upsert_idempotent` with `assert_that twice (equal_to once)` — whole-string equality, not a substring/size check. (The replace/append tests use substring checks, but those are existence assertions, not identity invariants, so CP3 does not require whole-value equality there.) |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | FAIL | The `bah_total_return_pct` docstring names the "only one bar" guard explicitly ("fewer than two usable closes span it ... or only one bar") but (a) no test exercises the single-bar scenario and (b) the code does not actually guard it (returns 0.0, not nan). Same root finding as CP1. The empty-list/disjoint guards on `period_intersection` and the `<= 0.0` base guard on `total_return_pct` ARE pinned (test_intersection_empty_list, test_intersection_disjoint, test_total_return_nonpositive_base). |

### .mli claim → test mapping (CP1 detail)

- `period_intersection` intersection (max-first/min-last) → test_intersection_staggered_starts, test_intersection_staggered_ends ✓
- `period_intersection` empty list → None → test_intersection_empty_list ✓
- `period_intersection` disjoint → None → test_intersection_disjoint ✓
- `total_return_pct` math → test_total_return_positive/negative ✓
- `total_return_pct` non-positive base → nan → test_total_return_nonpositive_base ✓
- `bah_total_return_pct` date-based entry/exit selection (unsorted, before/after-window ignored) → test_bah_uses_first_and_last_in_window ✓
- `bah_total_return_pct` empty-window → nan → test_bah_unpriceable_window ✓
- `bah_total_return_pct` "only one bar → nan" → **NO TEST + FALSE claim** ✗ (see CP1/CP4)
- `inclusive_days` single-day=1, span=31 → test_inclusive_days, test_inclusive_days_span ✓
- `inclusive_days` `end < start → 0` → **NO TEST** ✗ (minor)
- `Readme_block.render` wraps in markers → test_render_wraps_in_markers ✓
- `Readme_block.upsert` replace / append / idempotent / raise-on-unterminated → test_upsert_replaces_region / appends_when_absent / idempotent / raises_on_unterminated ✓

### Behavioral Checklist (domain S*/L*/C*/T* rows)

NA — Reporting-only module; consumes the strategy via `Backtest.Runner.run_backtest` but adds no Weinstein domain logic (no stage definitions, stop machine, or screener cascade). Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire S*/L*/C*/T*/A1 block is NA.

### Rework-commit drift check

The rework commit (75c9e567) touched only `readme_block.ml` and `toplines_runner.ml` — no `.mli`, no test files. The 16-test suite passes at the tip SHA (11 coverage + 5 readme_block, verified `dune runtest --force`), so the same outcomes are still pinned. No behavioral drift introduced by the nesting refactor.

## Quality Score

3 — Clean, well-documented reporting module with strong test coverage on the core paths; one docstring contract (`bah_total_return_pct` single-bar → nan) is both unpinned and contradicted by the implementation, which the test author noticed but routed around rather than fixing.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP1/CP4: `bah_total_return_pct` "only one bar → nan" docstring claim is false and unpinned
- Finding: `coverage.mli` (lines 49-51) documents that `bah_total_return_pct` "Returns [Float.nan] when the window cannot be priced: fewer than two usable closes span it (empty series, all dates outside the window, **or only one bar**)". The implementation (coverage.ml:27-40) returns **0.0** for a single in-window bar: entry and exit both resolve to the same pair, `entry_date <= exit_date` holds (equal), `entry_close > 0.0` holds, so it computes `total_return_pct ~initial:c ~final:c = 0.0`. The committed test `test_bah_unpriceable_window` only exercises the empty-window path (dates 2030-2031 with a single 1999 bar → no in-window bars → nan); its own comment (test_coverage.ml:88-90) explicitly acknowledges the single-bar case yields 0.0, not nan, and then tests the other path.
- Location: `trading/trading/backtest/readme_toplines/lib/coverage.mli:49-51`; `coverage.ml:27-40`; gap visible at `test/test_coverage.ml:88-96`.
- Authority: the module's own `.mli` docstring (the primary contract for this infra module per `.claude/rules/qc-behavioral-authority.md` §"For infrastructure...").
- Required fix: reconcile doc and code, then pin it. Either (a) tighten the implementation to return `Float.nan` when `entry_date = exit_date` (i.e. truly "fewer than two distinct usable closes"), and add a test asserting single-in-window-bar → nan; or (b) correct the docstring to state a single in-window bar yields 0.0 (entry==exit), and add a test pinning that 0.0. Either path must add a test exercising the single-bar boundary so the contract is pinned.
- harness_gap: LINTER_CANDIDATE — a golden unit test with a one-element in-window `close_series` and a fixed expected value (nan or 0.0) catches this deterministically; no inferential judgment required.

### CP1 (minor): `inclusive_days` reversed-range branch unpinned
- Finding: `coverage.mli:59-63` documents `inclusive_days` "Returns [0] when [end_date < start_date]". The branch exists (coverage.ml:43) but no test exercises it (only single-day=1 and span=31 are pinned).
- Location: `trading/trading/backtest/readme_toplines/lib/coverage.ml:43`; `coverage.mli:62-63`.
- Authority: module `.mli` docstring.
- Required fix: add one assertion `inclusive_days ~start_date:(later) ~end_date:(earlier)` → `equal_to 0`. Cheap; bundle with the CP1/CP4 fix.
- harness_gap: LINTER_CANDIDATE — deterministic golden unit test.

---

## Behavioral Re-review (c37ffbac)

Re-review of PR #1617 after the rework addressing the prior CP1/CP4 + CP1-minor findings. Structural QC re-approved at this tip.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | The previously-false claim is reconciled. `coverage.mli:49-52` now documents single-bar (entry==exit, "zero-span, unpriceable window") → `Float.nan`, and `coverage.ml:38` enforces it with `Date.( < ) entry_date exit_date` (was `<=`). `test_bah_single_bar_window` (test_coverage.ml:101-107) pins it: window 1999-01-01..1999-12-31 with a single bar at 1999-06-15 (a real in-range bar yielding entry==exit) → asserts `Float.is_nan` — non-vacuous. The `inclusive_days` `end<start → 0` branch is now pinned by `test_inclusive_days_end_before_start` (lines 122-126). All other .mli claims remain pinned (mapping in the prior section). |
| CP2 | Each claim in PR body "Test plan" has a corresponding committed test | PASS | Every Test-plan category named in the PR body maps to a committed, passing test (intersection staggered/disjoint/empty, total-return, BAH math, Readme_block insert/replace/idempotency/raise). No advertised test is missing. The body's count ("16 tests") is now stale-low — the rework raised the suite to 18 (13 coverage + 5 readme_block); an undercount is a superset, not a CP2 violation (CP2 FAILs only on a claimed-but-absent test). Minor accuracy nit, not blocking. |
| CP3 | Pass-through / identity / invariant tests pin identity (whole-value equality), not just size_is | PASS | Unchanged from prior pass: idempotency invariant pinned by whole-string `equal_to` in `test_upsert_idempotent`. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | The single-bar guard (now real, `Date.( < )`) is exercised by `test_bah_single_bar_window`. The empty-window guard remains pinned by `test_bah_empty_window` (renamed from `test_bah_unpriceable_window`; the stale comment documenting the unfixed mismatch was removed). Empty-list/disjoint guards on `period_intersection` and the `<=0.0` base guard remain pinned. |

### Verification at tip

- `coverage.ml:38` guard is `Date.( < ) entry_date exit_date` — code and `coverage.mli:49-52` now AGREE: single in-window bar → `Float.nan`.
- `dune runtest trading/backtest/readme_toplines/test/` (in-container, `--force`): `test_coverage.exe` → **13 tests, OK**; `test_readme_block.exe` → 5 tests, OK. All green at c37ffbac.
- Four README top-line numbers unaffected: the pinned period is **1998-12-22 → 2026-06-12** (many-bar window, entry strictly before exit by ~27.5y). The `< vs <=` boundary change only affects the degenerate single-bar case, which cannot occur over this window. README block numbers (+888.9% / +1132.4% / +408.0% / +528.9%) unchanged.

### Behavioral Checklist (domain S*/L*/C*/T*/A1 rows)

NA — Reporting-only module; no Weinstein domain logic added (no stage definitions, stop machine, or screener cascade). Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire S*/L*/C*/T*/A1 block is NA.

## Quality Score (re-review)

4 — Prior CP1/CP4 + CP1-minor findings fully resolved via path (a): code reconciled to the docstring (nan on zero-span window), both boundary branches now pinned with non-vacuous tests, stale comment removed. Only residual is a cosmetic stale test-count in the PR body (16 vs 18), which is non-blocking.

## Verdict (re-review)

APPROVED
