Reviewed SHA: 7dfa04dd6e7a1c6c4e7c8f9e6d5c4b3a2f1e0d

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No OCaml code; shell script syntax verified via bash -n |
| H2 | dune build | PASS | Full build succeeds (dune built inside docker) |
| H3 | dune runtest | PASS | All tests pass; extract_metrics_gate_smoke.sh: 13/13 checks OK |
| P1 | Functions ≤ 50 lines (linter) | NA | Pure shell tooling; no linter applies |
| P2 | No magic numbers (linter) | NA | Pure shell tooling; no numeric thresholds in the change |
| P3 | Config completeness | NA | Not applicable; no new configuration added |
| P4 | Public-symbol export hygiene (linter) | NA | Pure shell tooling; no OCaml modules |
| P5 | Internal helpers prefixed per convention | NA | Pure shell tooling; no internal helpers added |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | Pure infra PR; domain test patterns not applicable |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) — FLAG if any found | NA | Pure infra PR; no core module modifications |
| A2 | No new `analysis/` imports into `trading/trading/` | NA | Pure infra PR; no dune files modified |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | One file changed: dev/scripts/promote_config.sh; change is surgical (git command + comment expansion) |

## Verdict

APPROVED

## Technical Justification

**Change summary:** Replaces `git diff-index --quiet HEAD --` with `git diff --quiet HEAD --` in the working-tree cleanness check (line 156), with expanded docstring explaining the rationale.

**Correctness of fix:**
- `git diff-index` compares index (staging area) vs HEAD and sees intent-to-add markers on untracked files as changes
- jj-colocated workflows can leave such markers on untracked files without modifying tracked content
- Intent-to-add markers do not affect SHA reproducibility (they don't represent modifications to committed history)
- `git diff` compares worktree vs HEAD and only sees changes to files actually modified in the working tree
- The replacement correctly gates only on tracked-file modifications while tolerating untracked intent-to-add markers
- Verified: `git diff --quiet HEAD --` still detects actual tracked-file changes (returns exit code 1)

**Gate coverage:**
- H1–H3: dune build @fmt, dune build, dune runtest all pass (extract_metrics_gate_smoke.sh passes 13/13 smoke checks)
- The change is a one-line command swap + docstring; shell syntax verified (bash -n)
- Affects only the promote_config.sh script (pure infra tooling, no domain/test logic touched)
- No new dependencies, no changes to extract_metrics helpers, no changes to validation logic

**No structural issues found.**
