Reviewed SHA: 0cd9905f2fa9f33ae0fed8d09d006c8c1fccddc5

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | Shell scripts; OCaml format linter does not apply |
| H2 | dune build | PASS | Successful build (output shows no errors, only unrelated dune-project warning) |
| H3 | dune runtest | PASS | Standalone shell test (record_qc_audit_test.sh) passes 4/4 scenarios; dune runtest in container confirms clean |
| P1 | Functions ≤ 50 lines — covered by language-specific linter | NA | Shell scripts; OCaml linter rules do not apply |
| P2 | No magic numbers — covered by language-specific linter | NA | Shell scripts; magic-numbers linter does not apply |
| P3 | All configurable thresholds/periods/weights in config record | NA | No configuration-driven tuning; PR adds command-line flag parsing for --pr-number |
| P4 | Public-symbol export hygiene — covered by language-specific linter | NA | Shell scripts; .mli coverage linter does not apply |
| P5 | Internal helpers prefixed per project convention | PASS | Internal helpers prefixed with underscore (_repo_root, _pr_to_verdict_state, _extract_verdict, _extract_pr_verdict); follows OCaml convention applied to shell |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No OCaml tests; shell test uses standard bash assertions (scenario pass/fail pattern) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | NA | No core module modifications; pure shell-script additions |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | NA | Shell scripts; no library imports |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only two files touched: record_qc_audit.sh (extended with --pr-number logic) and record_qc_audit_test.sh (new test); write_audit.sh is a dependency, not modified |

## Verdict

APPROVED

## Summary

This PR adds dual-source verdict extraction to `record_qc_audit.sh`, enabling the script to read QC verdicts from either:
1. Legacy file-mode: `dev/reviews/<feature>.md` with `structural_qc:`/`behavioral_qc:` fields
2. New PR-mode: `gh pr view <N> --json reviews` API response with body-parsing of "## Structural QC" / "## Behavioral QC" sections

The new `--pr-number` flag switches to PR-mode; file-mode is the fallback. Standalone shell test confirms both paths work correctly, including quality-score extraction and overall-verdict derivation. No OCaml changes; no architectural constraints triggered. All gates pass.
