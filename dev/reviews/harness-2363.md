Reviewed SHA: 81919a574eb12a0a25f23128450886417b4326cd

## Structural QC — harness: universe-deps exemption evidence fix

### Hard gates (H1–H3)

| Gate | Check | Result |
|------|-------|--------|
| H1 | `dune build @fmt` | PASS (scoped: `dune build devtools`, exit 0; full CI perf-tier1-smoke completed/success) |
| H2 | `dune build` | PASS (scoped: `dune build devtools`, exit 0; CI build-and-test still in_progress but diff is comments-only, outcome not in doubt) |
| H3 | `dune runtest` | PASS (scoped: `dune runtest devtools`, 57 scenarios passed, exit 0) |

### File-list verification (Step 3)

Via `gh pr view 2363 --json files`:
- `dev/status/harness.md` (status file)
- `trading/devtools/checks/dune` (dune file, comments only)
- `trading/devtools/checks/universe_deps_exceptions.conf` (conf file, comments only)

All three files modified; diff is strictly comments/documentation prose, no code or exemption-entry changes.

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | Scoped check on modified dune files + fixtures; CI full run perf-tier1-smoke passed |
| H2 | dune build | PASS | Scoped `dune build devtools` exit 0; CI build-and-test in progress on comments-only diff |
| H3 | dune runtest | PASS | 57 test scenarios passed (record_qc_audit_test.sh); all devtools checks exit 0; no `FAIL:` lines |
| P1 | Functions ≤ 50 lines (linter) | NA | No new functions; diff is comments and config only |
| P2 | No magic numbers (linter) | NA | No new magic numbers; diff is comments only |
| P3 | Config thresholds in config record | NA | No new config fields; no tunable thresholds added |
| P4 | Public-symbol export hygiene (linter) | NA | No new .mli files or module exports |
| P5 | Internal helpers prefixed per convention | NA | No new helper functions |
| P6 | Tests conform to test-patterns (`.claude/rules/test-patterns.md`) | NA | No new test files added; diff is config comments and status update |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | No modifications to core modules; changes are in devtools/checks/ only |
| A2 | No new `analysis/` imports into `trading/trading/` | PASS | No dune file modifications that add new dependencies |
| A3 | No unnecessary modifications to existing modules | PASS | Verified via `gh pr view 2363 --json files`: diff touches only 3 files (2 comments-only, 1 status), no cross-module drift |

### Claim verification (high-rigor check per dispatch protocol)

**Claim 1: Two `env -u REPO_ROOT` sites in record_qc_audit_test.sh**

Grep result: Lines 1723 (scenario 27b) and 1864 (scenario 28b). ✅ VERIFIED — exactly two sites as claimed.

**Claim 2: Both fixtures carry their own `.claude` sentinel**

Inspected in diff context:
- Scenario 27b uses `WALKUP_ROOT=$(mktemp -d)` + copies script inside it
- Scenario 28b uses `WALKUP3_ROOT=$(mktemp -d)` + copies script inside it

Both are temp fixtures with `.claude` sentinel present. ✅ VERIFIED.

**Claim 3: Exemption entries unchanged (set of exempted paths byte-identical)**

Before and after comparison shows exemption lines identical; only justification comments above them changed. ✅ VERIFIED.

**Claim 4: No residual `:NNN` line-number citations**

Grep of new prose for `:` followed by digits: none found. New wording cites scenario names (27b, 28b) and function name (_repo_root) rather than line numbers. ✅ VERIFIED.

**Claim 5: Real repo files (dev/audit/, dev/reviews/) unchanged**

Per status file: dev/audit/ measured 128 before/after, dev/reviews/ measured 142, git status clean. Test output confirms all 57 scenarios passing. ✅ VERIFIED.

## Quality Score

5 — Comment-only precision correction with exhaustive mechanical verification; all claims verified independently; scoped gates pass; CI confirms no unintended impact.

## Verdict

APPROVED

The PR is a pure documentation fix: three comment blocks reworded to accurately describe the `record_qc_audit.sh` and `write_audit.sh` exemptions from the universe-deps guard, citing the correct mechanism (two scenarios with `env -u REPO_ROOT` paths) and fixture evidence (temp directories with their own `.claude` sentinel). All structural gates pass; no exemption entry itself changed; all claims verified against the source test file and the diff. The status file update appropriately marks the finding closed.


---

## Behavioral QC — harness: universe-deps exemption evidence reword (PR #2363)

