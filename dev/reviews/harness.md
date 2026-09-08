Reviewed SHA: 6a1dfdcc58092a6bec8360265d9772b23a110904

# QC review — PR #2721 (`harness/daily-summary-publisher`)

Orchestrator run 34252318116, 2026-09-08.

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | `dune build @fmt` | PASS | exit 0 |
| H2 | `dune build` | PASS | exit 0 |
| H3 | `dune runtest` | PASS | exit 0; 0 `^FAIL:` lines; `OK: publish_daily_summary_test_runner.sh` present in the full log, so the new rule genuinely runs |
| P1 | Function length | NA | No OCaml; shell procedures exit early |
| P2 | No magic numbers | NA | Exit codes (0/1/2) and HTTP codes (201/422) are named, not bare |
| P3 | Configurable values in a config record | NA | No strategy knobs; repo/remote/base-branch/daily-dir come from a declared ENV section |
| P4 | Public-symbol export hygiene | NA | Internal functions underscore-prefixed; a guard restricts the exported surface when sourced |
| P5 | Internal helpers prefixed per convention | PASS | All internal functions `_`-prefixed; `cmd_publish` is the single public entry point |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | NA | Shell suite, not OUnit/Matchers. Explicit `check()` / `check_contains()` / `check_not_contains()` assertions, mock `curl`, real git fixtures |
| A1 | Core module modification (Portfolio/Orders/Position/Strategy/Engine) | NA | Harness/infrastructure only |
| A2 | `analysis/` → `trading/trading/` dependency boundary | NA | No `trading/trading` source touched; no `(libraries ...)` change |
| A3 | No unnecessary modifications to existing modules | PASS | 5 files: 3 new, 2 additive edits (`dune` + `harness.md`). File list taken from `/pulls/2721/files`, not a git-log ancestry walk |

### Absolute rules

- **No Python** (`.claude/rules/no-python.md`): `find . -name "*.py"` returns empty. PASS.
- **POSIX sh**: all three scripts are `#!/bin/sh`; no bash-isms in the script itself. PASS.
- **Dune wiring**: matches the `prior_cell_check_test_runner.sh` / `prune_candidates_test_runner.sh` shim pattern — `repo_root()` resolution, `(universe)` dep for cache invalidation, FAIL (not SKIP) when the test is absent. PASS.

### Non-vacuity — measured twice, independently

The orchestrator ran these before opening the PR; the reviewer re-derived them rather than inheriting them, and the two sets agree.

| mutation | suite |
|---|---|
| no-summary guard `return 1` → `return 0` (fail **open** — the exact shape being replaced) | **34/35**, exit 1 |
| drop the `-plan.md` exclusion from summary resolution | **33/35**, exit 1 |
| restored | **35/35**, exit 0 |

### Adversarial checks performed

- **Every exit path fails closed** — resolution, `GH_TOKEN` validation, file existence, git operations, PR-create. No silent-success path found. This is the load-bearing property: the defect being replaced failed *silently*.
- **`--dry-run` fidelity** — network-touching steps (`curl`, `git push`, PR-create) are skipped under `--dry-run`; the suite pins this with a forbidden-`curl` mock, so a dry-run that secretly reached the network would go red.
- **Idempotency** — the already-open-PR path (422 → look up by head) is wired, not merely described.

## Quality Score

5 — Exemplary. POSIX shell throughout, fail-closed at every step, 35 fixture-driven scenarios including network failure, idempotency and dry-run isolation, mutation-verified guards, correct dune wiring. No code smell, no drift, no suppression markers.

## Verdict

APPROVED

## Note for behavioral review

Pure harness/infrastructure PR. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", the S\*/L\*/C\*/T\* domain block is NA; review against the generic Contract Pinning Checklist CP1–CP4 only.

## Declared scope limit (not a defect)

This PR closes the **mechanism** and explicitly not the **call site**: `.claude/agents/lead-orchestrator.md` Step 8 still publishes via `jj` and has not been repointed at the new script, because `.claude/agents/**` is write-gated in this runtime. The PR body and the `dev/status/harness.md` entry both state this, and the backlog item is deliberately left `- [ ]`. Until Step 8 is repointed, summaries will keep being lost exactly as measured.

---

# Behavioral review — same SHA `6a1dfdcc`

Gates re-derived independently in the reviewer's own worktree: `dune build @fmt` 0, `dune build` 0, `dune runtest` 0, `^FAIL:` 0; suite 35/35 under `bash`, under `dash`, via the shim, and inside `dune runtest`. **All matched the orchestrator's measurements**, including both cited mutations (34/35 and 33/35, exit 1 each).

