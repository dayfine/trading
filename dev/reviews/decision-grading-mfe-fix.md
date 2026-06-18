Reviewed SHA: aa31e866e3d173ce20ed061ab5572c80bee9f559

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | CI green; no formatting issues |
| H2 | dune build | PASS | CI green; all targets build |
| H3 | dune runtest | PASS | CI green; all tests pass |
| P1 | Functions ≤ 50 lines — covered by dune linter | PASS | New functions `_mfe_index` (~15 lines) and `_find_mfe` (~13 lines) both well under limit. CI fn_length_linter passed. |
| P2 | No magic numbers — covered by dune linter | PASS | New constant `_join_tolerance_days = 7` is documented with semantic meaning (max calendar-day gap for audit record join). CI magic_numbers linter passed. |
| P3 | All configurable thresholds in config record | PASS | `_join_tolerance_days` is a const comment with clear rationale ("kept in sync with Trade_audit_ratings._join_tolerance_days"). Not a tunable parameter, so no config field needed. |
| P4 | Public-symbol export hygiene (linter) | PASS | All new functions prefixed with `_` (internal helpers). CI mli_coverage linter passed. |
| P5 | Internal helpers prefixed per convention | PASS | All new helpers (`_mfe_index`, `_find_mfe`, `_join_tolerance_days`) use `_` prefix. |
| P6 | Tests conform to test-patterns rules | NA | No test files added or modified in this PR. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules. This PR changes only `decision_grading_bin.ml` (a CLI binary under `trading/trading/backtest/decision_grading/bin/`). |
| A2 | No disallowed analysis/ imports into trading/trading/ | PASS | New dune deps: `core_unix.sys_unix` (from Core, not analysis/) and `backtest` (from `trading/trading/backtest/lib/`, not analysis/). File is under `trading/trading/backtest/`, which is allowed to use `backtest` library. No analysis/ imports. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | PR modifies exactly 5 files per `gh pr view 1650 --json files`: 3 docs/experiment files + the 2 code files (dune + bin). No cross-feature drift. |

## Verdict

APPROVED

## Quality Score

9 — A focused, well-scoped fix to a reporting CLI. The bug is clearly described (MFE join misses due to ~1-day offset between audit entry_date and trades.csv entry_date), the fix is sound (read MFE directly from trade_audit.sexp, replicate the same nearest-within-tolerance join pattern Trade_audit_ratings uses), and the implementation is clean (small helper functions, good comments explaining the offset rationale, no unnecessary changes). CI gates all pass. No test failures. Exactly what a follow-up harness fix should be.

## Notes

