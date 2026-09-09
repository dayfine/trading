Reviewed SHA: 07629f5eb1fbadcff0050c8c87e24cde4d70f136

## Behavioral QC — harness/publisher-mutant-reconcile (PR #2749, rework pass)

Supersedes the qc-behavioral verdict posted at `906c9390` (NEEDS_REWORK, quality 2).
Scope: pure harness/infra PR — the diff is `dev/scripts/publish_daily_summary.sh`
(comment-only; verified no non-comment line changed vs `origin/main`) and
`dev/status/harness.md` (prose). Reviewed through generic CP1–CP4; the entire
Weinstein S\*/L\*/C\*/T\* block is NA.

### Measurements taken (all exit codes read unpiped, standalone suite, no dune)

| # | what | result |
|---|------|--------|
| M0 | baseline `sh dev/scripts/publish_daily_summary_test.sh` | **52/52, exit 0** |
| M1 | **recorded recipe replayed verbatim** — delete both `if [ -z "$_num" ]; …; fi` blocks in `_create_pr` (lines 195–198 and 207–210, whole `if`/`fi` incl. their `echo`), line-331 backstop untouched | **51/52, exit 1**, sole failure `FAIL malformed-201 names the risk: expected output to contain no PR number in the response body` — **matches the record exactly, including the failing check's name** |
| M2 | inverted recipe replayed — keep both blocks and their `echo`s, flip only `return 1` → `return 0`, backstop untouched | **52/52, exit 0** — matches the record |
| M3 | **equivalence probe** — one extra `check_contains "…" "$_out" "pushed but has NO PR"` added to the malformed-201 scenario, run against production | **53/53, exit 0** |
| M4 | same probe run against the M2 mutant | **52/53, exit 1**, `FAIL PROBE malformed-201 also names the outer risk` |

Both mutated files restored byte-identically (`git diff` empty, suite back to
52/52 exit 0); no `.orig`/`.bak` left on disk or tracked.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | New `.mli` docstring claims pinned by tests | NA | No `.mli` in the diff; no OCaml touched. |
| CP2 | PR-body / recorded claims vs committed tests + measured reality | **FAIL** | Two live false claims at this tip — see F1, F2 below. The 51/52 recipe itself replays perfectly (M1); what fails is (F1) the PR body still attributing 51/52 to the *inverted* recipe, contradicting the status file corrected in this same PR, and (F2) the status file classifying the inverted reading as an *equivalent mutant* when M3/M4 show a one-line assertion distinguishes it. |
| CP3 | Pass-through / identity assertions pin identity, not just size | NA | No pass-through semantics introduced. The published-content identity assertions (`_remote_file_content` + "pushed branch carries the summary CONTENT") already exist from #2727 and are untouched here. |
| CP4 | Guards named in docstrings have tests exercising the guarded scenario | PASS | Every guard the header names (`resolve` no-summary, push-failure, PR-create curl-error, malformed-201, 422-lookup-empty, line-331 backstop) has a scenario; M1 confirms the malformed-201 diagnostic is genuinely load-bearing (deleting it reddens exactly one check). Caveat: the *201/422 inner guards' return code* is only pinned transitively via the backstop — that is the substance of F2. |

### Behavioral Checklist (Weinstein domain)

| # | Status | Notes |
|---|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | NA | Pure harness / docs PR; no strategy, stops, screener, or simulation logic touched. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely". No `BOOK-CHECK-NEEDED` items arise. |

### CP2-a (prior finding) — CLOSED

