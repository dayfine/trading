Reviewed SHA: 6b979c77

# QC review — PR #2504, `harness/audit-scenario22-diagnosability-2440`

## Structural QC

APPROVED (quality 5). Full checklist posted as a PR review on
[#2504](https://github.com/dayfine/trading/pull/2504); this file was not
committed on the branch, so only the verdict is mirrored here.

---

## Behavioral QC — audit-scenario22-diagnosability (#2440)

Scope: pure harness PR (2 files, +171/−8; no OCaml source, no domain logic).
Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file
entirely", the Weinstein S\*/L\*/C\*/T\* block is NA in full. The review is the
generic Contract Pinning Checklist.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Non-trivial claims in new docstrings pinned by an identified test | **FAIL** | `report_conjuncts()`'s docstring claims it "prints one `conjunct FAILED: <label>` line per broken conjunct". **Nothing in the committed tree pins this.** Measured: three independent mutations of the helper — early `return 0` (silent no-op), inverted `[[ "$2" == "0" ]]`, and `shift 1` instead of `shift 2` — each leave the suite at **60 passed / 0 failed, exit 0**. See finding CP1-a. |
| CP2 | PR-body "what shipped" claims correspond to committed artifacts | PASS | Every checkable claim reproduced — see the evidence table below. The 8-mutation driver is **explicitly declared not committed**, so it is not an advertised-but-missing test; I ran 7 independent mutations instead (below). |
| CP3 | Identity / equivalence claims pinned, not merely asserted | PASS | The `&&`-chain → `0/1` concat rewrite claims semantic equivalence. True-direction pinned by scenarios 21/22 green. False-direction verified by measurement, not inheritance: 10 of the 12 conjuncts forced false individually (mutations B/C/D/E/F) each turned the suite red with exactly the right conjunct(s) named. **Vacuous pass impossible by construction**: all six operands are assigned a literal single-char `0`/`1` immediately before use, so the 6-char concat admits exactly one match for `"111111"` (exhaustively enumerated). |
| CP4 | Guards named in docstrings have a test exercising the guarded scenario | PASS | The guards named in the scenario 21/22 comment blocks (grep exit 1 → silent skip; grep exit 2 → loud WARNING) are exercised by scenarios 21 and 22 themselves. The one *new* guard (`if [[ "${c2x_file}" == "1" ]]`, replacing the original chain's short-circuit) is not docstring-called-out; verified complete by measurement under `set -euo pipefail` — mutation F. |

### Weinstein domain checklist

| # | Status |
|---|--------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | **NA** — pure harness PR; no domain logic, no OCaml, no strategy config. Domain checklist not applicable. |

No `BOOK-CHECK-NEEDED` items: the PR contains no domain content, so tier-2
authority was never in question.

### Evidence — what I re-measured

Environment: GNU grep 3.7, bash 5.1.16, no docker. Mutations applied only to
copies under `/tmp/mutrepo`; `git status --porcelain` on the checkout was empty
before and after (verified).

| PR / status-file claim | Result |
|---|---|
| Suite is 60/60, exit 0 on the branch | ✅ `record_qc_audit_test: 60 passed, 0 failed`, exit 0 |
| Scenario 22 "did not reproduce" | ✅ `origin/main` also 60/60, exit 0 — the non-reproduction is environmental, as claimed |
| Suppressing the `WARNING` emission → RED 59/1, two conjuncts, observed value `<none>` | ✅ Reproduced exactly; the other four conjuncts stayed silent (no false positives) |
| `posix_sh_check.sh` exit 0 | ✅ `OK: posix-sh linter -- 79 scripts clean` |
| #2440 should stay open | ✅ issue 2440 is `open` |
| Latent `ls -1` bug is real | ✅ Reproduced — see below |
| "~50" multi-conjunct blocks, count explicitly hedged as unreliable | ✅ My own crude counts bracket it (49 single-line `if …&&`; 59 multi-line-aware). Hedging is appropriate and in the safe direction |
| Scenario 23's `bash -c 'umask 077 && exec "$0" "$@"'` embedded `&&` | ✅ Real, at lines 1429 and 1492 |

Additional mutations I ran (beyond the one the orchestrator reproduced), each
isolating exactly the right conjunct(s) with the observed value inline, and each
with **zero** false positives on the remaining conjuncts:

| Mutation | Conjunct(s) that fired |
|---|---|
| B — `CONSECUTIVE + 1` → `+ 0` | `c21_json_count` (`actual: "consecutive_rework_count": 1`), `c21_out_count`, `c22_count` |
| C — WARNING emitted but path redacted | `c22_path` only — correctly **did not** fire `c22_warn` |
| D — spurious WARNING on the tolerated exit-1 path | `c21_no_warn` only |
| E — `write_audit.sh` exits 3 on the `feat/new` call | `c21_rc3`, `c22_rc3`, `c21_out_count` (`<not found>`) |
| F — `JSON22` pointed at a nonexistent path | `c22_file`, `c22_count` (`actual: <file missing>`) — guard held under `set -euo pipefail`, no abort |

Together these force 10 of the 12 conjuncts false individually; the remaining
two (`c21_rc1`/`c22_rc1`) are the same construction as `c2x_rc3`, verified by E.

### Eager-evaluation review

The rewrite evaluates all conjuncts where the original `&&` chain
short-circuited. Checked and clean:

- The only conjunct that touches the filesystem (`grep … "${JSON2x}"`) is
  guarded by an explicit `if [[ "${c2x_file}" == "1" ]]` — mutation F confirms
  the guard holds with no abort under `set -euo pipefail`. The guard is
  complete: every other conjunct reads only already-set shell variables.
- The `c21_no_warn=1; echo … | grep -q 'WARNING' && c21_no_warn=0` form does not
  trip `set -e` — the failing pipeline is not the command following the final
  `&&`, so it is exempt; scenario 21 reaches its `pass` line on the green run.
- Label command-substitutions are inside `report_conjuncts` arguments, evaluated
  only in the `else` branch, so they cost nothing on a green run.

### The filed latent bug — reproduces

Reproduced directly against a copy of `write_audit.sh`:

- **Dir-only glob match**: with `dev/audit/<date>-feat-x-<feature>.json` as a
  *directory* and no sibling record, `ls -1 <dir>` lists the directory's empty
  contents → **zero words** → the `for` loop never iterates → `rc=0`, **zero
  WARNING lines**, `consecutive_rework_count=1`.
- **Control**: the same feature with a real, readable prior `NEEDS_REWORK`
  record yields `consecutive_rework_count=2`.
- **Scenario-22 shape** (dir + sibling file): the WARNING *does* fire — and it
  names `…-both.json:` with a **trailing colon**, i.e. `ls -1`'s header format,
  not a real path. `grep -qF` passes on the substring, so scenario 22 as written
  would not catch that defect. The status file identifies this precisely and
  honestly.

So the same corrupt record is loudly reported in one state shape and completely
invisible in another — a real violation of H-PREV-VERDICT-PIPEFAIL's own design
note ("must never silently BREAK the streak"). One calibration nuance, flagged
but not blocking: "silently under-counted" is exact only if the directory stands
in for a record that *would* have been `NEEDS_REWORK` — which is the realistic
provenance (a corrupted write of a real record), so the phrasing is fair.

**I agree with filing rather than fixing.** The fix changes behaviour on a
carefully-reviewed path and needs its own regression scenario; bundling it into
a diagnosability PR would land a behaviour change without its own pin — the same
class of gap CP1-a flags below. The follow-up item as written already specifies
the `find`-based replacement and the missing fixture shape.

### Status-file honesty

`dev/status/harness.md` (+112) is accurate and appropriately hedged throughout.
It does not claim to fix the CI failure, states plainly that scenario 22 did not
reproduce, marks the "~50" survey as unreliable and declines to give a per-
scenario count, and records the trailing-colon artifact that its own scenario
does not catch. No overclaiming found.

---

## NEEDS_REWORK Items

### CP1-a: `report_conjuncts()`'s own contract is unpinned

- **Finding:** The helper's behaviour is exercised only inside the `else`
  branches of scenarios 21 and 22, which never execute on a green tree. Its
  correctness rests entirely on a mutation driver that is not in the repo.
  Measured — each of these leaves the committed suite at **60 passed / 0 failed,
  exit 0**:
  - early `return 0` (helper becomes a silent no-op);
  - `[[ "$2" == "0" ]]` (inverted — would report passing conjuncts as failed);
  - `shift 1` (breaks the label/value pairing).

  The mechanism demonstrably works *today* (mutations A–F above). Nothing keeps
  it working.
- **Location:** `trading/devtools/checks/record_qc_audit_test.sh:43-60` (helper +
  docstring); call sites at `:1342` and `:1397`.
- **Authority:** The file's **own established convention**. Scenario 42 exists
  for exactly this hazard class — `_glob_count called DIRECTLY (not via command
  substitution) against a nonexistent directory prints a clean 0 and does not
  abort` — and `_glob_count`'s docstring names the health item by ID:
  `H-AUDIT-GLOB-COUNT-GUARD-UNPINNED`, "see scenario 42 … for the call shape
  where removing it actually turns this suite red." A new helper in the same
  file, with a docstring making a behavioural claim, and no such scenario, is
  inconsistent with the precedent the file already sets.
- **Required fix:** One scenario, modelled on 42, calling `report_conjuncts`
  directly with a known mix (e.g. `"a" 1 "b" 0 "c" 0`) and asserting the output
  is exactly the two `conjunct FAILED:` lines for `b` and `c` and nothing for
  `a`. That single assertion kills all three mutations above. ~10–15 lines.
- **Blocking:** **Yes**, but narrowly. The blast radius is bounded — a broken
  helper degrades diagnostics back to today's `main` baseline; it cannot make a
  gate pass that should fail, so this is *not* the vacuous-pass family (#2430 →
  #2462 → #2464 → #2494). What makes it blocking is that the fix is one scenario
  with a template already in the file, and this PR's entire thesis is that an
  unexercised diagnostic is worth nothing. Landing the diagnostic unexercised
  reproduces the argument it was written to defeat.

  If a maintainer judges the diagnostic-only blast radius makes this
  non-blocking, the coherent alternative is to merge and make this scenario the
  **first** item of the already-filed follow-up — not to leave it unpinned
  indefinitely.
- **harness_gap:** `LINTER_CANDIDATE` — "a helper defined in a `*_test.sh` file
  whose only call sites are inside `else`/failure branches" is mechanically
  detectable, and is the generalisation of `H-AUDIT-GLOB-COUNT-GUARD-UNPINNED`.

---

## Non-blocking nits

1. **Label can misreport a present file as missing.** In
   `"… (actual: $([[ "${c2x_file}" == "1" ]] && grep -o … || echo '<file missing>'))"`,
   `grep`'s exit 1 (file present, field absent) falls into the same `||` branch
   as file-absent. Measured (mutation G — renamed the JSON field in
   `write_audit.sh`): the file existed, yet the label printed
   `(actual: <file missing>)`. Minor, and self-disambiguating in practice
   because the `JSON2x exists` conjunct sits directly above and stays silent —
   but it is a wrong statement about the world in the one construct whose job is
   diagnostic accuracy. `|| echo '<no match>'` on the inner grep would fix it.
2. **Survey example is slightly over-hedged.** Scenario 23's
   `bash -c 'umask 077 && exec "$0" "$@"'` is a real embedded `&&`, but it is not
   inside an `if`, so it would not actually be a false positive for an
   `^\s*if .*&&` grep. Hedging in the safe direction; no action needed.
3. **Mutation B produced 5 red scenarios, only 3 of them diagnosed** — a
   concrete, quantified illustration of why the filed "remaining ~48" follow-up
   matters. Worth citing in that follow-up when it is picked up.

## Quality Score

2 — Below the bar on one fixable point: the new diagnostic helper ships without
the direct scenario the file's own scenario-42 precedent calls for, and three
mutations of it leave the suite green. The surrounding craft is strong — honest
hedging, correct scoping of the latent bug, real mutation discipline — which is
why the gap is one ~12-line scenario away from closing.

## Verdict

NEEDS_REWORK

---

## Re-review — Rework Iteration 1 of 2 @ `6b979c77`

**Prior verdicts at `07abcc99`:** Structural APPROVED (quality 5); Behavioral NEEDS_REWORK (quality 2).

### Summary of rework commit

Rework addresses the CP1-a finding by adding scenario 43, which directly invokes `report_conjuncts()` with 4 known conjuncts (2 passing, 2 failing) and verifies the output contains exactly 2 "conjunct FAILED" lines (for the failing conjuncts only).

### Re-verification of scenario 43

**Baseline suite**: 61/0 passed, exit 0 (new baseline with scenario 43).

**Mutation 1 — early `return 0`**: Produces 0 output lines. Caught by conjunct-presence checks (`c43_b_reported`, `c43_d_reported`). Expected behavior: ✅

**Mutation 2 — inverted test `[[ "$2" == "0" ]]`**: Reports passing conjuncts as failed, failing ones as passing. Caught by all four label-presence checks (`c43_a_silent`, `c43_b_reported`, `c43_c_silent`, `c43_d_reported`) and line count. Expected behavior: ✅

**Mutation 3 — `shift 1` instead of `shift 2`**: Produces 5 lines instead of 2. Caught by line-count assertion (`c43_line_count == "2"`). Author's caveat verified: labels mis-pair but count is load-bearing. Expected behavior: ✅

### Structural re-check

- **H1** (dune build @fmt): PASS
- **H2** (dune build): PASS
- **H3** (dune runtest): PASS (61/0, all passing including new scenario 43)
- **P1–P5** (linter coverage): PASS (no new violations)
- **P6** (test patterns): PASS (scenario 43 follows the direct-invocation convention of scenario 42)
- **A1** (core module mods): NA (pure harness, no trading/portfolio/orders/strategy/engine changes)
- **A2** (analysis imports): NA (no dune dependency changes)
- **A3** (unnecessary mods): PASS (3 files changed: test file + 2 docs; all changes scoped to the feature)

### Nonblocking nit resolution

The rework did not address the non-blocking nits filed in the prior behavioral review:

1. **Label distinguishes `<file missing>` from `<no match>`**: Not yet fixed. Author notes the distinction is minor and self-disambiguating. Reasonable to defer.
2. **Survey hedge**: Still present; acceptable per behavioral notes.
3. **Mutation B scope**: Filed for follow-up; acceptable per behavioral notes.

These remain eligible for a separate follow-up PR and do not block approval of the rework.

### Quality Score

5 — Rework directly pins the unpinned diagnostic helper via three independent mutation tests and confirms the scenario catches all three failure modes; the fix is minimal, focused, and follows established precedent (scenario 42's template).

## Verdict

**APPROVED**

---

## Behavioral QC — Re-review at `6b979c77` (rework iteration 1 of 2)

Re-review by qc-behavioral, the author of the NEEDS_REWORK verdict at
`07abcc99` (quality 2). Every result below was **re-derived in this
worktree** against a `/tmp` copy of the suite; none was accepted from the
rework commit message or from qc-structural's re-review section above.
The real source was never mutated (`diff` against HEAD confirmed clean
after each pass; `git status --porcelain` clean at exit).

### Baseline

`bash trading/devtools/checks/record_qc_audit_test.sh` → **61 passed, 0
failed, exit 0**. Scenario 43 registers as a `PASS`; it does **not**
pollute pass/fail accounting despite deliberately exercising a *failure*
diagnostic, because — following scenario 42's convention — it invokes the
helper directly and evaluates the result itself rather than routing through
`fail()`.

### CP1-a (my blocking finding) — CLOSED

All three mutations I demonstrated at `07abcc99` now turn the suite red.
Re-derived independently:

| mutation | before (`07abcc99`) | after (`6b979c77`) |
|---|---|---|
| M1 — early `return 0` in `report_conjuncts` | 60 passed / 0 failed, exit 0 | **60 / 1, exit 1**, scenario 43 FAIL |
| M2 — polarity inverted (`[[ "$2" == "0" ]]`) | 60 / 0, exit 0 | **60 / 1, exit 1**, scenario 43 FAIL |
| M3 — `shift 1` instead of `shift 2` | 60 / 0, exit 0 | **60 / 1, exit 1**, scenario 43 FAIL |

The helper's docstring contract — *"prints one `conjunct FAILED: <label>`
line per broken conjunct to stderr"* — is now pinned by a committed test.

### The load-bearing caveat — verified, and explicitly signed off

The author's docstring states that under M3 the individual label text for
conjuncts B/D coincidentally still matches, so the **exact line-count
assertion** is what catches it. This is accurate. Probing the mutated
helper directly on the scenario's own fixture yields **5** lines, not 2:

```
      conjunct FAILED: 1
      conjunct FAILED: conjunct B (should fail)
      conjunct FAILED: 0
      conjunct FAILED: 1
      conjunct FAILED: conjunct D (should fail)
```

B and D labels are present; A and C stay silent — so all four label checks
pass under M3, exactly as documented.

I then tested the question that matters: **if the count assertion were
removed, does the scenario collapse to a single point of failure?** Forcing
`c43_line_count=1` unconditionally and re-running each mutation:

| mutation | with count assertion neutralized |
|---|---|
| none | 61 / 0, exit 0 (control) |
| M1 — early `return 0` | **60 / 1** — still caught (label checks) |
| M2 — inverted polarity | **60 / 1** — still caught (label checks) |
| M3 — `shift 1` | 61 / 0, exit 0 — **undetected** |

So the scenario does **not** rest on one assertion in general: two of three
mutations are caught by the four label checks alone. Only M3 depends
solely on the count. **I sign off on that as adequate**, for three reasons:
the count assertion is committed and unconditional, not optional; the
reliance is documented in the scenario's own comment, so a future editor
tempted to drop the count has the reason in front of them; and the
dependency is an artifact of the alternating `1/0/1/0` fixture rather than
a design flaw — the `shift 1` walk happens to realign on it. Widening the
fixture (e.g. distinct non-`0/1` values) would remove the coincidence, but
that is a strengthening option, not a defect.

### Non-blocking nit from `07abcc99` — FIXED (and correctly)

The label fallback now distinguishes `<field missing>` from `<file
missing>`, at **both** call sites (scenario 21 line ~1346, scenario 22 line
~1401). Verified empirically across all four reachable states:

| state | output | correct? |
|---|---|---|
| file exists, field present | `"consecutive_rework_count":2` | ✅ |
| file exists, field absent (grep exits 1) | `<field missing>` | ✅ |
| file absent (`c*_file == 0`) | `<file missing>` | ✅ |
| `grep` errors outright (exit 2) | `<field missing>` | ⚠ see residual R2 |

The `A && { B || C; } || D` bracing is correct: the brace group makes the
`grep`-failure branch return 0, so the outer `|| echo '<file missing>'`
cannot fire when the file genuinely exists. The pre-rework form conflated
states 2 and 3 — that nit was real, and it is closed.

### Did the rework introduce a new unpinned contract?

Applying the same standard that produced the original finding, one real
residual: **scenario 43 reintroduces the "suite dies with no summary line"
class** that scenario 42's own docstring — ~110 lines above, same file —
explicitly enumerates and guards against as a failure class *"this file
has already been patched for twice."*

`out43="$(report_conjuncts ... )"` runs under the suite's `set -euo
pipefail` with no guard. Measured:

| mutation | result |
|---|---|
| `report_conjuncts` returns non-zero | exit 1, **no summary line**, no scenario-43 FAIL — suite dies at the assignment |
| `report_conjuncts` renamed | exit **127**, **no summary line** — same death |

This is **non-blocking**, and the distinction is the same one that made the
original finding blocking. My CP1-a finding was blocking because a broken
helper left the suite **green** (60/0, exit 0) — a pin that did not pin, so
the regression was invisible. Here the suite goes **red** (exit 1 / 127):
CI still catches it, the gate cannot falsely pass, and the only loss is
diagnostic tidiness on an already-failing run. That is squarely the
bounded-blast-radius category I declined to block on before, so blocking
now would be applying a *stricter* bar to the fix than to the original —
the opposite error the proportionality note warns about. Filed as R1.

### Residuals (non-blocking, for `dev/status/harness.md`'s follow-up list)

- **R1 — `H-AUDIT-REPORT-CONJUNCTS-CALL-UNGUARDED`.** Guard scenario 43's
  direct invocation the way scenario 42 guards its own preconditions:
  a `declare -f report_conjuncts 2>/dev/null || echo MISSING` check plus
  `|| true` (or an `if !` wrapper) on the capture, so a renamed/removed or
  non-zero-returning helper becomes an orderly scenario-43 FAIL with a
  summary line instead of a bare `exit 127`. ~4 lines, mirrors existing
  precedent in the same file.
- **R2 — grep-error state.** A genuine `grep` error (exit 2, e.g. an
  unreadable or directory-shaped `JSON21`) reports `<field missing>`. The
  adjacent `JSON21 exists at ...` conjunct line disambiguates it in
  practice, so this is third-order on a diagnostic label. Optional.
- **R3 — PR body `## Gates` is stale.** It still reads
  `record_qc_audit_test.sh` **60/60, exit 0**; the committed state is
  **61/61, exit 0**. Not a CP2 FAIL (CP2 fails on a body advertising a test
  that does *not* exist; here the body under-reports), but it should be
  refreshed before merge so the record matches the tree.

### Correction to the structural re-review section above

qc-structural's "Nonblocking nit resolution" item 1 states the
`<file missing>` / `<field missing>` label nit was **"Not yet fixed …
Reasonable to defer."** That is **incorrect** — the rework *did* fix it, at
both call sites, in this very commit (`git show HEAD -- …record_qc_audit_test.sh`,
hunks at lines 1346 and 1401), and I verified the fixed behaviour across all
four states above. Structural's verdict is unaffected; the finding-status
line is simply wrong and should not be carried forward as an open nit.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | **PASS** | No `.mli` (shell harness); read against the equivalent — shell-function docstrings. `report_conjuncts()` docstring → *"prints one `conjunct FAILED: <label>` line per broken conjunct to stderr"* → **scenario 43** (direct invocation). This closes CP1-a, the `07abcc99` blocker. `_glob_count()` → scenario 42 (pre-existing). Scenarios 21/22 conjunct decomposition → present and exercised by the existing 21/22 pins. |
| CP2 | Each PR-body "Test plan"/"Test coverage" claim has a corresponding committed test | **PASS** | Body claims verified against the tree: (a) `report_conjuncts()` beside `pass`/`fail`, alternating `<label> <0\|1>` pairs → committed, lines 55–60, now pinned; (b) scenarios 21/22 evaluate each conjunct into a named `0`/`1` var and combine → committed, verified at lines ~1327–1334 and the scenario-22 sibling. No advertised-but-absent test. The `## Gates` count is stale (60/60 vs actual 61/61) — filed as R3, not a CP2 FAIL, since the body under-reports rather than advertising a phantom test. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | **PASS** | Scenario 43 pins **identity**, not merely count: four exact-string `grep -qF` checks asserting both presence (B, D) *and* absence (A, C) of specific labels, **plus** an exact total-line count. The count alone would be a `size_is`-shaped pin and is explicitly *not* what the scenario relies on for M1/M2 — verified above, both survive the count's removal. |
| CP4 | Each guard named in code docstrings has a test exercising the guarded-against scenario | **PASS** | Scenario 43's docstring names three failure shapes (silent no-op; inverted polarity; `shift 1` mis-pairing) and claims each is caught. All three **independently re-derived** in this review: 60/1, exit 1. The docstring's caveat that M3 is caught by the count rather than by label text is accurate and was verified at the raw-output level. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | **NA** | Pure harness PR — the diff touches one shell test-harness file plus two docs, and no trading, screener, stops, or strategy logic. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the entire domain block is not applicable; CP1–CP4 constitute the full review. No book-faithfulness question arose, so no `BOOK-CHECK-NEEDED` is queued (book tier 2 is unreachable in this environment per issue #2457). |

### Quality Score

4 — The rework is minimal, precisely targeted, and follows the file's own
established precedent (scenario 42); its docstring is candidly honest about
the one assertion that is load-bearing for M3, which is exactly what made
this reviewable rather than something I had to reverse-engineer. Held back
from 5 by two documentation-accuracy residuals (R1's unguarded call shape,
inconsistent with scenario 42 ~110 lines above; the stale `60/60` gate line
in the PR body) — minor nits, no correctness defect.

### Verdict

**APPROVED**

All four CP rows PASS; the domain block is NA. The `07abcc99` blocking
finding (CP1-a) is closed and independently re-verified. Residuals R1–R3
are non-blocking and filed for follow-up.
