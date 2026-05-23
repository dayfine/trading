Reviewed SHA: 31e7f0a327f11c6ce3e55de82bb53012ece7f2d7

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No formatting violations detected |
| H2 | dune build | PASS | Full build succeeded |
| H3 | dune runtest | PASS | All tests passed, including new extract_metrics_gate_smoke.sh test (13 assertions) |
| P1 | Functions ≤ 50 lines (linter) | PASS | New functions in shell scripts are well under limit; fn_length_linter runs as part of H3 |
| P2 | No magic numbers (linter) | PASS | No hardcoded numeric thresholds in code; all configurable via env vars (PROMOTE_SHARPE_REGRESSION_THRESHOLD, PROMOTE_MAXDD_INCREASE_THRESHOLD, PROMOTE_TRADES_RATIO_MAX) |
| P3 | Config completeness | PASS | All configurable thresholds properly exposed as env vars with reasonable defaults |
| P4 | Public-symbol export hygiene (linter) | NA | No .ml/.mli files touched; shell-only changes |
| P5 | Internal helpers prefixed per convention | PASS | Helper functions in extract_metrics.sh follow underscore-prefix pattern (_validate_*) where applicable; new trades_out_of_ratio is a public helper (no underscore needed) |
| P6 | Tests conform to test-patterns (P6) | NA | No OCaml test files in diff; smoke test is shell (extract_metrics_gate_smoke.sh follows established devtools/checks/ pattern) |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core modules touched; shell tooling only |
| A2 | No new analysis/ → trading/trading/ imports | NA | No dune imports modified; shell scripts with no module dependencies |
| A3 | No unnecessary existing module modifications | PASS | Only 4 files modified, all in intended scope (dev/scripts/, trading/devtools/checks/); verified via gh pr view against ancestry |

## Verdict

APPROVED

All hard gates pass (H1–H3). New code is shell tooling only (no OCaml). Test-pattern rules (P6) do not apply to shell smoke tests; extract_metrics_gate_smoke.sh is properly positioned in devtools/checks/ and follows the established pattern (posix_sh_check passes with #!/bin/sh shebang; smoke test invokes 13 assertions covering regresses_by_more_than, trades_out_of_ratio, extract_metric). Env var handling is clean (no magic numbers, all configurable). No core modules or analysis imports affected. Cross-feature drift verified via gh pr view (4 files, all in scope).
