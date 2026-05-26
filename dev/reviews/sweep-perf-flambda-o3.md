Reviewed SHA: 20e92aded83be191e5a70a9ee5a498f749ed9546

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | No format violations |
| H2 | dune build | PASS | Full project builds successfully |
| H3 | dune runtest | PASS | All tests pass |
| P1 | Functions ≤ 50 lines (linter) | NA | No `.ml` files added; pure infrastructure/config PR |
| P2 | No magic numbers (linter) | NA | No new code with numeric literals |
| P3 | Config completeness | NA | Dune compiler flags are properly parameterized in `dune-workspace` |
| P4 | Public-symbol export hygiene (linter) | NA | No `.mli` files modified |
| P5 | Internal helpers prefixed per convention | NA | No new helper functions |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | No test files modified |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No core modules touched; only build config and status tracking |
| A2 | No new `analysis/` imports into `trading/trading/` outside exceptions | PASS | No new library imports added; purely infrastructure changes |
| A3 | No unnecessary existing module modifications | PASS | Three files in diff (Dockerfile, dune-workspace, status file) are all expected and in-scope for Win #3 implementation |

## Verdict

APPROVED

## Notes

This is a pure infrastructure/harness PR implementing Win #3 of the sweep-perf track:
- Enables Flambda variant of OCaml 5.3 via opam switch in Dockerfile (documented decision: base image tag ubuntu-22.04-ocaml-5.3-flambda does not exist on Docker Hub)
- Adds `-O3` optimization flag for release builds via `ocamlopt_flags` in `dune-workspace` (correctly targets native compiler only, not bytecode)
- Updates status file to mark Win #3 in progress with PR reference

All three hard gates (format, build, test) pass. No core modules or test patterns modified. No architectural violations. Ready for behavioral review and merge once CI green.

---

# Behavioral QC — sweep-perf-flambda-o3
Date: 2026-05-26
Reviewer: qc-behavioral

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | No new .mli files; PR adds only Dockerfile + dune-workspace flag + status doc update |
| CP2 | Each claim in PR body / plan §Win #3 has a corresponding test or verification | PASS | Claims pinned: (a) "dune build passes" → qc-structural H2 PASS; (b) "dune runtest passes" → qc-structural H3 PASS; (c) "ocamlopt_flags restricts -O3 to native compiler" → verified by inspecting `trading/dune-workspace` (uses `ocamlopt_flags`, not `flags` — bytecode compiler unaffected); (d) "flambda variant not yet active in this CI run because the GHA container runs against the old image" → explicitly acknowledged in PR body as manual follow-up; the plan acceptance criterion `ocamlopt -config \| grep flambda → true` is deferred to post-image-rebuild and IS NOT advertised as satisfied by this PR; (e) "-O3 wired and verifiable via `dune rules --profile release`" → wiring confirmed by static read of dune-workspace; runtime verification deferred to post-rebuild. Tier-1 smoke gate is a CI concern, not a QC concern |
| CP3 | Pass-through / identity / invariant tests pin identity (not just size_is) | NA | No pass-through semantics in a Dockerfile + dune compiler-flag PR |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded scenario | NA | No `.ml` guard claims. The Dockerfile comment ("ubuntu-22.04-ocaml-5.3-flambda does not exist on Docker Hub") is build-time reasoning, not a runtime guard requiring a test |

## Behavioral Checklist

Pure infra / harness / refactor PR; domain checklist (A1, S*/L*/C*/T* rows from `.claude/rules/qc-behavioral-authority.md`) not applicable. No Weinstein domain logic touched (no stage classifier, no stops, no screener, no orders, no strategy). The Contract Pinning Checklist above is the full behavioral review per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".

## Quality Score

5 — Cleanly scoped infra change with honest, explicit deferral of the post-rebuild verification step. The PR body correctly distinguishes "wiring landed (verifiable now)" from "perf benefit landed (requires image rebuild)", and the `ocamlopt_flags` vs `flags` choice shows correct understanding of dune's flag-scoping semantics (avoids the bytecode-compiler `-O3` rejection trap). Dockerfile workaround for the missing `ubuntu-22.04-ocaml-5.3-flambda` tag is documented inline with rationale + plan reference.

## Verdict

APPROVED