The header's pointer now resolves to text that agrees with it. `H-JJ-JST-BROKEN-GHA`
opened on `main` with "**`jj` and `jst` are non-functional in the GHA orchestrator
container**, so **no dispatched agent can open its own PR**"; at this tip it opens
with "**`jst submit` (and any `jj` subcommand that triggers `jj git fetch
--all-remotes`) is non-functional …**, so **no dispatched agent can open its own PR
via `jst`**", plus an explicit scope note forbidding the blanket reading from being
extended to plain `jj git push`.

Checked for over- and under-claim against issue #2741 directly (re-read, not from
the first pass's notes):

- D1 as now stated (image git 2.34.1 vs jj's `jj git fetch --porcelain` needing
  ≥ 2.41.0, `jst submit` dying inside the fetch) matches #2741's measurement table
  and its own D1 paragraph verbatim in substance. Not overstated.
- The generalisation "any `jj` subcommand that triggers `jj git fetch
  --all-remotes`" is broader than the single measured caller (`jst submit`), but
  the fault is in `jj git fetch` itself (measured exit 1 standalone in #2741), so
  it is invariant to the caller. Sound, and strictly narrower than what it replaced.
- Not understated either: the entry declines to claim `jj git push` works, and
  routes that positive claim to #2741 / the `H-DAILY-SUMMARY-PR-LOST` entry, which
  does state it with the probe-branch evidence. The D2 characterisation there
  (git-identity not read by jj; missing `jj describe`; both independently fatal;
  `jj config set --user …` + `jj describe` fixes both) matches #2741 line for line.
- The downgrade of "every agent-facing PR-creation path **is** dead" to "**was
  treated as** dead … the only working path is the Step 4.5 `curl` REST fallback
  (still true for `jst`/`gh` specifically)" is the right correction: PR *creation*
  still needs REST (no `gh`, `jst` broken) even though `jj git push` works.

No new wrongness introduced in the other direction. CP2-a is closed.

### CP2-b (prior finding) — the recipe replays; the classification does not hold

The literal contract of this rework item passes. **M1 reproduces 51/52, exit 1**,
with the same single failing check the record names. **M2 reproduces 52/52, exit
0.** The record's mechanism for the M2 result is also correct as written: the
surviving `echo` writes to fd 2, so `check_contains "malformed-201 names the risk"`
still passes; `_create_pr`'s captured *stdout* is still empty (the `return 0` exits
before the `printf`), so the line-331 backstop independently forces `rc = 1`.

What does not hold is the classification. `dev/status/harness.md` line 164 says the
two guards "become redundant under this mutation **without changing any externally
observable behavior** … an **equivalent mutant**, not a caught regression." That is
falsifiable and false:

- Production, malformed-201 path: `_create_pr` returns 1 → `cmd_publish` line 324
  emits *"PR creation failed -- branch `<b>` is pushed but has NO PR. Do not treat
  the push alone as success."*
- M2 mutant, same path: `_create_pr` returns 0 with empty stdout → line 324 is
  skipped and line 332's *"PR creation reported no PR number -- treating as a
  failure"* is emitted instead.

The scenario already captures `2>&1`, so this difference is inside the suite's
existing observation window. Adding one `check_contains` for `"pushed but has NO
PR"` to the malformed-201 scenario gives production **53/53** (M3) and the mutant
**52/53, exit 1** (M4). A mutant killed by a one-line assertion is a **live
survivor**, not an equivalent mutant.

This is not a cosmetic label. The repo's own standard for the term, in this same
file (the `s5` row of `H-GATEPARSER-NO-MUTATION-COVERAGE`), is a **verified**
equivalent mutant — "confirmed directly … no test can ever distinguish the two
readings". This entry asserts equivalence without that verification, and the
verification fails. The lost line is specifically the operator-facing message that
`H-DAILY-SUMMARY-PR-LOST` exists to make loud, and the sibling create-failure
scenario asserts that exact string — so a future reader taking the "equivalent
mutant" label at face value could delete a guard and quietly narrow the diagnostic.
That is the same shape of harm as CP2-a: a reader deriving an action from this
file's rationale.

## NEEDS_REWORK Items

