Reviewed SHA: 6f7785e22132149dea10799eec8088c32dc1a436

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No source changes; doc file passes trivially |
| H2 | dune build | PASS | Build succeeds, no build impact from markdown file |
| H3 | dune runtest | PASS | All tests pass; 0 failures. Linters (magic-numbers, no-python) both OK |
| P1 | Functions ≤ 50 lines (linter) | NA | Documentation-only PR; no functions |
| P2 | No magic numbers (linter) | PASS | Linter passed; no OCaml source added |
| P3 | Config completeness | NA | Documentation-only PR |
| P4 | Public-symbol export hygiene (linter) | NA | Documentation-only PR |
| P5 | Internal helpers prefixed per convention | NA | Documentation-only PR |
| P6 | Tests conform to test-patterns rules | NA | Documentation-only PR; no test files added |
| A1 | Core module modifications | NA | No modifications to Portfolio/Orders/Position/Strategy/Engine |
| A2 | No new `analysis/` imports into `trading/trading/` | NA | Documentation-only PR |
| A3 | No unnecessary existing module modifications | PASS | PR modifies only `dev/notes/screener-weights-inertness-2026-05-13.md` (per `gh pr view 1061 --json files`) |

## Verdict

APPROVED

---

## Summary

Pure documentation PR adding investigation note on screener `scoring_weights` surface. Note walks evidence from PR #1051's failed grid sweep (which swept non-existent config key paths), correctly interprets the M5.4 E4 baseline evidence (weights are demonstrably load-bearing along heterogeneous-signal axes), and recommends Option C: keep weights, document the binding mechanism (rank-among-admitted via entry-walk), and validate grid-sweep paths. No source changes; all gates pass; no structural concerns.
