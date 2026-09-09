Reviewed SHA: 5232a8cf3b7958f953dbbdbee8b6626368ff11b5

## Structural QC — harness/goldens-nested-new-field (PR #2748)

### Summary
This PR fixes a false-positive in `goldens_affected_check.sh` Step 2c (nested-config embedding field emission). The script was emitting the outer strategy-config knob (e.g., `stops_config`) whenever ANY field in a nested config file changed, including brand-new fields with no prior default. This caused false FAIL verdicts on PR #2642 when `stop_skip_entry_bar` was added to `Weinstein_stops.config`, matching goldens that armed the outer knob for unrelated existing fields.

The fix gates outer-knob emission on at least one changed field existing at BASE_REF (via conservative `grep -qw` presence check). New fields alone do not trigger emission. Assertions 22 (brand-new field → OK) and 23 (pre-existing field with changed default → still FAIL) verify the fix is load-bearing and does not over-suppress.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Script and test file are correctly formatted. |
| H2 | dune build | PASS | Full build completes with no errors. |
| H3 | dune runtest | PASS | 23 assertions pass (21 prior + 2 new); no ^FAIL: lines. |
| P1 | Functions ≤ 50 lines (linter) | NA | Shell scripts; dune runtest passed (includes format/lint gates). |
| P2 | No magic numbers (linter) | NA | Shell scripts; dune runtest passed. |
| P3 | Config completeness | NA | No config fields in this PR. |
| P4 | Public-symbol export hygiene (linter) | NA | Shell scripts; dune runtest passed. |
| P5 | Internal helpers prefixed per convention | NA | Shell scripts use standard `_function_name` convention for private routines. |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | Test file uses shell-script assertion patterns (pass/fail counters), not OCaml test matchers. Shell-test assertions are appropriate for this fixture-driven harness. |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No OCaml library modifications; devtools shell scripts only. |
| A2 | Dependency-direction rules (Tier 1 & 2) | NA | No OCaml library dependencies added. |
| A3 | No unnecessary modifications to existing modules | PASS | Three files changed: script (fix), test (2 new assertions), status (documentation). All related to this issue. |

### Critical Over-Suppression Verification

**Question:** Can the new predicate `git show "${BASE_REF}:${f}" | grep -qw -- "$knob_field"` over-suppress emission for genuinely CHANGED defaults or REMOVED fields?

**Answer:** No. Verified via three scenarios:

1. **Changed default value** — Field name still appears in BASE_REF file (old value line contains it) → `grep -qw` finds it → HAS_PREEXISTING_FIELD=1 → outer knob IS emitted. ✓ (Verified by test assertion 23: pre-existing `stop_skip_entry_bar` with flipped default still FAILs as expected.)

2. **Removed field** — Field name appears in BASE_REF (the line being removed contains it) → `grep -qw` finds it → HAS_PREEXISTING_FIELD=1 → outer knob IS emitted. ✓

3. **Word-boundary correctness** — `grep -qw` uses word boundaries; a field named `config` does not match inside `my_config`. ✓ (Independently verified.)

The predicate's bias toward over-emission (emit unless proven "new") matches the direction `.claude/rules/config-default-blast-radius.md` exists to protect (PR #2384's under-emission cost −40.91pp).

### Quality Score

5 — Focused fix with load-bearing test fixtures (assertions 22 and 23 confirm both correctness and lack of regression); all gates pass; predicate is conservative and sound.

## Verdict

APPROVED


---

## Behavioral QC — harness/goldens-nested-new-field (PR #2748)

Reviewed SHA: 5232a8cf3b7958f953dbbdbee8b6626368ff11b5

### Scope

Pure harness / devtools PR — no domain logic. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the entire Weinstein S*/L*/C*/T* block is **NA**; review is through the generic
CP1–CP4 Contract Pinning Checklist alone.

