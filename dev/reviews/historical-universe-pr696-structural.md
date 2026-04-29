Reviewed SHA: 2026-04-30 docs/notes (pure PR)

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | NA | Pure docs PR; no compileable code |
| H2 | dune build | NA | Pure docs PR; no compileable code |
| H3 | dune runtest | NA | Pure docs PR; no tests |
| P1 | Functions ≤ 50 lines (linter) | NA | Pure docs PR |
| P2 | No magic numbers (linter) | NA | Pure docs PR |
| P3 | Config completeness | NA | Pure docs PR |
| P4 | .mli coverage (linter) | NA | Pure docs PR |
| P5 | Internal helpers prefixed with _ | NA | Pure docs PR |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | Pure docs PR; no test files |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | Only file changed: `dev/notes/historical-universe-membership-2026-04-30.md` (no core modules) |
| A2 | No imports from `analysis/` into `trading/trading/` | PASS | Pure docs PR; no imports |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | Only file added: `dev/notes/historical-universe-membership-2026-04-30.md` (new doc, no modifications to existing modules) |

## Verdict

APPROVED

## Notes

- Single 142-line docs file capturing a gap analysis (survivorship bias in 30y backtests on indexed universes)
- Frames the work as a 6-phase `ops-data` track item with clear phasing and cross-references
- No code changes, no test changes, no config changes — pure documentation
- Follows existing `dev/notes/*-2026-04-XX.md` format convention
- Cross-references to `data-availability-2026-04-29.md`, `session-followups-2026-04-29-evening.md`, and `sector-data.md` are all internal and correct
