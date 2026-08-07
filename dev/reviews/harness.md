Reviewed SHA: a89e61da97ab690eb2c407a669865f37799f3681

## Structural QC — harness/audit-hook-gate-truthy (PR #2221), rework iteration 1 — DELTA

Delta re-review over my APPROVED 5/5 at `bd06c68c`, covering qc-behavioral's F1 rework.

### Scope gate: is this really test-file-only?

**Yes, verified by blob hash, not by diff-reading.** `write_audit.sh` is
`54c5b9f9ede5374fb7f5f0faf77a1f834de4175d` at *both* `bd06c68c` and `7416161e` — genuinely
byte-identical, so the entire code-under-test surface is unchanged and every conclusion about
it carries forward. Delta is 2 files, +87/−31: `record_qc_audit_test.sh` and
`dev/status/harness.md`. Counts held at **30 passed / 26 scenarios** — the two scenarios got
stronger in place rather than multiplying, as claimed.

### Delta checklist

| # | Check | Status | Basis |
|---|-------|--------|-------|
| H1 | `dune build @fmt` | PASS | **re-derived** — exit **0** |
| H2 | `dune build` | PASS | **re-derived** — exit **0** |
| H3 | `dune runtest` | PASS | **re-derived** — full repo exit **0**; `dune runtest devtools/checks/ --force` exit **0** → `record_qc_audit_test: 30 passed, 0 failed`, all four of `PASS: scenario 25a/25b/26a/26b` present in dune's own output with the new "all 6 documented 'off' spellings" wording. Uncached execution confirmed. `posix_sh_check` green (62 scripts clean). |
| P1 | Functions ≤ 50 lines | NA | **carried** — delta adds no OCaml; linter scans `lib/*.ml`. |
| P2 | No magic numbers | NA | **carried** — same reason. |
| P3 | Configurable values in config record | NA | **carried** — no tunable introduced; `HOOK_DISABLE_VALUES` is a test fixture enumerating a documented contract, not a tunable. |
| P4 | `.mli` coverage | NA | **carried** — no OCaml modules. |
| P5 | Internal helpers prefixed per convention | PASS | **re-derived** (test file changed) — `_run_write_audit_25/26` unchanged and still `_`-prefixed; new identifiers (`HOOK_DISABLE_VALUES`, `offenders25/26`, `seen25/26`, `hookval25/26`) are loop-local test state, not helpers, and follow the file's existing naming. |
| P6 | Test-patterns conformance | NA | **carried** — rules file governs OCaml OUnit2+Matchers; no `.ml` test files. Spirit satisfied and improved: failures now name the offending values rather than dumping raw output. |
| A1 | Core module modifications | PASS | **carried** — delta touches no `trading/trading/{portfolio,orders,position,strategy,engine}/`. |
| A2 | `analysis/` → `trading/trading/` imports | NA | **carried** — no `dune` files touched. |
| A3 | No unnecessary modifications | PASS | **re-derived** — 2 files, both strictly in scope for F1 (the two loops + the status record). No drift. |

### 1. MT1 re-run — the iteration-counter guard

Re-ran it myself. **Reproduces exactly as claimed:**

```
FAIL: scenario 25a — ... for all 6 documented 'off' spellings; exercised 5; offending values:none
FAIL: scenario 26a — ... exercised 5, record_present=yes; offending values:none
```
→ 28 passed, **2 failed**. The guard is correct: unquoting drops the empty element, `seen`
falls to 5 while `${#HOOK_DISABLE_VALUES[@]}` stays 6, and `offending values:none` is exactly
the "shrank rather than broke" signature a value-by-value check cannot produce. The guard
itself is not wrong.

### 2. Vacuity probe — the guard is narrower than it looks (FINDING, non-blocking)

The coordinator asked whether the counter covers an emptied array or a skipped loop body.
**It does not.** The counter compares `seen` against `${#HOOK_DISABLE_VALUES[@]}` — *both
derived from the same array* — so it is invariant to the array's contents. Two probes:

- **MV-A, `HOOK_DISABLE_VALUES=()`:** suite goes red 28/2 — but via **25b and 26a's
  independent record-existence checks, not the counter**. Scenario 25a itself **passes
  vacuously**, emitting the self-evidently absurd `PASS: scenario 25a — all 0 documented
  'off' spellings (0 false no yes true '') leave ... disabled`.
- **MV-B, `HOOK_DISABLE_VALUES=(0)`:** **30 passed, 0 failed — exit 0, entire suite green.**

MV-B is the one that matters: trimming the list back to `(0)` or `(0 false)` silently
reproduces *the exact defect F1 was filed for* — docstring promises seven spellings, tests
assert fewer — with zero signal. The guard defends the empty-element mechanism only, not list
content.

**Not scored as a FAIL**, on three grounds: (a) the current state is correct — all six
documented values are genuinely pinned, verified below; (b) the PR does not overclaim — the
in-code comment scopes itself to "that specific refactor" and the status file to "the loop
mechanics trap", both accurate as written; (c) this guards against a hypothetical future edit,
which is defence-in-depth, not correctness. **Cheap hardening if the writer wants it:** assert
`seen` against a separately-declared literal (`HOOK_DISABLE_EXPECTED_COUNT=6`) instead of
`${#HOOK_DISABLE_VALUES[@]}` — one line, and it catches MT1, MV-A and MV-B alike.

### 3. Does the shared array actually kill MW1/MW5? Yes — verified

Both widening mutations applied to *both* hook sites, each restored before the next:

| Mutation | Result | Offenders named |
|---|---|---|
| **MW1** (gates → `1\|true\|yes`) | 28 passed, **2 failed** (25a, 26a) | `[yes](rc=1) [true](rc=1)` |
| **MW5** (fire on non-empty except `0`/`false`) | 28 passed, **2 failed** (25a, 26a) | `[no](rc=1) [yes](rc=1) [true](rc=1)` — and 26a reports `record_present=yes`, i.e. the original bug's published-record blast radius, back under a different spelling and now caught |

Restore → 30/0. The offender lists match the status file's recorded battery verbatim. The
shared-array coupling is the right call: symmetry between the two hooks is the property under
protection, and one list cannot drift against itself.

### 4. The `TRUE` / `01` removal reasoning — spot-checked, and it holds

This was load-bearing for the list being *exactly six*, so I tested the two gate shapes
directly rather than trusting the note. `write_audit.sh` runs under `set -euo pipefail`
(line 82), which is what makes the argument work:

- **Arithmetic gate `(( VAR == 1 ))`:** `false`/`no`/`yes`/`true` each become an unset *variable
  name* in arithmetic context → `unbound variable` → rc=1. Confirmed end-to-end (mutation MA):
  28 passed, 2 failed, offenders `[false] [no] [yes] [true]`. `01` would fire (octal → 1) but
  is **not the sole detector** — the gate is already caught four times over.
- **Case-folding gate:** any gate accepting `TRUE` accepts `true` by construction; `true` is in
  the list and fires. `TRUE` detects nothing new.

So both dropped values were genuinely redundant, the recorded negative result is accurate, and
the list is not one value short.

### 5. Uncached dune execution

Confirmed, as last pass. Full-repo `dune runtest` again served the suite from cache; the forced
`dune runtest devtools/checks/ --force` run (exit 0) shows all four new assertions executing
with the updated 6-value wording.

## Quality Score

4 — Good: the rework closes F1 properly (MW1/MW5/MA all caught with precise offender
reporting), the shared array is the right anti-drift call, and the `TRUE`/`01` negative result
holds up under direct test; held back from 5 only by the counter guard being narrower than it
reads — `HOOK_DISABLE_VALUES=(0)` still passes 30/30, re-opening F1's exact shape with no
signal, fixable in one line.

## Verdict

APPROVED

Raw exit codes: `dune build @fmt` = **0**, `dune build` = **0**, full-repo `dune runtest` = **0**,
`dune runtest devtools/checks/ --force` = **0**. Counts unchanged at 30 assertions / 26
scenarios, measured directly at this tip.

---

## Behavioral QC — harness/audit-hook-gate-truthy (PR #2221), rework iteration 1 — DELTA

Reviewed SHA: 7416161efe747b6ea9fabc05a701bc8da6868cb5

Scope: `write_audit.sh` is byte-identical across `bd06c68c..7416161e` — independently confirmed
by blob hash (`54c5b9f9ede5374fb7f5f0faf77a1f834de4175d` at both), not by reading the diff. The
delta is `record_qc_audit_test.sh` + `dev/status/harness.md` only.

Baseline at this tip: `bash record_qc_audit_test.sh` = **exit 0**, `30 passed, 0 failed`.
`dev/lib/run-in-env.sh dune runtest devtools/checks/ --force` = **exit 0** (uncached, suite line
present in output).

### F1 is closed — verified with my own two mutations, not the author's report

Both mutations that passed 30/30 green at `bd06c68c` now go red:

| mutation (of `write_audit.sh`) | @bd06c68c | @7416161e |
|---|---|---|
| **MW1** gates widened to `1\|true\|yes` | exit 0, **30/0 green** | exit 1, **28/2** — `offending values: [yes] [true]` |
| **MW5** gates fire on non-empty except `0`/`false` | exit 0, **30/0 green** | exit 1, **28/2** — `offending values: [no] [yes] [true]`, and 26a reports **`record_present=yes`** |

MW5 is the one that mattered: it reinstates the original filed bug (`VAR=no` fires, publishing
the record and returning rc=1). 26a now catches it *and* reports the published-record blast
radius in the failure text. The contract "only the literal `1` enables" is now pinned as a claim
over the documented set rather than two enumerated instances. **F1 resolved.**

The `TRUE`/`01` negative result is sound and I accept structural's confirmation without
re-deriving it: under an arithmetic gate `false`/`no`/`yes`/`true` are unset *names* that trip
`set -u`, so `01` is never the sole detector, and case-folding is already caught by `true`.
Recording a measured negative in the comment so it is not re-attempted is the right instinct.

### Judgement on the residual — my call: **not blocking**

I reproduced all three probes exactly:

| mutation (of the test) | result |
|---|---|
| **MT1** unquoted `${HOOK_DISABLE_VALUES[@]}` | exit 1, 28/2 — `exercised 5; offending values:none` (matches structural) |
| **MT2** array shrunk to `(0)` | **exit 0, 30/0 fully green** |
| **MT3** array emptied `()` | exit 1, 28/2 — but **25a passes vacuously** (`all 0 documented 'off' spellings`); 26a fails only via its independent `[[ -f "${JSON26}" ]]` |

