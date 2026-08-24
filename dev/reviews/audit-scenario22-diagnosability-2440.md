Reviewed SHA: 07abcc99

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
