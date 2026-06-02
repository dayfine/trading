---
name: ocamlformat container vs CI skew — narrow + agents hallucinate fmt diffs
description: Container's ocamlformat 0.29.0 disagrees with CI's on docstring `{[ ... ]}` block indentation specifically (verified 2026-05-06). Other "skew" reports from rework agents (e.g. let-binding line breaks) have been agent hallucinations — they edited without running fmt. Always verify against actual `dune build @fmt` output.
type: project
originSessionId: 62a91729-bd17-40ce-ab8e-226d718d658a
---

## What's actually true (verified 2026-05-06)

Both Dockerfile and CI install `ocamlformat.0.29.0` from the same
opam-repository recipe. The released git tag `0.29.0`
([github.com/ocaml-ppx/ocamlformat/releases/tag/0.29.0](https://github.com/ocaml-ppx/ocamlformat/releases/tag/0.29.0))
is **stable** — it has not been force-moved. So mutable-tag drift is NOT
a credible root cause.

Yet a real divergence does exist on docstring `{[ ... ]}` indentation:

```bash
# Reproducer (2026-05-06):
git show 9e4093d4:trading/trading/backtest/lib/runner.mli \
  | docker exec -i trading-1-dev bash -c \
    'eval $(opam env) && ocamlformat - --name=runner.mli --enable-outside-detected-project' \
  | sed -n "136,142p"
# Local container rewrites the (CI-accepted) 4-space-indented {[ ... ]}
# back to 6-space — diverging from CI's released 0.29.0 which accepts
# 4-space.
```

This was the genuine fix in PR #884 (commit `9e4093d4`). Local container
disagrees with CI on this construct. Root cause is unknown — same opam
recipe, same stable git tag, but different output. Likely a transitive
dep (ocamlformat-lib build state? compiler patch level?) but not yet
isolated.

## What's NOT true: agent-hallucinated skews

PR #893's CP4 rework agent (commit before `7b49e165`) split a
`let evaluator = Evaluator.build ~fixtures_root:"/u" ~scenarios in`
onto 3 lines, claiming "to match ocamlformat 0.29.0 expectations".
Verified afterward:

```bash
# Local container fmt of that file produces SINGLE-LINE — same as CI.
```

The agent never actually ran `dune build @fmt`. It guessed and pushed.
CI rejected it. Fix `7b49e165` reverted to the single-line form that
both local AND CI accept.

**Lesson:** assume "fmt skew" claims by rework agents are 50/50 to be
hallucinations. Always run `dune build @fmt` (or pipe the file through
`ocamlformat - --name=<file>`) before pushing a fmt-only commit.

## Detection

`ocamlformat --version` reports `0.29.0` in both local and CI — useless
as a skew indicator. To check for real divergence on a specific file:

```bash
# Inside the container, with the suspect file at $F:
cat "$F" | docker exec -i trading-1-dev bash -c \
  'eval $(opam env) && ocamlformat - --name='"$(basename "$F")"' \
   --enable-outside-detected-project' \
  | diff -u "$F" -
```

If the diff is non-empty AND CI is green on that file → real skew on this
construct. If CI is red and the diff is empty → CI is right, not a skew,
the file is genuinely misformatted.

## Fix (when CI fmt fails on a PR)

1. **Verify before patching.** Pipe the failing file through the
   container's ocamlformat as above.
   - Container output matches CI's expectation → just push that.
   - Container output differs from CI → known docstring-class skew;
     apply the CI diff manually, do NOT auto-promote.
2. **Never trust an agent's "I matched CI fmt" claim** without seeing the
   `dune build @fmt` exit-zero output in their report.
3. Restore unrelated files the local auto-promote rewrote with
   `jj restore <file> --from main@origin`.

## Scope of real skew (as of 2026-05-09)

| Construct | Skew real? | Evidence |
|---|---|---|
| Docstring `{[ ... ]}` code-block indent | **YES** | runner.mli reproducer above; PR #884 needed CI-direction fix |
| Docstring `(** ... *)` paragraph word-wrap | **YES** | PR #902 `position.mli` line 162-167: container produces 5-line wrap, CI wants 4-line wrap. 2026-05-06. Confirmed again on PR #1015 `trade_context.mli` `precompute` + `of_precomputed` docstrings — container produced 3-line wrap, CI wanted 2-line. |
| Long single-line record-field type annotations near 80-col | **YES** | PR #1015 `trade_context.ml` `type precomputed = { audit_by_key : (string, ..., String.comparator_witness) Map.t; ... }` — container kept fields on a single line each (~84 chars); CI wrapped each field's type onto its own indented line. Apply CI's wrap manually; container's `dune build @fmt --auto-promote` won't surface it locally. |
| Long single-line record *value* literals near 80-col | **YES** | PR #1199 `panel_runner.ml` `{ stop_log; trade_audit; force_liquidation_log; stale_hold_log; audit_recorder }` — 88 chars one-line. Container accepted single-line; CI wrapped over 7 lines. Same shape as the record-field-type case above; both auto-promote in container leaves the single-line form. Manual fix: split each field onto its own line, trailing semicolon, closing `}` on its own line. 2026-05-19. |
| `let ... = expr in` line break near 80-col | NO | PR #893 case verified container == CI on single-line |
| Other (untested) | unknown | assume agent-hallucinated until reproduced |

## Reference

- First documented: 2026-05-06 on PR #877
- Real skew confirmed: `9e4093d4` (PR #884) — runner.mli docblock indent
- Agent hallucination confirmed: pre-`7b49e165` (PR #893) — let-binding
  multi-line
- **2026-05-15 PR #1100 (commit `3099b3d5`):** container auto-promote
  reproduced CI's demanded diff exactly on `matchers.mli` (docstring
  prose reflow + `all_of [...]` compaction). Original commit `4d349503`
  added `contains_substring` without running `dune build @fmt` — pure
  stale-fmt, not skew. Yet another data point: most reported "skew" is
  agents skipping `@fmt` before commit.

## How to apply

When dispatching a feat-* / fix-* agent that touches `.mli` docstrings:
- Tell the agent to run `dune build @fmt` (no `--auto-promote`) and paste
  the actual exit code in its report.
- If the agent claims a fmt-skew workaround, demand the reproducer command
  + diff before accepting the change.
- For docstring `{[ ... ]}` blocks specifically, expect the local-vs-CI
  skew and apply the CI-log diff manually if CI fmt fails.