**I do not think this is my F1's shape, and that is the basis of the call.** The two differ in
what can regress behind them:

- **F1 was a coverage gap.** A mutation of the *system under test* reintroduced a real, filed
  production bug while the harness stayed green. The code could regress and nothing would notice.
- **The residual is test-weakening.** MT2 mutates the test's own input data. `write_audit.sh` is
  untouched and still correct; nothing about the product regresses. This is the universal
  property that any suite can be weakened by deleting assertions — every test file in this repo
  has it.

On the coordinator's sharper question — is a guard that appears to cover shrinkage but doesn't
*worse* than no guard? **No, and MT1 is why.** The counter is not inert: it catches the unquoted
expansion silently dropping the `""` element, which is genuinely invisible in review. What it
misses is deliberately editing a six-element list down to one, on the line directly beneath an
eight-line comment explaining why the list is exactly what it is — precisely the kind of change
human review *does* catch. So the guard covers the low-visibility failure and leaves the
high-visibility one to the reviewer. That division is sensible, not a trap.

Nor does the prose set up the misreading: the comment says the counters exist to make **"that
specific refactor"** go red, naming the unquoted expansion. It is accurately scoped, and the
status file's "the loop mechanics trap" is likewise accurate. There is no overclaim to fail on
— which is the CP4 test, and it passes.

**One real wart, for the follow-up.** Under MT2 the green pass line reads:

> `all 1 documented 'off' spellings (0 false no yes true '')`

The count says one, the hardcoded parenthetical asserts six. A green suite emitting a
self-contradicting coverage claim is the thing that would actually mislead a future reader —
more than the counter's scope does. Structural's suggested one-liner
(`HOOK_DISABLE_EXPECTED_COUNT=6`, compared independently of the array) fixes MT1, MT2 and MT3
alike and makes the message unreachable in that state. Worth doing; worth doing standalone,
where the literal-vs-array drift question can be thought about on its own rather than under
rework pressure. (Being within cap is consistent with merging, but is not part of my reasoning.)

### Contract Pinning Checklist (delta)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | `.mli` docstring claims pinned | NA | Carried forward — shell PR, no `.mli`. The `ACCEPTED SPELLING:` blocks live in `write_audit.sh`, byte-identical across the delta, so the delta cannot move this row; assessed under CP4. |
| CP2 | PR-body / status-file claims have committed tests | PASS | Delta claims re-measured at this tip: "counts unchanged at 30/26" ✓ (measured 30 passed, 26 scenarios); "MW1 and MW5 both now go red" ✓ (28/2 each, offenders as documented); "MT1 reproduces `exercised 5; offending values:none`" ✓. The status file additionally files my F2/F3 as tracked items (`H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED`, `H-AUDIT-TEST-SUT-READ-UNGUARDED`) and self-files the `REPO_ROOT` trap that bit me — accurate, no overclaim. |
| CP3 | Identity/invariant tests pin identity, not size | PASS | Carried forward — 25b's byte-identity assertion and its `[[ != "MISSING" ]]` precondition are untouched by the delta (confirmed in the diff). |
| CP4 | Documented guards have tests exercising the guarded-against scenario | **PASS** (was FAIL) | All six documented "off" spellings (`0 false no yes true ""`) are now exercised by both 25a and 26a via the shared array. The seventh documented state, *unset*, is covered by scenarios 1-24, none of which sets either hook and all of which require normal completion — the comment's reasoning here is correct, `VAR=""` sets-to-empty rather than unsetting, so the two states genuinely needed separate coverage and both have it. |

### Domain block

Unchanged and explicitly **NA**: the delta touches `trading/devtools/checks/` and
`dev/status/harness.md` only. Whole S\*/L\*/C\*/T\* block NA, A1 NA. Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".

### Follow-up to file (non-blocking)

**H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL** — `record_qc_audit_test.sh:1257` +
25a/26a pass conditions. `seen{25,26}` is compared against `${#HOOK_DISABLE_VALUES[@]}`, both
derived from the same array, so the check is invariant to the array's *contents*: shrinking it
to `(0)` leaves the suite 30/0 green while the pass line still claims six spellings, and
emptying it to `()` leaves 25a passing vacuously. Catches loop-mechanics regressions (MT1,
`exercised 5`), not list-shrinkage. Fix: a standalone literal `HOOK_DISABLE_EXPECTED_COUNT=6`
compared independently of the array, which covers MT1/MT2/MT3 together.
`harness_gap: LINTER_CANDIDATE` — "an expected-count guard must compare against a literal, not
against the length of the same collection it iterates" is a greppable rule, and it generalises
past this file.

## Quality Score

4 — Good. The finding is properly closed at the level of the contract rather than the two
reported values: MW1 and MW5 both go red, MW5 with the published-record blast radius surfaced in
the failure text. Sharing one array across both hooks so symmetry cannot drift, and recording
the measured `TRUE`/`01` negative so it is not re-attempted, are both better than the minimum
asked. Held at 4, not 5, for the tautological iteration guard — harmless in the present state
and honestly scoped in the prose, but it leaves a green suite able to print a coverage claim it
did not meet.

## Verdict

APPROVED

Residual filed as `H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL` (non-blocking, one-line fix,
better standalone).

Raw exit codes — baseline `record_qc_audit_test.sh` = **0** (30/0);
`dune runtest devtools/checks/ --force` = **0** (30/0, uncached);
MW1 = **1** (28/2); MW5 = **1** (28/2); MT1 = **1** (28/2); MT2 = **0** (30/0, the residual);
MT3 = **1** (28/2, 25a vacuous).

Tree left clean: `write_audit.sh` and `record_qc_audit_test.sh` both restored byte-identical to
tip after every mutation (`diff -q` clean). No stray audit record this pass — the `REPO_ROOT`
trap that bit me at `bd06c68c` is now itself a filed item
(`H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE`). `dev/reviews/support-floor-stops.md`,
`trading/compile_commands.json` and the orchestrator's `dev/audit/*.json` untouched.

---

Reviewed SHA: bd06c68ce9ab195efbe533880f750b4a85d6ffec

## Structural QC — harness/audit-hook-gate-truthy (PR #2221)

### Context

Closes H-AUDIT-HOOK-GATE-TRUTHY (F1) and H-AUDIT-TEST-FAILS-OPEN-WORDING (F3) from
#2211. Pure shell/harness PR — no OCaml. Reviewed in the GHA orchestrator container
(no docker, no jj, no gh); build gates via `dev/lib/run-in-env.sh`. Mutation testing
done in throwaway `git worktree add --detach` checkouts so the shared working tree was
never mutated; both removed afterward.

