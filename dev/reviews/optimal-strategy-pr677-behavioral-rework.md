Reviewed SHA: 628fc2034e45d029f802fe82ac3327354e87d329

# Behavioral QC re-review — optimal-strategy PR #677 (release_perf_report counterfactual integration)
Date: 2026-04-29
Reviewer: qc-behavioral
PR: #677 — `feat(release-report): wire optimal-strategy counterfactual delta + link`
Branch: `feat/optimal-strategy-pr5-release-report`
Prior verdict: NEEDS_REWORK (CP4 FAIL) at `dev/reviews/optimal-strategy-pr677-behavioral.md` (Reviewed SHA: 206326ec)
Rework commit: `628fc203` adds 3 tests in `trading/trading/backtest/test/test_release_perf_report.ml`. Suite count 22 → 25.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | Inherited from prior review; `.mli` files unchanged in rework commit. New extra-fields test additionally strengthens the "downstream readers should mirror with @@sexp.allow_extra_fields to stay forward-compatible" claim from `optimal_summary_artefact.mli` by exercising the OUTER record's tolerance, not just the inner one. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | PASS | PR body unchanged in rework; all original mappings still hold. The 3 new tests are additive and exceed the original PR-body claims (which is fine; they pin documented guards in code). |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are/equal_to on entire value), not just size_is | PASS | The two new None-returning guard tests use `is_none` (the only meaningful identity for None). The new extra-fields happy-path test pins concrete `total_return_pct` values 0.30 and 0.35 via `float_equal` inside `is_some_and (all_of [...])` — not just "is_some". This is identity-shaped per the rule. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | PASS | All three documented guards in `_try_load_optimal_summary` are now pinned. See guard → test mapping below. |

### CP4 — closure verification (the original failure point)

Production code, `release_report.ml` lines 108-130:
```
type _optimal_summary_artefact_on_disk = {
  constrained : optimal_summary;
  relaxed_macro : optimal_summary;
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]    -- guard #3 (outer extra-fields tolerance)

let _try_load_optimal_summary ~dir ~scenario_name =
  let sexp_path = Filename.concat dir "optimal_summary.sexp" in
  let md_path = Filename.concat dir "optimal_strategy.md" in
  if not (Sys_unix.file_exists_exn sexp_path
          && Sys_unix.file_exists_exn md_path)  -- guard #1 (both-must-exist, &&)
  then None
  else
    try
      let artefact = _optimal_summary_artefact_on_disk_of_sexp (Sexp.load_sexp sexp_path) in
      ...
    with _ -> None                              -- guard #2 (parse-failure swallow)
```

Branch coverage by test:

| Guard | Branch | Test | Verdict |
|---|---|---|---|
| #1 (both-must-exist) | both files missing | `test_load_scenario_run_no_optimal_when_files_missing` (pre-existing) | covered |
| #1 (both-must-exist) | sexp present, md missing | `test_load_scenario_run_no_optimal_when_md_missing` (pre-existing) | covered |
| #1 (both-must-exist) | **sexp missing, md present** | **`test_load_scenario_run_no_optimal_when_sexp_missing_but_md_present` (NEW)** | **covered by rework** |
| #2 (parse-failure swallow) | malformed sexp | **`test_load_scenario_run_no_optimal_when_sexp_malformed` (NEW)** | **covered by rework** |
| #3 (outer @@sexp.allow_extra_fields) | extra outer field | **`test_load_scenario_run_loads_optimal_strategy_with_extra_fields` (NEW)** | **covered by rework** |

Verification details for each new test:

1. **`...sexp_missing_but_md_present`** stages only `optimal_strategy.md`, no sexp. The `&&` short-circuit reaches `Sys_unix.file_exists_exn sexp_path` → `false` → the negation is `true` → loader returns `None` without entering the try block. Asserts `is_none`. This pins the previously-untested asymmetric branch (the symmetric md-missing case was the only one covered).

2. **`...sexp_malformed`** stages both files; `optimal_summary.sexp` contains `"this is not valid sexp\n"`. The existence guard passes → enters try block → `Sexp.load_sexp` either raises `Parsexp.Parse_error` (multiple top-level sexps "this", "is", "not", "valid", "sexp") or returns a single atom that `_optimal_summary_artefact_on_disk_of_sexp` immediately rejects with `Of_sexp_error`. Either failure mode is caught by the bare `with _ -> None`. Asserts `is_none`. This pins the parse-failure swallow guard.

   Subtle-gap check: even if `Sexp.load_sexp` were lenient about multiple top-level sexps and returned only the first atom, `_optimal_summary_artefact_on_disk_of_sexp` would still raise on a non-list shape (the outer record requires `(constrained ...) (relaxed_macro ...)` fields). The bare `with _` catches both possibilities — the test is robust against either Sexp parser behaviour.