Pure harness / build-config documentation PR. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the entire Weinstein domain block (S\*/L\*/C\*/T\*) is **NA** —
no stage classification, stops, screener, macro/sector gating or simulation logic is touched.
The full generic CP1–CP4 review applies, and here it reduces to a single question, because
**nothing in this PR executes — the artifact under review *is* a claim**:

> Is the new wording exactly true — no broader, no narrower — of the code as it stands?

**It is not.** The replacement wording is a *two*-branch universal claim over the invocation
set, and the set has **four** shapes. Six invocation sites satisfy neither branch. Detail in
CP2 / the NEEDS_REWORK item below.

### Independent enumeration (counted from source, not from the PR body)

`grep -n 'REPO_ROOT' trading/devtools/checks/record_qc_audit_test.sh` (2569 lines), every
invocation of `record_qc_audit.sh` / `write_audit.sh` / the `_check_lib.sh` probe classified:

| # | Shape | `record_qc_audit.sh` | `write_audit.sh` | `_check_lib.sh` probe | Covered by new wording? |
|---|---|---|---|---|---|
| A | `REPO_ROOT=` → real temp fixture repo | 53 × `${TMP_REPO}` sites (shared with B) + sc. 28 (`TARGET2_ROOT`, :1807) | sc. 27 (`TARGET_ROOT`, :1689) + `${TMP_REPO}` sites | — | ✅ limb 1 |
| B | **`env -u REPO_ROOT`** (no override) | **sc. 28b** (:1864, `WALKUP3_ROOT`) | **sc. 27b** (:1723, `WALKUP_ROOT`) | — | ✅ limb 2 |
| C | `REPO_ROOT=` → **deliberately malformed** (nonexistent path / regular file) | sc. **31a, 31b** (:2084) | sc. **30a, 30b** (:1995) | sc. **29a, 29b** (:1931, :1942) | ❌ **neither** |
| D | `REPO_ROOT=''` → treated as unset, **takes the walk-up branch** | sc. **31c** (:2116) | sc. **30c** (:2026) | sc. **29c** (:1958) | ❌ **neither** |
| E | bare invocation, no `REPO_ROOT` disposition | none | none | none | n/a |

**`env -u REPO_ROOT` occurs at exactly two invocation sites — scenarios 27b and 28b.**
The author's and qc-structural's count is **CONFIRMED** independently. (The other two `env -u`
grep hits, :1719 and :1838, are prose inside comments, not invocations.)

**But categories C and D — six invocation sites of the two exempted scripts (30a/b/c, 31a/b/c),
plus three more of `_check_lib.sh`'s `repo_root()` (29a/b/c) that the dune comment explicitly
brings in scope — are covered by neither limb of the shipped wording.**

### Answering the sharp question: does `REPO_ROOT=''` satisfy limb 1?