**File list** (canonical, `git diff --name-only origin/main...bd06c68c` — `gh` unavailable):
`dev/status/harness.md`, `trading/devtools/checks/record_qc_audit_test.sh`,
`trading/devtools/checks/write_audit.sh`. 3 files, +164/−6 — matches the PR body exactly.
Branch is 1 commit ahead of `origin/main` and **0 behind** (merge-base = `480a59b7` = tip
of main, i.e. includes #2220). No staleness FLAG.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | `dune build @fmt` | PASS | exit **0** |
| H2 | `dune build` | PASS | exit **0** |
| H3 | `dune runtest` (full repo) | PASS | exit **0**. `record_qc_audit_test` was served from dune cache in the full run, so I re-ran `dune runtest devtools/checks/ --force` (exit **0**) to prove the new scenarios genuinely execute under dune: `record_qc_audit_test: 30 passed, 0 failed`, with `PASS: scenario 25a/25b/26a/26b` all present in dune's own output. `posix_sh_check` green (62 scripts clean). |
| P1 | Functions ≤ 50 lines | NA | `fn_length_linter` scans `lib/*.ml`; no OCaml in diff. Green under H3. |
| P2 | No magic numbers | NA | `linter_magic_numbers.sh` scans `lib/*.ml`; no OCaml in diff. Green under H3. |
| P3 | Configurable values in config record | NA | No tunable threshold/period/weight introduced. The literal `"1"` in the gates is not a tunable — it is the *accepted-spelling contract itself*, documented at both sites. |
| P4 | Public-symbol export hygiene (`.mli`) | NA | `linter_mli_coverage.sh` scans `lib/*.ml`; no OCaml modules added. Green under H3. |
| P5 | Internal helpers prefixed per convention | PASS | New shell helpers `_run_write_audit_25` / `_run_write_audit_26` carry the `_` prefix, matching the file's existing convention (`_is_nonneg_int`, `_repo_root`). |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | That rules file governs OCaml OUnit2 + `Matchers`; the three greppable sub-rules are OCaml-specific and no `.ml` test files are in the diff. Applied in spirit and satisfied: every new assertion checks a concrete observable (rc, record presence, `OK:`/abort message, content identity), never "ran without error". |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No files under `trading/trading/{portfolio,orders,position,strategy,engine}/`. Nothing to route to qc-behavioral. |
| A2 | `analysis/` → `trading/trading/` import direction | NA | No `dune` files touched; no library dependencies added or changed. |
| A3 | No unnecessary modifications to existing modules | PASS | All 3 files are in-scope for the two follow-ups: the two hook sites, their regression pins, and the status-file checkboxes. No cross-feature drift. |

### Verification beyond the checklist

**1. Is the fix complete?** Yes. After the change, `write_audit.sh` retains exactly two
`[ -n "${VAR:-}" ]` gates, and **neither is the same defect class**:
- L164 `REPO_ROOT` — a path override, not a boolean flag; empty == unset is correct semantics.
- L224 `WRITE_AUDIT_RECORDED_AT_NS` — a *value* override, not a boolean. `=0` is a legitimate
  timestamp, and `=false` fails **loudly** via `_is_nonneg_int` (`FAIL: ... must be a
  nonnegative integer` + `exit 1`). There is no silent-disable failure mode, so `-n` is the
  right gate. Correctly left alone.

No other test/debug env gate exists in the script or in `record_qc_audit_test.sh`. The only
in-repo caller is the test script, which sets `=1`.

**2. Did the fix kill the hooks?** No — and I re-ran MG3 myself, as it is the dangerous
failure mode. **All three mutations reproduce the PR body's table exactly**, each restored
before the next; restoring returned 30/0 every time:

| Mutation | Claimed | **Measured** |
|---|---|---|
| MG1 (BEFORE gate → `-n`) | 2 F | **28 passed, 2 failed** — 25a, 25b. 25b reports `prior_record_present=no` ✓ |
| MG2 (AFTER gate → `-n`) | 1 F, `record_present=yes` | **29 passed, 1 failed** — 26a: `got rc(0)=1, rc(false)=1, record_present=yes` ✓ exactly the blast-radius asymmetry |
| MG3 (both gates dead) | 4 F incl. 19 and 24 | **26 passed, 4 failed** — 19, 24, 25b, 26b ✓ |

MG3 is the load-bearing one and it holds: had the fix over-corrected into permanently-dead
hooks, the suite catches it *and* surfaces the collateral damage to the pre-existing
atomicity (19) and mode-order (24) pins. The (b)-direction scenarios are doing real work.

**3. The self-found harness bug (25b's unguarded `cat`).** Guard is correct.
`CONTENT_25_BEFORE="$(cat "${JSON25}" 2>/dev/null || echo MISSING)"` prevents `set -euo
pipefail` from killing the run when no record exists — verified empirically: under MG1
(where the record genuinely does not exist) the run completed, printed a full summary, and
reported scenario 26. The `[[ "${CONTENT_25_BEFORE}" != "MISSING" ]]` precondition genuinely
prevents the vacuous pass: under MG1, 25b **failed** with `prior_record_present=no` rather
than passing on `MISSING == MISSING`. The author avoided the self-inflicted version of the
bug class.

**4. `ACCEPTED SPELLING:` docs.** Present at both hook sites, accurate against
`[ "${VAR:-0}" = "1" ]`, and mutually consistent (BEFORE enumerates `0/false/no/yes/true/
empty/unset`; AFTER states the same rule more briefly and cross-references BEFORE for the
rationale). The asymmetry argument for rejecting `1|true|yes` is sound and is the right call.

**5. Dune wiring intact.** `trading/devtools/checks/dune` (unchanged) declares
`(deps record_qc_audit.sh write_audit.sh)` + `(run bash %{dep:record_qc_audit_test.sh})`.
Because both changed files are dune deps, the cache key invalidates — confirmed by the forced
run above. Invocation with `bash` (not `sh`) is deliberate and documented; both files carry
`#!/usr/bin/env bash`, and `posix_sh_check.sh` explicitly skips bash-shebang scripts
(`_is_bash_script`), so the `[[ ]]` / `(( ))` constructs are legitimately out of scope rather
than slipping past the linter.

**6. Counts, measured independently** (running the script at each revision myself):

| | assertions | scenarios |
|---|---|---|
| `origin/main` (`480a59b7`) | **26 passed, 0 failed** | **24** |
| tip (`bd06c68c`) | **30 passed, 0 failed** | **26** |

Matches the claimed `26/24 → 30/26`. No behaviour change to records confirmed: scenario 23
(mode 644) and scenario 24 (static chmod-before-`mv` order) both still pass unchanged.

**7. Comment fix (F3).** `fails open` → `fails CLOSED` is correct, and the rewording names a
guard that actually exists: `[[ -n "${CHMOD_TMP_LINE_24}" ]]` at L1167, with
`source_order_ok=0` defaulting closed at L1166. Zero remaining "fails open" occurrences.
Comment-only; no executable line touched.

### Non-blocking observations (no action required)

- `$(cat ...)` strips trailing newlines on both sides of the 25b comparison, so
  "byte-identical" is precisely "identical modulo trailing newlines". Adequate for the
  property being pinned (abort-before-rename leaves the record intact); noting only because
  the comment says "byte-identical".
- `write_audit.sh:437`'s pre-existing "Mirrors the `WRITE_AUDIT_RECORDED_AT_NS` test-only
  override above" is now a slightly looser analogy, since the two use different gate forms
  for good reason (flag vs. value). The sentence is about the *test-only override* concept,
  so it still reads correctly.

## Quality Score

5 — Exemplary: complete fix with no missed gate sites, an anti-over-correction guard that I
independently confirmed catches the dangerous failure mode, a self-found harness bug fixed
with a non-vacuous precondition, and a mutation table that reproduces exactly as documented.

## Verdict

APPROVED

Raw exit codes: `dune build @fmt` = **0**, `dune build` = **0**, full-repo `dune runtest` = **0**,
`dune runtest devtools/checks/ --force` = **0**.

---

## Behavioral QC — harness/audit-hook-gate-truthy (PR #2221)

Reviewed SHA: bd06c68ce9ab195efbe533880f750b4a85d6ffec

Baseline: `bash record_qc_audit_test.sh` = **exit 0**, `30 passed, 0 failed`.
`dev/lib/run-in-env.sh dune runtest devtools/checks/ --force` = **exit 0** (uncached;
`record_qc_audit_test: 30 passed, 0 failed` present in output).

Structural's MG1/MG2/MG3 were not re-run (accepted as verified). All mutations below are new.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | NA | Shell PR; no `.mli`. The two `ACCEPTED SPELLING:` comment blocks (`write_audit.sh:439-453`, `499-506`) are the docstring-equivalent contract and are assessed under CP4. |
| CP2 | Each PR-body / status-file claim has a corresponding committed test | PASS | `dev/status/harness.md` claims "+2 scenarios / +4 assertions; 26 across 24 → 30 across 26" — confirmed: 25a/25b/26a/26b are 4 new assertions in 2 new scenarios; measured total 30. Claim "no behaviour change to the records themselves — mode still 0644, still atomic, chmod-before-`mv`; scenario 24's static order check passes unchanged" — confirmed, 23 and 24 both green. F3 (fails-open→fails-closed rewording) is comment-only; verified no executable line changed in that hunk. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | Scenario 25b pins byte-identity (`CONTENT_25_AFTER == CONTENT_25_BEFORE`) and the `[[ != "MISSING" ]]` precondition makes it non-vacuous — the correct shape, not a `size_is` stand-in. |
| CP4 | Each guard called out explicitly in the docstrings has a test exercising the guarded-against scenario | **FAIL** | The `ACCEPTED SPELLING:` blocks promise **seven** enumerated values leave the hook disabled (`0`, `false`, `no`, `yes`, `true`, empty, unset). Tests pin **two** (`0`, `false`) plus `unset` implicitly. `no` / `yes` / `true` / empty are named-but-unpinned, and mutation **MW5** below reintroduces the original bug through `no` with the suite fully green. See F1. |

### Domain block — explicit call

Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely": this PR
touches only `trading/devtools/checks/` (test harness) and `dev/status/harness.md`. No stage
classifier, screener, stops, sizing, or strategy logic. **The entire S\*/L\*/C\*/T\* block is NA**
— pure harness PR; domain checklist not applicable. **A1 = NA** (qc-structural raised no A1
flag; no core module touched).

### Verification of the author's asymmetry argument (requested — checked, not admired)

The PR justifies the narrow contract by claiming a guessed-wrong *enable* spelling is "loud and
self-correcting". **Measured, and it holds.** I rewrote each of the four committed enable sites
from `1` to `true` in turn, against the unmutated gate:

| enable site | scenario | result |
|---|---|---|
| L880 `ABORT_BEFORE_RENAME=true` | 19 (atomicity pin) | **exit 1**, 29/1, sole FAIL scenario 19 |
| L1136 `ABORT_AFTER_RENAME=true` | 24 (mode-order pin) | **exit 1**, 29/1, sole FAIL scenario 24 |
| L1260 `_run_write_audit_25 true` | 25b | **exit 1**, 29/1, sole FAIL scenario 25b |
| L1303 `_run_write_audit_26 true` | 26b | **exit 1**, 29/1, sole FAIL scenario 26b |

I specifically expected scenario 24 to pass silently (its Part A asserts mode 644, which a
non-firing hook also produces, and Part B is static). It does **not** — 24 also asserts `rc!=0`
and the `simulating interruption right after rename` string, so a non-firing hook goes red on
those conjuncts. My hypothesis was wrong; the author's claim is correct as written.

### Partial hook death (requested — a different mutation from MG1/MG2)

Structural's MG3 killed both gates (4 F). I killed them one at a time:

| mutation | result | failing scenarios |
|---|---|---|
| **MW3** BEFORE gate `= "__never__"`, AFTER left correct | exit 1, 28/2 | 19, 25b |
| **MW4** AFTER gate `= "__never__"`, BEFORE left correct | exit 1, 28/2 | 24, 26b |

Clean decomposition with correct attribution — `{19,25b} ⊎ {24,26b}` is exactly MG3's four, and
each half names the hook that died. **No partial-failure gap.** Negative result, no finding.

### Latent unguarded-substitution audit (requested — the "two instances is a pattern" question)

Delegated a full read-only inventory of every `$(...)` and unconsumed pipeline in the 1300-line
suite, with empirical confirmation (11 mutations of `write_audit.sh` / `record_qc_audit.sh`,
checking whether each run reaches the summary line rather than aborting mid-flight).

**Negative result: no remaining latent instances of the bug class.** All 39 `outN=$(…) && rcN=0 || rcN=$?`
sites are guarded by the sanctioned idiom; the three greps in assignments (L1161-1163) all carry
`|| true` from fix #1; both `cat`s at L1259/1261 carry the `|| echo MISSING` from fix #2; L878's
`cat` sits inside an `[[ -f ]]` else-branch. Ten of eleven mutations reached the summary. Two
low-priority residuals recorded as F2/F3 — neither is in this PR's diff, so neither blocks.

### Findings

#### F1 — `CP4` — the deliberately-narrowed contract is documented but not pinned  **[blocking]**

- **Location:** `trading/devtools/checks/write_audit.sh:439-453` and `:499-506` (the two
  `ACCEPTED SPELLING:` blocks); tests at `record_qc_audit_test.sh:1231-1234`, `1289-1290`.
- **Claim left unpinned:** "the ONLY value that enables this hook is the literal string `1`.
  Every other value — `0`, `false`, `no`, `yes`, `true`, the empty string, unset — leaves the
  hook disabled." The suite pins the two spellings it enumerates, not the contract.
- **Mutation MW1** — both gates widened to `case "${VAR:-0}" in 1|true|yes) …` (precisely the
  `1|true|yes` spelling the PR body argues against at length): **exit 0, 30 passed / 0 failed.**
  The contract decision the author wrote three paragraphs defending is invisible to the suite.
- **Mutation MW5 (the damning one)** — both gates changed to
  `[ -n "${VAR:-}" ] && [ "${VAR:-}" != "0" ] && [ "${VAR:-}" != "false" ]`, i.e. "fire on
  anything non-empty except the two values the tests happen to try": **exit 0, 30 passed / 0
  failed.** Under this mutation the docstring-promised disable value `no` **fires the hook**.
  Direct probe: `WRITE_AUDIT_TEST_ABORT_AFTER_RENAME=no` → `rc=1` with the record already
  published — bit-for-bit the blast radius H-AUDIT-HOOK-GATE-TRUTHY was filed to eliminate.
  The suite is green while the original bug is back under a different spelling.
- **Why this is blocking rather than a nit:** the narrowed contract *is* this PR's deliverable.
  The prior round on #2211 was reworked for a structurally identical defect (finding B1: "a
  behavioral-only pin that was itself incomplete"). A test that enumerates instances where the
  docstring quantifies over a set is the same shape of gap.
- **Required fix:** extend the existing 25a/26a disable-direction checks from the hardcoded pair
  to the full documented set — loop over `0 false no yes true ""` and assert inert for each.
  Roughly a few lines, since both scenarios already run the value twice; the loop replaces the
  duplicated pair. Alternatively narrow the `ACCEPTED SPELLING:` blocks to claim only what is
  tested — but extending the test is the better trade, since the enumeration is the useful part
  of the docstring. MW5 must go red afterward.
- `harness_gap: LINTER_CANDIDATE` — "every value named in an `ACCEPTED SPELLING:` block appears
  in a test in this suite" is a deterministic grep-level check.

#### F2 — non-blocking follow-up — 20 unguarded `find | wc -l` pipelines

- **Location:** `record_qc_audit_test.sh` L367, 424, 546, 552, 623, 628, 646, 653, 691, 697, 730,
  735, 769, 774, 794, 801, 821, 828, 887, 938.
- `X="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name … | wc -l | tr -d ' ')"` — exactly the
  crash shape (unguarded pipeline in an assignment; `pipefail` turns `find`'s rc=1 into a
  run-killer, and L367 aborts before any summary). Reachable only if `${TMP_REPO}/dev/audit`
  disappears mid-run; no plausible `write_audit.sh` mutation removes it (it took a hand-written
  `rm -rf "$AUDIT_DIR"` to trigger, which did abort at L367). Defense-in-depth only.
- **Fix:** `"$(find … 2>/dev/null | wc -l | tr -d ' ' || echo 0)"`. Not this PR's diff.
- `harness_gap: LINTER_CANDIDATE` — same rule would cover F3.

#### F3 — non-blocking follow-up — unguarded read of the script under test

- **Location:** `record_qc_audit_test.sh:1149`,
  `CODE_ONLY_24="$(sed -E 's/^[[:space:]]*#.*$//' "${WRITE_AUDIT}")"`.
- The only unguarded direct read of the SUT. Safe today (`${WRITE_AUDIT}` is the L35 copy and
  nothing deletes it), but it is the one spot where a future refactor pointing the static check
  at a computed path would silently reintroduce the class. `|| echo ''` plus the existing
  `[[ -n … ]]` guards would fail-closed the way L1161's `|| true` already does.
- `harness_gap: LINTER_CANDIDATE`.

### What the PR got right (recorded, since it offsets the score)

F3 (fails-open wording) was **verified before compliance**, not taken on faith — the author
traced B1's behaviour against a chmod-deleted copy and confirmed the phrase was genuinely
inverted rather than editing on instruction. The mid-flight 25b `cat` bug was self-found during
mutation testing and fixed with a *non-vacuous* precondition, which is the harder and correct
version. The anti-over-correction (b)-direction assertions are real load-bearing coverage, as
MW3/MW4 confirm.

## Quality Score

2 — One documented contract, the deliberately-narrowed "only literal `1`" spelling, is left
unpinned: mutation MW5 reintroduces the exact filed bug via `no` with the suite at 30/30 green.
Fixable in a few lines. The surrounding craft is genuinely strong — self-found harness bug,
non-vacuous precondition, verified-before-complying on F3 — but the score tracks the gap, and
the thing left undefended is this PR's central claim.

## Verdict

NEEDS_REWORK

Raw exit codes observed — baseline `record_qc_audit_test.sh` = **0** (30/0);
`dune runtest devtools/checks/ --force` = **0** (30/0, uncached);
MW1 = **0** (30/0, gap); MW5 = **0** (30/0, gap);
MW2 ×4 = **1** each (29/1, correct); MW3 = **1** (28/2); MW4 = **1** (28/2).

Tree left clean: both PR files restored byte-identical to tip (`diff -q` clean); one probe
record I leaked into `dev/audit/` (`2026-08-06-b-probe.json`, from running the real
`write_audit.sh` in place — `REPO_ROOT` is self-computed, not env-overridable outside the
suite's copied harness) was removed. The orchestrator's `compile_commands.json`,
`support-floor-stops.md` and `2026-08-06-feat-split-safe-fallback-*.json` were not touched.

---

Reviewed SHA: c5e06533809855f794b2b62995bb0b003f339600

# QC review — harness track

PR #2184 `harness/prev-verdict-pipefail` (H-PREV-VERDICT-PIPEFAIL). MERGED `94343ea0`.

> **Recovered from GitHub.** The on-disk copies of these three reviews were destroyed
> mid-run by shared-working-tree churn (concurrent agents branch-switching in the single
> GHA checkout). They survived only because the orchestrator posted each one to the PR via
> the REST API immediately after the reviewing agent returned. Restored here verbatim from
> `GET /pulls/2184/reviews`. See the 2026-08-03 run-2 daily summary §Escalations.

---

<!-- github review id 4844920871, state COMMENTED -->

Reviewed SHA: 1bfbb38e54b37e4a5237ba1efb05fc7a4d57ec10

## Structural QC — harness/prev-verdict-pipefail (PR #2184)

### Context

Closes H-PREV-VERDICT-PIPEFAIL. Pure shell/harness PR — 3 files, +161/-3
(`trading/devtools/checks/write_audit.sh`, `trading/devtools/checks/record_qc_audit_test.sh`,
`dev/status/harness.md`). No OCaml touched. Reviewed by ref only
(`git fetch` + `git diff`/`git show` against `origin/main...1bfbb38e`) —
no `jj edit`/`git checkout` performed, per the shared-tree read-only constraint.

Build-gate baseline (main @ merge-base `b4b7a3d0`) reported green by the
dispatcher (`dune build` 0, `dune runtest` 0, `status_file_integrity.sh` 0) —
not repeated here. Independently re-verified the PR's own test claim by
extracting `write_audit.sh` + `record_qc_audit_test.sh` (PR tip) plus the
unmodified `record_qc_audit.sh` (main) into an isolated temp directory
(no shared-tree writes) and running the suite directly:

```
record_qc_audit_test: 24 passed, 0 failed   (PR tip — scenarios 1-22 incl. new 21/22)
```

Then reproduced the author's change-detection claim independently (reverted
only `write_audit.sh` to `origin/main`'s pre-fix shape, kept the new test
file):

```
record_qc_audit_test: 22 passed, 2 failed   (pre-fix write_audit.sh)
  FAIL: scenario 21 — got rc=0/1, consecutive_rework_count=1 (not 2)
  FAIL: scenario 22 — got rc=0/2, consecutive_rework_count=1 (not 2)
```

This matches the PR body's reported 22/2 → 24/0 transition exactly. Scenarios
21/22 are real, non-vacuous assertions — they fail hard against the pre-fix
code and pass against the fix.

### Guard-logic trace (write_audit.sh, NEEDS_REWORK escalation path)

```
prev_grep_status=0
prev_verdict=$(grep -o '...' "$f" 2>/dev/null | head -1 | sed '...') || prev_grep_status=$?
case "$prev_grep_status" in
  0) [ -n "$prev_verdict" ] || continue ;;   # matched-but-empty defensive skip
  1) continue ;;                             # no match — truncated/malformed record
  *) echo "WARNING: ..." >&2; continue ;;    # grep exit >1 — unreadable target
esac
if [ "$prev_verdict" = "NEEDS_REWORK" ]; then CONSECUTIVE=$((CONSECUTIVE + 1)); else break; fi
```

- Under `set -o pipefail`, a pipeline's exit status is the last command to
  exit non-zero (here always `grep`, since `head`/`sed` cannot fail on this
  input) — so `$prev_grep_status` faithfully reflects grep's own exit code.
  Verified directly: `grep -o '...' <directory>` on this container's GNU
  grep 3.7 exits 2 ("Is a directory"), confirming scenario 22's fixture
  (a directory at the `*-<feature>.json` glob path) is a sound, portable,
  root-safe way to force the "unreadable" branch without relying on chmod
  (which root would bypass, as the PR notes).
- Cases `1)` and `*)` both `continue` before the loop reaches the
  `if`/`CONSECUTIVE` logic, so a skipped record neither increments nor
  breaks the streak — exactly the documented "treat as absent from history"
  behavior. Traced by hand and confirmed via the scenario 21/22 assertions
  (`consecutive_rework_count=2`, i.e. current + the older valid record
  *beyond* the truncated/unreadable one — proving the bad record was
  skipped, not counted as a break).
- The `WARNING:` line is written with `>&2` (stderr) and prefixed
  `WARNING:` (not `FAIL:`), so it cannot be mistaken for a `FAIL:` line by
  `pr-merge-gates.md`'s `grep -E 'FAIL:'` CI-log check.
- No remaining unguarded pipeline under `set -euo pipefail` was found in
  the diff — the only other pre-existing extraction of this shape
  (`recorded_at_ns`) was already guarded before this PR (`|| true`) and is
  untouched here.

### Shell portability

Both `write_audit.sh` and `record_qc_audit_test.sh` carry explicit
`#!/usr/bin/env bash` shebangs, which places them in `posix_sh_check.sh`'s
documented EXCLUDED set ("Scripts with explicit bash shebang ... are out
of scope"). Confirmed by reading `posix_sh_check.sh` directly — no
POSIX-sh violation possible here. The new `case`/`$((...))` bash
constructs are fine under this shebang.

### dune wiring

`trading/devtools/checks/dune` already declares
`(deps record_qc_audit.sh write_audit.sh)` for the `record_qc_audit_test.sh`
alias-runtest rule (pre-existing, unmodified by this PR) — the new
scenarios 21/22 ride the existing rule with no dune-file edit needed,
matching the PR's claim ("wired into dune runtest via the existing rule,
unmodified").

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Baseline green on merge base; PR touches no OCaml, no formatting surface changed |
| H2 | dune build | PASS | Same — no OCaml files in diff |
| H3 | dune runtest | PASS | Independently re-ran the targeted suite in an isolated temp dir (not the shared tree): 24 passed, 0 failed at PR tip; reproduced 22 passed/2 failed against pre-fix write_audit.sh, confirming non-vacuous change-detection |
| P1 | Functions ≤ 50 lines (linter) | NA | `fn_length_linter` scopes `.ml` files only; this PR is pure shell |
| P2 | No magic numbers (linter) | NA | `linter_magic_numbers.sh` header states scope is "lib .ml files"; confirmed by reading the script — not applicable to `.sh` |
| P3 | Config completeness | NA | No new tunable threshold/period/weight introduced — this is error-handling/control-flow logic (skip-vs-abort-vs-break decision), not a numeric knob |
| P4 | Public-symbol export hygiene (mli coverage) | NA | No `.mli` files in diff (shell scripts have no interface-file convention) |
| P5 | Internal helpers prefixed per convention | NA | `_`-prefix convention (`ocaml-patterns.md`) is OCaml-specific; shell scripts here use plain descriptive names (`prev_grep_status`, `prev_verdict`), consistent with the rest of this file |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | test-patterns.md governs OUnit2 + the OCaml Matchers library (`assert_that`/`field`/`all_of`); this is a bash smoke-test harness using its own `pass`/`fail` helpers, pre-existing convention for this file, unaffected by this PR |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No core-module files touched |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception | NA | No OCaml/dune files touched, no imports of any kind |
| A3 | No unnecessary modifications to existing (non-feature) modules | PASS | `git diff --name-only origin/main...1bfbb38e` shows exactly the 3 files the PR claims (`write_audit.sh`, `record_qc_audit_test.sh`, `dev/status/harness.md`) — no cross-feature drift |

## Quality Score

5 — All gates pass (independently re-verified, not just re-stated), the guard logic was hand-traced and matches both grep's documented exit-code semantics and the scenario assertions, the new tests are non-vacuous (reproduced red pre-fix / green post-fix), and the fix stays inside the file's existing shell conventions with no scope creep.

## Verdict

APPROVED

## NEEDS_REWORK Items

(None — verdict is APPROVED.)

---
_Posted by the lead-orchestrator on behalf of `qc-structural` (GHA run 30817481526). `gh` is absent in this runtime, so the agent could not post it itself._

---

<!-- github review id 4845010892, state COMMENTED -->

## Behavioral QC — harness/prev-verdict-pipefail (PR #2184)

### Scope note

Pure infra/harness PR (shell script + fixture test + status-file note); no
Weinstein domain logic touched. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the entire domain checklist (S*/L*/C*/T*)
is marked NA below. Review focused on the generic Contract Pinning Checklist
(CP1–CP4), per this track's explicit false-green history (#2169: 22/22 passed
with the invariant broken).

### Independent verification performed

Extracted `write_audit.sh` + `record_qc_audit_test.sh` (PR tip) plus
unmodified `record_qc_audit.sh` (main) into an isolated `/tmp` dir (no
shared-tree writes) and ran the suite directly — reproduced qc-structural's
24/0 (post-fix) and 22/2 (pre-fix, `write_audit.sh` reverted to
`origin/main`) results exactly.

Went one step further than presence-of-test verification, per this track's
explicit false-green mandate: **mutation-tested each specific sub-claim** in
the code docstring / PR body / status-file note to see whether the test
suite would actually catch a regression in that specific claim, not just in
the headline "does it abort" behavior.

**Mutation 1 — skip vs. break (claims 1–2, "the direction decision").**
Changed the `1)` case's `continue` to `break` (i.e., a truncated record
*breaks* the streak instead of being skipped, the "unsafe direction" the
harness item itself names). Result: **scenario 21 goes red**
(`consecutive_rework_count=1`, not the expected `2`) while 22 stays green.
This is real, non-vacuous coverage — the test would catch a regression to
the unsafe direction. PASS.

**Mutation 2 — "silently" (claim 3).** Injected a spurious
`echo "WARNING: ..." >&2` into the exit-1 (`No overall_qc field found`)
branch, i.e. made the "silent" skip also emit a warning. Result: **all 24
scenarios still pass.** Scenario 21 never asserts the *absence* of a
`WARNING:` line on this path, only that `consecutive_rework_count=2` and
rc=0. A regression that made the "silent" path noisy (or, conversely, code
that accidentally routed real unreadable-file failures through the silent
branch) would not be caught. This is exactly the CP4 gap this checklist
exists to find: the docstring makes an explicit, granular claim
("tolerated silently") that the test does not pin.

**Mutation 3 — "naming the file" (claim 4).** Removed `$f` from the
`WARNING: could not read prior audit record for consecutive_rework_count
scan: $f (grep exit $prev_grep_status)` message. Result: **all 24 scenarios
still pass.** Scenario 22 only asserts the substring
`'WARNING: could not read prior audit record'`, not that the offending
filename actually appears in the message. A regression that dropped the
file identity from the warning (defeating its stated purpose — "visible in
orchestrator run logs," where the whole point is knowing *which* file is
bad) would not be caught.

Both mutations 2 and 3 are test-completeness gaps only — the shipped
implementation is correct in both cases (verified by direct reading of
`write_audit.sh` lines 341–346); nothing here indicates the code itself
misbehaves. But per this track's own standard (a test is not evidence
unless it can fail), these two specific claims are currently unpinned.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | No new `.mli` — pure shell PR. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" sections has a corresponding test in the committed test file | FAIL | PR body: "grep exit 1 (no match) is skipped silently; grep exit >1 ... is skipped but also emits a stderr WARNING naming the file. Adds scenarios 21-22 ... pinning both cases." The count/no-abort/warning-presence sub-claims are pinned (scenarios 21, 22). The "silently" (no warning on the exit-1 path) and "naming the file" (filename present in the exit->1 warning) sub-claims are asserted in prose but not pinned by any assertion — see Mutations 2 and 3 above. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size_is | NA | No pass-through/identity semantics in this feature. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | FAIL | `write_audit.sh` lines ~326–345 docstring explicitly claims: "grep exit 1 ... is tolerated silently" and grep exit >1 "is surfaced as a stderr WARNING ... naming the file". The guarded-against *scenarios* (exit 1, exit >1) are each exercised (scenarios 21/22), but the specific claimed *properties* of each ("silently" = no warning; warning names the specific file) are not asserted — see Mutations 2 and 3. |

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | NA | No core module touched; not flagged by qc-structural. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | NA | Pure infra/harness/refactor PR; domain checklist not applicable (per qc-behavioral-authority.md "When to skip this file entirely"). |