Then it went further: **28 mutations run, 16 killed, 12 survived.**

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial docstring claim has an identified test pinning it | **FAIL** | `_resolve_summary_path` claims "newest … (mtime order)". `ls -t` → `ls` survives **35/35** — including the check literally named "picks the newest `-runN` variant **by mtime**", because the fixture's files sort identically under both orders. Against the real naming on `main` today (`2026-07-28-run2/3/4.md`) the mutant resolves **run2** where the shipped script resolves **run4** — publishing the day's FIRST summary while reporting success. `--summary`, `--base` and the branch-**reuse** behaviour are documented in USAGE and likewise unpinned |
| CP2 | Each PR-body test claim has a corresponding committed test | **PASS** | "35 fixture-driven checks" verified across four invocation paths; the non-vacuity table reproduces exactly. No advertised test is missing |
| CP3 | Pass-through / invariant tests pin identity, not existence or count | **FAIL** | The three `"landed on the bare remote"` assertions run `git branch --list ops/daily-…`, which pins the branch **name** and never that the summary is **on** it. Inserting `git reset -q --hard` immediately before `git push` yields: prints `PR #123 <url>`, **exit 0**, branch present on the remote, `dev/daily/2026-09-08.md` **absent from it** — and the suite reports **35/35** |
| CP4 | Each guard named in a docstring has a test exercising the guarded scenario | **FAIL** | (a) **The production code path is never executed** — every fixture `git add && git commit`s the summary *before* invoking publish, so only the "already committed, nothing to add" branch runs; replacing the script's own `git add`+`git commit` branch with `return 1` leaves **35/35 green**. In production the summary is a new, uncommitted file, so the untested branch *is* the production path. (b) The mock `curl` never inspects the POST payload, so `head`/`base`/`title`/`body` are unasserted — a wrong `head` would open a PR from the wrong branch, another silent-drop shape |

## Domain checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | **NA** | Pure harness/infrastructure PR — a shell publisher, its suite, a dune shim and a status entry. No stage classification, entry/exit, stop, screener, sizing or backtest logic. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely", CP1–CP4 constitute the full review. No `BOOK-CHECK-NEEDED` items — no faithfulness claim is made or implied |

## Dry-run fidelity — hypothesis right in kind, wrong in location

The dispatch asked the reviewer to hunt `--dry-run` fidelity adversarially. It cleared dry-run and found the real gap elsewhere: dry-run skips exactly three things (existing-PR pre-check, `git push`, PR-create POST) and **all three are genuinely exercised in non-dry-run mode** against a local bare `origin` plus a mocked `curl`; six mutations against them all go red.

The divergence is **upstream, in the fixture**: it pre-commits the summary, so both modes exercise only the degenerate "already committed" shape. That is why neither dry-run inspection nor qc-structural's code read could see it.

## Honesty of scope — PASS

The declared limitation is stated correctly and is not a defect. Two accuracy notes worth fixing in the same pass, since this repo squash-merges the body into `main`'s commit message: the body says `--dry-run` skips "the push and the POST" (it also skips the existing-PR lookup — the script's own docstring is correct), and `harness.md` points at a mutation list "in the script's own header" that lives only in the PR body.

## Quality Score

2 — Below standard. The implementation and its guards are well built and 16 of 28 mutations are properly killed, but the suite does not pin the PR's own thesis (a mutant that publishes nothing still reports success at 35/35) and never executes the production commit path.

## Verdict

NEEDS_REWORK

## Required fixes

1. **CP3** — assert branch **content**, not branch existence: `git --git-dir="$BARE_DIR" show "ops/daily-<date>:dev/daily/<date>.md"` must contain a sentinel.
2. **CP4/CP1** — add one scenario in the **production shape** (write the summary, do *not* pre-commit it), asserting exit 0 **and** the sentinel on the pushed branch. The reviewer verified empirically that this single scenario passes against the shipped script and **kills both** critical survivors.
3. **CP1** — add a third `-runN` whose lexical and mtime order **disagree**, and assert the mtime winner.
4. **CP4** — have the mock `curl` write its `-d` payload to a file and assert `head`/`base`/`title`; add `--summary`, `--base` and branch-reuse scenarios. In-repo precedent for pinning survivors explicitly rather than leaving them undiscovered: `trading/devtools/checks/pr_gate_status_mutation_*`.

## Combined result

`overall_qc: NEEDS_REWORK (behavioral)` — structural APPROVED (5), behavioral NEEDS_REWORK (2) at the same SHA. Audit: `dev/audit/2026-09-08-harness-daily-summary-publisher-harness.json`.


---

# QC review — PR #2725 (`harness/prune-anchor-selfref`)