#### F1 — the PR body still carries the inverted recipe the rework was raised to fix
- Finding: the PR body's "Control:" paragraph reads *"the interactive pass's own
  mutation C (**both no-PR-number guards → `return 0`**) still gives **exit 1,
  51/52**"*. Measured (M2): that recipe gives **52/52, exit 0**. 51/52 belongs to
  the *guards-deleted* recipe (M1). The status file corrected in this same PR
  (line 164) says so explicitly — so the PR and its own record contradict each
  other at this tip, and the PR body is what a merger reads.
- Location: PR #2749 body, "Control:" paragraph (≈ line 42 of the body), vs
  `dev/status/harness.md:162` and `:164`.
- Authority: `dev/status/harness.md:164` (this PR's own corrected record);
  measurements M1/M2 above.
- Required fix: restate the PR-body control as the guards-**deleted** recipe →
  51/52 exit 1, or drop the recipe wording and cite the status-file entry. One
  sentence; no code change.
- harness_gap: ONGOING_REVIEW — requires reading a prose claim against a measured
  number; no linter can pair them.

#### F2 — "equivalent mutant" is a live survivor, not a verified equivalence
- Finding: `dev/status/harness.md:164` classifies the guards-flipped reading as an
  equivalent mutant "without changing any externally observable behavior". M3/M4
  show a single added `check_contains` for `"pushed but has NO PR"` separates
  production (53/53) from the mutant (52/53, exit 1). The observable difference is
  which outer diagnostic `cmd_publish` emits — line 324 vs line 332 — and the
  scenario already captures stderr.
- Location: `dev/status/harness.md:164`; mechanism at
  `dev/scripts/publish_daily_summary.sh:195-200` and `:322-334`;
  scenario at `dev/scripts/publish_daily_summary_test.sh:441-451`.
- Authority: the repo's own bar for the term, `dev/status/harness.md` `s5` row
  ("verified equivalent mutant … no test can ever distinguish the two readings");
  `.claude/rules/qc-behavioral-authority.md` CP2 (recorded claims must match what
  the tests actually do).
- Required fix: either (a) **preferred** — add the one-line
  `check_contains "malformed-201 also names the outer risk" "$_out" "pushed but has
  NO PR"` after `publish_daily_summary_test.sh:451`, which makes the suite 53/53,
  kills the mutant, and makes the classification question moot; or (b) restate the
  entry as "not distinguished by the suite as it stands — a survivor, not a
  verified equivalent mutant; the outer diagnostic does differ (line 324 vs line
  332)". Do not leave the current wording.
- harness_gap: LINTER_CANDIDATE for the (a) branch — the missing assertion is a
  concrete, deterministic test that pins a named diagnostic string, exactly the
  shape the rest of this suite already uses.

### Non-blocking items from the prior pass — both closed

- `dev/scripts/publish_daily_summary.sh.orig` is **not** committed: `git ls-files`
  finds no `.orig`/`.bak` anywhere, and none exist on disk. The only untracked path
  in the worktree is the prior review file `dev/reviews/harness-publisher.md`.
- The false *"#2727 merged before #2729 was filed"* claim does **not** appear in
  `dev/status/harness.md`. The only chronology it states is "landed via #2727 on
  2026-09-08", which is correct (verified via API: #2727 merged
  `2026-09-08T19:49:23Z`). The PR body now carries an explicit correction block
  with the same timestamps.

### Non-blocking nit (not a FAIL)

`dev/status/harness.md:160` heads the follow-up "(issue #2729, **2026-09-09**)".
#2729 was filed `2026-09-08T19:14:33Z`. The natural reading — that 2026-09-09 is
the date of the follow-up work, matching the entry-date convention used at line
158 — is correct, so this is ambiguity rather than error; worth disambiguating
only because this PR is specifically about citation precision.

## Quality Score

2 — The hard part landed: the 51/52 recipe now replays exactly, and the #2741
rescoping is accurate in both directions. But two claims are still wrong at this
tip — the PR body preserves the very recipe inversion this rework existed to fix,
and "equivalent mutant" is a live survivor a one-line assertion kills. Below
standard, and both fixes are small.

## Verdict

NEEDS_REWORK
