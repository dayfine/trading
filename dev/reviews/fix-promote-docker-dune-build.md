Reviewed SHA: 58aab1aebc982f8ab5b831fd82ee36c38eea66af

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | No OCaml changes, shell-only |
| H2 | dune build | PASS | Full build succeeds |
| H3 | dune runtest | PASS | All tests pass; no-python + magic-numbers linters clean |
| P1 | Functions ≤ 50 lines (linter) | NA | No OCaml functions |
| P2 | No magic numbers (linter) | NA | No OCaml changes |
| P3 | Config completeness | NA | No tunable parameters |
| P4 | Public-symbol export hygiene (linter) | NA | No OCaml changes |
| P5 | Internal helpers prefixed per convention | NA | No OCaml changes |
| P6 | Tests conform to test-patterns | NA | No test changes |
| A1 | Core module modifications | NA | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No new analysis/ imports into trading/trading/ | NA | No new dependencies |
| A3 | No unnecessary modifications to existing modules | PASS | Only dev/scripts/promote_config.sh changed (non-core) |

## Verdict

APPROVED

Notes:
- Shell syntax check passes (`bash -n`).
- Fix is mechanical: routes `dune build` and `scenario_runner.exe` invocations through `docker exec trading-1-dev` instead of running on host.
- Path rewriting uses safe bash parameter expansion; no injection risk.
- Two QC review files bundled (from #1240) are documentation only — not functional changes.
- Ancestry clean: one commit directly off main.