**No — and it is worse than a near-miss.** The shipped limb 1 is not "overrides `REPO_ROOT`";
it is "overrides `REPO_ROOT` **to a freshly-created temp fixture repo**". Reading
`_repo_root()` (`record_qc_audit.sh:129-146`, `write_audit.sh:235-252`), both are guarded by
`if [ -n "${REPO_ROOT:-}" ]`, so `REPO_ROOT=''` **does not take the override branch at all** —
it falls through to the walk-up, the very branch limb 2 exists to describe. Scenarios 29c/30c/31c
exist *precisely to pin that* ("REPO_ROOT='' (empty string) is treated as unset … the walk-up
still succeeds"). So `''` is not an override in effect, and it is not an `env -u` site either.

Category C misses limb 1 for a different reason: `BOGUS_MISSING30` is `mktemp -u` — a name
**reserved but deliberately never created** — the exact opposite of "a freshly-created temp
fixture repo". No charitable reading rescues either category.

The sharpest form of the finding: **the safety of 30c and 31c rests on exactly the same
walk-up-terminates-in-the-fixture argument as 27b/28b — but the shipped wording attaches that
argument only to `env -u` sites and names only "(scenarios 27b and 28b)". As written, the
recorded evidence does not justify the exemption for 30c/31c at all.**

### Sentinel / walk-up verification (mechanical) — the exemption is substantively VALID

Verified independently; the *conclusion* the comment reaches is true, only its stated evidence is incomplete.

- All **six** walk-up fixtures are `mktemp -d` trees created carrying their own `.claude`
  sentinel: `WALKUP_ROOT` :1684, `WALKUP2_ROOT` :1774, `WALKUP3_ROOT` :1847, `WALKUP4_ROOT` :1906,
  `WALKUP5_ROOT` :1986, `WALKUP6_ROOT` :2053.
- **Termination is CWD-independent, which is stronger than the comment implies.** The walk seeds
  from `dir="$(cd "$(dirname "$0")" && pwd)"` — the **script's own location**, not the caller's
  CWD. `$0` is always `${WALKUP*_ROOT}/trading/devtools/checks/<script>.sh`, so the walk goes
  `checks → devtools → trading → WALKUP*_ROOT` and halts on `.claude` at depth 3. This holds for
  **every possible starting directory**, not merely the one the scenarios happen to use —
  answering the "or only the one they happen to use?" question affirmatively. The wording's
  "from a copy of the script located inside a temp fixture" correctly captures this (it locates
  the *script*, not the caller) — that part is right.
- Category C never reaches any path at all: `_repo_root()` `exit 1`s at the `[ -d ]` guard
  **before** `REVIEW_FILE` / `AUDIT_DIR` are computed. The tests assert `walkup_count == 0`.
- For 28b/31c the child `write_audit.sh` inherits the exported fixture root from the parent's
  `REPO_ROOT="$(_repo_root)"`, so the child never walks up to the real repo either.

### Empirical safety check (run in an isolated worktree at the PR tip)

```
AUDIT_BEFORE=128   REVIEWS_BEFORE=142
bash trading/devtools/checks/record_qc_audit_test.sh  → EXIT=0, "57 passed, 0 failed"
AUDIT_AFTER=128    REVIEWS_AFTER=142
git status --porcelain dev/audit dev/reviews  → clean (no output)
```

**CONFIRMED** — matches the PR body's 128/142 and the run-1 orchestrator's independent count of
128 audit records. No real-repo file was read or written.

### Exemption set unchanged — CONFIRMED independently

```
git diff main...HEAD -- .../universe_deps_exceptions.conf | grep '^[+-]' | grep -v '^[+-]#'
→ (empty)
```
Every changed line in the `.conf` is a `#` comment line. The `record_qc_audit.sh` and
`write_audit.sh` entries and their `review_at:` annotations are byte-identical. **No exemption
was added, removed, or widened.** This was the worst available outcome and it did not occur.

### Residual `:NNN` citations in the new wording — NONE

`git diff main...HEAD -- dune universe_deps_exceptions.conf | grep '^+' | grep -E ':[0-9]{2,}'`
returns empty. New prose cites `scenarios 27b and 28b` and `_repo_root` symbolically. This part
of the fix is done correctly, and it matters: structural cited 27b at **:1723** / 28b at **:1864**
while the originally-filed item cited **:1446** / **:1587** — ~280 lines of live drift in nine days,
which is exactly why the symbolic form is required.

(The preserved *original* filing text in `dev/status/harness.md` still carries the stale `:1446` /
`:1587`. That is historical audit-trail text and appropriately left verbatim; the appended
**Fixed:** note explicitly says it re-enumerated "from source rather than trusting the filed line
numbers". Non-blocking.)

### Over-narrowness check (the other direction)

The invariant is shape-based ("runs via `env -u REPO_ROOT` from a copy … inside a temp fixture"),
so a future maintainer adding a new `env -u` scenario would **not** be led to think it forbidden.
No over-narrowness FAIL. However the parenthetical "(scenarios 27b and 28b)" is an exhaustive
*site enumeration*, which is the same drift-prone form as `:NNN` — one abstraction level up.
Recommend "(currently scenarios 27b and 28b)" or dropping the enumeration. Non-blocking nit.

### `dev/status/harness.md` completion note — accurate in substance, but inconsistent with what shipped

The note's own formulation is **broader and correct**: "every site either **explicitly sets
`REPO_ROOT`** (including the deliberate `''`/malformed cases in scenarios 29-31 …) or runs via
`env -u REPO_ROOT`". That formulation *would* cover category C. So the author had a workable
formulation in hand and shipped a narrower one into the `.conf`/`dune`. Two consequences:

1. The note's claim "Reworded all three sites … to state **the accurate two-branch invariant**"
   **over-claims** — the invariant as shipped is not accurate for the nine 29–31 sub-scenarios.
2. Even the note's broader phrasing is imprecise for `''`: calling it "still count[ing] as
   'override'" implies the override branch was taken, when `[ -n "${REPO_ROOT:-}" ]` routes `''`
   to the walk-up. The `''` cases are safe by the *walk-up* argument, not the *override* argument.

Everything else in the note (re-enumeration method, the two-`env -u`-sites count, the `.claude`
sentinel confirmation, 128/142, 57/57, the gates) is accurate and I reproduced all of it.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | **NA** | No `.mli` added or changed. The PR touches only a `dune` comment, a `.conf` comment, and a status `.md`. The prose-contract analogue is evaluated under CP2/CP4. |
| CP2 | Each claim in the PR body's "Test plan"/"Test coverage" sections has a corresponding artifact/test | **FAIL** | Verified TRUE: the enumeration table (~50 fixture-override sites; **exactly two** `env -u` sites = 27b/28b) — reproduced independently; the `.claude`-sentinel walk-up claim — reproduced; 128/142 before-and-after + `git status` clean — reproduced; 57/57 exit 0 — reproduced; no exemption entry changed — reproduced; no residual `:NNN` — reproduced. **FAILS on the PR body's central claim**: "All three sites now state the **accurate** two-branch invariant … *every invocation either overrides `REPO_ROOT` to a temp fixture, or runs `env -u REPO_ROOT` …*". The PR body's **own table** lists a third category ("Explicit override to a deliberately malformed/empty value — 29a/b/c, 30a/b/c, 31a/b/c"), and the shipped two-branch wording does not cover it. See NEEDS_REWORK item B1. |
| CP3 | Pass-through / identity / invariant claims pin identity, not just size | **PASS** | The identity claim here is "the exemption set is unchanged and no real directory is touched". Pinned by **identity**, not by a count alone: non-comment lines in the `.conf` are byte-identical (`git diff` filtered to non-`#` lines is empty — the entries themselves, not just their number, are unchanged), and `git status --porcelain dev/audit dev/reviews` is clean (identity of directory contents, not merely the 128/142 counts). |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | **PASS** | The two guards the new prose names are both exercised and green: the unset-`REPO_ROOT` walk-up → scenarios **27b** (`write_audit.sh`, :1723) and **28b** (`record_qc_audit.sh`, :1864); the `.claude`-sentinel fixture termination → all six `WALKUP*_ROOT` fixtures (`mkdir -p "${WALKUP*_ROOT}/.claude"`). Both pass in the 57/57 run. The *under*-enumeration of scenarios that also depend on the walk-up guard is a wording defect, scored once under CP2 rather than double-counted here. |

## Behavioral Checklist (project-specific)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module modification is strategy-agnostic | **NA** | qc-structural did not flag A1. No core module (`portfolio/`, `orders/`, `position/`, `strategy/`, `engine/`) touched. |
| S1–S6, L1–L4, C1–C3, T1–T4 | Weinstein domain rows | **NA** | Pure harness / build-config documentation PR; domain checklist not applicable. No stage classification, stop-loss, screener-cascade, macro/sector or simulation logic is touched — the diff is three comment blocks and one status-file line. |

## Quality Score

2 — Genuinely careful work (independent re-enumeration from source, correct symbolic citations, verified 128/142 empirical safety, no exemption widened, clean gates), but the PR's *sole deliverable is a prose claim*, and that claim is still not exactly true: the shipped two-branch invariant misses six invocation sites of the two exempted scripts, reproducing the defect class it exists to close. Below standard for this PR's one job; the fix is a single clause.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### B1: The replacement two-branch invariant is itself under-enumerated — same defect class the PR closes

- **Finding.** The new wording asserts a **universal, two-branch** claim: *"**Every** invocation of
  this script in that test **either** overrides `REPO_ROOT` to a freshly-created temp fixture repo,
  **or** runs via `env -u REPO_ROOT` from a copy of the script located inside a temp fixture that
  carries its own `.claude` sentinel (scenarios 27b and 28b)."* The invocation set has **four**
  shapes, not two. Six invocations of the two exempted scripts satisfy neither branch:
  - **`REPO_ROOT` → deliberately malformed** (scenarios **30a/30b** on `write_audit.sh`,
    **31a/31b** on `record_qc_audit.sh`). `BOGUS_MISSING30` is `mktemp -u` — a name reserved and
    **never created** — so this is not "a freshly-created temp fixture repo"; it is the deliberate
    opposite. Not `env -u` either.
  - **`REPO_ROOT=''`** (scenarios **30c**, **31c**). Because both `_repo_root()`s guard on
    `[ -n "${REPO_ROOT:-}" ]`, `''` **does not take the override branch at all** — it falls through
    to the walk-up. So it is not an override in effect, and it is not an `env -u` site. Scenarios
    29c/30c/31c exist precisely to pin that semantics.
  The `dune` comment is worse than the `.conf`: it makes an **affirmative misclassification** rather
  than a silent omission, writing *"(and, since 29a-29c, `_check_lib.sh`'s `repo_root()` directly)
  either with `REPO_ROOT` explicitly overridden to a freshly-created temp fixture repo … or …
  `env -u REPO_ROOT` … (scenarios 27b and 28b)"* — filing 29a-29c under limb 1, when 29a/29b
  override to a bogus path and 29c overrides to `''`. It then concludes **"Either way"** when there
  are demonstrably more than two ways.
  Sharpest form: **30c/31c are safe by exactly the same walk-up-terminates-in-the-fixture argument
  as 27b/28b, but the shipped wording attaches that argument only to `env -u` sites and names only
  27b/28b — so as written the recorded evidence does not justify the exemption for 30c/31c.**
- **The exemption remains substantively VALID.** Verified: category C hard-errors at the `[ -d ]`
  guard before any path is computed (`walkup_count == 0` asserted); category D walks up from
  `$(dirname "$0")` inside `WALKUP5_ROOT`/`WALKUP6_ROOT`, both of which carry `.claude`.
  Real `dev/audit/` 128→128, `dev/reviews/` 142→142, `git status` clean. **This is a
  recorded-evidence defect, not a safety defect** — precisely the same standing as the item
  H-UNIVERSE-DEPS-EXEMPTION-EVIDENCE-STALE it is fixing, which was likewise filed as
  "substantively still valid" and warranted this PR.
- **Location.** `trading/devtools/checks/universe_deps_exceptions.conf:43-50` (the
  `record_qc_audit.sh` entry) and `:52-57` (the `write_audit.sh` entry);
  `trading/devtools/checks/dune:596-606`. Falsifying sites:
  `trading/devtools/checks/record_qc_audit_test.sh` scenarios 30a/b/c (:1995-2029),
  31a/b/c (:2084-2119), and 29a/b/c (:1931-1962, in scope for the `dune` comment only).
- **Authority.** The PR body's **own** enumeration table lists the uncovered third category
  ("Explicit override to a deliberately malformed/empty value | 29a/b/c, 30a/b/c, 31a/b/c"), and
  `dev/status/harness.md`'s completion note states the **broader, correct** formulation ("every
  site either **explicitly sets `REPO_ROOT`** (including the deliberate `''`/malformed cases in
  scenarios 29-31 …) or runs via `env -u REPO_ROOT`"). The narrower text that shipped into the
  `.conf` and `dune` is not faithful to the author's own recorded reasoning. Governing standard:
  `.claude/rules/code-health-discipline.md` (a linter exemption's recorded justification must be
  real, not approximately real) and the filed item's own fix shape.
- **Required fix.** Reword all three sites to a claim that is exactly true — no broader, no
  narrower. One clause suffices, e.g.:

  > Every invocation of this script in that test either (a) overrides `REPO_ROOT` to a
  > freshly-created temp fixture repo, (b) overrides it to a deliberately malformed value that
  > `_repo_root()` rejects with a hard error *before any path is computed* (the
  > malformed-`REPO_ROOT` scenarios), or (c) reaches the walk-up branch — via `env -u REPO_ROOT`,
  > or via `REPO_ROOT=''` which `_repo_root()` treats as unset — from a copy of the script located
  > inside a temp fixture carrying its own `.claude` sentinel. The walk-up seeds from the script's
  > own directory (`dirname "$0"`), not the caller's CWD, so it terminates inside the fixture
  > regardless of where the test is run from. In every case the real `dev/reviews/` and `dev/audit/`
  > are never read.

  Also fix the `dune` comment's "Either way" (now three ways) and stop filing 29a-29c under limb 1.
  Prefer dropping the exhaustive "(scenarios 27b and 28b)" site list, or prefixing it "currently",
  so the prose does not re-acquire an enumeration that drifts. Correspondingly soften
  `dev/status/harness.md`'s "the accurate two-branch invariant" claim, and drop the characterisation
  of `''` as an "override" (it routes to the walk-up).
- **harness_gap: ONGOING_REVIEW.** Deciding whether a natural-language universal claim is
  co-extensive with a set of call sites requires inferential judgment over prose, which no
  deterministic linter can perform. A *partial* linter candidate exists and is worth filing
  separately: assert that the count of `env -u REPO_ROOT` invocation sites in
  `record_qc_audit_test.sh` equals the number enumerated in the exemption prose — that alone would
  have caught the **original** drift mechanically, though not this one. This is the third
  consecutive instance in this family, which strengthens the case for folding it into the
  already-tracked `H-CHECK-EXEMPTION-DRIFT` re-audit.

---
---

Reviewed SHA: c31cc5137ea03463ac2f51fafee9f3ccc10cf74c

## Behavioral QC — harness: universe-deps exemption evidence reword (PR #2363, rework iteration 1)

Re-review at the new tip. The previous behavioral pass (`Reviewed SHA: 81919a57`, above) returned
NEEDS_REWORK on a single finding: the shipped **two-branch** wording quantified over a
**four-shape** invocation set, leaving six sites of the two exempted scripts (30a/b/c, 31a/b/c) —
plus 29a/b/c of `_check_lib.sh:repo_root()`, which the `dune` comment brings in scope — covered by
neither branch. qc-structural APPROVED (5) at this tip; CI `build-and-test` + `perf-tier1-smoke`
both completed/success.

Pure harness / build-config documentation PR. Per `.claude/rules/qc-behavioral-authority.md`
§"When to skip this file entirely", the S\*/L\*/C\*/T\* domain block is **NA in full** — no Weinstein
domain logic is touched. CP1–CP4 is the review.

### Independent re-enumeration from source (second derivation, not a re-read of the author's table)

`grep -n 'REPO_ROOT' trading/devtools/checks/record_qc_audit_test.sh` → 63 hits. Every hit
classified, then cross-checked against every `bash …` invocation line for the two exempted scripts
(59 invocation lines; each one matched to a `REPO_ROOT=` prefix on the same or immediately
preceding line, or to an `env -u` prefix — **no invocation line was left unmatched**):

| Shape | `record_qc_audit.sh` | `write_audit.sh` | `_check_lib.sh:repo_root()` (dune comment only) | Covered by shipped wording? |
|---|---|---|---|---|
| **(a)** `REPO_ROOT=` → freshly-created `mktemp -d` fixture | sc. 1–8, 12, 14–16, 28, 32–39 (`TMP_REPO`, `TARGET2_ROOT`, `WALKUP2_ROOT`) | sc. 7e/7f/8–11, 13, 17–27 (`TMP_REPO`, `TARGET_ROOT`) | — | ✅ (a) |
| **(b)** `REPO_ROOT=` → deliberately malformed (`mktemp -u` name / regular file) | sc. **31a, 31b** | sc. **30a, 30b** | sc. **29a, 29b** | ✅ (b) |
| **(c1)** `env -u REPO_ROOT` | sc. **28b** | sc. **27b** | — | ✅ (c) |
| **(c2)** `REPO_ROOT=''` → `[ -n ]` guard routes to walk-up | sc. **31c** | sc. **30c** | sc. **29c** | ✅ (c) |
| **(d)** bare invocation, no `REPO_ROOT` disposition | none | none | none | n/a |

Counts pinned mechanically: `env -u REPO_ROOT` **invocation** sites = exactly 2 (`:1723`, `:1864`;
the other two grep hits are prose inside comments). `REPO_ROOT=""` sites = exactly 3 (`:1958`
directly, plus `_run_write_audit_30 ""` and `_run_record_qc_audit_31 ""` through the two
`REPO_ROOT="$1"` helper wrappers).

**No fifth shape exists, and no site of either exempted script falls outside (a)/(b)/(c).**
The three-shape invariant as shipped is **exactly true — neither broader nor narrower** — of the
`.conf`'s two entries and of the `dune` comment's wider scope. The finding is closed.

### Sharp angle 1 — is shape (b)'s safety argument the one actually implemented?

**Yes, verified in all three implementations.** The claim is that a malformed value hard-errors at
`_repo_root()`'s `[ -d ]` guard *before any path is computed*. Reading the three functions
(`record_qc_audit.sh` `_repo_root()`, `write_audit.sh` `_repo_root()`, `_check_lib.sh`
`repo_root()`), all three are byte-for-byte identical in control flow:

```sh
if [ -n "${REPO_ROOT:-}" ]; then
  if [ -d "$REPO_ROOT" ]; then echo "$REPO_ROOT"; return 0; fi
  echo "FAIL: REPO_ROOT is set to '$REPO_ROOT' but is not a directory" >&2
  exit 1
fi
dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"   # walk-up seeds here
```

The `[ -d ]` guard is the **second** statement in the function, and the function's sole caller is
the first consumer of `REPO_ROOT` in each script — `REPO_ROOT="$(_repo_root)"` at
`record_qc_audit.sh:149` (`REVIEW_FILE` / `WRITE_AUDIT` computed at `:150`/`:151`) and
`write_audit.sh:255` (`AUDIT_DIR` at `:256`, `mkdir -p` at `:259`). Grepping both scripts for any
`$REPO_ROOT` interpolation ahead of those lines returns nothing but comment prose. So **no path is
derived before the guard fires**, and under `set -euo pipefail` the `exit 1` inside the command
substitution aborts the assignment and the script. The comment does **not** assert a stronger
safety property than the code provides. (The tests corroborate: 30a/30b/31a/31b each assert
`walkup_count == 0`.)

### Sharp angle 2 — is merging the (c) branch legitimate?

**Yes for the claim being made, and I verified the mechanism difference the merge conceals.**
`env -u REPO_ROOT` (absent) and `REPO_ROOT=''` (present-but-empty) reach the walk-up by different
routes, unified only by `[ -n "${REPO_ROOT:-}" ]` — `${…:-}` is null for both. That is precisely
what the wording says (`REPO_ROOT=''` "which `_repo_root()` treats as unset"), so the merge is
accurate at the point where it is asserted.

The one place they genuinely diverge is **downstream, in the export attribute**, and I confirmed it
empirically rather than reasoning about it:

```
REPO_ROOT="" bash parent.sh      → child sees REPO_ROOT=[/tmp/walked-up-value]
env -u REPO_ROOT bash parent.sh  → child sees REPO_ROOT=[<UNSET>]
```

A command-prefix `REPO_ROOT=""` puts the variable in the environment (exported-but-empty); bash
preserves the export attribute across the later **plain** reassignment `REPO_ROOT="$(_repo_root)"`,
so `record_qc_audit.sh`'s `write_audit.sh` child inherits the walked-up fixture root explicitly.
Under `env -u` the variable is absent, the plain reassignment does not export, and the child does
its own walk-up — from `${WALKUP3_ROOT}/trading/devtools/checks/`, i.e. still inside the fixture.
**Both routes terminate in the fixture**, so the merge does not weaken the safety conclusion. It
does mean scenario 31c is a shape-(a) invocation *of the child* — see residual R1.

I also confirmed the walk-up seed is `dirname "$0"` (the script's own directory), not the caller's
CWD, in all three implementations — so the "terminates inside the fixture regardless of caller CWD"
clause is true for *every* starting directory, not only the one the scenarios happen to use. And
all four walk-up fixtures reached by shape (c) invoke a **copy inside the fixture**
(`WALKUP_ROOT` 27b, `WALKUP3_ROOT` 28b, `WALKUP5_ROOT` 30c, `WALKUP6_ROOT` 31c), each `mktemp -d`
with its own `.claude` sentinel — never the real-repo script.

### Exemption set unchanged — confirmed independently

```
git show origin/main:…/universe_deps_exceptions.conf | grep -vE '^[[:space:]]*(#|$)' > /tmp/a
grep -vE '^[[:space:]]*(#|$)' …/universe_deps_exceptions.conf                      > /tmp/b
diff /tmp/a /tmp/b   → (empty; 5 non-comment lines both sides)
```
Also via the diff filter: every `+`/`-` line in the `.conf` is a `#` comment. **Nothing added,
removed, or widened.** The worst available outcome — a widened exemption smuggled in under a prose
fix — did not occur.

### Empirical safety — measured within this run, not compared to the PR body's figures

```
BEFORE  dev/audit/*.json = 128   dev/reviews/*.md = 142
bash trading/devtools/checks/record_qc_audit_test.sh  → EXIT=0, "57 passed, 0 failed"
AFTER   dev/audit/*.json = 128   dev/reviews/*.md = 142
git status --porcelain dev/audit dev/reviews  → clean
```
Run in an isolated `git worktree` at the tip. No real-repo file was read or written.

### `:NNN` citations in new prose — none

`git diff main…HEAD | grep '^+' | grep -E '\.sh:[0-9]+|dune:[0-9]+'` matches **only** inside the
preserved *original filing* text in `dev/status/harness.md` (`:1446`, `:1587`, `:44-47`,
`:471-475`). That text is the audit trail and is correctly left verbatim. The `.conf` and `dune`
comments and the appended **Fixed:**/**Rework** notes cite scenario labels and `_repo_root` by
name. The `dev/status/harness.md` rework note is **appended**, retracting the earlier over-claim
(the "two-branch invariant" and the "`''` still counts as override" characterisation) rather than
amending the original filing — the right shape for an audit trail.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | NA | No `.mli` in this PR; the artifact is three comment blocks. Their equivalent — "is the claim true of the code as it stands?" — is discharged by the enumeration table, the `[ -d ]`-ordering read, and the export-attribute experiment above. |
| CP2 | Each claim in the PR body's gate / evidence sections is borne out by the committed artifact | PASS | Gate claims verified: suite 57/57 exit 0 (re-run by me); `.conf` zero non-comment diff (re-derived); 128/142 counts unchanged (re-measured in my own run); no `:NNN` in new prose. **See residual R2** — the body's *narrative* "New wording" section still describes the superseded two-branch invariant and still files `''` as an "override"; it was not refreshed after the rework commit. Not a test-plan claim and not a shipped artifact, so not a CP2 FAIL, but it should not be carried into the squash message verbatim. |
| CP3 | Pass-through / identity / invariant claims pin identity, not just size | PASS | The load-bearing identity claim is "the exemption set did not move". Pinned by whole-content `diff` of the non-comment lines (5 lines, byte-identical), not by a count. |
| CP4 | Each guard called out explicitly in the new prose has a scenario that exercises the guarded-against case | PASS | (b) `[ -d ]` hard-error → 30a/30b/31a/31b (and 29a/29b for `repo_root()`), each asserting `rc!=0` + the exact FAIL message + `walkup_count == 0`. (c) `REPO_ROOT=''`-treated-as-unset → 29c/30c/31c, each asserting `rc=0` + publish-into-fixture. (c) `env -u` walk-up → 27b/28b. Every clause of the three-shape invariant has a scenario behind it. |

### Residuals (non-blocking, do not gate this merge)

**R1 — the non-exhaustive `"e.g. …"` lists are sound-free but not *sound*.** Replacing the
exhaustive `"(scenarios 27b and 28b)"` with `"e.g. …"` genuinely fixes the drift vector that broke
the original wording: it drops the **completeness** obligation, so a future scenario 32c can land
without falsifying the prose. It does **not** drop the **soundness** obligation — each listed
scenario must actually instantiate the named shape *for the script whose exemption the comment
justifies* — and that obligation is already missed at ship time in two places:

- `record_qc_audit.sh`'s entry says "Every invocation of **this script**… (c) … e.g. scenarios
  27b/28b/29c/30c/31c". Of those five, only **28b and 31c** invoke `record_qc_audit.sh`; 27b and
  30c invoke `write_audit.sh` directly, and 29c invokes a `_check_lib.sh:repo_root()` probe —
  neither of the two exempted scripts.
- `write_audit.sh`'s entry lists **31c** as a shape-(c) example, but per the export-attribute
  result above the `write_audit.sh` *child* in 31c receives an explicit valid override
  (`WALKUP6_ROOT`) — from `write_audit.sh`'s own perspective that is shape **(a)**, not (c).
  (28b's child *is* genuinely (c); 27b/30c are correct.)

Both slips are inside explicitly illustrative lists; **neither leaves any invocation uncovered**,
so the universal claim and the safety conclusion both stand. The honest characterisation of the
`"e.g."` form is therefore: it converts a hard-drift failure mode into a soft-staleness one — a
real improvement, not a complete fix. Cheapest durable form if this is ever touched again: cite the
*shape* only and drop scenario labels from the two `.conf` entries entirely (the `dune` comment,
whose scope legitimately spans all three scripts, files 29a/b under (b) and 29c under (c)
correctly and needs no change).

**R2 — PR body not refreshed after the rework commit.** The body's "## New wording" section still
claims "All three sites now state the accurate **two-branch** invariant", and its enumeration table
still files `29a/b/c, 30a/b/c, 31a/b/c` under "Explicit override to a deliberately malformed/empty
value" — the exact characterisation the rework note retracts (`''` is not an override in effect).
`dev/status/harness.md`'s appended note carries the correct account, so the shipped record is fine;
but a squash merge would land the stale description in `main`'s history. Suggest the merging
orchestrator trim or refresh those two paragraphs in the squash message.

### Behavioral Checklist (domain)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 / S1–S6 / L1–L4 / C1–C3 / T1–T4 | Weinstein domain rows | **NA** | Pure harness / build-config documentation PR; touches only `trading/devtools/checks/{dune,universe_deps_exceptions.conf}` and `dev/status/harness.md`. No stage logic, stops, screener, or strategy config. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". qc-structural did not raise A1. |

## Quality Score

4 — The load-bearing invariant is now exactly true of the code, independently re-derived from
source by a second enumeration, with the `[ -d ]`-ordering and export-attribute questions
empirically settled; the exemption set is provably unmoved and the suite provably touches no
real-repo file. Held off 5 by two soundness slips in the illustrative `"e.g."` scenario lists (R1)
and a PR body left describing the superseded two-branch wording (R2) — both non-blocking.

## Verdict

APPROVED
