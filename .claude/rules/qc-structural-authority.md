---
description: Project-specific authority + checklist appendix for the qc-structural agent. The agent's generic protocol (build gates, format compliance, FAIL semantics) lives in `.claude/agents/qc-structural.md`. This file lists the project-specific checklist rows that get appended to the generic structural checklist for every PR review.
harness: project
---

# qc-structural authority — Weinstein Trading System

This file is the **project-specific augmentation** of the generic qc-structural
agent. The agent's protocol (run order, FAIL/PASS rules, write `dev/reviews/<feature>.md`,
harness_gap classification, etc.) is in `.claude/agents/qc-structural.md` and is
reusable across projects. The rows below are specific to *this* repo's
architecture and conventions.

## Project context

- Codebase: OCaml + Dune (see `.claude/rules/no-python.md`, `.claude/rules/ocaml-patterns.md`).
- Build gates the agent runs (`dune build @fmt`, `dune build`, `dune runtest`)
  cover most checks via dune-wired linters: `fn_length_linter`,
  `linter_magic_numbers.sh`, `linter_mli_coverage.sh`, `nesting_linter`.
- Test framework of record: OUnit2 + the in-repo Matchers library
  (`base/matchers/`). Test conventions are in `.claude/rules/test-patterns.md`.

## Architecture rules to verify (append to the generic structural checklist)

After completing the generic checklist (H1–H3, P1–P5), append these rows:

```
| # | Check | Status | Notes |
|---|-------|--------|-------|
| P6 | Tests conform to `.claude/rules/test-patterns.md` (presence + conformance) | PASS/FAIL/NA | Load the rules file and apply three greppable sub-rules to every test file in the diff. Sub-rule 1: `List\.exists .* equal_to (true\|false)` in test files → FAIL (use `List.count + equal_to N`). Sub-rule 2: `let _ = .*on_market_close\b` or `let _ = .*\.run\b` in test files → FAIL (Result must be asserted, e.g. `assert_that result is_ok`). Sub-rule 3: `match .* with` followed by `\| Error .* -> assert_failure` or bare `\| Ok .* ->` without `assert_that`/`is_ok_and_holds` in test files → FAIL (use `is_ok_and_holds`). A file with `open Matchers` that still contains any of the three patterns is a FAIL, not a PASS. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | PASS/FLAG/NA | FLAG does not block approval; it routes to qc-behavioral for generalizability judgment. |
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS/FAIL/NA | **Allow-listed exception:** `trading/trading/backtest/**/dune` files may declare `weinstein.*` (i.e. `analysis/weinstein/`) dependencies — this pattern is established practice (5+ dune files). **Still FAIL:** (1) any import from an `analysis/` path *other than* `analysis/weinstein/` into any `trading/trading/` path; (2) any import from `analysis/weinstein/` into `trading/trading/` paths *outside* `trading/trading/backtest/**` (e.g. into `trading/trading/portfolio/`, `trading/trading/orders/`, `trading/trading/engine/`, `trading/trading/strategy/`, `trading/trading/simulation/`). To apply mechanically: grep the diff for `analysis/` library refs in dune files; pass if every hit is under `trading/trading/backtest/` and the library begins with `weinstein.`; FAIL otherwise. Reverse direction (`trading/trading/` → consumed by `analysis/`) is always fine. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS/FAIL/NA | Look for cross-feature drift in the diff. |
```

## Project-specific reusable references

When filling notes:

- **Core modules** (A1 watch-list): `trading/trading/portfolio/`,
  `trading/trading/orders/`, `trading/trading/position/`,
  `trading/trading/strategy/`, `trading/trading/engine/`.
- **Test framework**: see `.claude/rules/test-patterns.md` for the canonical
  `assert_that` + matcher composition rules. P6 sub-rules above quote those.

## What the generic agent doesn't know about

- Which paths constitute "core modules" (A1) — listed above.
- The specific dune-wired linters (`fn_length_linter`,
  `linter_magic_numbers.sh`, etc.) — referenced from the generic checklist's
  P1/P2/P4 rows but the names are this repo's.
- Repo layout (`trading/`, `analysis/`, `dev/`).

If reusing the generic qc-structural agent in a new project, replace this
file with the new project's architecture rules. The agent itself does not
change.