Structural reviewed at SHA `c96e6c2b`. **Tip is now `4bd4c221`** after an
orchestrator rebase onto `bd7ac580` (see "SHA caveat" below).

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | `dune build @fmt` | PASS | exit 0 |
| H2 | `dune build` | PASS | exit 0 |
| H3 | `dune runtest` | PASS | exit 0; `prune_candidates_test: 36 passed, 0 failed` |
| P1–P4, P6 | linter-covered rows | NA | POSIX shell + markdown; no OCaml |
| P5 | Internal helpers prefixed | NA→PASS | shell `_function_name` convention followed throughout |
| A1 | Core module modification | NA | harness script only |
| A2 | Dependency boundary | NA | no `(libraries …)` change |
| A3 | No unnecessary modifications | PASS | three files, all necessary: `prune_candidates.sh`, `prune_candidates_test.sh`, `dev/status/harness.md` |

**No Python** verified. Both scripts pass `dash -n`.

## The six scepticism items the dispatch asked for

1. **`ROOT` swap leak** — PASS. `ROOT="$tmp"` at line 531; **all six** return paths (534, 541, 548, 555, 561) restore `ROOT="$orig_root"` unconditionally. No early exit escapes restoration.
2. **Writes into the real repo** — PASS. Every write is confined to the `mktemp -d` dir; no redirect targets a path outside it; `rm -rf "$tmp"` is unconditional.
3. **Two-sidedness real** — PASS, and independently reproduced. Mutation 1 (`_is_cited` → `return 0`) trips the false-CLEAN guard; mutation 2 (`return 1`) trips the false-ORPHAN guard. The two guards are independent — neither alone covers both directions.
4. **Live script exits 0 on this tree** — PASS, run *after* the status-file edit. This is the trap the fix had to survive: the new `harness.md` entry necessarily names the old anchor, so a fix that still resolved against the live tree would have re-broken the probe while documenting the repair.
5. **The declared tradeoff** (the probe no longer proves `find`'s enumeration of the real tree) — **argued, not merely asserted.** All three historical failures of this probe were citation/dating *primitive* bugs (`\s` vs `[[:space:]]`, git `safe.directory`, and this one); `find -mindepth 1 -maxdepth 1 -type d` has no regex or locale surface to break the same way. Reviewer judged the trade reasonable on that evidence.
6. **The self-disclosed gap** (deleting the `_checker2_self_test || return 1` call site is caught by nothing) — legitimate and consistent: the pre-existing checker3 probe has the identical hole. Recorded rather than hidden, which is the point.

## Mutations — independently re-run, matched the author exactly

| # | mutation | author claimed | reviewer measured |
|---|---|---|---|
| 1 | `_is_cited` → `return 0` (match everything) | 4 passed / 32 failed | **4 / 32 — exact match** |
| 2 | `_is_cited` → `return 1` (match nothing) | 5 passed / 31 failed | **5 / 31 — exact match** |

## Fixture C — the regression test for this bug's shape

Documents a synthetic old experiment dir from a synthetic `dev/status/harness.md`, mirroring exactly what `efc25d68` did to the real anchor, and asserts the probe still passes with the dir correctly excluded. Reviewer confirmed it reproduces the historical bug's shape rather than a weaker cousin.

## Quality Score

5 — Exemplary. Gates all green, mutations two-sided and non-vacuous with counts matching to the digit, regression fixture pins the exact issue, temp-resource cleanup unconditional on every path, and both the tradeoff and the residual gap disclosed rather than buried.

## Verdict

APPROVED

## SHA caveat — read before merging

The verdict above was taken at `c96e6c2b`. PR #2721 merged mid-run and took the same `dev/status/harness.md` section, leaving #2725 `mergeable_state: dirty` — and **a conflicted PR gets no CI at all**, because GitHub cannot build the merge ref that `pull_request` workflows run against. The orchestrator therefore rebased onto `bd7ac580` and force-pushed `4bd4c221`.

**The only delta is the conflict resolution** — both backlog entries kept, `main`'s `H-DAILY-SUMMARY-PR-LOST` first, then `H-PRUNE-ANCHOR-SELFREF`. No script or test byte changed. After the resolution the orchestrator re-verified, because `harness.md` is itself one of the script's five citation sources and had just changed:

```
bash dev/scripts/prune_candidates.sh        exit 0
bash dev/scripts/prune_candidates_test.sh   exit 0   (36 passed, 0 failed)
```

Strictly, the structural verdict is stale at the new tip and should be re-confirmed there. It is recorded as APPROVED-at-`c96e6c2b` rather than silently carried forward. **Behavioral QC has not run at all.**
