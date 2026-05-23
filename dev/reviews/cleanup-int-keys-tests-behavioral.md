Reviewed SHA: 2db7fcade3145cd84bf6351e4761138f60933e3f

---

# Behavioral QC — cleanup-int-keys-tests
Date: 2026-05-23
Reviewer: qc-behavioral

## Classification

Test-infra PR + 1-line .mli docstring clarification. No domain logic. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the Weinstein S*/L*/C*/T* checklist is NA. Only the generic CP1–CP4
Contract Pinning Checklist applies.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new/changed .mli docstrings has an identified test that pins it | PASS | Five claims in `bayesian_runner_spec.mli` `int_keys` block / shadow comment: (a) "Per-binding sugar [(key (lo hi) (int))]" → `test_load_int_marker_per_binding`; (b) "Explicit field [(int_keys ...)]" → `test_load_explicit_int_keys_field_merges_with_per_binding_markers`; (c) "When both forms appear, keys from both are merged (explicit first, per-binding markers appended)" → same merge test (asserts exact order `[explicit; per-binding₁; per-binding₂]`); (d) "Empty list (default) is omitted from the emitted sexp" → `test_load_no_int_marker_defaults_to_empty_int_keys` + existing emission asymmetry pinned by `test_int_keys_round_trip_non_empty`; (e) "Round-trip [t_of_sexp ∘ sexp_of_t = id] holds for any [t]" → `test_int_keys_round_trip_non_empty` (non-empty case; empty case covered by existing `test_holdout_folds_round_trip_none` style and the explicit empty default test). Code-block example caveat ("the bare atom `int` is rejected by t_of_sexp's pre-processor") → `test_load_bare_int_atom_marker_raises`. |
| CP2 | Each claim in PR body "Test plan" has a corresponding test in the committed test file | PASS | PR body Test plan: (a) `dune build @fmt` clean → qc-structural H1 PASS at SHA `2db7fcad`; (b) `dune build` clean → H2 PASS; (c) `dune runtest trading/backtest/tuner` — 50 tests pass (was 45 before; 5 added) → H3 PASS reports "50 tests total (5 new), all passed"; (d) `test_bayesian_runner_bin.exe -list-test` shows 5 new names → all 5 new tests verified by name in `suite` (lines 1127–1140 of test file): `test_load_int_marker_per_binding`, `test_load_no_int_marker_defaults_to_empty_int_keys`, `test_int_keys_round_trip_non_empty`, `test_load_explicit_int_keys_field_merges_with_per_binding_markers`, `test_load_malformed_int_marker_with_extra_atom_raises`, `test_load_int_alias_marker_raises`, `test_load_bare_int_atom_marker_raises` (actually 7 new test additions per `>::` lines; PR body says 5 but structural reports 50 vs 45 = 5 new — discrepancy is in PR-body wording but the test names enumerated in the "What changed" §3+§4 sum to 5 distinct claims as counted: 1 merge + 3 malformed + 1 round-trip = 5; the two parses of "no markers" and "with markers" already existed pre-PR per `git diff` shows additions at lines 139+). All advertised tests are present. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | PASS | `test_int_keys_round_trip_non_empty` asserts the full ordered key list via `elements_are [equal_to k1; equal_to k2]` (not `size_is 2`). `test_load_explicit_int_keys_field_merges_with_per_binding_markers` likewise pins the exact `[explicit; per-binding₁; per-binding₂]` order, exercising the `explicit @ extracted_int_keys` semantics rather than just element count. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded scenario | PASS | `_is_int_marker` docstring (lines 83–88 of `bayesian_runner_spec.ml`): "Matches only the exact one-atom form `(int)` — anything else (extra atoms, quoted, wrapped) is rejected so typos do not silently parse as float bindings." Three guards × three tests: (i) extra atoms → `test_load_malformed_int_marker_with_extra_atom_raises` with `(int extra)`; (ii) atom mismatch → `test_load_int_alias_marker_raises` with `(int_alias)`; (iii) bare atom (not `Sexp.List`) → `test_load_bare_int_atom_marker_raises` with `int`. All three assert `Failure` with `"failed to parse"` substring — guards pinned end-to-end. |

## Spec content verification (informational)

Verified at SHA `2db7fcad`:
- **`.mli` example block swap** — confirmed via `git diff`: the previous
  `{[ ... ]}` block contained two bindings; the new `{v ... v}` block adds
  a third `("screening.weights.w_positive_rs" (5.0 40.0) (int))` showing
  the `(int)` parens that ocamlformat would have stripped inside `{[ ]}`.
  Caveat sentence ("verbatim — the `(int)` marker on the third binding
  must be parenthesised; the bare atom `int` is rejected") added immediately
  above the block; pointer to `{!int_keys}` for the underlying rule.
- **Implementation alignment** — `_preprocess_spec_sexp` (line 174 of
  `bayesian_runner_spec.ml`) does `explicit @ extracted_int_keys` —
  ordered concat, no dedup. `.mli` line 183–184 wording "merged (explicit
  first, per-binding markers appended)" is accurate; no `Set` semantics
  claimed. The merge test uses three distinct keys, so dedup is not pinned
  either way — acceptable since the implementation does not promise dedup.
- **No production code change** — only `.mli` docstring and test file
  modified per `gh pr view 1268 --json files`.

## Quality Score

5 — All four follow-ups from the prior qc-behavioral review of #1261 pinned with named, single-purpose tests. Round-trip test asserts full ordered list (not size), three guard tests each pin a distinct `_is_int_marker` rejection path, merge test pins the exact `explicit @ per-binding` order. Docstring caveat + verbatim block fix removes a permanent ocamlformat trap. Pure cleanup PR with full traceability between .mli claims and test names.

## Verdict

APPROVED
