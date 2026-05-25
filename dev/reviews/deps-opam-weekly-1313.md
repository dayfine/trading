Reviewed SHA: 8e3dc1382

# QC — deps-opam-weekly (PR #1313)

## Structural QC — deps-opam-weekly
Date: 2026-05-25
Reviewer: qc-structural
Verdict: APPROVED

Single-file chore: `trading/deps-snapshot.txt` patch-bumps dune /
dune-build-info / dune-configurator (3.23.0 → 3.23.1) and integers
(0.7.0 → 0.8.0). No source code, no tests, no docstrings touched.
CI (`build-and-test` + `perf-tier1-smoke`) green at this SHA.

---

# Behavioral QC — deps-opam-weekly
Date: 2026-05-25
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No `.mli` files in diff; only `trading/deps-snapshot.txt` (lock-file refresh). |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | NA | PR body is a chore-style deps bump (commit msg: "chore: update opam deps snapshot"); no "Test plan"/"Test coverage" claims to verify. CI (`build-and-test`, `perf-tier1-smoke`) green is the implicit acceptance signal. |
| CP3 | Pass-through / identity / invariant tests pin identity (elements_are [equal_to ...] or equal_to on entire value), not just size_is | NA | No test changes in diff; no pass-through semantics introduced. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | NA | No code or docstrings in diff; no guard claims introduced. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1–T4 (all rows) | Weinstein domain checklist | NA | Pure deps-snapshot version bump; no source, tests, or docstrings touched; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". |

### Notes on bumped packages (sanity scan)

- **dune / dune-build-info / dune-configurator 3.23.0 → 3.23.1**: patch
  release of the build tool itself. Does not touch runtime semantics of
  compiled OCaml code. CI passing on this SHA confirms the build still
  succeeds and all tests pass.
- **integers 0.7.0 → 0.8.0**: minor bump. Not imported directly by any
  `dune` file in this repo (transitive via `ctypes` or `core`). Numeric
  semantics relied on by the codebase use `Core.Int`, `Float`, and
  domain wrappers in `trading/base/`, not the `integers` library
  directly. No surface where a 0.7 → 0.8 change in `integers` could
  silently alter a domain contract pinned in this codebase. CI green at
  this SHA confirms no observable behavior change from the bump.

## Quality Score

5 — Mechanically-verifiable chore PR: 4 patch/minor version bumps in a
lock-file, no source touched, CI green on both required workflows, no
domain contract surface in scope.

## Verdict

APPROVED