The contract under review is not "the false positive is gone" but
**"nothing that previously FAILed correctly now passes"** — `goldens_affected_check.sh`
is the required PR gate behind `.claude/rules/config-default-blast-radius.md`,
which exists because #2384 merged a config-default flip on green CI at a cost of
−40.91pp. This PR makes that gate fire *less* often, so over-suppression is the
only failure mode that matters.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Non-trivial docstring claims pinned by tests | PASS | No new `.mli` (shell PR); the `.sh` header block is the operative contract. Claim "outer knob emitted only when ≥1 changed field already existed at BASE_REF, whole-word presence check" → matches the code exactly (`git show "${BASE_REF}:${f}" \| grep -qw -- "$knob_field"`, gate `HAS_PREEXISTING_FIELD -eq 1`). Pinned by assertions 22 (additive → suppress) + 23/18 (pre-existing → emit). Header, in-line comment, and `dev/status/harness.md` entry all describe the predicate accurately — no drift. |
| CP2 | PR-body "Tests" claims exist in the committed test file | PASS | Every claim independently re-verified, not taken on report. "21 → 23 assertions": `^echo "=== Assertion` count is 21 at `HEAD~1`, 23 at HEAD. "all passing": `sh goldens_affected_check_test.sh` → **exit 0, 23 passed 0 failed** (read unpiped). "Assertion 22 verified RED against the pre-fix script (22/23, assertion 22 failing)": **reproduced exactly** — ran the new suite against `git show HEAD~1:…check.sh` → exit 1, `22 passed, 1 failed`, sole failure `assertion 22`, failing with the reported false-positive FAIL. Test is wired into `dune runtest` (`trading/devtools/checks/dune` line 937, with `_check_lib.sh` + the script as explicit deps). |
| CP3 | Invariant tests pin identity, not just a count | PASS | The load-bearing invariant is behavioural identity of the FAIL path, and it is asserted as identity: assertion 23 requires `rc=1` **and** `'stops_config'` **and** `embeds:stop_types.mli` **and** `fixture-golden.sexp` in the output — the specific knob, the specific provenance tag, and the specific spec, not merely "some FAIL". Assertions 14/18 retain the pre-existing nested FAIL shapes unmodified. |
| CP4 | Docstring guards exercised by tests | PASS | Guard "a field that changed value keeps its name in the BASE_REF file … never misses a real value-change" → assertion 23. Guard "the same carve-out Step 4b applies to top-level knobs, extended to the nested case" → assertion 22 + unmodified 21. One half-claim is unpinned — the docstring says "value-change **or removal**" and no committed assertion covers removal — but I verified the removal shape is safe by direct probe (R1 below), so it is recorded as a residual per the unpinned-but-**safe** rule rather than a FAIL. |
| A1 | Core module modification strategy-agnostic | NA | qc-structural did not flag A1; no core module touched. |

### Weinstein Behavioral Checklist

| # | Status |
|---|--------|
| S1–S6, L1–L4, C1–C3, T1–T4 | **NA** — pure harness / devtools PR; touches no stage classifier, stop, screener, or macro logic. Domain checklist not applicable. No `BOOK-CHECK-NEEDED` items arise. |

### Independent verification performed

All work done in `/tmp/mut` against copies; the worktree was never mutated
(`git status --porcelain` shows only the pre-existing `dev/reviews/harness.md`
edit; no `.orig`/`.bak` anywhere).

**1. Assertion 22 pins the bug, not the fix** — reproduced (above). A fixture
green both before and after would pin nothing; this one is genuinely RED
pre-fix, and it is the *only* assertion that flips, so the fix is both
load-bearing and isolated.

**2. Assertion 23 is a real over-suppression guard** — mutation-tested:

| mutant | effect | suite result | 23 caught it? |
|---|---|---|---|
| gate → never true (never emit outer knob) | max over-suppression | 21/23 | **yes** (with 18) |
| gate inverted (`-eq 1` → `-eq 0`) | inverted classification | 20/23 | **yes** (with 18, 22) |
| `grep -qw` → `grep -q` (drop word-boundary) | *widens* matching | 23/23 | no — see R4 |

Assertion 23 dies under both narrowing mutants, so it is a genuine guard.