## Quality Score

2 — Below standard but fixable: the direction-decision claim (skip vs. break, the actual point of the harness item) is soundly pinned and mutation-verified. But two granular claims stated explicitly in the code docstring and PR body — "silently" (no warning) on the exit-1 path, and the warning "naming the file" on the exit->1 path — are not pinned by any assertion that would catch their regression. Per this track's own explicit false-green standard (the reason this review was scoped so pointedly), presence of a passing test is not sufficient evidence; these two claims currently have none. The underlying implementation is correct (verified by direct code reading) — this is a test-completeness gap, not a domain-logic defect, so it should be a quick fix.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP2/CP4: "Silently" and "naming the file" sub-claims unpinned in scenarios 21/22
- Finding: Two specific behavioral claims made in `write_audit.sh`'s docstring (lines ~326–345) and restated in the PR body / `dev/status/harness.md` are not exercised by any assertion that would fail if they regressed:
  1. Claim: grep exit 1 (truncated record) is skipped **silently** (no stderr output). Mutation test: injecting a spurious `WARNING:` echo into that branch left scenario 21 (and the whole suite) green.
  2. Claim: grep exit >1 (unreadable record) emits a WARNING **naming the file**. Mutation test: stripping `$f` from the warning string left scenario 22 (and the whole suite) green.
