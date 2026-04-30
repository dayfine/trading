Reviewed SHA: 25885eaa7a3f6253eb6541e3d0fa4c51154699bf

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | No OCaml source files in diff; only sexp/shell/markdown |
| H2 | dune build | NA | No OCaml source files in diff; no compilable code changes |
| H3 | dune runtest | NA | No OCaml source files in diff; no test code changes |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml source files in diff |
| P2 | No magic numbers (linter) | NA | No OCaml source files in diff |
| P3 | All configurable thresholds in config record | NA | Scenario sexp uses reasonable permissive ranges (capacity-smoke-gate, not baseline); documented as intentionally wide |
| P4 | .mli files cover all public symbols | NA | No OCaml source files in diff |
| P5 | Internal helpers prefixed with _ | NA | No OCaml source files in diff |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No test files in diff |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; only new test data and scripts |
| A2 | No imports from analysis/ into trading/trading/ | PASS | No OCaml imports; shell script and sexp data only |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only 4 new files added: 1 markdown note, 1 shell script, 2 sexp files; no existing files modified |

## Technical Verification

### File scope (A3)
Verified via `gh pr view 697 --json files`: exactly 4 new files, no modifications to existing code:
- `dev/notes/n1000-30y-capacity-2026-04-30.md` — capacity validation results note
- `dev/scripts/curate_30y_universe.sh` — POSIX shell universe builder
- `trading/test_data/backtest_scenarios/universes/broad-1000-30y.sexp` — universe definition
- `trading/test_data/backtest_scenarios/goldens-broad/sp500-30y-capacity-1996.sexp` — scenario sexp

No production code, no analysis/ imports, no core module changes.

### Shell script (curate_30y_universe.sh)
- Shebang: `#!/usr/bin/env bash` ✓
- Error handling: `set -euo pipefail` ✓
- Deterministic logic: symbol filtering by data_start_date <= 1996-01-01, sector intersection, SP500-first composition, alphabetic backfill
- Temporary files: created via mktemp, cleaned up via trap ✓
- No hardcoded paths outside of sensible defaults (REPO_ROOT, DATA_DIR, SP500_SEXP, CUTOFF, TARGET_SIZE, OUT all parameterizable)
- Output: valid sexp with `(Pinned ((symbol ...) (sector ...)) ...)` structure

### Sexp files
Both universe and scenario sexp files are syntactically well-formed:
- **broad-1000-30y.sexp**: 1,000 entries in `(Pinned ((symbol X) (sector S)) ...)` form; valid termination with `))`
- **sp500-30y-capacity-1996.sexp**: standard scenario sexp format with `name`, `description`, `period`, `universe_path`, `universe_size`, `config_overrides`, `expected` fields; properly closed parentheses; marked `perf-tier: capacity-only` comment

### Documentation
- Capacity-validation caveat clearly stated in both the markdown note and scenario sexp header
- Survivorship bias warning repeated in all 4 files
- References to related issues (#696, #682, #693) and design docs provided
- Results (6.3 GB peak, 31:58 wall, 8 trades, zero positions for ~28.7y) documented with diagnostic analysis
- Cross-references to cost-model, 10y baseline, point-in-time membership filter

## Verdict

APPROVED

This PR adds capacity-validation infrastructure only: measurement results, a deterministic universe curation script, and test data (sexp files). No production logic changes, no core module modifications, no analysis/ imports. The shell script is portable (POSIX-compliant with set -euo pipefail), sexp files are syntactically valid, and documentation is clear about capacity-validation-only use. Ready for merge.