> **Polarity correction to the review brief.** The brief asked me to confirm 23
> goes red "if the predicate were **widened** (e.g. drop the `-w`)". It does not,
> and it should not: widening makes the check emit **more**, and 23 asserts a
> FAIL, so it stays green by construction. Assertion 23 guards the **narrowing**
> direction — which is the correct polarity for it to guard, since narrowing is
> the #2384 failure mode. The guard is real; the brief's stated mutation was
> simply the wrong direction to test it with.

**3. Adversarial diff shapes (item 4).** Nine bespoke fixtures against the
post-fix script. `EMIT` = outer knob emitted → gate FAILs (safe);
`SUPPRESS` = gate passes.

| # | shape | result | safe? | pinned? |
|---|---|---|---|---|
| S1 | field **renamed** in the same commit | EMIT | safe | no |
| S2 | new field whose name is a **substring** of an existing identifier (`stop_pct` vs `catastrophic_stop_pct`) | SUPPRESS | safe — genuinely new, `-w` correctly refuses the substring match | no |
| S3 | field **added *and*** another field's default **changed**, same record | EMIT | safe | no |
| S4 | field **removed** | EMIT | safe | no |
| S5 | entire nested config **file** is new at HEAD | SUPPRESS | safe — all fields new, nothing can inherit | no |
| S6 | new field whose name appears only in a BASE_REF **comment** | EMIT | safe — the documented over-emit bias, working | no |
| S7 | `.ml` record-literal, pre-existing value changed | EMIT | safe | no |
| S8 | `.ml` record-literal, brand-new field | SUPPRESS | safe | no |
| S9 | `.ml` record-literal, **mixed** add + value-change | EMIT | safe | no |

**Zero unsafe suppressions across all nine.** This is structural, not luck:
`_changed_body_lines` captures both `+` **and** `-` diff lines, so any
pre-existing field that changed or was removed contributes *its own name* to
`FILE_KNOBS`, and that field's declaration line is by construction present in
the BASE_REF text with the name as a whole word (`foo : …` / `foo = …`). A
pre-existing changed field therefore cannot fail the `grep -qw` presence test.
The rename case (S1) is safe for the same reason — the `-` line carries the old
name. Assertions 22/23 exercise only the `.mli` `[@sexp.default]` extractor;
S7–S9 confirm the `.ml` record-literal extractor feeds the same predicate with
identical, safe behaviour.

### Residuals (unpinned but verified safe — not FAILs)

- **R1** — the docstring claims the predicate "never misses a real value-change
  **or removal**"; removal (S4) has no committed assertion. Verified safe by
  probe. *harness_gap: LINTER_CANDIDATE* — a 24th assertion mirroring 23 with a
  deleted field is a few lines.
- **R2** — the **mixed** add + value-change shape (S3/S9) is the most realistic
  real-world PR shape and the one where suppression would be most damaging; it
  is unpinned. Verified safe. *harness_gap: LINTER_CANDIDATE.*
- **R3** — the `.ml` record-literal path through the new predicate (S7–S9) is
  unpinned; 22/23 are `.mli`-only. Verified safe. *harness_gap: LINTER_CANDIDATE.*
- **R4** — dropping `-w` survives the whole suite (23/23). This is the
  *over-emitting* direction (a substring collision would resurrect the #2643
  false positive but can never suppress a real change), so it is a cosmetic
  hole, not a safety hole. *harness_gap: ONGOING_REVIEW.*

None of these blocks approval: each is unpinned-**and-safe**, verified by direct
probe in this review. Together they would make a tidy single follow-up
(assertions 24–26) if the harness track wants belt-and-braces on a gate this
load-bearing.

## Quality Score

5 — Exemplary: a narrow, well-reasoned fix to a required merge gate whose
central safety claim I could not break in nine adversarial probes and three
mutants; the RED-pre-fix reproduction and the over-suppression guard are
exactly the two fixtures that matter, and the header, in-line comment, and
status entry all describe the predicate accurately.

## Verdict

APPROVED
