---
description: Project-specific authority + checklist appendix for the qc-structural agent. The agent's generic protocol (build gates, format compliance, FAIL semantics) lives in `.claude/agents/qc-structural.md`. This file lists the project-specific checklist rows that get appended to the generic structural checklist for every PR review.
harness: project
---

# qc-structural authority — Weinstein Trading System

This file is the **project-specific augmentation** of the generic qc-structural
agent. The agent's protocol (run order, FAIL/PASS rules, PR review comment delivery,
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
| A2 | No new `analysis/` imports into `trading/trading/` outside the established backtest exception surface | PASS/FAIL/NA | **Allow-listed exceptions:** `trading/trading/backtest/**/dune` files may declare (1) `weinstein.*` (i.e. `analysis/weinstein/`) dependencies — this pattern is established practice (5+ dune files); and (2) `universe` (i.e. `analysis/data/universe/`) dependencies — same precedent + reason: backtest scenarios are the integration point that consumes custom-universe goldens produced by `analysis/data/universe/` (added 2026-05-17 when the universe-snapshot consumer adapter landed). **Still FAIL:** (1) any import from an `analysis/` path *other than* `analysis/weinstein/` or `analysis/data/universe/` into any `trading/trading/` path; (2) any import from the two allow-listed analysis paths into `trading/trading/` paths *outside* `trading/trading/backtest/**` (e.g. into `trading/trading/portfolio/`, `trading/trading/orders/`, `trading/trading/engine/`, `trading/trading/strategy/`, `trading/trading/simulation/`). To apply mechanically: grep the diff for `analysis/` library refs in dune files; pass if every hit is under `trading/trading/backtest/` and the library is in the allow-list (`weinstein.*` or `universe`); FAIL otherwise. Reverse direction (`trading/trading/` → consumed by `analysis/`) is always fine. |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS/FAIL/NA | Look for cross-feature drift using `$PR_FILES` from Step 3 (file list per `gh pr view <N> --json files`), NOT from a git-log ancestry walk. This is where PR #687's false-positive originated: the agent walked git ancestry and saw 128 unrelated files; `gh pr view 687 --json files` showed 6. |
```

## Operational requirements for QC agents in this repo

QC agents dispatched on this repo MUST be invoked with both of:

1. **`isolation: "worktree"`** — qc-structural and qc-behavioral aren't
   read-only. They run `jj edit <branch>` to check out the PR. Without
   isolation, those edits mutate the parent workspace's shared `.jj/repo/`
   and snapshot unrelated files into surprise commits. Observed
   2026-05-14: two non-isolated QC agents rebased the parent `@` onto
   `experiments/continuation-tuning` and reverted `dev/status/screener.md`
   to pre-fix content on disk. Same rule as `feat-*` per
   `.claude/rules/worktree-isolation.md`.

2. **Run `dune` inside docker** — the dispatch prompt must explicitly
   instruct the agent to run every `dune build` / `dune build @fmt` /
   `dune runtest` via:

   ```bash
   docker exec trading-1-dev bash -c \
     'cd /workspaces/trading-1/trading && eval $(opam env) && dune build'
   ```

   Running natively against the host's opam state produces ENVFAIL
   reports (ocamlformat 0.27.0 vs 0.29.0 skew, missing `core` / `owl`
   libraries) that aren't about the PR. The container is named
   `trading-1-dev`; dune root is `/workspaces/trading-1/trading`.
   Observed 2026-05-14 PR #1090: qc-structural reported ENVFAIL despite
   the PR being clean and its CI green.

If a QC review comes back ENVFAIL or with bookmark conflicts after the
agent ran, suspect one of these was skipped — re-dispatch with the
correct invariants rather than treating the verdict as authoritative.

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