- The fix reads `exit_decision.max_favorable_excursion_pct` straight from `trade_audit.sexp` (not from the report's Trade_audit_ratings analysis), addressing the 1-day offset between audit decision dates and fill dates.
- The new `_mfe_index` function builds a per-symbol index with fallback handling for two sexp formats (`audit_blob_of_sexp` and `audit_records_of_sexp`), with defensive try-catch.
- The `_find_mfe` function implements a nearest-within-tolerance join matching the pattern already used in Trade_audit_ratings (same `_join_tolerance_days` constant).
- Documentation in FINDINGS.md shows the fix enables the "capture" column in the decision-grading report, which was previously all `n/a`. The report now shows quantified decision-level metrics (e.g., stop_loss captures −2.83 on average, laggard_rotation +1.6%).
- Scope is tight: only the CLI binary and its dune file change; no domain logic, no core module changes, no strategy changes.

---

## Behavioral QC — decision-grading-mfe-fix

Reviewed SHA: aa31e866e3d173ce20ed061ab5572c80bee9f559

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new `.mli` added. The new symbols (`_mfe_index`, `_find_mfe`, `_join_tolerance_days`) are internal `_`-prefixed helpers in the CLI binary (`decision_grading_bin.ml`), which has no `.mli`. |
| CP2 | Each claim in PR body / committed artifacts has a corresponding pinning evidence | PASS | Three claims, each pinned by a committed reproducible artifact. (1) Reads `exit_decision.max_favorable_excursion_pct` from `trade_audit.sexp`: verified against `trade_audit.mli` — `audit_record.entry.entry_date`, `audit_record.exit_ : exit_decision option`, `exit_decision.max_favorable_excursion_pct : float`, and both `audit_blob_of_sexp` / `audit_records_of_sexp` exist and are used exactly as typed. (3) Capture column now populates: `grade-2011.md` shows real values (laggard_rotation −0.09, stage3_force_exit −0.90, stop_loss −2.83, unlabeled −1.59) where it was previously all `n/a`; `scenario.sexp` fixture + FINDINGS.md are the reproducible artifact. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | NA | No pass-through / identity semantics in this feature. |
| CP4 | Each guard called out in docstrings has a test exercising the guarded scenario | PARTIAL→see harness_gap | The `_find_mfe` docstring names a guard: "[None] when the symbol has no audit MFE within tolerance" — the `gap <= _join_tolerance_days` filter. This guard is **not** exercised by an automated test (the join lives in the untested `bin`). Not a FAIL for a reporting CLI per CP-judgment (see rationale below); recorded as a harness_gap (TEST_GAP). |

**CP4 rationale (not a FAIL):** This is a thin reporting CLI with no `.mli`. The substantive arithmetic it feeds (`DG.Grade.entry_capture_ratio`) is unit-tested in `decision_grading/test/test_grade.ml`. The only new logic is sexp-read glue (`_mfe_index`) and a nearest-within-tolerance join (`_find_mfe`). Crucially, `_find_mfe` is a **verbatim structural replica** of the already-shipped, in-scope `Trade_audit_ratings._nearest_within` (`trade_audit_report/trade_audit_ratings.ml:347-352`): identical `Int.abs (Date.diff …)` gap, identical `<= _join_tolerance_days` filter, identical `List.min_elt`-by-gap, identical `Option.map ~f:snd`. The reused pattern is itself exercised by `test_trade_audit_ratings.ml`. The join's behavioral correctness is therefore inherited from a tested sibling, and the end-to-end populated `grade-2011.md` artifact is a reproducible integration check. A unit test for the bin's join would still be cheap and worth adding — recorded below.

### Claim-2 tolerance verification (the load-bearing check)

**VERIFIED — the tolerance matches.** The PR claims its 7-day join tolerance "matches the tolerance `Trade_audit_ratings` itself uses." Cross-checked against source:
- `decision_grading_bin.ml`: `let _join_tolerance_days = 7`
- `trade_audit_report/trade_audit_ratings.ml:343`: `let _join_tolerance_days = 7`
- `trade_audit_report/trade_audit_report.ml:76`: `let _audit_join_tolerance_days = 7`

All three agree at 7 calendar days, and the join algorithm in `_find_mfe` is structurally identical to `Trade_audit_ratings._nearest_within`. The PR's docstring even names the sync dependency ("Kept in sync with [Trade_audit_ratings._join_tolerance_days]"). No defect. The semantic justification (Friday audit decision date vs next-trading-day fill, ~1-3 days across a weekend) is consistent across both modules' comments.

### Domain Checklist (S*/L*/C*/T*)

NA — Pure analysis-tooling PR; domain checklist not applicable. This PR changes only the decision-grading reporting CLI (`decision_grading_bin.ml` + its dune); it touches no Weinstein domain logic (no stage classifier, stops, screener, macro/sector gates). Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire A1/S*/L*/C*/T* block is NA.

### harness_gap

- **TEST_GAP** — `_find_mfe` / `_mfe_index` (the nearest-`entry_date`-within-7-days join in the CLI bin) have no automated unit test. A small OUnit test feeding two audit records for one symbol (one within 7 days, one outside) and asserting the nearest in-tolerance MFE is returned (and `None` when all candidates exceed tolerance) would deterministically pin the guard. Low priority: the join is a verbatim replica of the unit-tested `Trade_audit_ratings._nearest_within`, and the committed `scenario.sexp` + `grade-2011.md` provide a reproducible integration check. Recommend filing as a follow-up, not blocking.

## Behavioral Quality Score

5 — All three claims pinned by reproducible committed artifacts; the load-bearing tolerance claim verified to match `Trade_audit_ratings` exactly (both 7 days, identical join algorithm); the new join is a verbatim replica of a tested sibling. Only gap is a cheap, low-priority bin unit test for the join — recorded, non-blocking.

## Behavioral Verdict

APPROVED