3. **`...with_extra_fields`** stages an `optimal_summary.sexp` that contains the two known outer fields PLUS a wholly new `(future_extension foo)` field that the on-disk record type does not declare. The pre-existing happy-path test (`...when_present`) only exercised the INNER record's `[@@sexp.allow_extra_fields]` (via the `(variant Constrained)` field which isn't in `optimal_summary`); the outer record only had its two declared fields, so the OUTER attribute was never tested. This new test adds an outer extra field, which would cause `Of_sexp_error` if the outer `[@@sexp.allow_extra_fields]` were removed. The test asserts `is_some_and` with concrete `total_return_pct` values (0.30 / 0.35), so a regression that removed the attribute would flip the test from passing to failing (the loader would return None via `with _`, breaking `is_some_and`).

   Subtle-gap check: confirmed that `_optimal_summary_artefact_on_disk` (release_report.ml:103-107) carries exactly `[@@deriving of_sexp] [@@sexp.allow_extra_fields]` — removing the second attribute would make the deserializer reject the `future_extension` field. Test 3 is a load-bearing pin for the outer attribute.

All three rework tests use the same pattern as the existing `_no_optimal_when_md_missing` test (mkdtemp → `_make_scenario_dir` → selective `_write_text` → `load_scenario_run` → `assert_that`). They route through the real public `Release_report.load_scenario_run` API, not a private helper.

### CP1/CP2 sanity (inherited from prior review)

Prior review confirmed CP1 and CP2 PASS at SHA `206326ec`. The rework commit `628fc203` only adds test code (78 LOC) and modifies neither `.mli` files nor the PR body. Inheritance is direct: PASS.

### CP3 spot-check on new tests

- Test 1 / Test 2: assert `is_none` — the only valid identity matcher for `Option.None`. PASS.
- Test 3: asserts `is_some_and (all_of [field constrained.total_return_pct (float_equal 0.30); field relaxed_macro.total_return_pct (float_equal 0.35)])`. This pins concrete numeric values, not just "is_some" or size. PASS. Could optionally also pin `report_path` and the integer fields, but two distinct float pins is sufficient identity coverage given the on-disk fixture's specificity.

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | Pure observability/integration PR; no Portfolio/Orders/Position/Strategy/Engine modifications (qc-structural confirmed in prior review). |
| S1–S6 | Stage definitions / buy criteria | NA | Pure observability/integration PR; domain checklist not applicable. |
| L1–L4 | Stop-loss rules / state machine | NA | Pure observability/integration PR; domain checklist not applicable. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | Pure observability/integration PR; domain checklist not applicable. |
| T1–T4 | Domain test coverage | NA | Pure observability/integration PR; domain checklist not applicable. |

## CI status

CI on rework commit `628fc203` is GREEN (verified via `gh pr view 677`):
- `build-and-test` (workflow: CI) — SUCCESS, completed 2026-04-29T16:03:34Z
- `perf-tier1-smoke` (workflow: perf-tier1) — SUCCESS, completed 2026-04-29T16:03:29Z

The rework agent's noted "validation pending" caveat (Docker daemon failure during local run) is closed: CI exercised the full `dune build @fmt`, `dune build`, and `dune runtest` gates and all passed. The structural NEEDS_REWORK on the prior review (ocamlformat 0.29.0 vs 0.27.0 environment mismatch) is also resolved on the build server side — though the structural verdict update itself is out of scope for this re-review per the task brief.

## Quality Score

4 — All three documented guards now pinned with branch-specific tests; CP4 closure is clean (no subtle parse-edge or fixture-shape gaps); CP3 identity-shape preserved on the new positive-case test. Could rate 5 if Test 3 also pinned `report_path` or integer fields for fuller identity coverage on the outer-extra-fields case, but this is a polish nit, not a behavioral gap.

## Verdict

APPROVED

CP4 gap from prior review is closed cleanly. The 3 new tests exercise distinct previously-uncovered branches:
- the asymmetric "sexp missing, md present" branch of the both-must-exist `&&` guard,
- the bare `with _ -> None` parse-failure swallow,
- the OUTER record's `[@@sexp.allow_extra_fields]` tolerance (the inner attribute was already implicitly exercised by the `variant` field in the original happy-path fixture; the outer was not).

Inherited PASS on CP1/CP2 (no `.mli` or PR body changes). CI green on `628fc203`. Domain checklist NA (pure observability PR).