- Location: `trading/devtools/checks/write_audit.sh` lines 341–346 (the `case "$prev_grep_status"` block); `trading/devtools/checks/record_qc_audit_test.sh` scenario 21 (~line 1003) and scenario 22 (~line 1040).
- Authority: PR body — "grep exit 1 (no match) is skipped silently; grep exit >1 (e.g. 2, unreadable target) is skipped but also emits a stderr WARNING naming the file." Same language repeated in `dev/status/harness.md`'s H-PREV-VERDICT-PIPEFAIL entry and in the code's own inline comment ("grep exit 1 ... is tolerated silently ... grep exit >1 ... is surfaced as a stderr WARNING (visible in orchestrator run logs)").
- Required fix: In scenario 21, additionally assert that `out21_3` (or a captured stderr-only stream) does **not** contain `WARNING`. In scenario 22, additionally assert that the WARNING line contains the actual offending file's basename (e.g. `2026-07-30-feat-unreadable-${FEATURE22}.json`), not just the fixed substring `WARNING: could not read prior audit record`.
- harness_gap: LINTER_CANDIDATE — both fixes are mechanical (grep for absence of a substring; grep for the fixture's own filename in the warning), not judgment calls; a future test-writer could add both in under 10 lines total.

---
_Posted by the lead-orchestrator on behalf of `qc-behavioral` (GHA run 30817481526). `gh` is absent in this runtime, so the agent could not post it itself._

---

<!-- github review id 4845279653, state COMMENTED -->

## Behavioral QC re-review — rework iteration 1 (tip `c5e06533`)

Reviewed SHA: c5e06533809855f794b2b62995bb0b003f339600

## Behavioral QC — PR #2184 `harness/prev-verdict-pipefail` (rework iteration 1 re-review)

**Context:** at `1bfbb38e` this reviewer returned NEEDS_REWORK (quality 2/5): the code's
own docstring named two distinct sub-claims for `write_audit.sh`'s handling of an
unparseable/unreadable prior `overall_qc` record — (1) grep exit 1 ("no match", the
truncated-record shape) is skipped **silently**, no warning; (2) grep exit >1 (e.g. 2,
genuinely unreadable) is skipped but emits a `WARNING:` line **naming the offending
file**. Both had zero assertion coverage: injecting a spurious `WARNING:` echo into the
exit-1 branch, and stripping `$f` from the exit->1 warning message, each left all 24
scenarios green. The direction decision itself (skip, don't break the streak) was already
soundly pinned and not in question.

Rework `c5e06533` (2 files, +11/-8, `write_audit.sh` untouched) adds exactly two new
conjuncts: scenario 21 gained `&& ! echo "${out21_3}" | grep -q 'WARNING'`; scenario 22
gained `&& echo "${out22_3}" | grep -qF "${UNREADABLE_PATH_22}"` (capturing the seeded
directory path into a named variable first).

### Independent re-verification (mutation-tested from a clean `/tmp` copy of the committed scripts, not taken on trust)

Baseline: 24/0 clean, matching the committed SHA byte-for-byte.

| Mutation | Result | Cross-pattern claim | Confirmed? |
|---|---|---|---|
| Inject spurious `echo "WARNING: ..." >&2` into the exit-1 (silent-skip) branch | 23/1 | scenario 21 reddens, scenario 22 stays green | **Yes** — exact match |
| Strip `$f` from the exit->1 warning message | 23/1 | scenario 22 reddens, scenario 21 stays green | **Yes** — exact match |
| Both reverted independently | 24/0, byte-identical to `write_audit.sh.orig` | — | Yes |

The reported one-to-one mapping holds exactly: each new assertion pins its own distinct
claim, neither trips on the other's side effect.

**Extra adversarial mutation (not in the author's report, run to stress the "over-fitted"
question):** replaced the correct `$f` with a *different, non-empty, wrong* path
(`/some/other/wrong/path.json`) rather than deleting it outright. Result: scenario 22
alone reddens (23/1), scenario 21 stays green; reverting restores 24/0. This confirms
`grep -qF "${UNREADABLE_PATH_22}"` pins "names *this specific* file," not merely "some
non-empty text is present" — a materially stronger guarantee than the single
deletion-mutation the author reported.

### Answering the specific risk questions

- **Over-fitting to message wording?** No. `grep -qF "${UNREADABLE_PATH_22}"` matches the
  path as a substring anywhere in the combined stdout+stderr capture — it does not anchor
  on the surrounding sentence ("could not read prior audit record...", etc.). A legitimate
  future rewording of the warning sentence survives this assertion as long as the path is
  still emitted somewhere in it. This is the right level of coupling — precise on the
  load-bearing fact (which file), loose on prose.
- **Can scenario 21's negative assertion (`! grep -q 'WARNING'`) pass vacuously (e.g. on
  empty output)?** No. It is ANDed with `rc21_1==0`, `rc21_3==0`, `[[ -f "${JSON21}" ]]`,
  and `grep -q '"consecutive_rework_count": *2'` on both the JSON file and the success
  message in `out21_3`. A crashed or silent run fails those first; the negative check only
  matters once the positive path is already proven to have executed and produced the
  correct count. Not a weak guard.
- **CP2/CP4 — fully pinned now?** Yes. The two previously-FAIL claims are now PASS. No new
  implementation claims were introduced this rework (the diff excludes `write_audit.sh`
  entirely — it's a test-only + status-doc rework, correctly narrow in scope). No other
  documented sub-claim in the `write_audit.sh:296-357` comment block lacks coverage: the
  exit-0-but-empty-value branch is explicitly marked defensive/believed-unreachable in the
  comment itself and was not part of either review's findings.

## Contract Pinning Checklist (re-review)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | New `.mli` docstring claims pinned by tests | NA | No `.mli` in this diff (bash-only change) |
| CP2 | PR/status-note "what changed" claims have corresponding committed tests | PASS | Status-note claims (scenario 21 gains a no-warning assertion; scenario 22 gains a names-the-file assertion; both independently re-verified via mutation) all match `record_qc_audit_test.sh` at `c5e06533` |
| CP3 | Pass-through/identity tests pin full equality, not just size | NA | No pass-through semantics in this change |
| CP4 | Every guard named in the code docstring has a test exercising it | PASS | Both previously-FAIL rows (silent-skip on exit 1; names-the-file on exit >1) now independently confirmed test-covered and change-detecting |

## Behavioral Checklist

Pure harness/infra PR — domain S*/L*/C*/T* rows not applicable.

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | N/A | NA | No core-module (Portfolio/Orders/Position/Strategy/Engine) touch |
| S1-S6, L1-L4, C1-C3, T1-T4 | N/A | NA | Pure infra/harness PR; domain checklist not applicable |

## Quality Score

4 — both previously-identified assertion gaps are now genuinely closed and independently
re-verified (not merely re-reported); the extra adversarial mutation this pass ran shows
the fix is robust beyond the author's own minimal reproduction. Held at 4 rather than 5
because this is a narrow, mechanical closure of a prior finding rather than a novel
exemplary design — a solid, unremarkable rework.

## Verdict

APPROVED

---
_Posted by the lead-orchestrator on behalf of `qc-behavioral` (GHA run 30817481526). `gh` is absent in this runtime._


---

## PR #2231 — harness/audit-test-count-and-repo-root

Reviewed SHA: 1c67a533e1798a286992a0bf28c9811a3f496388

### Mutation-Tested Findings

All three mutation checks from the structural review protocol were conducted and reproduced the author's claims exactly:

**Mutation 1 (H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL):** Shrinking `HOOK_DISABLE_VALUES` to `(0)`:
- Pre-fix behavior: 30/30 green (tautological check), exit 0 — the array-against-itself check cannot detect the shrinkage
- Post-fix behavior: 29 passed, 2 failed (scenarios 25a, 26a fail), exit 1 — the independent `HOOK_DISABLE_EXPECTED_COUNT=6` constant detects the mismatch
- **Verdict:** Fix confirmed. The constant is a true second source of truth.

**Mutation 2 (HOOK_DISABLE_EXPECTED_COUNT independence):** Padding the array to 7 values:
- Constant remains `6` (hardcoded literal)
- Rendered message shows all 7 array values via `_disable_values_repr()` helper
- Tests fail with `exercised 7` vs `expected 6`
- **Verdict:** Constant is genuinely independent; drift is detected on edit.

**Mutation 3 (H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE):** Reverting `write_audit.sh`'s precedence order (walk-up first, REPO_ROOT fallback):
- Scenario 27 fails with `target_count=0, walkup_count=1` — record lands in WALKUP_ROOT instead of TARGET_ROOT
- Restoring the fix returns scenario 27 to PASS
- **Verdict:** Regression scenario 27 is a valid discriminator of the bug.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit code 0 |
| H2 | dune build | PASS | Exit code 0 |
| H3 | dune runtest | PASS | Exit code 0; 31 tests, 31 passed, 0 failed |
| P1 | Functions ≤ 50 lines (linter) | PASS | `record_qc_audit_test.sh`: `_disable_values_repr()` is 5 lines; `write_audit.sh` pre-change/post-change are both well under 50. Linter passed as part of H3. |
| P2 | No magic numbers (linter) | PASS | Linter passed as part of H3 |
| P3 | Config completeness | NA | No config records; shell test/harness scripts only |
| P4 | Public-symbol export hygiene | NA | Shell scripts only (no `.mli` / `.ml` files) |
| P5 | Internal helpers prefixed per convention | PASS | `_disable_values_repr()` correctly uses underscore prefix (internal helper). No violations in diff. |
| P6 | Tests conform to project test-patterns | PASS | Shell test framework, not OCaml/OUnit. Scenarios 25a, 26a, 27 all follow assertion/pass/fail convention: explicit test name, clear expected vs actual on failure, no nested assertions. |
| A1 | Core module modifications | NA | No core trading modules (`portfolio/`, `orders/`, `position/`, `strategy/`, `engine/`) touched |
| A2 | analysis/→trading/ imports | NA | No dune files modified |
| A3 | No unnecessary module modifications | PASS | Only 3 files: `dev/status/harness.md` (docs), `record_qc_audit_test.sh` (test harness), `write_audit.sh` (test harness helper). All changes are targeted to the two findings + docs. `dev/status/_index.md` not touched (correct). |

### Quality Score

5 — Both fixes are minimal, well-motivated, mutation-tested against the specific bugs they address, and introduce new regression scenarios (27) to pin the hazard permanently. The additional `set -euo pipefail` safety fix (ls→find) removes a latent defect class from the codebase. Exemplary test-harness work.

### Verdict

APPROVED

---


---

## Behavioral QC — harness/audit-test-count-and-repo-root (PR #2231)

Reviewed SHA: 1c67a533e1798a286992a0bf28c9811a3f496388

Pure test-harness / infrastructure PR. Touches `trading/devtools/checks/record_qc_audit_test.sh`,
`trading/devtools/checks/write_audit.sh`, `dev/status/harness.md`. No Weinstein domain logic.

Baseline: `bash trading/devtools/checks/record_qc_audit_test.sh` → **31 passed, 0 failed, exit 0** (1.6s).

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | NA | Shell-only PR; no OCaml modules, no `.mli` added. |
| CP2 | Each claim in PR body / status-file "Test coverage" has a corresponding test in the committed test file | PASS | Every advertised artefact exists and behaves as advertised, verified by re-running the author's own mutations. `HOOK_DISABLE_EXPECTED_COUNT=6` (L1269) + `_disable_values_repr()` (L1263-1270) present; scenarios 25a/26a compare against the constant (L1311, L1369); scenario 27 present (L1388-1434). Claimed counts confirmed: "31 assertions across 27 scenarios" → measured 31/31. Mutation claims reproduced exactly — see Probes A/B below. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | Scenario 27's contract is a *routing* identity ("which root did the record land in"), and the paired `target_count27==1` / `walkup_count27==0` assertion does establish it. Nit (non-blocking): it pins neither the record's filename nor its JSON contents — those are pinned by scenarios 1/8/9/20 through the same code path, so the residual is small. |
| CP4 | Each guard called out explicitly in code docstrings has a test that exercises the guarded-against scenario | **FAIL** | The new `_repo_root()` docstring (`write_audit.sh` L153-168) states a two-branch contract — `$REPO_ROOT` wins, *"and only falls back to the `.git`/`.claude` walk-up if unset"*. Only the first branch is pinned. Deleting the entire walk-up block leaves the suite **31/31 green** (Probe C). See B1. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | NA | Pure infra / harness PR; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". qc-structural did not raise A1 (no core-module changes). |

### Probes run (all measured, not reasoned)

| Probe | Mutation / action | Measured result |
|---|---|---|
| **A** | Pad `HOOK_DISABLE_VALUES` to 7 (`… "" off`), constant left at 6 | **29 passed, 2 failed**, exit 1. Message: `expected … for all 6 documented 'off' spellings ('0' 'false' 'no' 'yes' 'true' '' 'off'); exercised 7; offending values:none` |
| **B** | Shrink array to `(0)` (the original tautology mutation) | **29 passed, 2 failed**, exit 1. Message: `… for all 6 documented 'off' spellings ('0'); exercised 1; offending values:none` |
| **B2** | Shrink array to `(0)` **and** lower constant to `1` | **31 passed, 0 failed**, exit 0 — coverage silently back to one spelling |
| **C** | Delete the `.git`/`.claude` walk-up from `write_audit.sh:_repo_root()` | **31 passed, 0 failed, exit 0** — suite completely blind |
| **E1** | `REPO_ROOT=$T bash write_audit.sh` from a fake checkout with its own `.claude` | Record → `$T` (1), checkout (0). **Fix works.** |
| **E2** | Same override via `bash record_qc_audit.sh` (the wrapper) | Record → **checkout** (1), `$T` (0). **Override defeated.** |
| **F** | Probe E2 re-run against pre-fix `write_audit.sh` | Identical (checkout 1, `$T` 0) → E2 is **pre-existing, not a regression** |
| **G1/G2** | Proposed 27b: `env -u REPO_ROOT`, fixed code / walk-up-deleted code | G1 rc=0, record under walk-up root. G2 rc=1, `FAIL: could not locate repo root`. Pin is feasible and discriminating. |

### Assessment of the two claimed fixes

**H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL — genuinely fixed.** The tautology has moved
from *agreement-by-construction* (one edit, undetectable) to *agreement-by-two-coordinated-edits*
(Probe B2), which is the standard and correct escape from a self-referential assertion; the
inline comment at L1259-1268 names that residual and warns against it explicitly. Critically,
the failure message steers a maintainer **correctly** in the dangerous direction: Probe B prints
`for all 6 … ('0'); exercised 1`, where the array-derived repr makes the five lost spellings
visually obvious right next to the expected count — it reads as "you dropped five", not as
"lower the constant". `_disable_values_repr()` is doing real work here, not decoration.

**H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE — fix is correct, coverage is half.** The
precedence flip does what it claims (Probe E1) and matches `_check_lib.sh:66-68`. Scenario 27
is a well-built discriminating test for the override direction. The gap is the other direction
(B1).

### Quality Score

2 — Below standard. The two fixes are individually correct and unusually well-evidenced (real mutation runs, an avoided `pipefail`/`ls`-glob trap, honest in-file scoping notes), but a PR whose entire subject is *reordering two branches* ships with only one branch pinned, and the unpinned one is the production path — the same "coverage claim that isn't" defect class this PR exists to close.

### Verdict

NEEDS_REWORK

### NEEDS_REWORK Items

#### B1 (CP4): the walk-up fallback direction of `_repo_root()` is entirely unpinned
- **Finding:** `write_audit.sh:_repo_root()` now has two branches — explicit `$REPO_ROOT`, then the `.git`/`.claude` walk-up. Scenario 27 pins only the first. Deleting the walk-up block outright (Probe C) leaves the suite at **31/31 green, exit 0**: every existing caller in `record_qc_audit_test.sh` sets `REPO_ROOT` explicitly, and the new scenario 27 does too, so no test in the suite ever reaches the walk-up. The walk-up is nonetheless the **only** path used in production: the orchestrator's documented direct invocation (`.claude/agents/lead-orchestrator.md` L1414, the `record_qc_audit.sh`-failure fallback) runs `bash trading/devtools/checks/write_audit.sh --date … ` with `REPO_ROOT` unset. A future refactor that breaks or drops the walk-up ships green and silently strands the orchestrator's audit writes.
- **Location:** `trading/devtools/checks/write_audit.sh` L153-181 (`_repo_root`); `trading/devtools/checks/record_qc_audit_test.sh` L1388-1434 (scenario 27).
- **Authority:** the PR's own new docstring, `write_audit.sh` L153-156: *"An explicitly-set REPO_ROOT takes precedence over the walk-up … only falls back to `$REPO_ROOT` when it found nothing"*; and `dev/status/harness.md` L464: *"`_repo_root()` now checks `$REPO_ROOT` first **and only falls back to the `.git`/`.claude` walk-up if unset**"* plus the explicit non-regression claim *"this reorder only changes behaviour for the ad-hoc-invocation case only"*. Both halves are asserted; one half is tested. CP4: "FAIL if the docstring names an edge case but no test covers it."
- **Required fix:** add scenario 27b reusing scenario 27's existing `WALKUP_ROOT` fixture — invoke the copied `write_audit.sh` under `env -u REPO_ROOT` and assert rc=0, `OK: wrote`, and exactly 1 record under `WALKUP_ROOT/dev/audit`. Verified feasible and discriminating: Probe G1 (fixed code) rc=0 with the record present; Probe G2 (walk-up deleted) rc=1 with `FAIL: could not locate repo root`. Roughly 8 lines; bump the header count to 32 assertions / 28 scenarios.
- **harness_gap:** LINTER_CANDIDATE — "every branch of a repo-root resolver is exercised by at least one scenario" is mechanically checkable; the `repo_root()`/`_repo_root()` precedence family is already named as a linter candidate in the same status entry.

### Non-blocking follow-ups (file separately; do not gate this PR)

#### B2: the stated rationale for leaving `record_qc_audit.sh` unfixed is measurably wrong
`dev/status/harness.md` L464 scopes the sibling out because *"the two scripts' `REPO_ROOT` usage is
independently overridable."* Probe E2 disproves this: `REPO_ROOT=$T bash record_qc_audit.sh probe …`
writes into the **walked-up live repo**, not `$T`. Mechanism — `record_qc_audit.sh` L102 does
`REPO_ROOT="$(_repo_root)"`, overwriting the inherited value; because `REPO_ROOT` arrived via the
caller's `VAR=x cmd` prefix it is already *exported*, so the overwritten walk-up value stays exported
and becomes exactly what `write_audit.sh`'s **newly-first** `$REPO_ROOT` branch consumes. The sibling's
bug therefore propagates *through* this PR's new precedence rather than being independent of it.
Probe F confirms the wrapper behaves identically pre-fix, so this is **pre-existing and not a
regression** and the scope call itself is defensible — but the residual is understated and the reason
given should be corrected. Fix: apply the same three-line reorder to `record_qc_audit.sh` L85-100, or
amend the status note to say the wrapper path remains un-redirectable.

#### B3: the pad-direction message still self-contradicts
Probe A prints `for all 6 documented 'off' spellings ('0' 'false' 'no' 'yes' 'true' '' 'off')` — states 6,
lists 7. This is the same self-contradiction class the PR fixed in the shrink direction. Mitigated because
`exercised 7` appears on the same line, so a maintainer is not actually misled. Cheapest fix: print
`${#HOOK_DISABLE_VALUES[@]}` alongside the repr, or word it as `expected ${HOOK_DISABLE_EXPECTED_COUNT},
array holds ${#HOOK_DISABLE_VALUES[@]}: <repr>`.

#### B4: `6` has no mechanical tie to the documentation it encodes — and that documentation is self-inconsistent
`HOOK_DISABLE_EXPECTED_COUNT=6` traces to `write_audit.sh` L451-453 (BEFORE_RENAME: *"`0`, `false`, `no`,
`yes`, `true`, the empty string, unset"* = 6 settable spellings). Nothing connects the constant to that
block; they are two hand-maintained lists in different files that can drift. Separately — and pre-existing
— the AFTER_RENAME block (L511-513) enumerates only *three* (*"`0`, `false`, the empty string and unset"*),
so `write_audit.sh`'s two ACCEPTED SPELLING docstrings already disagree about their own contract, and `6`
matches only one of them. The test applying all six values to both hooks is a strict superset and therefore
sound, but the docs should be reconciled. Full mechanical derivation is probably not worth it (the source
is prose); reconciling the two blocks and cross-referencing the constant is.

### Premise checked and dropped

The dispatch asked whether an ambient `REPO_ROOT` (CI, dune sandbox, a wrapper) could make a
previously-correct in-repo invocation silently write elsewhere. **The premise is false.** No `REPO_ROOT`
appears in any of the 15 files under `.github/workflows/`, and there is no `export REPO_ROOT` anywhere
outside `_build/`. The only path by which `REPO_ROOT` reaches `write_audit.sh` from a non-test caller is
the `record_qc_audit.sh` re-export described in B2, and Probe F shows that path is behaviourally
unchanged by this PR. No blast-radius finding.

---
_Posted by the lead-orchestrator on behalf of `qc-behavioral`. `gh` is absent in this runtime._

---

## Delta Review — PR #2231, Rework Iteration 1

**Reviewed SHA:** a89e61da97ab690eb2c407a669865f37799f3681 (2 commits on top of approved 1c67a533)

### The B1 Critical Finding

qc-behavioral correctly identified that **scenario 27 only pins the REPO_ROOT-precedence direction**; it never exercises the walk-up branch. Every caller in the test file sets `REPO_ROOT` explicitly, so the walk-up code was entirely unpinned — despite being the **only path production uses** (`lead-orchestrator.md` invokes with `REPO_ROOT` unset).

#### B1 Mutation Test

Deleted the entire walk-up block (`dir=...` through `done`) from `_repo_root()`:
- Result: **31 passed, 1 failed**, exit 1
- Sole failure: **scenario 27b** (`expected rc=0 + 'OK: wrote' + exactly 1 record under WALKUP_ROOT; got rc=1, walkup_count=0`)
- Scenario 27 still passes (never reaches walk-up code)
- **Verdict:** 27b correctly discriminates the walk-up branch. ✅

#### Scenario 27b Implementation Soundness

- **Fixture independence:** Scenario 27 asserts `walkup_count27 == 0` (record went to TARGET_ROOT), so WALKUP_ROOT/dev/audit is empty at start of 27b. Scenario 27b reuses that fixture and asserts `walkup_count27b == 1`. No vacuous pass possible. ✅
- **Unset mechanism:** `env -u REPO_ROOT bash ...` correctly unsets the variable before invocation. ✅
- **Shell safety:** Uses `find` (not `ls`), which is safe under `set -euo pipefail`. No unguarded glob/pipe traps. ✅

### The B2 Corrected Rationale

Original claim: `record_qc_audit.sh`'s sibling `_repo_root()` was "out of scope because the two scripts' REPO_ROOT usage is independently overridable."

**Measured finding:** This rationale was **false**. Because bash's export attribute persists across a plain (non-`export`) reassignment of an already-exported variable, when `record_qc_audit.sh` does `REPO_ROOT="$(_repo_root)"`, it silently overwrites any caller override with its own walked-up value, which then propagates through to `write_audit.sh` as a child process. Author verified this with a two-script export-persistence repro (`REPO_ROOT="from-caller" bash mid.sh` where `mid.sh` reassigns `REPO_ROOT="from-mid"` and invokes child: child sees `from-mid`, not `from-caller`).

**Scope unchanged, but rationale corrected:** Leaving `record_qc_audit.sh`'s sibling `_repo_root()` unfixed because the finding named `write_audit.sh` specifically and fixing the sibling would require mutation-tested regression coverage (same rigor as above), which is new scope for a rework PR. **Filed as follow-up:** `H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING` (explicitly scheduled, not a dangling "worth a follow-up" note). ✅

### Non-Blocking Findings B3 and B4

**B3 — Wording inconsistency (pad direction):** Adding a 7th value to `HOOK_DISABLE_VALUES` prints `for all 6 ... (7-element list)` — internally contradictory like the pre-fix shrink direction. Functionally harmless (tests still fail), but wording is messy. Fix: word as "expected N, exercised M" without conflating the count with the list. **Filed:** `H-AUDIT-TEST-DISABLE-COUNT-PAD-DIRECTION-WORDING`.

**B4 — Docstring drift:** `write_audit.sh`'s BEFORE_RENAME block lists 6 accepted spellings; AFTER_RENAME block lists only 3. `HOOK_DISABLE_EXPECTED_COUNT=6` matches the superset (tests are sound), but the constant has no mechanical tie to the docs. Fix: reconcile the docstrings or explain the superset in a comment. **Filed:** `H-AUDIT-HOOK-DISABLE-COUNT-DOCSTRING-DRIFT`.

### Structural Checklist (Delta)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit code 0 |
| H2 | dune build | PASS | Exit code 0 |
| H3 | dune runtest | PASS | Exit code 0; 32 passed, 0 failed (27b integrated) |
| B1 | Scenario 27b pins walk-up branch | PASS | Mutation-tested: deleting walk-up kills 27b alone (31 pass, 1 fail). Fixture independent. ✅ |
| B2 | Status file B2 rationale corrected | PASS | Export-persistence mechanism measured and documented. `record_qc_audit.sh` sibling filed as follow-up. ✅ |
| B3/B4 | Backlog items B3/B4 filed | PASS | Non-blocking wording + docstring issues captured. ✅ |
| P1–P5, A1–A3 | (unchanged from first pass) | PASS | Delta touches only test scenarios + status docs; no new code violations. |

### Quality Score

5 — The B1 mutation methodology is rigorous (two-direction testing: precedence reversal verified first, now deletion of one branch verified). Status file corrections are measured against live behavior, not overclaimed. Backlog items are properly filed rather than lost to prose notes. Work demonstrates scientific discipline on a subtle harness hazard.

### Verdict

APPROVED

---

---

## Behavioral QC — harness/audit-test-count-and-repo-root (PR #2231), rework iteration 1 — DELTA

Reviewed SHA: a89e61da97ab690eb2c407a669865f37799f3681

Delta pass over `1c67a533..a89e61da` (39 insertions, 2 files). Prior-pass PASS rows on CP1/CP2/CP3 stand unchanged; only CP4 was in question. Baseline at the new tip: `bash trading/devtools/checks/record_qc_audit_test.sh` -> **32 passed, 0 failed, exit 0**.

### Contract Pinning Checklist (delta)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | .mli docstring claims pinned | NA | Unchanged — shell-only PR, no OCaml modules. |
| CP2 | PR-body / status-file claims have corresponding tests | PASS | Delta claims re-verified independently and reproduce exactly. Scenario 27b at L1436-1462. Claimed "32 assertions" -> measured 32. B1 mutation claim reproduced verbatim (Probe H). B2's export-persistence repro reproduced (Probe B2-2). |
| CP3 | Identity pinned, not just size | PASS | Unchanged. 27b asserts rc=0 **and** `OK: wrote` **and** exactly 1 record — the rc/`OK:` guards prevent a stale-fixture false pass. |
| CP4 | Guards named in docstrings have tests exercising the guarded-against scenario | **PASS** (was FAIL) | Both branches of `_repo_root()`'s two-branch contract are now pinned. 27 pins override-beats-walk-up; 27b pins walk-up-when-unset — the branch production actually uses (`lead-orchestrator.md` L1414). Verified at contract level: 27b catches 3 of 4 independently-constructed subtler walk-up regressions. |

### Behavioral Checklist (Weinstein domain)

All rows (A1, S1-S6, L1-L4, C1-C3, T1-T4) **NA** — pure infra / harness PR; domain checklist not applicable per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely".

### Probes run (delta pass, all measured)

| Probe | Action | Measured result |
|---|---|---|
| Baseline | suite at `a89e61da` | **32 passed, 0 failed, exit 0** |
| H | Delete entire walk-up block (the original B1 mutation, previously 31/31 green) | **31 passed, 1 failed, exit 1**; sole failure 27b (`rc=1, walkup_count=0`, `FAIL: could not locate repo root`); 27 still passes |
| K1 | Sentinel narrowed to `.git` only | 31/1 — 27b FAIL, caught |
| K2 | Sentinel narrowed to `.claude` only | 32/0 — not caught (R3; not a real regression here) |
| K3 | Walk-up returns `dirname` of the sentinel | 31/1 — 27b FAIL, caught |
| K4 | Walk-up starts from `$PWD` not `dirname $0` | 31/1 — 27b FAIL, caught (R2) |
| I1 | Full suite with ambient `REPO_ROOT="$PWD"` | 32/0, live `dev/audit` 104->104 (no leak) |
| I2 | Same with `env -u REPO_ROOT` removed from 27b | 31/1 **and leaked** into live `dev/audit` (104->105) |
| J1 | Scenario 27's write neutralized, fixture kept | 27 FAIL, **27b PASS** — no dependence on 27 running |
| J2 | Revert the precedence fix (walk-up first) | 30/2 — both red; over-reports, never false-green |
| J4 | Remove the `WALKUP_ROOT` fixture | `WALKUP_ROOT: unbound variable`, exit 1 — fails loud under `set -u` |
| L1/L2/L3 | `set -euo pipefail` audit of all 3 substitution sites in 27b | All safe |
| B2-1/2/3 | `record_qc_audit.sh` diff; export-persistence toy repro; E1/E2 re-run | Walk-up-first confirmed L85-100 + plain reassign L102; E1 = 1/0, E2 = 0/1 |

### Assessment

**B1 — closed at the contract level, not just the mutation.** 27b catches a narrowed sentinel (K1), a wrong-ancestor return (K3), and a wrong starting directory (K4) in addition to full deletion (H). Only K2 slips, and K2 is not a real regression: this repo's root carries both `.git` and `.claude`, so narrowing to `.claude` alone changes nothing in production. A fixture limitation, not a contract gap.

**`env -u REPO_ROOT` is load-bearing — the best detail in the delta.** Probe I2 measured it: with the guard removed and the suite run under an ambient `REPO_ROOT`, 27b not only fails, it writes a record into the **live `dev/audit/`** — reproducing the exact litter bug this item was filed for, inside the test meant to pin it. Necessary, not cosmetic, and it is the same export-persistence mechanism the B2 correction documents.

**Ordering coupling — sound and fail-loud in every direction constructed.** 27b depends on the *fixture*, not 27's side effects (J1). Fixture removal is an unbound-variable abort, not a silent pass (J4). A precedence revert reddens both with a readable `walkup_count=2` (J2). No false-green path exists today.

**No fourth instance of the unguarded-substitution class.** All three substitution/pipeline sites in the new block are safe under `set -euo pipefail`. The `find` (not `ls`-glob) choice carried over correctly from scenario 27.

**B2 — accurate, not merely different.** Every claim in the replacement text was verified independently, *including the negative direction*: with the caller not setting `REPO_ROOT`, the child sees `<unset>` rather than the mid-script's plain var — so the qualifier "of an already-**exported** variable" is precise rather than sloppy. The efficacy claim is correctly narrowed ("does not close the leak **when reached through** `record_qc_audit.sh`"); direct invocation still works (E1 = 1/0). A dangling prose note became a real backlog item with a fix shape. This is a retraction that lands.

## Quality Score

4 — Precise, minimal, correctly targeted: it pins the contract rather than the one mutation that exposed it, the `env -u` guard is demonstrably load-bearing, the new code introduces no `pipefail` trap in a file that has produced three, and the B2 rationale was corrected with measured evidence rather than quietly softened. Three minor robustness residuals keep it below exemplary.

## Verdict

APPROVED

## Non-blocking residuals (filed; do not gate this PR)

- **R1** — 27b's `walkup_count27b == 1` is a cumulative count on a fixture shared with 27. Robust today (J2 confirms no false-green) but sensitive to any future scenario writing into `WALKUP_ROOT`. Fix shape: snapshot the count before 27b and assert a delta of exactly 1, or give 27b its own fixture.
- **R2** — under a `$PWD`-resolving walk-up regression (K4), 27b goes red *and* leaves a stray record in the live `dev/audit/`. Inherent to exercising the unset-`REPO_ROOT` path with an in-tree script; the test does go red so a human looks. Fix shape: `cd` to a scratch dir for the 27b invocation.
- **R3** — K2 unpinned: narrowing the sentinel to `.claude` only is not caught, since `WALKUP_ROOT` carries only `.claude`. Low value; closing it needs a `.git`-sentinel fixture variant.
