# Status: harness

## Last updated: 2026-08-21

## Recent activity (2026-05-09..22, since last refresh)

### CI hardening (PRs #1117, #1121, #1130, #1131, #1138)

- **#1117 — `no_python_check.sh` race-proof prune** (MERGED 2026-05-16):
  guards against dune sandbox cleanup racing the no-Python linter walk
  (closes intermittent CI red triggered by sandbox dir disappearing
  mid-`find`).
- **#1121 — remove cache restore-keys** (MERGED 2026-05-16): GHA cache
  partial-key hits were resurrecting stale binaries that built on a
  prior libc. Explicit-key only.
- **#1130 — rebuild image with `-march=x86-64-v2` + CPU-flag smoke
  test** (MERGED 2026-05-16): baseline CPU level bump for #1129
  dependency floor; smoke test added in the devcontainer build
  pipeline.
- **#1131 — browser headers + 503/429 retry-with-backoff for IWV
  fetcher** (MERGED 2026-05-16): partial unblock attempt for the IWV
  scrape (`data-foundations` Phase 1.4); Akamai still ultimately
  blocks both local + GHA-runner egress (see `data-foundations.md`
  for the open vendor decision).
- **#1138 — `iwv-scrape-once` workflow_dispatch** (MERGED 2026-05-17):
  GHA workflow for IP-independent IWV retries; Akamai blocks the GHA
  egress path too, but the workflow lets ops-data run from a different
  runner pool on demand.

### CSV-storage / CSV-manifest test guards (PRs #1153, #1158)

- **#1153 — `is_directory` guard on `_reconcile_log_for` readdir**
  (MERGED 2026-05-17): closes a CSV-manifest test race that surfaced
  on #1148/#1150 (Phase 2 + Phase 3 manifest stack) when test temp_dir
  cleanup raced the reconcile-log inspection.
- **#1158 — `is_directory` guard on `test_reconcile_log_path_layout`
  readdir** (MERGED 2026-05-17): same hazard, second test site.

### Weekly deep health scan + rules promotion (PRs #1198, #1227)

- **#1198 — weekly deep health scan 2026-05-18** (MERGED 2026-05-18):
  ops/health-deep PR per the existing GHA Monday-cron workflow.
- **#1227 — promote session-tested QC + merge + rampup norms from
  memory to repo** (MERGED 2026-05-21): institutional-knowledge-capture
  PR. New repo-level rules under `.claude/rules/` (referenced by
  qc-structural-authority.md, qc-behavioral-authority.md):
  pr-merge-gates, session-rampup, code-health-discipline. Lifts norms
  previously held only in `~/.claude/memory/` so they apply in every
  harness session, not only when memory pre-loaded.

## sweep-honor-locks (2026-05-08 incident)
- **Incident (2026-05-08):** Operator ran `--force --stale-hours 0` while two cleanup agents were mid-flight. The script removed their worktrees, killing both agents' work in progress. Root cause: script used `git worktree remove --force` (overrides lock) and `rm -rf` fallback unconditionally; did not read lock state from `git worktree list --porcelain`.
- **Fix (PR harness/sweep-honor-locks):** (1) Parse `git worktree list --porcelain` once per run; build locked-paths set; skip any locked candidate unless `--include-active` is passed. (2) Reject `--stale-hours 0` with exit 1. (3) Drop `--force` from `git worktree remove` so git's own lock check fires. (4) Log each skipped locked worktree. New `--include-active` flag for emergency override (must be combined with `--stale-hours >= 1`). Smoke test: `trading/devtools/checks/sweep_worktrees_smoke.sh` (wired into `dune runtest`). `.claude/rules/worktree-isolation.md §Cleanup` updated with new flags and lock-honoring behavior.
- **Verify:** `dune runtest devtools/checks/` — prints `OK: sweep_worktrees_smoke — 3 assertion(s) passed, 0 failed.`; `bash dev/scripts/sweep_stale_worktrees.sh --stale-hours 0` exits 1 with error message.

## Status
IN_PROGRESS

## structural_qc (gha-cost-tracking, PR #483): APPROVED (2026-04-21 run-2, re-review after rework)
Branch: harness/gha-cost-tracking. SHA: 792b5b0901c963a021526e53223f6adaef65dcdf. See dev/reviews/harness.md §"Structural Checklist — harness gha-cost-tracking (PR #483, re-review after POSIX-sh rework)". All 13 checklist items PASS or NA; H3 now PASSES after POSIX-sh fixes (shebang `#!/bin/sh`, `set -eu`, bash array → tmpfile + xargs, `${BASH_SOURCE[0]}` → `repo_root` helper, `<<<` → `< /dev/null`). Behavioral review N/A (harness/utility-script PR — no domain logic). Mergeable_state "dirty" is a status-file conflict with #485 (docs-only), not a QC failure — resolved at merge time.

**Prior review (historical):** structural_qc NEEDS_REWORK at SHA d1ba14a3 (2026-04-21 run-1). Original review body retained at top of dev/reviews/harness.md.

## structural_qc: APPROVED (2026-04-20)
Branch: harness/deep-scan-drift-coverage. SHA: f0c402a620247a9423a9982c4300222cf2cd644a. See dev/reviews/harness.md.

## structural_qc (consolidate_day, PR #467): APPROVED (2026-04-20)
Branch: harness/consolidate-day. SHA: 6f2255639cb326745aad06f755de1839a9fe3847. See dev/reviews/harness.md §"Structural Checklist — consolidate_day (PR #467)".

## CI

- CI is now live (#270, #271) — `dune build && dune runtest && dune build @fmt` gates on every PR
- Weekly deps-freshness workflow added
- `test_data/` fixtures committed for CI reproducibility

## Design doc
`docs/design/harness-engineering-plan.md`

---

## Tier 1 — Immediate

- [x] T1-A: Add `dune fmt --check` as hard gate — `devtools/checks/fmt_check.sh` uses `ocamlformat --check` on all source files
- [x] T1-A: Add architecture layer test (`analysis/` cannot import `trading/trading/`)
- [x] T1-A+: Custom linter — function length (>50 lines = test failure) — OCaml AST-based via `compiler-libs`; `@large-function` annotation to opt out specific functions
- [x] T1-A+: Custom linter — magic numbers in `analysis/weinstein/` not in config — extended to whole codebase; path exceptions in `devtools/checks/linter_exceptions.conf`
- [x] T1-A+: Custom linter — magic numbers: allow named constant definitions (`let foo = <num>`)
- [x] T1-A+: Custom linter — public `.ml` functions missing from `.mli`
- [x] T1-B: Create `qc-structural` agent (refactored from `qc-reviewer`; A1 is FLAG not FAIL)
- [x] T1-B: Create `qc-behavioral` agent (new, domain-focused; includes A1 generalizability judgment)
- [x] T1-B: Update `lead-orchestrator` to spawn both QC agents (structural gates behavioral)
- [x] T1-C: Add `## Acceptance Checklist` to each `feat-*.md` agent definition
- [x] T1-C: Create `feat-agent-template.md` — required sections for all feat-agents (extensibility + health-scanner compliance)
- [x] T1-D: Define structured QC checklist output format (per-item PASS/FAIL/FLAG, not prose)
- [x] T1-E: Pre-flight context injection on every feat-agent dispatch (test failures, last QC, open follow-ups)
- [x] T1-F: Define lead-orchestrator blueprint format (explicit deterministic vs agentic nodes)
- [x] T1-G: Add max-iterations policy to each feat-agent definition (cap build-fix cycles at 3)
- [x] T1-H: Specify allowed tool subsets per agent type in agent definitions
- [x] T1-I: Agent definition compliance test — `devtools/checks/agent_compliance_check.sh` verifies all feat-*.md have required sections; runs as part of `dune runtest`
- [x] T1-J: Stale branch preflight in `qc-structural` — Step 1 now checks commits-behind-main; FLAG (not FAIL) if > 10 commits behind
- [x] T1-K: Linter exception retirement policy — `linter_exceptions.conf` entries now carry `# review_at:` annotations; health-scanner deep scan will surface expired ones (T3-A)
- [x] T1-L: Parallel write conflict policy documented in `lead-orchestrator` Step 4 — shared files read-only during parallel execution; proposed changes surfaced in return values
- [x] T1-M: "Done" definition — add explicit acceptance criteria to each Tier 1 item's completion note (harness items should state what was built, where it lives, and how to verify) — DONE: see Completed section below
- [x] T1-N: Golden scenario test suite — screener regression tests; 8 scenarios using real AAPL data; `trading/analysis/weinstein/screener/test/regression_test.ml`. Verify: run `./_build/default/analysis/weinstein/screener/test/regression_test.exe` (8 tests, OK)
- [x] T1-N: Golden scenario test suite — stop state machine regression tests; 5 scenarios covering Stage2 trailing, Stage3 tightening, stop-hit, short side; `trading/trading/weinstein/stops/test/regression_test.ml` — DONE: see completion note below (#204)
- [x] T1-O: `health-scanner` agent — fast scan: stale status files, main build health, new unexcepted magic numbers; runs post-orchestrator; spec extends `docs/design/harness-engineering-plan.md`
- [x] T1-P: Add `## Blocking Refactors` section to all feat-agent status files; update `lead-orchestrator` to dispatch blocking refactors before feat-agents
- [x] T1-P: Update `lead-orchestrator` to count followup items and schedule non-blocking maintenance cycles (threshold: 10 items or every 3rd run)
- [x] T1-P: Add `## Refactor Mode` prompt variant to feat-agent definitions
- [x] T1-Q: Cyclomatic complexity linter — extend `fn_length_linter` via `compiler-libs`; CC > 10 = warning; output to `dev/metrics/cc-YYYY-MM-DD.json`
- [x] T1-Q: qc-behavioral quality score — add `## Quality Score` (1–5 + rationale) to output; tracked in audit trail
- [x] T1-R: Auto-cleanup merged-PR worktrees on session end — `dev/scripts/cleanup_merged_worktrees.sh` (jj-state-driven; no registry; sweeps `.claude/worktrees/agent-*/` whose branch is gone from origin); wired via Stop hook in `.claude/settings.json`. Closes the disk-pressure gap during long interactive sessions where merged-PR worktrees idle for hours before the SessionStart sweep catches them. Verify: dry-run via `bash dev/scripts/cleanup_merged_worktrees.sh --dry-run`. Slash-command surface (`/cleanup-merged` for opt-in mid-session reclaim) deferred to follow-up.
- [x] T1-S: GitHub branch protection on `main` — required status checks `build-and-test` + `perf-tier1-smoke`, `enforce_admins: true`, no force-pushes, no deletions; `strict: true` (branch must be up-to-date before merge). Applied via `gh api repos/dayfine/trading/branches/main/protection`. Closes issue #885. Verify: `gh api repos/dayfine/trading/branches/main/protection | jq '.required_status_checks.checks'` — should show both check names; `gh pr merge --squash` on a PR with failed CI now returns an error. PR: harness/ci-merge-gate.

## Tier 2 — Milestone-gated

- [ ] T2-B: Performance gate test (`trading/weinstein/simulation/test/performance_gate_test.ml`) (at M5)
- [x] T2-B: Reference backtest config + expected metrics — landed at `trading/test_data/backtest_scenarios/goldens/` via #316 (sexp, not json; different location than originally planned). See `dev/status/backtest-infra.md`.
- [ ] T2-C: Walk-forward regression gate (`dev/benchmarks/best_config.json`) (at M7)
- [ ] T2-D: Live trading gate + paper-trading validation period in `dev/milestones/m6-paper-trading.md` (before M6)

## Tier 3 — After M5 stable

- [x] T3-A: `health-scanner` agent — deep scan (weekly: dead code, design doc drift, TODO accumulation, size violations) — DONE: see completion note below
- [x] T3-A: `health-scanner` deep scan — QC calibration audit (verdicts vs regression history) — DONE: see completion note below
- [x] T3-A: `health-scanner` deep scan — harness scaffolding review (flag unused harness components) — DONE: Check 7 in `trading/devtools/checks/deep_scan.sh`; three heuristics (script not referenced, linter binary not wired, broken agent path ref); output under `## Harness Scaffolding` in `dev/health/YYYY-MM-DD-deep.md`. Verify: `sh trading/devtools/checks/deep_scan.sh` — report contains `## Harness Scaffolding` section.
- [x] T3-A: `health-scanner` deep scan — feat-agent template compliance check (covered by T1-I: `agent_compliance_check.sh`)
- [x] T3-A+: **Move health-scanner deep scan to weekly GHA cron.** `.github/workflows/health-deep-weekly.yml` dispatches `health-scanner` in deep mode every Monday at 15:17 UTC (08:17 PT). Report lands on `ops/health-deep-<YYYY-MM-DD>` branch; PR opened via GH REST API with title `ops: weekly deep health scan <YYYY-MM-DD>`. No auto-merge — advisory scan, human reviews and merges. `if: always()` on the push step captures partial reports on agent failure. Verify: `gh workflow run health-deep-weekly.yml` (manual trigger) or check a Monday GHA run; PR title matches pattern above; report at `dev/health/<date>-deep.md`.
- [x] T3-A+: **Retire inline health-scanner fast scan; fold must-runs into orchestrator.** Step 6 in `lead-orchestrator.md` now runs two shell commands directly: (1) `dune build && dune runtest` exit code (gate is exit code only, not advisory `FAIL:` text), (2) `status_file_integrity.sh`. Both were the only load-bearing checks. Advisory checks (stale review, linter exception dates) deferred to weekly deep scan. `health-scanner.md` updated with "Fast mode deprecated" notice at top; deep mode intact. Harness plan §T3-A annotated. Verify: read `lead-orchestrator.md` Step 6 — should show deterministic sub-steps 6.1/6.2/6.3 with no `health-scanner` agent spawn. PR: harness/retire-inline-fast-scan.
- [x] T3-A+: **Flip PR draft→ready on QC APPROVED.** `feat-*` agents open PRs as drafts by convention. Previously, once QC APPROVED, nothing flipped the `isDraft` flag — PRs looked un-reviewed in `gh pr list` (which filters out drafts by default). Added a new Stage 3 to `lead-orchestrator` Step 5 that calls GitHub's GraphQL `markPullRequestReadyForReview` mutation after `overall_qc: APPROVED`. No REST endpoint exists for this; scope-compatible with the existing `BOT_GITHUB_TOKEN`. Source: 2026-04-19 run-4 postmortem (QC APPROVED #447 but it stayed draft until manual flip).
- [x] T3-A+: **Harness dispatch cap=2 + plan-first fresh-stack dispatch.** Two budget-utilization fixes for per-run throughput (`lead-orchestrator.md`). Step 2c now dispatches up to 2 harness items per run (was 1). Step 1.5 gains a "fresh-stack" branch — when `N == 0` on a plan-first track with ≥2 un-implemented increments, dispatches both (increment N against main + increment N+1 stacked on N's branch) instead of just one. Pairs with existing depth-2 cap-on-open-PR path so total plan-first throughput doubles when budget allows. Source: 2026-04-19 budget audit (run-5 used 24%; target 60–80%).
- [x] T3-B: AVR loop closure in `lead-orchestrator` (auto-dispatch QC on READY_FOR_REVIEW)
- [ ] T3-C: Cross-feature context injection (beyond T1-E baseline — superseded for basic case)
- [x] T3-D: Audit trail — `dev/audit/YYYY-MM-DD-<feature>.json` with `harness_gap` field on NEEDS_REWORK
- [x] T3-E: Cost/token budget visibility in daily summary + budget cap in `merge-policy.json`
- [x] T3-F: Create `docs/design/dependency-rules.md` with initial known boundaries + state lifecycle
- [x] T3-F: Architecture graph analyzer in health-scanner deep scan (import graph vs. rules doc) — DONE: see completion note below
- [x] T3-F: Rule promotion path — generate dune checks from `enforced` rules automatically — DONE: see completion note below
- [x] T3-G: Status file integrity check in health-scanner fast scan — verify required fields present (Status, Last updated, Interface stable) in each `dev/status/<feature>.md`; flag missing or malformed entries (part of T1-O fast scan). Done: see Completed section.
- [x] T3-G: `health-scanner` deep scan extension — followup-item count + CC trend analysis in weekly report (extends T1-Q CC linter output)
- [x] T3-G: Audit trail — include qc-behavioral quality score in `dev/audit/` records (extends T3-D)
- [ ] T3-H: Commit-level QC mode — spawn `qc-structural` on individual commits (not whole branches) to catch violations earlier; low priority, adds cost; explore when golden scenarios (T1-N) are stable

## Tier 4 — Continuous development loop (target end state)

- [ ] T4-A: Automated PR creation (orchestrator runs `gh pr create` on APPROVED)
- [ ] T4-B: Auto-merge on clean pass + `dev/config/merge-policy.json` + `automation-enabled.json` kill switch
- [ ] T4-C: Requirements intake workflow (design doc → agent def → decisions.md → auto-pickup)
- [ ] T4-D: Milestone evaluation reports (M4, M5, M7)
- [ ] T4-E: Rollback/recovery protocol + health-scanner regression check against baseline

---

## Follow-up / Known Improvements

Items surfaced in daily summaries but not yet scheduled as T1–T4 items.

- [x] **P0.1 — `.mli` file-length blind spot closed** (branch `harness/mli-file-length-coverage`, 2026-08-13, dev/notes/next-session-priorities-2026-08-14.md): `trading/devtools/checks/linter_file_length.sh` previously scanned only `*/lib/*.ml` (`-path "*/lib/*.ml"`), so `.mli` interface files were never checked at all. Re-measured before extending it: 439 `*/lib/*.mli` files exist, 14 exceed 300 RAW lines (worst: `weinstein_strategy_config.mli` at 1587), but all 14 are docstring-dominated — the same 14 files drop to a max of 217 lines once `(* ... *)` comment-block content and blank lines are stripped ("signature lines"). Using raw `wc -l` for `.mli` (the naive fix) would have redenned main on those 14 files despite zero interface-complexity problem, forcing either 14 `@large-module` markers landed purely to appease the linter or an ad-hoc `.mli` limit bump — both explicitly forbidden by `.claude/rules/code-health-discipline.md`. Fix: `.mli` files are now checked against a nested-comment-aware **signature-line count** (new `_mli_signature_line_count()`, a depth-counting `(* ... *)` stripper — handles `(* outer (* inner *) still outer *)` correctly, unlike a naive boolean in/out-of-comment toggle) using the SAME 300-soft/500-hard/11%-cap thresholds as `.ml`, with `.ml` and `.mli` populations tracked as two independent `TOTAL`/`LARGE_COUNT` pairs (so a burst of `.mli` `@large-module` markers can't eat the `.ml` population's opt-out budget or vice versa). `.ml` behavior (raw `wc -l`, the TOCTOU vanished-vs-unreadable discrimination per H-CHECK-SETE-DIAGNOSTICS FINDING-1, `@large-module`, `MAX_LARGE_PCT`) is unchanged — same code path, byte-identical logic. New fixture-driven self-test `trading/devtools/checks/linter_file_length_test.sh` (pattern: `tracked_artifact_linter_test.sh`), 5 assertions in private `mktemp -d` fixture trees: (A) raw>300/signature<=300 → PASS (the P0.1 bug itself, reversed); (B) 310 real signature lines → FAIL, violator + count named; (C) the nested-comment case, hand-verified: depth-counter parsing gives 2 signature lines on the fixture, a boolean-toggle mutation gives 307 on the identical input (crosses the 300 threshold the wrong way); (D1/D2) `@large-module` marker parity for `.mli` (350 signature lines PASSES only with the marker). `trading/devtools/checks/dune`'s `linter_file_length` rule now declares `(glob_files_rec %{workspace_root}/*.mli)` as an added dep (was `.ml`-only — would otherwise have been cache-blind on `.mli`-only changes, H-CHECK-CACHE-BLIND) plus a new rule wiring `linter_file_length_test.sh` into `runtest`. Real-tree result, unchanged from measurement: `OK: all lib/*.ml files within limits (17 declared-large of 448 total); all lib/*.mli signatures within limits (0 declared-large of 439 total).` — the current tree passes cleanly, no markers or limit changes needed anywhere. Sibling gap (test-file `.ml`/`.mli` scope, `-path "*/lib/*"` still excludes `*/test/*`) explicitly OUT OF SCOPE here — measured and recorded instead in `dev/status/cleanup.md`'s pre-existing `linter_coverage` entry (401 `*/test/*.ml` files, 154 over 300 lines, 70 over 500, largest `test_screener.ml` at 2687). Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest` exit 0; `sh trading/devtools/checks/linter_file_length_test.sh` directly prints `OK: linter_file_length_test — 5 assertion(s) passed, 0 failed.`

- [x] **`record_qc_audit_test.sh` wired into dune runtest** (branch harness/wire-record-qc-audit-test, 2026-06-15): `trading/devtools/checks/record_qc_audit_test.sh` was a fixture-driven smoke test (6 scenarios) for `record_qc_audit.sh` that existed but was not wired into CI. Added a rule to `trading/devtools/checks/dune` declaring `record_qc_audit.sh` and `write_audit.sh` as deps (cache invalidation) and invoking the test with `bash` (not `sh`, because the script uses `set -euo pipefail` and bash-specific constructs). Verify: `dune runtest devtools/checks/` — prints `record_qc_audit_test: 6 passed, 0 failed`.

- [x] **list_active_exceptions reporting tool** (issue #933 sub-item D, branch harness/list-active-exceptions): OCaml exe at `trading/devtools/list_active_exceptions/list_active_exceptions.{ml,mli}`. Reads `trading/devtools/checks/linter_exceptions.conf` (parse each non-comment row) and scans all `*.ml` files under `trading/` for `(* @large-module:` and `(* @large-function:` markers. Outputs a 3-section markdown report on stdout: (1) `linter_exceptions.conf entries (N)`, (2) `@large-module markers (N)`, (3) `@large-function markers (N)` — each as a markdown table with `status` column (`active` / `expired` / `no-review-at`). False positives avoided by requiring markers to be in genuine OCaml comments (trimmed line must start with `(*`). Wired into `dune runtest` as a passive linter (exits 0 always; output goes to build log). `dune build devtools/list_active_exceptions/list_active_exceptions.exe` builds the exe; invoke directly via `dune exec devtools/list_active_exceptions/list_active_exceptions.exe -- <trading-root>`. Verify: `dune runtest devtools/checks/` — all checks pass; the active-exceptions section of the build log shows 13 conf entries, 13 `@large-module` markers (no duplicates), 0 `@large-function` markers.

- [x] **Fast `magic_numbers_linter` — replaced `linter_magic_numbers.sh` with an OCaml exe** (branch harness/fast-magic-numbers-linter): the shell version forked ~8-10 subprocesses per source line (comment-depth tracking, quote counting, numeric-token extraction via grep/wc/sed) — ~460k-575k process spawns across ~445 `lib/*.ml` files / ~57k lines, measured ~35 minutes under Docker-on-macOS. Feat-agents re-run this 3-4x per PR (TDD loop + re-verify), so this one script cost 1.5-2.3 hours per PR — the single biggest drag on the dev loop per the 2026-08-10 session's 6-8 hour burn across five agents. New `trading/devtools/magic_numbers_linter/` replicates the identical line-by-line algorithm (same skip rules, same order, same PCRE alternation-with-backtracking semantics for numeric-token extraction, same unreadable-file diagnostics) as a single OCaml process with zero subprocess forking. Wired into `trading/devtools/checks/dune` in place of the shell rule; `linter_magic_numbers.sh` deleted. `sete_diagnostics_check.sh` Part 4 (the unreadable-file regression test) updated to exercise the new exe via a dune-`setenv`'d `MAGIC_NUMBERS_LINTER_EXE`. Real-tree measurement: shell ~35min -> exe 1.024s (>2000x). **qc-behavioral rework (CP1/CP2, iteration 1):** the module is split into `lib/magic_numbers_linter_lib.{ml,mli}` (all detection logic, `.mli`-documented per function — CP1 fix: the exempt surface, i.e. all skip rules and all 7 exempt literals with their exact order and surprising width, e.g. `->`/`config.`/`let ...=...` skipping the WHOLE line, is now enumerated on the functions themselves, not a dangling reference to the deleted shell script) and a thin `magic_numbers_linter.ml` CLI wrapper. Detection equivalence is pinned by a dune-wired OUnit2 suite, `test/test_magic_numbers_linter_lib.ml` (CP2 fix — replaces the scratch equivalence script that was deleted before commit and therefore proved nothing durably): one inline-string test per skip rule (`e.g.`, `->`, `config.`, `let`-binding, `= <digit>` / `= -<digit>`, `~f:`/`~len:`/`~pos:`, trailing backslash, odd quote count, comment markers including a nested `(* (* *) *)` depth-tracking case), the exempt-literal set including `1.0` and `0.5` (previously unpinned), adversarial extraction edge cases (`1e5`, `0x2A`, `12.`, `.55`, `42_000`, `12.34.56`, `v1.2.3` — none recognized; this is a character-level scan, not a numeric-literal parser), quoted-string stripping, and one end-to-end `scan_file_lines` case. **Correction to a prior overclaim in this entry:** an earlier draft of this note said the (now-deleted, uncommitted) scratch fixture "covers every skip rule, all 7 exempt literals" as the primary equivalence evidence — that fixture was never committed and is not the record of coverage. The committed `test/test_magic_numbers_linter_lib.ml` above is the actual durable coverage; it covers every skip rule and all 5 reachable exempt literals directly via `is_exempt_literal` (`0.0`, `1.0`, `0.5` newly-pinned by this rework; `2.0`, `100.0` already covered), with `0` and `1` explicitly noted as dead/unreachable arms (the extraction regex requires a 2+ digit run, so a bare single digit is never a candidate) rather than silently untested, but does not re-test file-discovery (path exclusions, `.pp.ml`, `_build`/`.formatted` pruning) inline — that surface remains covered only by CI's own dogfooding of the linter against the real tree plus `sete_diagnostics_check.sh` Part 4's unreadable-file case. Also measured the other `while read`-per-line checks in `devtools/checks/` as a follow-up candidate list (not fixed here): `linter_mli_coverage.sh` 11.83s, `arch_layer_test.sh` 7.27s, `testing_only_check.sh` 5.45s (direct invocation); full `dune runtest devtools/checks/` (~40 rules, warm) is 15.5s wall. Verify: `docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build @fmt && dune build && dune runtest devtools/checks/ && dune runtest devtools/magic_numbers_linter/'` — all exit 0.

- [~] **CI disk headroom -- recurring ENOSPC during dune link** (branch harness/ci-disk-headroom, 2026-06-17, GHA orchestrator run 27687153814): Root cause: CI image bakes `trading/_build` under `/workspaces/trading-1/` (~11 GB) which is explicitly unused in the CI job but occupies runner disk. Combined with the restored `_build` cache and fresh linker temporaries, the ubuntu-latest runner (~29 GB total) hit ENOSPC on `test_grid_search.exe`. Fix identified: add `Free disk headroom` step to remove `/workspaces/trading-1/trading/_build` (~11 GB), inactive opam `5.3` switch (~340 MB), opam download-cache (~34 MB), and opam logs. Also add `Disk diagnostic before build` step. BLOCKED: cannot push `.github/workflows/ci.yml` changes from GHA agent (requires `workflow` OAuth scope, not available in current token). Commit `4cc7d08066fdbd6856aa88acdc093d7acf9d73e2` has the correct ci.yml change and exists in git object store. Needs human with workflow-scoped PAT to push. See PR #1636 for details and the exact diff to apply. Closes issue #1634.

- [x] **CI nondeterministic SIGILL — owl/OpenBLAS AVX-512 on non-AVX512 runners** — **RESOLVED 2026-07-14 by PR #1961** (`b7628dcb`, merged GHA orchestrator run 2026-07-14). Fix option (d), no PAT needed: pin `OWL_CFLAGS=-march=x86-64-v2 -mtune=generic` via `ENV` in `.devcontainer/Dockerfile` so owl's stubs build with a portable ISA (mirrors the ta-lib #1129 fix in the same Dockerfile). Root cause: owl.1.2 configure defaults to `-march=native`; the 2026-07-13T07:19Z weekly `image.yml` rebuild landed on an AVX-512 build runner, baking AVX-512 into `dllowl_stubs.so`. Merging #1961 (touches `.devcontainer/Dockerfile`) auto-triggered `image.yml` (run 29300387751) to rebuild `trading-ci:latest` with portable owl. Original diagnosis below (surfaced GHA orchestrator run 2026-07-13-run3, blocked PR #1951): `build-and-test` reds intermittently depending on which `ubuntu-latest` runner CPU is assigned. Root cause: `test_bayesian_opt.exe` + `test_bayesian_runner_bin.exe` (tuner test exes) link `owl` (`trading/trading/backtest/tuner/lib/dune:10`) → OpenBLAS, whose default build ships AVX-512 kernels that raise `SIGILL` ("Command got signal ILL.") on runners lacking AVX-512. Evidence: run 29280804821 job 86921229531 + re-run on updated tip 6e4859de both failed with 4× `Command got signal ILL` in the tuner tests, **0** `^FAIL:` output lines; the runner running the 2026-07-13-run3 orchestrator has no `avx512*` flags in `/proc/cpuinfo`. The existing ci.yml AVX-512 guard (lines 66–96) checks **only `libta-lib.so`** (objdump passed — ta-lib is clean) and does NOT cover owl/OpenBLAS. Fix options: (a) pin OpenBLAS to a portable kernel in CI env — `OPENBLAS_CORETYPE=Haswell` (or `Prescott`) — smallest change but touches `.github/workflows/ci.yml`; (b) install/rebuild OpenBLAS with `DYNAMIC_ARCH=1` in the CI image (runtime ISA dispatch); (c) extend the existing objdump ISA guard to also scan the OpenBLAS `.so`. BLOCKED for GHA agents same as #1636: (a)/(c)-in-ci.yml need a `workflow`-scoped PAT; (b) needs a CI image rebuild. Needs human. Distinct from #1636 (ENOSPC) and the dune sandbox-race flake.

- [x] **CI nondeterministic `LAPACKE: 9` — Bayesian_opt GP Cholesky non-positive-definite (residual tuner flake, DISTINCT from the #1961 SIGILL)** — **RESOLVED 2026-07-19 (branch `harness/bayesian-gp-nugget-escalation`)**: applied the preserved WIP patch (adaptive-nugget escalation: `fit_gp` retries `Linalg.chol` with an escalating diagonal jitter only on the caught non-PD LAPACKE failure — bit-identical on the success path). To keep `bayesian_opt.ml` under the 300-line file-length linter limit (WIP patch would have pushed it to 355) the retry logic was EXTRACTED — not marker-suppressed — into a new sibling module `trading/trading/backtest/tuner/lib/bayesian_opt_cholesky.{ml,mli}` (mirrors the existing `bayesian_opt_early_stop.ml` / `bayesian_opt_validate.ml` split pattern), exposing `chol_with_nugget_escalation`. `bayesian_opt.ml` now calls it and is 297 lines (was 294; net +3). Added guard test `test_fit_gp_near_duplicate_observations_does_not_raise` in `test_bayesian_opt.ml` (near-duplicate `observations_x` rows, `noise_variance:0.0`, asserts `fit_gp` returns a well-formed finite posterior instead of raising) — registered in the suite, now 44 tests in `test_bayesian_opt.exe`. Verify: `dune build @fmt && dune build && dune runtest` all exit 0 from `trading/trading/`; `linter_file_length` reports "OK: all lib/*.ml files within limits"; no `FAIL:` lines. WIP diff `dev/notes/bayesian-gp-nugget-escalation-wip-2026-07-19.patch` fully consumed. Symptom: `build-and-test` reds intermittently in `test_bayesian_opt.exe` with `Failure("LAPACKE: 9")` — LAPACK `potrf` (Cholesky) reporting the 9th leading minor of the GP kernel matrix is not positive-definite. Two OUnit errors: `Tuner.Bayesian_opt:17:BO converges on 2D Branin` + `Tuner.Bayesian_opt:11:suggest_next GP phase respects bounds` (`FAILED: Cases: 43 Tried: 43 Errors: 2 Failures: 0`). **NOT the #1961 SIGILL class**: that was `Command got signal ILL` from AVX-512 owl stubs, fixed by pinning `OWL_CFLAGS=-march=x86-64-v2` (confirmed active this run: `OWL_CFLAGS` env carries the portable flags). This is a residual *numerical* non-PD flake in the GP fit, not an ISA/SIGILL issue. **Confirmed flaky, not a regression**: occurred on `3a633f6d` (#1995, a docs-only orchestrator-summary commit — identical test code to green parent `ad0b29ab`); base rate = 4/4 prior main commits (`ad0b29ab`/`9cdc8055`/`36863498`/`093c75b9`) all `build-and-test=success`; local reproduction 0/6 (test passed 6/6 standalone) + full `dune runtest` exit 0 this run. Evidence: GHA run 29599087810 job 87946588479, step 7 `dune runtest`. **Recommended fix (no workflow PAT needed — test/lib code only)**: raise the GP jitter/nugget floor. `Bayesian_opt` adds `noise_variance · I` to the kernel before Cholesky (`bayesian_opt.mli:220`); either bump the test fixture's `noise_variance` above the current `~1e-6`, or add adaptive-nugget escalation in the fit path (retry Cholesky with a larger diagonal on LAPACKE non-PD). Best done LOCAL where the low-rate flake can be stress-reproduced (loop the exe under varied BLAS thread counts). Rerun-on-flake is the interim mitigation but the API token available to the GHA orchestrator lacks `actions:write` (403 on `rerun-failed-jobs`), so no auto-reroll from the orchestrator; a human `gh run rerun --failed` clears a spurious red.

- [x] **CI red-main watchdog** (issue #934, PR #983, branch harness/ci-main-watchdog): `.github/workflows/ci-main-watchdog.yml` — triggers on `workflow_run` completion of `CI` workflow on `main`; on failure, auto-creates GitHub issue `[ci-watchdog] main CI red on <short-sha>` with run URL + first 20 lines of log + `cc @dayfine`; labels `ci-red`/`urgent` (auto-created if absent). Idempotent: comments on existing open watchdog issue instead of creating a duplicate. Verify: merge PR and run `gh workflow run ci-main-watchdog.yml --ref main -F sha=<any-sha>` — a watchdog issue should appear in the Issues tab. Closes #934.

- [x] **Dune linter dep tracking** (PR #943, harness/dune-linter-deps): `trading/devtools/checks/dune` rules for nesting_linter, fn_length_linter, cc_linter, linter_magic_numbers.sh, linter_mli_coverage.sh, linter_file_length.sh, fmt_check.sh, arch_layer_test.sh, testing_only_check.sh, posix_sh_check.sh did not declare `(deps (glob_files_rec ...))` for the source files they scan. Dune's cache key therefore only invalidated on the linter script/exe change — NOT on .ml content changes anywhere else. Root cause of incident PR #919 (linter cache hid violations; CI on fresh checkout caught them). Fix: add `(glob_files_rec %{workspace_root}/*.ml)`, `(glob_files_rec %{workspace_root}/*.mli)`, `(glob_files_rec %{workspace_root}/dune)`, `(glob_files_rec %{workspace_root}/*.sh)` deps as appropriate per linter. Files outside workspace (`.claude/agents/*.md`, `dev/status/*.md`) cannot be tracked via glob_files due to dune workspace boundary; those rules retain comment explaining the limitation. Verify: `dune build devtools/checks/` passes; introducing a new `.ml` violation should make `dune runtest` fail on next run.

- ~~**A2 rule stale — false-positive NEEDS_REWORK verdicts**~~ — DONE (harness/a2-rule-update): `.claude/rules/qc-structural-authority.md` §A2 updated from blanket ban to explicit allow-list. `trading/trading/backtest/**/dune` files may declare `weinstein.*` dependencies (established practice: 5+ dune files verified). Still FAIL: (1) non-`weinstein.*` analysis imports; (2) `weinstein.*` imports outside `trading/trading/backtest/**`. Source: orchestrator override notes in `dev/reviews/optimal-strategy.md` (PRs #652, #666). Verify: read `A2` row in `.claude/rules/qc-structural-authority.md`.

- ~~**`.claude/worktrees/` gitignore gap + stale worktree accumulation**~~ — DONE (harness/worktree-auto-cleanup-v2): `dev/scripts/sweep_stale_worktrees.sh` added (executable, bash, CLI flags: `--threshold-percent`, `--stale-hours`, `--dry-run`, `--force`). Probes disk via `df`, sweeps `agent-*` worktrees older than the stale threshold, falls back to `rm -rf` if `git worktree remove` fails, runs `git worktree prune` after sweep, appends to `dev/logs/worktree-sweep-YYYY-MM-DD.log`. `.claude/settings.json` `SessionStart` hook wired with default thresholds (85%/24h). `## Cleanup` section added to `.claude/rules/worktree-isolation.md` describing auto-detection trigger + manual invocation. Verify: `bash dev/scripts/sweep_stale_worktrees.sh --dry-run --force` prints candidates without deleting; `jq . .claude/settings.json` parses cleanly.

- **`isolation: "worktree"` creates git-worktrees, not jj-workspaces — concurrent agents race shared `op_heads` + default WorkspaceName** (NEW 2026-05-04). Root cause investigation in `memory/project_jj_worktree_root_cause.md`. Symptoms: edits silently revert mid-session (jj issue [#8929](https://github.com/jj-vcs/jj/issues/8929)), files leak across "isolated" worktrees (e.g. F.3.c's `panel_callbacks.{ml,mli}` appearing in M5.2a's diff during 2026-05-04 session, forcing #836 to be closed). Per jj's official docs (`Git compatibility` page), running jj inside a `git worktree add` directory with shared colocated `.jj/` is **explicitly unsupported**. GHA is unaffected (orchestrator runs `claude -p` inline; subagents share the runner's plain-git checkout — no jj). Fix options:

  - **Option A (low-effort, agent-side):** every feat-* dispatch prompt's pre-amble runs `jj workspace add /tmp/agent-ws-<id> --name agent-<id>` and `cd` there before doing work. Each agent gets a distinct `WorkspaceName` and an independent `@` slot in the shared view; op-merging is well-defined per [jj concurrency docs](https://docs.jj-vcs.dev/latest/technical/concurrency/). Update `feat-agent-template.md` + every feat-*.md prompt; document in `.claude/rules/worktree-isolation.md`. ~30 LOC of prompt boilerplate + one rule doc update. Removes the contamination class for cooperating agents but does not fix non-cooperating tools (e.g. linters, sweep scripts) that run in the parent worktree.
  - **Option B (highest-effort, runtime-level):** modify the Claude Code runtime so `isolation: "worktree"` calls `jj workspace add` instead of `git worktree add` when invoked in a colocated jj+git repo. Requires upstream Claude Code change; out of our control.
  - **Option C (medium-effort, dispatch-side):** stop using `isolation: "worktree"` for jj-writing agents; serialize them at ≤1 concurrent jj-writer (current rule). Read-only QC agents continue concurrent. Lossy on parallelism but immediately safe. Status quo as of 2026-05-04 sessions.

  **Decision needed:** A vs C. A unblocks parallel feat work; C is what we're doing today. Until A lands, ≤1-jj-writer rule per `feedback_worktree_isolation.md` is mandatory. Verify before fix lands: dispatch any 2 concurrent jj-writing feat agents on disjoint paths and observe contamination in `jj diff` mid-session (reproduces every time). Verify after fix lands: same dispatch produces clean PRs with non-overlapping file lists. References: `memory/project_jj_worktree_root_cause.md`, [Panozzo: Avoid losing work with jj for AI agents](https://www.panozzaj.com/blog/2025/11/22/avoid-losing-work-with-jujutsu-jj-for-ai-coding-agents/), [Slava Kurilyak: Parallel Claude Code with jj](https://slavakurilyak.com/posts/parallel-claude-code-with-jujutsu).

  **2026-05-04 update:** Option A landed via PR #839 — every feat-*/harness/ops-data agent prompt now includes a `## Pre-Work Setup` section that runs `jj workspace add /tmp/agent-ws-<id> --name agent-<id>` and `cd`s there before doing work. Boilerplate is byte-identical across the 5 agent files (md5 `008307131d6954b88f674145dd2cdf5d`); canonical template lives in `.claude/agents/feat-agent-template.md`. Two follow-up gaps remain (filed as separate items below).

- ~~**Pre-Work Setup boilerplate not enforced by `agent_compliance_check.sh`**~~ — DONE (PR #840-follow-up, harness/prework-setup-enforcement): `agent_compliance_check.sh` extended with Rule 2 — requires `## Pre-Work Setup` on all jj-writing agents (feat-*, harness-maintainer, ops-data); read-only QC agents (qc-structural, qc-behavioral, health-scanner, track-pacer, lead-orchestrator, code-health) are exempt. Smoke test in `trading/devtools/checks/agent_compliance_test.sh` (2 assertions: as-is tree passes; stripped feat-data.md FAILs). Both wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `dune runtest devtools/checks/` — prints `OK: agent compliance — 5 feat-* / harness / ops-data files have ## Pre-Work Setup.` and `OK: agent_compliance_test — all 2 assertions passed.`

- ~~**No automated smoke test for Pre-Work Setup runtime correctness**~~ — DONE (PR #840-follow-up, harness/prework-setup-enforcement): `trading/devtools/checks/jj_workspace_smoke.sh` added (~50 LOC POSIX sh). Execs the canonical boilerplate (`jj workspace add $AGENT_WS --name $AGENT_ID -r main@origin`), asserts `jj workspace list` shows the new entry, then cleans up (`jj workspace forget` + `rm -rf`). Skips cleanly if jj is not on PATH (`OK: jj_workspace_smoke — SKIPPED (jj not on PATH).`). Wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `dune runtest devtools/checks/` — prints `OK: jj_workspace_smoke — boilerplate exec + workspace_list + cleanup all passed.` (or SKIPPED on GHA).
- ~~**Pre-existing nesting linter failures**~~ — DONE (#461): `atr.ml` + `ad_bars.ml` refactored; `analysis/scripts/universe_filter` and `analysis/scripts/fetch_finviz_sectors` grandfathered in `linter_exceptions.conf`; `weinstein_strategy.ml` annotated `@large-module` (#453). `dune runtest devtools/checks` → `OK: nesting linter — all 832 functions within limits.` (verified 2026-04-20). `fetch_universe.ml`, `test_data_loader.ml`, `weinstein_strategy.ml` all clean.
- ~~**Orchestrator runner semantics**~~ — RESOLVED: `dev/run.sh` now has a
  pre-flight block that fast-fails if `claude` is missing, the
  lead-orchestrator agent file is missing, or its `## Allowed Tools` section
  no longer lists `Agent`. See `### run-sh hardening` in Completed.
- **Orchestrator daily summary drifts against reality** — sections like
  `## Integration Queue`, `## Recent Commits`, and `## Questions for You`
  get copied forward from prior daily summaries rather than derived from
  current state. Example: the 2026-04-14 12:35 run carried forward a "7
  open PRs from 2026-04-11" list that had been stale for 3 days; several
  questions referenced PRs long since merged.
  Fix: add a deterministic reconciliation step to `lead-orchestrator.md`
  Step 7 (Write daily summary) that queries the actual open-PR list
  (via `gh pr list` or the GH API) before writing `## Integration Queue`,
  and derives `## Recent Commits` from `jj log main@origin..main@origin`
  since the last daily summary date. Without `gh` auth in the runtime
  environment (see `dev/status/orchestrator-automation.md`), this part
  needs to land together with the automation work. Source:
  `dev/daily/2026-04-14.md` (refreshed end-of-day).
- ~~**Same-day summary consolidation**~~ — DONE (#467): `dev/lib/consolidate_day.sh` added;
  merges all `${DATE}*.md` (non-plan) into `${DATE}-summary.md` with deduped
  §Dispatched, merged §Escalations (with "(seen in: run-N)" suffix), summed §Budget,
  latest §QC per track, and per-run links. Wired into `lead-orchestrator` Step 8b
  (runs post-auto-merge when N >= 3). Smoke test: `trading/devtools/checks/consolidate_day_check.sh`.
  Source: 2026-04-18 plan-mode audit.
- **Deep scan heuristic gaps** — `trading/devtools/checks/deep_scan.sh`
  (T3-A, see #331) is missing several useful checks. Today's manual
  audit found four real issues the script didn't surface:
  1. ~~**Drift coverage too narrow**~~ — DONE: `trading/trading/backtest/`
     coverage added to `trading/devtools/checks/deep_scan/check_02_design_doc_drift.sh`;
     checks top-level subdirs of `trading/trading/backtest/` against
     `dev/plans/backtest-scale-optimization-2026-04-17.md`. Smoke test:
     `trading/devtools/checks/deep_scan_drift_coverage_check.sh`. Wired into
     `dune runtest` via `trading/devtools/checks/dune`. Current finding:
     `trading/trading/backtest/bin/` not mentioned in plan (WARNING).
     Verify: `dune runtest devtools/checks/` — prints OK; run
     `sh trading/devtools/checks/deep_scan.sh` — report has
     `Design doc drift items: 1` for `backtest/bin/`. See Completed section.
  2. ~~**Status file template enforcement**~~ — DONE: Check 10 added to
     `trading/devtools/checks/deep_scan.sh`; greps `dev/status/*.md` for
     forbidden `## Recent Commits` heading; findings emitted under
     `## Status File Template` in `dev/health/YYYY-MM-DD-deep.md`.
     Smoke test: `trading/devtools/checks/deep_scan_recent_commits_check.sh`.
     Zero current violations. Verify: `dune runtest devtools/checks/`.
  3. ~~**Linter exception expiry** — `linter_exceptions.conf` entries
     with `review_at: <milestone>` (e.g. M5) are never re-surfaced
     when the milestone lands. Add a check that compares current
     milestone in `weinstein-trading-system-v2.md` against the
     `review_at:` values.~~ — DONE: see Completed section below
  4. ~~**Stale local jj bookmarks**~~ — DONE: Check 12 added to
     `trading/devtools/checks/deep_scan.sh`; enumerates local jj bookmarks
     via `jj bookmark list --all 'glob:*'`, classifies as (a) local-only
     (no @origin entry) or (b) behind origin (local is ancestor of remote).
     Findings emitted under `## Stale Local Bookmarks` in
     `dev/health/YYYY-MM-DD-deep.md`. Protected names (main/master/HEAD/trunk)
     excluded. Severity: INFO. Degrades gracefully if jj absent.
     Smoke test: `trading/devtools/checks/deep_scan_stale_bookmarks_check.sh`.
     Verify: `dune runtest devtools/checks/` — prints OK; run
     `sh trading/devtools/checks/deep_scan.sh` — report contains
     `## Stale Local Bookmarks`.
  Source: `dev/daily/2026-04-14.md` end-of-day audit.
- ~~**POSIX shell portability linter**~~ — DONE (harness/posix-sh-linter): `trading/devtools/checks/posix_sh_check.sh` runs `dash -n` over all #!/bin/sh scripts in `trading/devtools/checks/`, `trading/devtools/checks/deep_scan/`, and `dev/lib/`. Scripts with `#!/usr/bin/env bash` shebang are exempt. Smoke test: `trading/devtools/checks/posix_sh_check_test.sh`. Wired into `dune runtest`. Verify: `dune runtest devtools/checks/` — prints `OK: posix-sh linter -- N scripts clean.` Pre-existing violations found: `dev/lib/cleanup-stale-worktrees.sh` and `dev/run.sh` use `#!/usr/bin/env bash` and are exempt (intentionally bash). Source: run-4 daily summary follow-up.
- ~~**`cc_linter.exe` overwrites its first `.ml` argument with the JSON report**~~ — DONE (PR-#570): JSON output now requires explicit `--out <path>` flag; extra positional args after the trading-root are silently ignored and never written to. Smoke test `trading/devtools/cc_linter/test/test_no_overwrite.ml` invokes the linter with two `.ml` paths and asserts byte-equality before/after. Verify: `dune runtest devtools/cc_linter/`.

- ~~**`isolation: "worktree"` creates git-worktrees, not jj-workspaces — concurrent agents race shared `op_heads` + default WorkspaceName**~~ — **DONE (PR #839, Option A).** Root cause: Claude Code's `isolation: "worktree"` uses `git worktree add`, not `jj workspace add`. All git-worktree dirs share the same `.jj/repo/` backend; they collide on `WorkspaceName = "default"` and the same `@` slot, causing file leaks and silent edit-reverts (jj issue #8929). Fix implemented: `## Pre-Work Setup` boilerplate (20 lines) added to `feat-agent-template.md`, `feat-weinstein.md`, `feat-data.md`, `feat-backtest.md`, `harness-maintainer.md`, and `ops-data.md`. Each agent now runs `jj workspace add /tmp/agent-ws-${AGENT_ID} --name ${AGENT_ID} -r main@origin && cd "$AGENT_WS"` as its first step, giving each agent a distinct `WorkspaceName` and independent `@` slot. `worktree-isolation.md` extended with §"jj workspace isolation" documenting the root cause and fix. Option B (upstream Claude Code change) remains out of scope. Option C (≤1 concurrent jj-writer) remains the conservative fallback for un-upgraded sessions. Root cause reference: `memory/project_jj_worktree_root_cause.md`. Verify: `grep -l "Pre-Work Setup" .claude/agents/*.md` should list 6 files; `grep "jj workspace isolation" .claude/rules/worktree-isolation.md` should match.

- [ ] **H-TRACKED-SCENARIO-DEBT: 7 pre-existing tracked-but-gitignored run-output directories, predate the new `tracked_artifact_linter`** (found 2026-08-09 while building `trading/devtools/checks/tracked_artifact_linter.sh`, dev/status/cleanup.md `tracked_artifact_linter`). Real, out-of-scope debt discovered by running `git ls-files -i -c --exclude-standard` against current main: besides the 1285 deliberately-committed `trading/test_data/**` golden bars (legitimate, exempted `review_at: never`), there are **49 files** across **7 directories** that are tracked in git AND match a `.gitignore` pattern intended only for *new* files, predating this linter and unrelated to the `trading/compile_commands.json` instance (#2248):
  - `dev/backtest/scenarios-2026-04-14-220839/` (5 files: `stop-buffer-*` scenario outputs)
  - `dev/backtest/scenarios-2026-04-14-222425/` (20 files)
  - `dev/backtest/scenarios-2026-04-14-225929/` (12 files)
  - `dev/experiments/bayesian-production-sweep-2026-05-18/` (4 files: `best.sexp`, `convergence.md`, `oos_report.md`, `bo_checkpoint.sexp`)
  - `dev/experiments/laggard-h-sweep-15y-2026-05-07/` (1 file: `run.log`)
  - `dev/experiments/rolling-5y-segmentation-ab-2026-05-11/` (1 file: `results/run.log`)
  - `dev/experiments/stage3-force-exit-impact-2026-05-06/` (6 files: `run-*.log`)

  These are allow-listed in `trading/devtools/checks/linter_exceptions.conf` under the `tracked_artifact` key with `review_at: 2026-09-09` (dated, not `never` — this is debt, not a deliberate convention like `trading/test_data/`) so the new linter passes on main without silently permanently exempting them. Two things worth deciding when this comes up for review: (1) whether these are safe to `git rm --cached` outright (they read as regenerable per-run artifacts, same class as the `_gate`/`_diag` scratch dirs `.gitignore` already excludes — but nobody has verified nothing downstream reads them, e.g. an experiment-ledger citation or a golden comparison), and (2) whether `dev/backtest/scenarios-*/`'s own gitignore comment ("timestamped per-run artefacts... regenerable and large") means ALL three `scenarios-2026-04-14-*` dirs were committed by accident in the first place, in which case the fix is a straight `git rm --cached` cleanup PR, not a permanent exception. Verify the current state: `sh trading/devtools/checks/tracked_artifact_linter.sh` passes; `git ls-files -i -c --exclude-standard | grep -v '^trading/test_data/'` shows the same 49 paths.

- [x] **H-TRACKED-ARTIFACT-SELF-TEST: `tracked_artifact_linter.sh` has no fixture-driven self-test** (found 2026-08-09 during PR #2252 rework, qc-behavioral review). **DONE**: `trading/devtools/checks/tracked_artifact_linter_test.sh` added, wired into `dune runtest` (see `trading/devtools/checks/dune`, rule right after the `tracked_artifact_linter.sh` rule). Follows the `run_in_env_root_check.sh` / `check_universe_deps_test.sh` pattern: real throwaway git repos under `mktemp -d` (real `git init`, real `.gitignore`, real `git add -f`), plus a private per-fixture copy of the linter + `_check_lib.sh` paired with a controlled `linter_exceptions.conf` (needed because the linter resolves `EXCEPTIONS_CONF` relative to its own script location, not via `REPO_ROOT`). Encodes all four cases qc-behavioral verified by hand during the #2252 review:
  1. **Novel `.gitignore` pattern, positive control**: a freshly force-added file matching a `.gitignore` pattern that has no `tracked_artifact` allow-list entry → expect exit 1, path named in output.
  2. **Contains-but-not-prefixed, negative control**: a `linter_exceptions.conf` `tracked_artifact` entry whose prefix is a *substring* of a violating path but not an *anchored prefix* (e.g. entry `foo/bar` vs. violating path `xfoo/bar/baz`) → expect exit 1 (NOT allow-listed), pinning the anchored-`^prefix` semantics documented in R3 above (`linter_exceptions.conf`'s `tracked_artifact` banner).
  3. **Unignored-artifact-type limitation**: a force-added file that matches NO `.gitignore` pattern at all → expect exit 0 (documented blind spot; the fixture pins that the blind spot is exactly this shape and not wider).
  4. **Git-error path (added by PR #2252 rework)**: git invocation fails (here: `REPO_ROOT` points at a plain, non-git directory) → expect a distinct `FAIL: tracked_artifact_linter -- could not read the git index: ...` message and exit 1, NOT a silent "0 violations" false-OK. This is the exact CI failure class (`fatal: detected dubious ownership`) this rework fixed; the fixture pins it against regressing back to the `set -e`-kills-silently shape.
  Mutation-verified: each fixture's corresponding linter behaviour was temporarily broken (disabling the allow-list gate, un-anchoring the allow-list prefix match, dropping `-i` from the `git ls-files` invocation, reverting the explicit `GIT_CODE` capture to the pre-#2252 `set -e`-loses-the-error shape) and confirmed to flip exactly the intended fixture red while the other three stayed green; the linter was then restored byte-identical and the suite re-confirmed green. Verify: `sh trading/devtools/checks/tracked_artifact_linter_test.sh` — prints `OK: tracked_artifact_linter_test — 4 assertion(s) passed, 0 failed.`; `dune runtest devtools/checks` also runs it. Reference implementation pattern: `trading/devtools/checks/run_in_env_root_check.sh` / `check_universe_deps_test.sh`.

- [x] **H-PRUNE-GIT-SAFEDIR — `prune-candidates-weekly` GHA cron failing on `git` dubious-ownership, script-side fix** (issue #2633, branch `harness/prune-git-safedir`). Same failure CLASS as the `tracked_artifact_linter.sh` fix directly above (`fatal: detected dubious ownership`), independently hitting a second script: `dev/scripts/prune_candidates.sh`'s checker1/checker2 date every file/dir via `git log -1 -- <path>`, and both call sites piped git's stderr to `/dev/null` and never checked its exit status. `actions/checkout@v4` registers its `safe.directory` exception via `git config --global` under a **temporarily overridden `HOME`**, then restores the real `HOME` (`/home/opam`) before any later workflow step runs — so the exception this repo's `--user 0` container needs never reaches the `prune_candidates.sh` step, and every `git log` call died with "detected dubious ownership", silently. Confirmed with a paired reproduction in this same container image at `43a7014a`: `HOME=<empty tmpdir> git log ...` → `fatal: detected dubious ownership ...` exit 128, byte-identical to job-log 33414112340/job 99560550387 line 471 (`FAIL(checker2): sanity probe failed -- dev/experiments/fuzz-startdate-crash was not flagged as an orphan candidate ...`) — the empty `cdate` from the swallowed git failure fed checker2's dating logic, which then correctly refused to report but named a **fabricated** cause (a missing anchor dir) rather than the real one (every git call failing).
  **Fix (script-side only — `.github/workflows/**` is out of reach for this token, no `workflow` OAuth scope, same standing blocker as #1636/H-BLAS):** new `_git_log_date()` helper in `dev/scripts/prune_candidates.sh` wraps every git-log call site with `git -c safe.directory="$ROOT" log ...` (inline `-c`, no `--global` side effect on the invoking environment) and checks git's exit status explicitly — a real git failure now aborts the checker with `FAIL(checker1|2): git log failed dating <path> -- see the git error above`, while a genuine "no history for this path" (git exit 0, empty stdout) still falls through to the pre-existing handling unchanged. Both call sites (checker1 line ~319, checker2 line ~410 pre-fix) now route through this one helper; grepped for any other git invocation in the file — there are none.
  **Regression test** (Fixture F, `dev/scripts/prune_candidates_test.sh`): drives the script under `HOME=$(mktemp -d)` (a clean HOME, faithfully matching the GHA step) with `GIT_TEST_ASSUME_DIFFERENT_OWNER=1` — git's own documented test-support env var for the safe.directory ownership check, confirmed present in this git binary (`strings $(command -v git) | grep GIT_TEST_ASSUME_DIFFERENT_OWNER`) — which reproduces "dubious ownership" with no real UID mismatch needed. Asserts exit 0, the correct git-derived date on the known orphan dir, and no "dubious ownership" text leaking into the report. **RED/GREEN discriminated by hand**, both read unpiped: reverting only the `_git_log_date`/`-c safe.directory` change (script-side git stash of `prune_candidates.sh` alone, test file untouched) → `sh dev/scripts/prune_candidates_test.sh; echo $?` → `26 passed, 3 failed`, exit **1**, with the exact fabricated-cause `FAIL(checker2)` message from the real job log reproduced verbatim; restoring the fix → `29 passed, 0 failed`, exit **0**. Also ran the full `dev/scripts/prune_candidates_test.sh` suite (29 assertions, all pre-existing fixtures A-E plus new fixture F) and `dune runtest devtools` (native, `TRADING_IN_CONTAINER=1`) — both exit 0, `prune_candidates_test: 29 passed, 0 failed` printed by the dune-wired runner too. Also ran `posix_sh_check.sh` — exit 0, `OK: posix-sh linter -- 90 scripts clean.` (script uses `local`, an accepted dash/bash extension per the file's own SCOPING NOTE, syntax-checked by `dash -n`).
  **Not a substitute for the workflow-side fix.** The cleaner fix remains adding a `git config --global --add safe.directory "${GITHUB_WORKSPACE}"` step to `.github/workflows/prune-candidates-weekly.yml` — exactly what `orchestrator.yml` already does, which is why the orchestrator's own git steps don't hit this — and it is still blocked on the missing `workflow` OAuth scope (see #1636/H-BLAS for the standing blocker). This PR is **defense-in-depth**, not closure of that blocker: the script no longer depends on ambient `safe.directory` at all, so the cron should go green on script-side merit alone regardless of whether the workflow-side fix ever lands. Expect the next Monday cron run to go green off this fix; if it still reds, the failure is no longer this mechanism (re-diagnose from the fresh job log rather than assuming this fix regressed).
  Verify: `sh dev/scripts/prune_candidates_test.sh` → `prune_candidates_test: 29 passed, 0 failed`, exit 0. `dev/lib/run-in-env.sh dune runtest devtools` → exit 0, `prune_candidates_test: 29 passed, 0 failed` in the log.
  **Rework iteration 1 (qc-behavioral NEEDS_REWORK, quality 2):** the review found the exit-status guard half of the fix — `_git_log_date()`'s `rc -ne 0` abort branch and its docstring's (b)-vs-(c) distinction (real git failure MUST abort; genuine no-history MUST still skip) — was unexercised: a tracer on the branch fired **0 times** across all 29 assertions, and both a degrade-to-skip mutation (`printf ''; return 0`) and the inverse no-history-to-`return 1` mutation left the suite green (`29 passed, 0 failed`, exit 0 in both cases). Added **Fixture G** (`dev/scripts/prune_candidates_test.sh`, new block after Fixture F): `PRUNE_CANDIDATES_ROOT` pointed at a **plain, non-git directory** with the same minimal tree — `git log` fails there with `fatal: not a git repository` even under `-c safe.directory="$ROOT"` (safe.directory only fixes an ownership mismatch inside a real repo, not "no repo at all"), giving a deterministic real-failure reproduction independent of `GIT_TEST_ASSUME_DIFFERENT_OWNER`. Pins that checker1 and checker2 each abort with `FAIL(checker1|2): git log failed dating <path>`, exit 1, and that git's own `not a git repository` message is surfaced rather than swallowed. Also added two claim-(c) checks reusing the existing Fixture F tree plus one never-committed directory under `dev/experiments/`: under plain ambient git config (no forced-ownership override), a genuinely history-less tracked-repo path must still exit 0 and never produce a `FAIL(checker2)` line. Suite is now 34 assertions. **Mutation-checked by hand, both unpiped:** degrade-to-skip mutation (`printf ''; return 0` on the failure path) → `31 passed, 3 failed`, exit **1** (the 3 new Fixture G checks go red; the 2 claim-(c) checks correctly stay green since collapse-to-skip doesn't touch the already-empty no-history case); restored → `34 passed, 0 failed`, exit **0**. No-history-to-`return 1` mutation (`[ -z "$out" ] && return 1` before the success return) → `29 passed, 5 failed`, exit **1** (all 3 dubious-ownership-simulation checks plus both claim-(c) checks go red, since that simulation's forced-failure path now also fires on the previously-legitimate no-history dir); restored → `34 passed, 0 failed`, exit **0**, byte-identical diff to pre-mutation. Also re-ran `dune runtest devtools` (native, `TRADING_IN_CONTAINER=1`, no Docker in this environment) and `posix_sh_check.sh` — both exit 0, `prune_candidates_test: 34 passed, 0 failed` printed by the dune-wired runner.
  Verify (post-rework): `sh dev/scripts/prune_candidates_test.sh` → `prune_candidates_test: 34 passed, 0 failed`, exit 0. `dev/lib/run-in-env.sh dune runtest devtools` → exit 0, same count in the log.

- [x] **H-SCHEDULED-WORKFLOW-HEALTH — scheduled (cron) workflow health check, script half of #2634** (branch `harness/scheduled-workflow-health`, GHA orchestrator run 33894722318). Nothing in this repo previously monitored whether its scheduled workflows were still succeeding: two weekly workflows had been red for weeks (one for five) and a daily cron silently missed a day, all found only when a human happened to look. **Built:** `trading/devtools/checks/scheduled_workflow_health.sh`, a standalone POSIX-sh script (no `.github/workflows/**` changes — see Scope below) that queries `GET /repos/{owner}/{repo}/actions/workflows` (fully paginated to completion, not just the first page) then, for every ACTIVE workflow, `GET .../workflows/{id}/runs?event=schedule&per_page=1` for its single newest scheduled run. Classifies each into RED (conclusion failure/cancelled/timed_out/action_required) / STALE (not RED, but older than a staleness window — default 216h/9 days, overridable via `--stale-hours` / `SCHEDULED_WF_HEALTH_STALE_HOURS`) / NO-SCHEDULE (zero observed scheduled runs — informational only, never fails the gate) / OK. Exit codes are distinct per failure class and never collapse "couldn't measure" into "measured green": 0 = clear, 1 = at least one RED/STALE (the real signal), 2 = no `GH_TOKEN` and no fetch hook (can't call the API at all), 3 = an API call failed or returned non-JSON, 64 = usage error. The HTTP call is injectable via `SCHEDULED_WF_HEALTH_FETCH` (an external-command hook, same seam shape as `PR_GATE_STATUS_LIB` in `dev/scripts/pr_gate_status.sh`), and "now" is injectable via `SCHEDULED_WF_HEALTH_NOW_EPOCH`, so the fixture test is fully hermetic (no network). Two traps this repo has been burned by before were addressed directly: (1) **pagination-is-a-floor** (the 2026-09-02 orchestrator undercounted a failure streak 3x by reading a `per_page=5` page boundary as the whole answer) — the workflow-list call actually loops to completion and the summary line states the real page count fetched, and the per-workflow runs call is `per_page=1` by design (it only ever claims "the single newest run's conclusion," never a streak count, so there's no floor to mislabel); (2) **a check that can't fail is not a check** — the missing-token and API-error paths were mutation-tested by hand (stripping the no-token guard, breaking RED-conclusion matching) to confirm the corresponding assertions actually go red, not just pass vacuously. **Real bug caught and fixed during development, not shipped:** an early version called `exit 3` from inside `_api_get_json`, which is always invoked via `x=$(...)` command substitution (a subshell) — `exit` there only kills the subshell, so the failure silently evaporated 1-2 subshell layers up and the script would have reported a false "0 active workflows, exit 0" on an API error. Fixed by having every network-calling helper `return` its failure code explicitly and having each caller (`_list_active_workflows`, `_newest_scheduled_run`, and `main()` itself) check and re-propagate it, rather than relying on `set -e` to cascade through multiple subshell boundaries. **Test:** `trading/devtools/checks/scheduled_workflow_health_test.sh`, 10 fixture-driven assertions (all-green; one RED named on its own line and in the summary; STALE via an aged-but-successful run; NO-SCHEDULE that does not force a non-zero exit; missing-token exit 2; API-error exit 3; malformed-JSON exit 3; full pagination across 2 pages proving `active=101` is a real total not a page-1 floor of 100; `--stale-hours` override actually reclassifying the same run age; malformed `--stale-hours` -> exit 64), wired into `dune runtest` via `trading/devtools/checks/dune` (explicit `(deps scheduled_workflow_health.sh)`, no `(universe)` needed — every fixture is a canned-JSON shell shim, the only real-repo file read is the script itself). Both `dash -n` (posix_sh_check.sh) and the full `dune build @fmt && dune build && dune runtest` are clean. **Live-API non-vacuity proof** (run against the real repo with a real `GH_TOKEN`, not just fixtures): reproduced all three known-red workflows unprompted — `RED Prune candidates weekly`, `RED Weekly track pacer`, `RED Weekly start sweep (BAH SPY)` — plus `SUMMARY: active=17 (1 page(s) fetched...) ok=7 red=3 stale=0 no-schedule=7`, exit 1. **Scope / what's still open:** wiring this into an actual cron or CI job (`.github/workflows/**`) is the other half of #2634 and is explicitly OUT of scope here — the orchestrator's token lacks the `workflow` OAuth scope (same standing blocker as #1636/H-BLAS/H-PRUNE-GIT-SAFEDIR above), and this script was deliberately built standalone so it can land without that scope. A human (or a workflow-scoped PAT) needs to add a scheduled job that runs it and surfaces a non-zero exit. Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest` exit 0; `dune runtest devtools/checks/` shows `scheduled_workflow_health_test: ... OK: scheduled_workflow_health_test -- all assertions passed.`; `GH_TOKEN=... sh trading/devtools/checks/scheduled_workflow_health.sh` against the real repo.

---

## Completed

### 7th gnu_time_rss copy + shape-based structural guard (issue #2576, 2026-08-27)

- [x] qc-behavioral reviewing #2572 (the rework of #2559) found a 7th,
  unfixed copy of the identical fused-digit `tr -d '\n'` bug in
  `dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh`
  (line 90, variable `$rss` — not `$rss_path`, which is exactly why #2559's
  discovery grep and the smoke test's old assertion 5 (hardcoded to the 6
  known call sites) both missed it). Branch: `harness/2576-rss-seventh-copy`.
  Fix, two parts:
  1. **Instance:** ported `run_with_perf.sh` to source
     `dev/lib/gnu_time_rss.sh` and call `_parse_gnu_time_rss`, same as the
     other 6 call sites; added it to `gnu_time_rss_smoke.sh`'s
     `CALL_SITES` list.
  2. **Class (the actual point of #2576):** added a new Assertion 6 to
     `trading/devtools/checks/gnu_time_rss_smoke.sh` that sweeps every
     `*.sh` file in the repo (pruning `.git`/`_build`/`node_modules`/
     `vendor`/`.devcontainer`/`worktrees`, same as `no_python_check.sh`) for
     the raw bug SHAPE — a same-line `tr -d '\n'` not already reduced to one
     line via `tail -n 1`/`head -n 1` — rather than a hardcoded path list.
     The regex names no variable, so it cannot be evaded by variable-name
     choice the way the old assertion 5 was. `dev/lib/gnu_time_rss.sh` (the
     canonical implementation) and the smoke-test script itself (which
     necessarily quotes the buggy shape in its own doc-comments/regex
     literal) are excluded by path; comment lines are skipped everywhere
     else.
  - Verified RED→GREEN→RED→GREEN by mutation: added a scratch script with a
    third, novel variable name (`$rssfile`/`$rssvalue`) reproducing the bug
    shape — Assertion 6 failed and named the exact file/line (RED, exit 1);
    removed the scratch file — GREEN again (exit 0), confirming the guard is
    shape-based, not a longer hardcoded list.
  - Documented residual explicitly in the check's own header comment: same-
    line match only, which fails SAFE rather than permissive — a genuine
    multi-line/intermediate-variable bug IS still caught (there is nothing
    on that line to match the "already reduced" exemption); what the
    same-line restriction actually produces is the opposite of a missed
    bug, a false POSITIVE on safe code that splits its `tail -n 1`
    reduction onto a separate line. Over-cautious, not a hole; only
    `*.sh` files are scanned (no inline shell
    in GitHub Actions `run:` YAML blocks, Makefiles, etc.); only the literal
    `tr -d '\n'` idiom is matched (a different newline-fusing idiom, e.g.
    `awk 'BEGIN{RS="\0"}'`, would not trip it); and the "safe shape" check is
    co-occurrence, not causal precedence — a line where `tail -n 1` and
    `tr -d '\n'` both appear for unrelated reasons (e.g. two
    semicolon-separated statements) is waved through as a false negative,
    which is a real gap in the check's logic, not just its scope.
  - Rework (2026-08-27, qc-behavioral iteration 1): assertion 6 previously
    ran only against the live repo, which is clean, so its passing state
    proved nothing about whether the detector itself still worked — a
    regex re-scoped to a specific variable name (the exact #2576 blind
    spot) or reduced to a no-op both stayed green. Fixed by extracting the
    sweep body into `_sweep_dir_for_tr_d_bug()` and adding assertion 7
    (runs it against a `$WORK` fixture: an arbitrary-name bug file must be
    detected, a `tail -n 1`-reduced safe file must not be) and assertion 8
    (pins the co-occurrence false negative above as a measured fixture
    result rather than prose only).
  - Verify: `sh trading/devtools/checks/gnu_time_rss_smoke.sh`, or `dune
    runtest trading/devtools/checks/`.

### Shared GNU-time RSS parser across all 6 call sites (issue #2559, 2026-08-27)

- [x] #2553 (below) fixed the digit-fusion peak-RSS bug only in
  `dev/scripts/golden_sp500_postsubmit.sh`. qc-behavioral on #2557 (the
  #2553 PR) flagged that the identical `rss_value=$(tr -d '\n'
  <"$rss_path")` line was still live, unfixed, in five sibling scripts:
  `perf_tier1_smoke.sh` (backs the **REQUIRED** `perf-tier1-smoke` PR gate
  — the highest-stakes instance, since a fused-digit misread there could
  misinform a merge-blocking perf regression call), `perf_tier2_nightly.sh`,
  `perf_tier3_weekly.sh`, `perf_tier4_release_gate.sh`, and
  `run_tier4_release_gate.sh`. Fix: extracted `_parse_gnu_time_rss()` into a
  shared `dev/lib/gnu_time_rss.sh` (sourced, not executed — same convention
  as `dev/lib/heartbeat.sh`) and pointed all six scripts at it, removing
  each script's private inline copy (including the
  `POSTSUBMIT_RSS_PARSE_TEST` dot-source-guard hack in
  `golden_sp500_postsubmit.sh`, no longer needed once the helper lives in
  its own file). Regression test generalized + renamed:
  `trading/devtools/checks/golden_sp500_postsubmit_rss_smoke.sh` →
  `trading/devtools/checks/gnu_time_rss_smoke.sh`, now sourcing
  `dev/lib/gnu_time_rss.sh` directly (4 fixture-shape assertions, unchanged
  from #2553) plus a 5th assertion that greps all six known call sites to
  confirm each sources the shared helper rather than re-inlining it (the
  mechanical guard against this exact bug recurring a third time). Verified
  RED (reverted the helper to the pre-#2553 `tr -d '\n'` body — assertions
  1 and 4, the two shapes with a leading GNU-time status line, failed with
  the fused-digit output) then GREEN (restored byte-identical). Corrected
  `.github/workflows/golden-runs-sp500-15y.yml`'s stale
  "unexplained-but-moot" framing of the 2026-08-24/25 "12.4 GB" figures to
  cite the digit-fusion bug as the likely explanation instead. Widened
  `.claude/rules/container-capacity-scheduling.md`'s "Pre-#2553 kill-report
  RSS figures are suspect" section to name all six scripts, not just
  `golden_sp500_postsubmit.sh`. Verify: `dune runtest
  trading/devtools/checks/` (or `sh
  trading/devtools/checks/gnu_time_rss_smoke.sh` directly).

### golden_sp500_postsubmit.sh peak-RSS parse fix (issue #2553, 2026-08-26)

> Superseded by #2559 (above): `_parse_gnu_time_rss()` moved out of this
> script into shared `dev/lib/gnu_time_rss.sh`, and the regression test
> below was renamed to `trading/devtools/checks/gnu_time_rss_smoke.sh`.
> Kept here as the historical record of the original fix.

- [x] Fixed `dev/scripts/golden_sp500_postsubmit.sh` mis-reporting peak RSS on
  every FAILING cell: GNU `/usr/bin/time`'s exit-status line ("Command exited
  with non-zero status 1") fused onto the `%M` value because
  `rss_value=$(tr -d '\n' <"$rss_path")` stripped ALL newlines from the
  output file, e.g. real `745192` kB read as `1745192` — off by ~1 GB, and
  only on failing cells, exactly when someone reads the number. Fix: new
  `_parse_gnu_time_rss()` helper reads the file's LAST line (`tail -n 1`)
  instead, which is always the `%M` value regardless of whether a status
  line precedes it; the `UNAVAILABLE` sentinel path is unaffected (single
  line, passes through unchanged). Regression test:
  `trading/devtools/checks/golden_sp500_postsubmit_rss_smoke.sh` (4 fixture
  cases: failing-cell status-line shape, passing-cell bare-value shape,
  `UNAVAILABLE` sentinel, killed-by-signal shape), dot-sourcing the real
  script with `POSTSUBMIT_RSS_PARSE_TEST=1` so the helper is exercised
  directly without a real scenario_runner invocation; wired into `dune
  runtest` via `trading/devtools/checks/dune`. Verified RED against the
  pre-fix `tr -d '\n'` body (2 of 4 assertions failed, reproducing the exact
  fused-digit bug) then GREEN after the fix. Added a note to
  `.claude/rules/container-capacity-scheduling.md` (adjacent to "Measure
  with `docker stats`, not per-process RSS") flagging that pre-fix
  failing-cell RSS figures — including the 2026-08-24/25 "12.4 GB" figures
  in issue #2537 — are suspect, not data. Verify: `dune runtest
  trading/devtools/checks/` (or `sh
  trading/devtools/checks/golden_sp500_postsubmit_rss_smoke.sh` directly).

### Repo-compression verification tooling (2026-08-20)

- [x] `dev/scripts/prune_candidates.sh` — verified, never-delete repo-compression
  worklist per `dev/plans/arc-readiness-2026-08-20.md` Axis 3. Three checkers:
  (1) superseded `dev/notes/next-session-priorities-*` docs cited by nothing
  under `dev/experiments/_ledger/`, `dev/plans/`, `dev/status/`, `.claude/`, or
  `CLAUDE.md`; (2) orphaned `dev/experiments/` dirs (uncited AND >= 30 days
  untouched by git-log dating, not filesystem mtime); (3) Rule-4 flag
  eligibility for default-off mechanism flags with a ledger REJECT, checked
  against live `*.sexp` references and `.ml` assignments. Every checker
  carries a mandatory sanity probe against a known-present fact and aborts
  nonzero rather than silently reporting a false-clean result — see the
  script's header for the concrete bugs this caught during development
  (a `tr -d '[:space:]'` call that concatenated all flag names into one
  string, and a `find | xargs grep` empty-input pattern that made BSD xargs
  report every empty citation-source dir as "cited"). Test suite:
  `dev/scripts/prune_candidates_test.sh` (18 cases, fixture-built throwaway
  git repos with controlled commit dates), wired into `dune runtest` via
  `trading/devtools/checks/prune_candidates_test_runner.sh`. Scheduled
  weekly via `.github/workflows/prune-candidates-weekly.yml`, writing
  `dev/health/prune-candidates-<date>.md` and opening an advisory PR.
  Verify: `sh dev/scripts/prune_candidates.sh` (real-repo run); `dune runtest
  trading/devtools/checks/` (test suite).

### Agent definitions

- [x] `harness-maintainer` agent defined — `.claude/agents/harness-maintainer.md`; owns T1-M, T1-N, T1-P, T1-Q and future harness items; dispatched by lead-orchestrator Step 2d. Verify: `cat .claude/agents/harness-maintainer.md` — should have `## Acceptance Checklist`, `## Max-Iterations Policy`, `## Allowed Tools`.
- [x] `health-scanner` agent defined — `.claude/agents/health-scanner.md`; fast scan (post-run) and deep scan (weekly); dispatched by lead-orchestrator Step 6; read-only. Verify: `cat .claude/agents/health-scanner.md`.
- [x] T1-O: `health-scanner` fast scan — operational spec added. Fast scan now has 5 explicit steps with shell commands: (1) stale review check, (2) main build health via `dune build && dune runtest`, (3) magic number gate check via `dune runtest devtools/checks/`, (4) status file integrity check, (5) linter exception review date check. Harness plan §T3-A updated to match. Agent definition now self-sufficient — agent can run fast scan without additional prompting. Verify: `cat .claude/agents/health-scanner.md` — should have numbered steps with bash commands; `cat docs/design/harness-engineering-plan.md` — T3-A fast scan should have 5 items.
- [x] `ops-data` agent defined — `.claude/agents/ops-data.md`; on-demand data fetch + inventory refresh; human-triggered. Verify: `cat .claude/agents/ops-data.md`.
- [x] `lead-orchestrator` updated — Step 2d (harness backlog dispatch), Step 6 (health-scanner fast scan), daily summary template updated with Harness Work and Health Scan sections. Verify: grep for "Step 2d\|Step 6\|health-scanner" in `.claude/agents/lead-orchestrator.md`.

### Plan and principles

- [x] Harness plan drafted and committed (`docs/design/harness-engineering-plan.md`). Verify: file exists; contains T1–T4 tiers, Target State, Tier 4 end-state.
- [x] Automation goals and target state defined (Target State + Tier 4).
- [x] Added audit trail, rollback/recovery, live trading gate, QC non-determinism policy, cost visibility.
- [x] Incorporated learnings from Anthropic, Fowler, Stripe Minions, and OpenAI harness articles.
- [x] Refined architecture checks: A1 FLAG not FAIL in qc-structural; generalizability judgment in qc-behavioral.
- [x] Added T3-F architecture graph analyzer + dependency-rules.md lifecycle to plan.
- [x] Created `docs/design/engineering-principles.md` — living document of guiding principles. Verify: file exists.

### T1-A: Hard deterministic gates

- [x] T1-A: Architecture layer test — `trading/devtools/checks/arch_layer_check.sh` or equivalent; enforces `analysis/` cannot import `trading/trading/`. Verify: `dune runtest trading/devtools/checks/` passes; introducing an illegal import would fail the suite.
- [x] T1-A: Magic number linter — `trading/devtools/checks/` with `linter_exceptions.conf` carrying `# review_at:` entries for path exceptions. Verify: `dune runtest trading/devtools/checks/` passes; adding an unexcepted numeric literal in `analysis/weinstein/` fails.
- [x] T1-A: `.mli` coverage linter — public functions in `.ml` without a corresponding `.mli` entry are flagged. Verify: `dune runtest trading/devtools/checks/` passes.
- [x] T1-A: File length linter — 300-line soft limit, 500-line declared-large (`@large-module`), 11% cap on oversized files. Verify: `dune runtest trading/devtools/checks/`.
- [x] T1-A+: Function length linter — `trading/devtools/fn_length_linter/`; OCaml AST via `compiler-libs`; >50 lines = test failure; `@large-function` to opt out specific functions. Verify: `dune runtest trading/devtools/fn_length_linter/`.

### T1-B: QC agent split

- [x] T1-B: Created `qc-structural` (`.claude/agents/qc-structural.md`) and `qc-behavioral` (`.claude/agents/qc-behavioral.md`); deleted `qc-reviewer.md`. `qc-structural` runs first, gates `qc-behavioral`. PR #171. Verify: both files exist; neither contains the word "qc-reviewer".
- [x] T1-B: `lead-orchestrator` spawns both QC agents in sequence (structural → behavioral). Verify: grep "qc-structural\|qc-behavioral" in `lead-orchestrator.md`.

### T1-C: Acceptance checklists

- [x] T1-C: `## Acceptance Checklist` added to all four feat-*.md agent definitions. `feat-agent-template.md` created. PR #171, #174. Verify: `dune runtest trading/devtools/checks/` (agent_compliance_check.sh verifies required sections).

### T1-D: Structured QC output

- [x] T1-D: Both QC agents produce structured per-item PASS/FAIL/FLAG output (not prose). Checklist items are verifiable claims. PR #171. Verify: read `qc-structural.md` and `qc-behavioral.md` — both have a checklist section with per-item verdicts.

### T1-E: Pre-flight context injection

- [x] T1-E: `lead-orchestrator` injects current test failures, last QC findings, and open follow-ups before every feat-agent dispatch. PR #171. Verify: grep "pre-flight\|preflight\|context injection" in `lead-orchestrator.md`.

### T1-F: Blueprint format

- [x] T1-F: `lead-orchestrator` uses an explicit blueprint format separating deterministic nodes (shell commands) from agentic steps (agent spawns). PR #171. Verify: grep "blueprint\|deterministic" in `lead-orchestrator.md`.

### T1-G: Max-iterations policy

- [x] T1-G: `## Max-Iterations Policy` (cap: 3 build-fix cycles) added to all four feat-agent definitions. PR #174. Verify: `dune runtest trading/devtools/checks/` (agent_compliance_check.sh).

### T1-H: Tool curation

- [x] T1-H: `## Allowed Tools` subset added to all four feat-agent definitions. PR #174. Verify: `dune runtest trading/devtools/checks/` (agent_compliance_check.sh).

### T1-I: Agent compliance check

- [x] T1-I: `trading/devtools/checks/agent_compliance_check.sh` verifies all `feat-*.md` have `## Acceptance Checklist`, `## Max-Iterations Policy`, and `## Allowed Tools`. Wired into `dune runtest`. Verify: `dune runtest trading/devtools/checks/`; adding a feat-agent without these sections fails.

### T1-J: Stale branch preflight

- [x] T1-J: `qc-structural` Step 1 counts commits on `main@origin` not reachable from the feature branch; FLAGs (not FAILs) if > 10 commits behind. Verify: read `qc-structural.md` Step 1 — should describe the stale-branch check.

### T1-K: Linter exception retirement policy

- [x] T1-K: All entries in `trading/devtools/checks/linter_exceptions.conf` carry `# review_at: YYYY-MM-DD` annotations. Format documented; health-scanner deep scan will surface expired entries (T3-A). Verify: `cat trading/devtools/checks/linter_exceptions.conf` — all exception lines have `# review_at:`.

### T1-L: Parallel write conflict policy

- [x] T1-L: `lead-orchestrator` Step 4 documents the parallel write conflict policy: shared files (status files, CLAUDE.md, design docs) are read-only during parallel feat-agent runs; proposed changes to shared files are surfaced in return values for orchestrator resolution. Verify: grep "parallel\|write conflict\|read-only" in `lead-orchestrator.md` Step 4.

### T1-N: Golden scenarios

- [x] T1-N: Screener regression tests — `trading/analysis/weinstein/screener/test/regression_test.ml`; 8 real-AAPL scenarios organised by module: Stage Classifier (6: 2023 bull, 2022 bear, mid-2023 stock analysis, 2019 pre-COVID, COVID crash, 2024 AI era), Screener (2: bearish macro gate, Stage4 short candidate with Stage3→4 breakdown). RS synthetic test moved to `analysis/weinstein/rs/test/test_rs.ml`. PR #217. Verify: `dune runtest analysis/weinstein/screener/test/` (8 tests, OK).
- [x] T1-N: Stop state machine regression tests — `trading/trading/weinstein/stops/test/regression_test.ml`; 5 scenarios: Stage2 trailing stop, Stage3 tightening, stop-hit, short side, stop-raise. PR #204. Verify: `dune runtest trading/trading/weinstein/stops/test/`.

### T1-Q: Cyclomatic complexity linter

- [x] T1-Q: CC linter — `trading/devtools/cc_linter/cc_linter.ml`; OCaml AST via `compiler-libs`; CC > 10 = warning (not failure); exits 0 always; optional JSON output to `dev/metrics/cc-YYYY-MM-DD.json`. Wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `dune runtest trading/devtools/checks/` — exits 0; prints OK or warning list.

### T3-G: Status file integrity check

- [x] T3-G: Status file integrity check — `trading/devtools/checks/status_file_integrity.sh` deterministically enforces the `dev/status/*.md` schema: `## Status` with a valid value (IN_PROGRESS | READY_FOR_REVIEW | APPROVED | MERGED | BLOCKED), `## Last updated: YYYY-MM-DD`, and `## Interface stable` (YES|NO) for feature files. Exempt files: `harness.md` (orchestrator backlog, different shape) and `backtest-infra.md` (human-driven, uses `## Ownership`). Wired into `dune runtest` via `trading/devtools/checks/dune`; health-scanner fast scan Step 4 now references the script. Verify: `dune runtest devtools/checks/` — prints `OK: all dev/status/*.md files have required fields.`; removing an `## Interface stable` section from any feature status file fails the test.

### T3-G: Deep scan Trends section

- [x] T3-G: Deep scan Trends extension — Check 8 added to `trading/devtools/checks/deep_scan.sh`. Emits a `## Trends` section in `dev/health/YYYY-MM-DD-deep.md` with two sub-sections: (a) followup-item count per status file — today vs second-most-recent deep scan, with per-file delta table; "no baseline" on first run; (b) CC distribution buckets (1-5 / 6-10 / >10) vs previous `dev/metrics/cc-*.json`, plus top-5 highest-CC functions by name, file, and line number. CC JSON generated by the existing `cc_linter` binary; first snapshot at `dev/metrics/cc-2026-04-16.json`. Structural smoke test: `trading/devtools/checks/deep_scan_trends_check.sh` — wired into `dune runtest`, grep-asserts that both sub-sections are present in the script and the most-recent deep scan report contains `## Trends`. Verify: `sh trading/devtools/checks/deep_scan.sh` from repo root — report contains `## Trends` with Followup items table and CC distribution table.

### T3-G: Audit quality score wiring

- [x] T3-G: Audit trail quality score — `trading/devtools/checks/record_qc_audit.sh`; thin wrapper around `write_audit.sh` that extracts structural verdict, behavioral verdict, and quality score from `dev/reviews/<feature>.md` and writes `dev/audit/YYYY-MM-DD-<feature>.json`. Extraction handles all observed output formats: `structural_qc:/behavioral_qc:` fields, `## Verdict` blocks (bare and `**bold**`), `## Quality Score` / `### Quality Score` headings with bare-digit (`5 — rationale`) or bold-digit (`**5 — rationale`) formats; last Quality Score section wins (behavioral takes precedence). `lead-orchestrator.md` Step 5 Stage 4 added — instructs the orchestrator to call `record_qc_audit.sh` after QC completes (APPROVED or NEEDS_REWORK) for every reviewed feature. `qc-behavioral.md` output contract note added — documents canonical format (`## Quality Score` + bare digit line) for grep-parseable output. Files: `trading/devtools/checks/record_qc_audit.sh`, `.claude/agents/lead-orchestrator.md` (Stage 4 in Step 5), `.claude/agents/qc-behavioral.md` (output contract note). Verify: `bash trading/devtools/checks/record_qc_audit.sh backtest-scale feat/backtest-scale 2026-04-20` — writes `dev/audit/2026-04-20-backtest-scale.json` with `quality_score: 5` (not null).

### T3-A: Deep scan

- [x] T3-A: Deep scan deterministic script — `trading/devtools/checks/deep_scan.sh`; standalone shell script (not wired into `dune runtest` — runs weekly, not on every PR). Covers 5 checks: (1) dead code detection (`.ml` files not in any dune library), (2) design doc drift (`analysis/weinstein/` and `trading/weinstein/` modules vs `eng-design-{1,2,3}` docs), (3) TODO/FIXME/HACK accumulation across `.ml`/`.mli` files, (4) size violations (files >300 lines without `@large-module`), (5) follow-up item count across `dev/status/*.md`. Writes report to `dev/health/YYYY-MM-DD-deep.md`. Health-scanner agent definition updated with Phase 1 (deterministic script) and Phase 2 (agentic steps: architecture drift, QC calibration, harness scaffolding review). Verify: `sh trading/devtools/checks/deep_scan.sh` from repo root produces `dev/health/YYYY-MM-DD-deep.md` with Metrics section.

- [x] T3-A: QC calibration audit — Check 6 in `trading/devtools/checks/deep_scan.sh`. For each `dev/reviews/*.md`, extracts the most recent overall verdict (APPROVED/NEEDS_REWORK) via three patterns (`overall_qc:`, `Status:`, `## Verdict`), then: (a) flags features with reviews but no audit trail record in `dev/audit/`, (b) if `dune` is on PATH, runs `dune runtest` on each feature's test directories and flags mismatches (APPROVED + failing tests = regression; NEEDS_REWORK + passing tests = stale review). Feature-to-test-directory mapping covers screener, data-layer, portfolio-stops, simulation. Output appears in the deep scan report under `## QC Calibration Detail`. Verify: `eval $(opam env) && sh trading/devtools/checks/deep_scan.sh` — report includes `QC calibration findings` in Metrics section.

### T3-D: Audit trail

- [x] T3-D: Audit trail writer — `trading/devtools/checks/write_audit.sh`; standalone shell script (not wired into `dune runtest` — operational tool, not a test gate). Takes `--date`, `--feature`, `--branch`, `--structural`, `--behavioral`, `--overall`, and optional `--harness-gap`, `--quality-score`, `--pass-count`, `--fail-count`, `--flag-count`, `--notes` arguments. Writes structured JSON to `dev/audit/YYYY-MM-DD-<feature>.json`. Computes `consecutive_rework_count` by reading prior audit files for the same feature (newest-first, counting contiguous NEEDS_REWORK verdicts). Idempotent (overwrites on same date+feature). Creates `dev/audit/` if missing. Validates date format, verdict values, and required arguments. Verify: `sh trading/devtools/checks/write_audit.sh --date 2026-04-14 --feature test --branch feat/test --structural APPROVED --behavioral APPROVED --overall APPROVED` — writes `dev/audit/2026-04-14-test.json` with valid JSON.

### T3-B and T3-F

- [x] T3-B: AVR loop closure already in `lead-orchestrator` Step 5 — auto-dispatches QC for any READY_FOR_REVIEW feature in the same orchestrator run. Verify: grep "READY_FOR_REVIEW\|auto.*QC\|Step 5" in `lead-orchestrator.md`.
- [x] qc-structural: P1/P2/P4 items updated to "verified by linter (H3)" — QC no longer manually re-scans these; linters are the deterministic gate. Verify: read `qc-structural.md` checklist — P1/P2/P4 items reference linter gates.
- [x] T3-F: `docs/design/dependency-rules.md` created — R1–R6 rules with lifecycle states (`proposed` / `monitored` / `enforced`); R1, R4, R6 enforced via dune tests; R2, R3 monitored; R5 proposed. Verify: file exists; `dune runtest trading/devtools/checks/` enforces R1.
- [x] T3-F: Architecture graph analyzer — Check 9 added to `trading/devtools/checks/deep_scan.sh`; grep-based MVP covering the two monitored rules: R2 (trading/trading/weinstein/ must not open analysis modules) and R3 (trading.simulation must not be a library dependency of live execution paths). Findings emitted under `## Architecture Graph` in `dev/health/YYYY-MM-DD-deep.md`; violations are INFO (monitored — human decides to promote to enforced). Companion smoke test at `trading/devtools/checks/deep_scan_arch_graph_check.sh` wired into `dune runtest`. Verify: `sh trading/devtools/checks/deep_scan.sh` — report contains `## Architecture Graph` with R2 and R3 sub-sections; `dune runtest devtools/checks/` — prints `OK: deep scan Architecture Graph section (T3-F) structural check passed.`
- [x] T3-F: Rule promotion path — `trading/devtools/checks/rule_promotion_check.sh` parses `docs/design/dependency-rules.md` for rules with `Lifecycle: enforced`, asserts each has a referenced check script that (a) exists on disk and (b) is mentioned in `trading/devtools/checks/dune`. Implicit checks (R4, R6 — enforced by dune structure) are accepted without a script path. Rules at `monitored` or `proposed` are skipped. Degrades gracefully if the rules doc is absent (WARNING, exits 0). Self-test at `trading/devtools/checks/rule_promotion_self_test.sh` (6 scenarios: valid pass, missing script, missing dune wiring, implicit-ok, monitored-ok, real-repo). `docs/design/dependency-rules.md` retrofitted: `State` → `Lifecycle` field in each rule table; `Check` field standardised to either a file path or `implicit (dune structure: ...)` or `none`. Both scripts wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `sh trading/devtools/checks/rule_promotion_check.sh` — prints 3 OK lines + summary; `sh trading/devtools/checks/rule_promotion_self_test.sh` — 6/6 assertions passed. To test failure mode: add `Lifecycle: enforced` + `Check: trading/devtools/checks/no_such_script.sh` to a rule, re-run — exits 1 with FAIL message.

### Deep scan heuristic gap sub-item 2: Status file template enforcement

- [x] Check 10 added to `trading/devtools/checks/deep_scan.sh` — greps `dev/status/*.md` for the forbidden `## Recent Commits` heading (anchored to line start) and emits findings under `## Status File Template` in `dev/health/YYYY-MM-DD-deep.md`. WARNING severity (easy fix: delete the section). Zero current violations (all three previously-offending files were already stripped). Smoke test: `trading/devtools/checks/deep_scan_recent_commits_check.sh` — verifies Check 10 logic markers are present in `deep_scan.sh` and that the most-recent deep scan report contains `## Status File Template`. Wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `dune runtest devtools/checks/` — prints `OK: deep scan Status File Template section (Recent Commits guard) structural check passed.`

### Deep scan heuristic gap sub-item 3: Linter exception expiry

- [x] Check 11 added to `trading/devtools/checks/deep_scan.sh` — reads `trading/devtools/checks/linter_exceptions.conf`, extracts each entry's `# review_at:` annotation, and surfaces entries whose review point has passed. Two comparison modes: milestone labels (M1-M7 extracted from annotation value, including descriptive phrases containing a milestone token; compared against current milestone from `docs/design/weinstein-trading-system-v2.md` — if doc has no current-milestone marker, emits a parse warning and surfaces all milestone-pinned entries for manual review); date strings (YYYY-MM-DD; compared to today). Entries with `review_at: never` are permanently exempt. Entries missing any `review_at:` annotation are flagged as policy violations (T1-K) in a separate "Missing review_at" sub-section. WARNING severity (not blocking). Findings emitted under `## Linter Exception Expiry` in `dev/health/YYYY-MM-DD-deep.md`. Smoke test: `trading/devtools/checks/deep_scan_linter_expiry_check.sh` — verifies Check 11 markers present in `deep_scan.sh` and most-recent deep scan report contains `## Linter Exception Expiry`. Wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh` — prints `OK: deep scan Linter Exception Expiry section (T1-K) structural check passed.`

### Deep scan decomposition

- [x] `trading/devtools/checks/deep_scan.sh` decomposed into per-check scripts under `trading/devtools/checks/deep_scan/`. The monolith (1284 lines, 11 checks) is replaced by a 4-line shim that execs `deep_scan/main.sh`. Per-check files: `_lib.sh` (shared helpers), `main.sh` (thin orchestrator, ~130 lines), `check_01_dead_code.sh` through `check_11_linter_expiry.sh`. Each check takes `<report_file> [findings_file]` and is independently runnable. The 4 existing smoke tests (`deep_scan_trends_check.sh`, `deep_scan_arch_graph_check.sh`, `deep_scan_recent_commits_check.sh`, `deep_scan_linter_expiry_check.sh`) updated to grep per-check files instead of the monolith. Report output is byte-identical to the monolith (verified by diff). Motivation: PRs #435 and #439 collided adding "Check 11"; future check additions are now 1-file PRs. Verify: `sh trading/devtools/checks/deep_scan.sh` — report matches expected output; `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh` — prints OK.

### T3-E: Cost/token budget visibility

- [x] T3-E: `max_daily_cost_usd` field added to `dev/config/merge-policy.json` (default: 50.0). Step 3.75 in `lead-orchestrator.md` now reads budget cap from merge-policy.json instead of using hardcoded $30 threshold; uses 60% of cap as the high-cost trigger and 40% as the clean-budget threshold. `## Budget` section added to Step 7 daily summary template — reports total subagents spawned, per-subagent breakdown (name, model, status, estimated tokens/cost), killed-mid-flight flag, budget utilization percentage, and whether scope was reduced. Verify: `jq .max_daily_cost_usd dev/config/merge-policy.json` returns 50; grep "Budget" in `.claude/agents/lead-orchestrator.md` shows the new section; grep "max_daily_cost_usd" in Step 3.75 shows the config reference.
- [x] T3-E+: GHA cost capture — measured (not estimated) cost reporting via `claude-code-action@v1` execution_file. Fallback 1b: action exposes `total_cost_usd` in SDKResultMessage; GHA step "Capture run cost" parses it post-run and writes `dev/budget/<date>-run<N>.json`. Removes hardcoded `~$2-4` estimate from lead-orchestrator Step 3.75b; replaces with `model_prices` block in merge-policy.json (Opus 4.5: $5/$25, Sonnet 4.6: $3/$15, Haiku 4.5: $1/$5 per MTok). `dev/lib/budget_rollup.sh` rollup tool + `trading/devtools/checks/budget_rollup_check.sh` smoke test (8 assertions, wired into dune runtest). `dev/status/cost-tracking.md` documents measured vs estimated signals and known gaps (per-subagent breakdown not available). PR #483. Verify: `dune runtest trading/devtools/checks/`; `jq . dev/budget/2026-04-20-run1.json`; `dev/lib/budget_rollup.sh 2026-04-20`.

### run-sh hardening

- [x] `dev/run.sh` pre-flight — fast-fails at the shell (not inside the orchestrator) if `claude` isn't on PATH, `.claude/agents/lead-orchestrator.md` is missing, or its `## Allowed Tools` section no longer lists `Agent`. Each failure prints `FAIL: <what>` to stderr and exits 1. Block is placed immediately after `REPO_ROOT=...` and uses only POSIX-compatible constructs (works with `set -euo pipefail`). Verify: `sh -n dev/run.sh` passes syntax check; temporarily rename `.claude/agents/lead-orchestrator.md` and re-run `dev/run.sh` — it exits 1 with a clear `FAIL:` message.
- [x] `dev/config/merge-policy.json` — default merge-policy config committed with inline defaults (`followup_threshold: 10`, `maintenance_cycle_ratio: 3`, `auto_merge_enabled: false`). Matches the inline defaults previously embedded in `lead-orchestrator.md` Step 2b — now visible and tweakable without editing the agent definition. Intent documented in `dev/config/README.md`. Verify: `jq . dev/config/merge-policy.json` parses cleanly.
- [x] Orchestrator `## Plan Mode` — added to `.claude/agents/lead-orchestrator.md`; triggered by a `--plan` token in the prompt, short-circuits Steps 2–6, writes `dev/daily/<YYYY-MM-DD>-plan.md` with `(plan mode)` marker, never mutates branches or status files. Structural smoke test at `trading/devtools/checks/orchestrator_plan_check.sh` wired into `dune runtest` — grep-asserts the required Plan Mode contract pieces in the agent definition. Does NOT invoke `claude -p` from dune runtest (credentials/network/flakiness). Verify: `dune runtest trading/devtools/checks/` — prints `OK: lead-orchestrator plan mode contract present.`

### Same-day summary consolidation

- [x] `dev/lib/consolidate_day.sh` — merges all `${DATE}*.md` (non-plan) in `dev/daily/` into
  `${DATE}-summary.md`. Sections: Pending work (last run), Dispatched (deduped union — same
  (Track, Agent, Outcome) appears once; conflicting Outcomes get "(run-N)" suffix), QC per track
  (latest per track), Budget (summed subagents + per-run utilization), Escalations (deduped union
  with "(seen in: run-N, run-M)" suffix), Integration Queue (last run), Per-run links. Idempotent;
  graceful on malformed sections (warns to stderr, continues). PR #467.
  Wired into `lead-orchestrator.md` Step 8b — runs after auto-merge when N >= 3; consolidated
  file committed into the same ops/daily-${DATE}-runN branch.
  Smoke test: `trading/devtools/checks/consolidate_day_check.sh` (9 assertions: run header,
  escalation dedup, distinct-outcome preservation, per-run links, budget sum, idempotency,
  error cases for missing arg / malformed date / no files).
  Verify: `dune runtest devtools/checks/` — prints `OK: consolidate_day_check — all assertions passed.`;
  `sh dev/lib/consolidate_day.sh 2026-04-20` with three 2026-04-20 daily files present.

### Deep scan heuristic gap sub-item 1: Drift coverage extension (backtest)

- [x] `trading/trading/backtest/` subsystem added to `trading/devtools/checks/deep_scan/check_02_design_doc_drift.sh` — checks top-level subdirectories of `trading/trading/backtest/` against `dev/plans/backtest-scale-optimization-2026-04-17.md` using the same heuristic as the existing Weinstein subsystem checks (grep for dir name in plan doc; missing = WARNING). Plan document is the active backtest design spec. Current live finding: `trading/trading/backtest/bin/` is not mentioned in the plan (expected — runner binary added post-plan). Smoke test: `trading/devtools/checks/deep_scan_drift_coverage_check.sh` — verifies BACKTEST_PLAN, BACKTEST_DIR, and the plan filename markers are present in `check_02`, and that the most-recent deep scan report references drift. Wired into `dune runtest` via `trading/devtools/checks/dune`. Verify: `sh trading/devtools/checks/deep_scan_drift_coverage_check.sh` — prints OK; `sh trading/devtools/checks/deep_scan.sh` — report shows `Design doc drift items: 1` and warns about `backtest/bin/`.

### orchestrator-daily bundle-budget checkout fix

- [x] GHA "Bundle budget into daily summary and auto-merge" step now resets the working tree before `git checkout "${DAILY_BRANCH}"`. Root cause: lead-orchestrator (jj) leaves modified `dev/reviews/*.md` and untracked `dev/audit/*` / `dev/health/*` files in the git working copy after pushing to the daily branch; `git checkout` refuses to overwrite them. Fix: `git reset --hard HEAD && git clean -fd` added immediately before `git fetch origin "${DAILY_BRANCH}"` with an explanatory comment. Failed run: https://github.com/dayfine/trading/actions/runs/25109871573. File: `.github/workflows/orchestrator.yml` (lines 374–382). Verify: next scheduled run (00:17 or 05:17 PT) completes the step without checkout error.

### Track pacer agent

- [x] `track-pacer` agent defined — `.claude/agents/track-pacer.md`; weekly work-pace and strategic-fit audit; reads all track status files + git log; writes to `dev/reviews/track-pacer-YYYY-MM-DD.md`. GHA workflow `.github/workflows/track-pacer-weekly.yml` — schedule: Sunday 06:00 UTC; branch `ops/track-pacer-<date>`; PR opened for human review (not auto-merged). Seven checks: P1 PR cadence (active/slowing/stalled), P2 Next Steps staleness, P3 `[info]` carryover age (≥3 reconciles), P4 new tracks without owner, P5 recurring discussion topics, P6 diminishing returns (maintenance-only PRs), P7 capability gaps vs milestone plan. Distinct from `health-scanner` (code health) — this agent audits *work pace and strategic fit*. Verify: `cat .claude/agents/track-pacer.md` — should have 7 checks, output format section, and Allowed Tools; `cat .github/workflows/track-pacer-weekly.yml` — should have `cron: "0 6 * * 0"` and push+PR step.

### POSIX shell portability linter

- [x] POSIX shell portability linter — `trading/devtools/checks/posix_sh_check.sh`; runs `dash -n` (syntax-only parse) over all #!/bin/sh scripts in `trading/devtools/checks/`, `trading/devtools/checks/deep_scan/`, and `dev/lib/`. Scripts with `#!/usr/bin/env bash` or `#!/bin/bash` shebang are exempt. Approach: `dash` is pre-installed in the devcontainer base image; `shellcheck` is not. Catches parse-time bash-isms: bash arrays `arr=(...)`, here-strings `<<<`, and process substitution `<(...)` — exactly the class that caused rework on PR #483. Smoke test: `trading/devtools/checks/posix_sh_check_test.sh` (3 assertions: bad-fixture FAIL, clean-fixture OK, bash-exempt OK). Both wired into `dune runtest` via `trading/devtools/checks/dune`. Pre-existing violations found at survey time: `dev/lib/cleanup-stale-worktrees.sh` and `dev/run.sh` have `#!/usr/bin/env bash` and are correctly exempt (intentionally bash). Follow-up: add shellcheck to the devcontainer image for richer coverage of runtime bash-isms ([[ ]], mapfile, ${BASH_SOURCE[0]}). Verify: `dune runtest devtools/checks/` — prints `OK: posix-sh linter -- N scripts clean.` and `OK: posix_sh_check_test -- all 3 assertions passed.`; `sh trading/devtools/checks/posix_sh_check.sh` from repo root.

## Added 2026-07-27 (orchestrator run 2, run 30239958068)

- [ ] H-BLAS: `.github/workflows/ci.yml` — the distro OpenBLAS **mis-detects the `Intel Xeon 6973P-C` GHA runners as `Cooperlake`** (`OPENBLAS_VERBOSE=2` prints `Core: Cooperlake`; confirmed directly) and dispatches AVX-512 kernels that compute wrong results for n>=33. Measured: `chol ~upper:false (4*I)` fails for every 33<=n<=63; **`chol ~upper:true` returns info=0 with a silently WRONG factor** (5-7% rel., 98% at n=120); square `dgemm` wrong by 19.5 at n=120; `Linalg.inv` at n=120 aborts with `double free or corruption`. `OPENBLAS_CORETYPE=Haswell|SkylakeX|Zen|Nehalem` repairs every probe to 1e-15. **Two-part fix:** (a) set `OPENBLAS_CORETYPE` in the CI env; (b) turn the existing CPU-flag smoke step into an actual *numerical* self-check — `chol(4*I)` at n=33 and `dgemm`-vs-naive at n=120 are one line each, and would have caught this in minutes rather than four runs. BLOCKED: editing `.github/workflows/` needs a `workflow`-scoped PAT (same blocker as #1636). PR #2113 removes the tuner's exposure; the repo-wide guard is this item.
- [x] H-AUDIT-COLLISION: Fixed by keying `dev/audit/` filenames on `<date>-<branch-sanitized>-<feature>.json` (branch `/` → `-`) instead of bare `<date>-<feature>.json`, in `trading/devtools/checks/write_audit.sh`. Branch (not a run counter) was chosen because it's always available as an argument (no local equivalent of `$GITHUB_RUN_ID`) and is what actually distinguished the two colliding records in the 2026-07-27 incident; refusing to overwrite was rejected because it degrades a legitimate second same-day review to a silent missing record, same data loss just louder. The branch segment sits *between* date and feature (not appended after) so filenames still end in `-<feature>.json`, preserving the two existing consumers that glob that suffix (`write_audit.sh`'s own `consecutive_rework_count` scan, `deep_scan/check_06_qc_calibration.sh`) without needing changes. Re-invoking for the same branch+feature+date still overwrites its own record (idempotent — verified in `record_qc_audit_test.sh` scenario 7b). Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (13 scenarios, including 7a/7b for the collision + idempotency regression and 9/10/11 for the rework-2 hardening). MERGED `fa23c9df` (PR #2123) after two rework iterations across runs 3-4; both QC gates APPROVED (structural 5/5, behavioral 4/5). Iteration 1 added `recorded_at_ns` ordering; iteration 2 fixed a crash that made its default-to-zero path unreachable, and hardened the timestamp against non-numeric input and BSD `date`. Verified in production post-merge: the new record coexists with run 3's `2026-07-27-harness-run3.json` rather than clobbering it.

- [x] H-PREV-VERDICT-PIPEFAIL: Fixed in `trading/devtools/checks/write_audit.sh`. **Direction decision (the item explicitly asked for one, not a blind patch):** an unparseable or unreadable prior record is now **skipped** — it neither extends nor breaks the `consecutive_rework_count` streak — rather than (a) aborting the whole script under `set -euo pipefail`, which would permanently disable audit writes for that feature since the same bad record is re-scanned every future run, or (b) silently breaking the streak, which under-counts and suppresses the `>= 3` human-escalation trigger (the item's own text names this "the unsafe direction"). Rationale: a missed escalation (false negative) is strictly worse than an occasional over-sensitive one, so the failure mode that biases toward *preserving* the streak across an unreadable gap is the safer default for a safety-net counter. Distinguished the two grep failure classes per the item's request: grep exit 1 (no match — the shape a truncated record produces, e.g. `recorded_at_ns` present but `overall_qc` missing) is skipped silently, matching the existing legacy-record tolerance; grep exit >1 (e.g. 2 — genuinely unreadable target, such as the file vanishing mid-scan) is skipped but also emits a `WARNING:` line to stderr naming the file, so it's visible in orchestrator run logs without aborting. **Regression tests** (added to the existing `record_qc_audit_test.sh`, no new file, no `dune` edit, per instructions): scenario 21 seeds a hand-truncated record (`recorded_at_ns` present, `overall_qc` absent) as the immediately-preceding record in write order on the NEEDS_REWORK path, and asserts the script does not abort (rc=0), the record is written, and `consecutive_rework_count=2` (this record + the older valid NEEDS_REWORK record beyond the truncated one) — proving the truncated record was skipped, not treated as a streak break (which would have produced 1). Scenario 22 seeds a directory at a path matching the `*-<feature>.json` glob (GNU grep exits 2 — "Is a directory" — for this, as opposed to exit 1 for no-match, and is unaffected by root bypassing file permission bits, which ruled out a chmod-based fixture in this container), asserting the script still doesn't abort, still writes, and emits the `WARNING:` message. **Change-detection verified live:** reverted only `write_audit.sh` to its pre-fix `origin/main` shape (keeping the new scenarios) — scenarios 21 and 22 went RED as expected (22 passed, 2 failed; both failures showed the pre-fix script aborting with `rc=1` and `consecutive_rework_count=1` instead of 2). Re-applied the fix — 24/24 green. **Rework iteration 1 (qc-behavioral NEEDS_REWORK, quality 2/5):** two granular sub-claims stated in the code docstring/PR body — grep exit 1 is skipped **silently** (no warning), and the grep exit >1 warning **names the file** — had zero assertion coverage (mutation-tested: injecting a spurious `WARNING:` echo into the exit-1 branch, and stripping `$f` from the exit->1 warning message, both left all 24 scenarios green). Closed both gaps: scenario 21 now additionally asserts `out21_3` contains no `WARNING` substring; scenario 22 now additionally asserts the WARNING line contains the actual offending path (`UNREADABLE_PATH_22`). Re-verified change-detection for both new assertions independently: injecting the spurious warning into the exit-1 branch turned scenario 21 red (23/1) while 22 stayed green; stripping `$f` from the exit->1 warning turned scenario 22 red (23/1) while 21 stayed green; reverting each brought the suite back to 24/0. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (24 scenarios; wired into `dune runtest` via the existing `trading/devtools/checks/dune` rule, unmodified).
- [x] H-AUDIT-ATOMIC-WRITE: Fixed in `trading/devtools/checks/write_audit.sh`. The write now stages content into `TMP_FILE="$(mktemp "${OUTPUT_FILE}.XXXXXX")"` (same directory as `$OUTPUT_FILE`, hence guaranteed same filesystem — a cross-filesystem `mv` degrades to copy+unlink, which would silently reintroduce the truncation window) and `mv -f "$TMP_FILE" "$OUTPUT_FILE"` after the heredoc completes, instead of writing `cat > "$OUTPUT_FILE" <<ENDJSON` directly. An `EXIT INT TERM` trap (`rm -f "$TMP_FILE"`) cleans up the temp file on any failure/interruption before the `mv`; it's a no-op after a successful `mv` since the temp path no longer exists. This removes H-PREV-VERDICT-PIPEFAIL's trigger at the source — a truncated record with `recorded_at_ns` but no `overall_qc` can no longer be produced by this script (H-PREV-VERDICT-PIPEFAIL itself is intentionally left open per its own text: whether an unparseable *prior* record breaks vs. skips the streak is a separate direction decision, not touched here). **Temp-file naming vs. the two `dev/audit/` glob consumers:** both `write_audit.sh`'s own `consecutive_rework_count` scan and `deep_scan/check_06_qc_calibration.sh` glob on `*-<feature>.json` (filename must literally END in `.json`). `mktemp`'s `.XXXXXX` template appends random chars after the literal `.json` in `${OUTPUT_FILE}.XXXXXX`, so the temp filename never ends in `.json` — it is invisible to both globs even if left behind by a SIGKILL (which bypasses the trap). Confirmed no other script in `trading/devtools/checks/` globs `dev/audit/` (grepped for `dev/audit` across the tree; only the two consumers above and this script itself reference the directory). **Regression test** (added to the existing `record_qc_audit_test.sh`, no new file, no `dune` edit): scenario 19 writes a real record (content A), then re-invokes for the SAME date/branch/feature with a new test-only hook `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=1` (mirrors the pre-existing `WRITE_AUDIT_RECORDED_AT_NS` test-only override pattern) that makes the script exit 1 right after finishing the temp file but before the `mv` — simulating a SIGTERM/ENOSPC interruption in that exact window — and asserts the on-disk target is still byte-identical to content A (not truncated, not partially overwritten by content B) with no stray temp file left over. Scenario 20 pins the uninterrupted happy path (record written, no leftover temp file). **Change-detection verified live:** reverted only `write_audit.sh` to its pre-fix `origin/main` shape (keeping the new test scenarios), reran the suite — scenario 19 failed exactly as expected (`rc2=0` instead of nonzero: the "interrupted" second call succeeded and silently clobbered content A with content B, since the pre-fix script has no abort hook and no atomicity); every other scenario still passed (21/22). Re-applied the fix — 22/22 green. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (22 scenarios; wired into `dune runtest` via the existing `trading/devtools/checks/dune` rule, unmodified). (source: 2026-07-27 run 4 qc-behavioral N4 follow-up on PR #2123; built 2026-07-29 run 2, harness/audit-atomic-write)
- [ ] H-CI-DISPATCH: GitHub Actions created **no check-suite at all** for branch `fix/lapacke-gp-cholesky` (PR #2113) across three SHAs, a PR open, a close/reopen, and a PAT-authenticated `synchronize` push — while sibling PRs #2112/#2114/#2115 triggered normally in the same window. `ci.yml` and `perf-tier1.yml` are plain `on: pull_request` with no path/branch filters, so this is not configuration. A QC-APPROVED fix could not clear gate 1 and was correctly held. Worth a watchdog: if a PR has been open >N minutes with zero Actions check-suites, say so loudly rather than waiting forever.
- [x] H-QC-SCALE: Fixed both ends. (1) Agent definitions now state the polarity explicitly and unmissably: `.claude/agents/qc-behavioral.md` and `.claude/agents/qc-structural.md` each carry a "Polarity: 1 = worst → 5 = best" line at the Quality Score Rubric heading, citing the #2115 incident by name, plus an instruction at the point the score is assigned (Step 4 in both files) that the rationale's adjective must agree with the digit before posting. qc-structural.md previously had **no** Quality Score section at all (the incident's actual root cause — it was posting a score only because the dispatch prompt asked ad hoc, with no polarity anchor in the agent definition itself); it now has the same Quality Score Rubric / output-contract / template-block structure as qc-behavioral.md, with structural-flavored rubric anchors (build/gate health rather than domain correctness). (2) Hardened the consumer: `record_qc_audit.sh`'s two score-extraction awk blocks (PR-mode and file-mode) now capture the full leading digit run instead of matching only a single `[1-5]` char, so an out-of-range value is captured as-is rather than silently discarded; a new validation step then fails loudly (`exit 1`, naming the offending value and source) if the parsed score isn't exactly one digit 1-5. `write_audit.sh` — the final consumer that emits the JSON body, reachable directly per its documented orchestrator fallback path — independently validates `--quality-score` the same way before writing anything, so a bad value can never reach a committed audit record through either entry point. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (scenarios 12 and 13 — file-mode out-of-range score rejected with exit 1, no record written; `write_audit.sh` rejects an out-of-range `--quality-score` when invoked directly; the prior 13 scenarios are unchanged/still passing; see H-AUDIT-GH-FALLBACK below for scenario 14).
- [x] H-AUDIT-GH-FALLBACK: Found while verifying the H-QC-SCALE fix above, in the same file: `record_qc_audit.sh --pr-number N` silently wrote a **false APPROVED** when the `gh` binary is not installed on the runner. Mechanism: the `gh pr view` query's output is swallowed by `2>/dev/null || true`, so a missing binary produces an empty `$BODIES` — indistinguishable in shape from "this PR legitimately has no reviews yet" (the case scenario 6 exists to cover) — and the script silently fell through to reading `dev/reviews/<feature>.md`, which can belong to an entirely different PR/run for the same feature name. Observed in production: a PR whose real verdict was `NEEDS_REWORK, quality=3` got recorded as `APPROVED, quality=4` this way, exit 0, `OK: wrote ...` — worse than no record, because a false APPROVED resets the `consecutive_rework_count` streak that #2123 exists to protect. Fix: when `--pr-number` is explicitly given, `record_qc_audit.sh` now checks `command -v "$GH_BIN"` up front and fails loudly (naming the missing binary and the review-file path it refused to fall back to) rather than silently substituting an unrelated file's verdict; omitting `--pr-number` still explicitly opts into file mode, unaffected. Scope is intentionally narrow — this covers "gh binary missing," the exact reported symptom; the residual (gh present but unauthenticated/rate-limited/network-failed, or a PR genuinely at zero reviews) is tracked separately as H-AUDIT-GH-FALLBACK-RESIDUAL below, not closed here. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (16 scenarios total; new scenario 14 seeds an unrelated APPROVED review file, points `RECORD_QC_AUDIT_GH_BIN` at a nonexistent path, and asserts exit 1 with no audit record written).
- [x] H-AUDIT-GH-FALLBACK-RESIDUAL: **Fixed 2026-08-15 (harness/audit-gh-fallback-residual).** Closed the residual left open by H-AUDIT-GH-FALLBACK above. `record_qc_audit.sh`'s `gh pr view` call now captures both the exit code (`&& GH_RC=0 || GH_RC=$?`, the sanctioned `set -euo pipefail`-safe idiom already used elsewhere in this script) and stderr (redirected to a `mktemp` file, read back, then removed — kept out of stdout so it can't corrupt the `STATE:/ENDBODY` frame the awk parser consumes). Only "exit 0, empty stdout, no stderr" is now treated as "PR genuinely has no reviews yet" and falls through to file mode; a nonzero exit OR any stderr output (even alongside exit 0 — a warning-emitting `gh` is not a trustworthy empty result) refuses loudly with the same message shape as the missing-binary guard (names the PR, the exit code, captured stderr, and the review-file path it refuses to fall back to). Added 5 new scenarios (32-36) to `record_qc_audit_test.sh`: nonzero exit + stderr (rate-limited-style), nonzero exit silent, exit 0 + stderr warning + empty stdout, exit 0/empty/no-stderr regression pin (the one case that still legitimately falls back), and exit 0/non-empty-stdout happy-path-unchanged pin. Mutation-verified three ways, each reverted after: (1) reinstating the old `2>/dev/null || true` discard turns 32/33/34 red (51/54), 35/36 stay green; (2) checking stderr only (dropping the exit-code check) turns exactly 33 red (the silent-nonzero-exit case) — proves the exit-code check is load-bearing independently of stderr; (3) checking exit code only (dropping the stderr check) turns exactly 34 red (the exit-0-with-warning case) — proves the stderr check is load-bearing independently of exit code. Suite is 54/54 green with the fix applied. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (54 assertions across 36 scenarios); `dune runtest devtools/checks` (full suite, including `posix_sh_check.sh` and the `@fmt` rule, green). Merged as #2334 -> `3eaa8676` (structural APPROVED 5, behavioral APPROVED 4). One non-blocking residual filed below (H-AUDIT-GH-STDERR-GATE-TOO-BROAD).

- [x] H-AUDIT-GH-STDERR-GATE-TOO-BROAD: **Fixed 2026-08-15 (harness/audit-gh-stderr-gate).** Gated the stderr refusal arm on `[ -z "$BODIES" ]` (`if [ "$GH_RC" -ne 0 ] || { [ -n "$GH_STDERR" ] && [ -z "$BODIES" ]; }; then`), reworded the two refusal messages so the exit-0 arm no longer says the self-contradictory "failed (exit 0)" (now "returned no reviews and wrote to stderr (exit 0)"), and updated the explanatory comment. Added scenario 37 pinning the exit-0 + non-empty-stdout + stderr cell, paired with a companion `dev/reviews/` fixture holding a deliberately wrong verdict+score per the established convention. Scenario 37 initially failed even with the gate fix applied — a second, previously-unpinned bug: the unconditional "scan for overall_qc anywhere in the file" fallback (used to run whenever `$OVERALL` was empty, regardless of PR-mode vs file-mode) leaked the companion file's wrong `overall_qc` into an otherwise-correctly-resolved PR-mode record. Fixed by introducing a `FILE_MODE` flag set only in the true file-mode branch and gating that fallback scan on it. Mutation-verified: reverting only the one-line condition change (keeping scenario 37) reddens exactly scenario 37 (54/55); restoring it returns 55/55, all other scenarios unaffected. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (55 assertions across 37 scenarios); `dune runtest devtools/checks`. **Rework 2026-08-16 (qc-behavioral CP4):** the `FILE_MODE` comment claimed the `## Verdict` block parsers and the file-mode quality-score extractor were also file-mode-only, but only the `overall_qc` scan actually carried the guard — in PR mode with one review unresolved (e.g. behavioral not yet run), those three sites still read a same-feature-name `dev/reviews/` leftover and populated the unresolved field from it instead of the correct `SKIPPED`/`null` default. Closed by gating all three (`:382`, `:391`, `:442`) on `FILE_MODE`, adding `2>/dev/null` to the two awk calls so a missing/empty review file in PR mode is silent rather than leaking `awk: can't open file` to stderr. Added scenario 38 (PR mode, structural-only review, conflicting companion file) pinning `APPROVED`/`SKIPPED`/`APPROVED`/`null`. Mutation-verified: reverting the three guards reddens exactly scenario 38 (55/56); restoring returns 56/56. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (56 assertions across 38 scenarios). **Rework 2 (2026-08-16, qc-behavioral):** the `FILE_MODE` comment at `:335-347` claimed *every* `REVIEW_FILE`-reading fallback was FILE_MODE-gated; qc-behavioral found one exception (the SHA extractor at `:497-498`, see H-AUDIT-SHA-FILE-LEAK below) and asked for the comment to name the closed list of four gated sites rather than restate a now-falsified universal claim. Narrowed accordingly; no code path changed, no new scenario (residual is pre-existing and intentionally not fixed here).

- [x] H-AUDIT-SHA-FILE-LEAK: **Fixed 2026-08-16 (harness/audit-sha-file-leak).** Found by qc-behavioral while reviewing #2338's `FILE_MODE` comment, filed as a residual, then fixed as the cheapest open harness item. `record_qc_audit.sh`'s "Reviewed SHA" extractor (the `REVIEW_FILE` fallback inside the "Extract reviewed SHA" block — three successive line-number citations for this site, `:493-499` then `:497-498` then `:506-507`, were each invalidated by later edits to the surrounding comment shifting the line numbers below it; this entry and the in-file comment now name the block by its heading instead of a line number, per qc-behavioral's rework finding on #2359) fell back to `grep`-ing `$REVIEW_FILE` whenever `$BODIES` yielded no `Reviewed SHA:` line, **unconditionally** — including in PR mode, unlike the four sites the `FILE_MODE` guard already covered. Measured: PR-mode run with a structural-only review (no `Reviewed SHA:` line in `$BODIES`) plus a same-feature-name companion `dev/reviews/` file containing `Reviewed SHA: FOREIGNSHA99` recorded `sha: "FOREIGNSHA99"` in the audit JSON; the control (no companion file present) recorded `sha: ""`. Pre-existing on `main`, not introduced by #2338. Consequence: `write_audit.sh` uses `--sha` as the identity key for `consecutive_rework_count` (H-AUDIT-REWORK-COUNT-BLIND) — a leaked foreign SHA could mis-key that collision-detection logic, masking or fabricating a rework streak. Fixed by gating the extractor on `[ "$FILE_MODE" -eq 1 ]`, matching the idiom at the other four sites; the `FILE_MODE` comment block above `FILE_MODE=0` now documents a closed list of five gated sites (by name, not line number) instead of a four-site list plus a residual. Added scenario 39 (PR mode, structural-only review with no `Reviewed SHA:` line, conflicting companion file) pinning `sha: ""` instead of the foreign value. Mutation-verified: reverting only the one-line guard reddens exactly scenario 39 (56/57 → confirmed `sha: "FOREIGNSHA99"` leaked); restoring returns 57/57, all other scenarios unaffected. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (57 assertions across 39 scenarios).
- [ ] H-QC-SCORE-ADJECTIVE-LEXICON: Filed from PR #2135 rework (qc-behavioral N3, 2026-07-27), NOT built there — new scope. #2115's root cause was a digit/adjective mismatch (score 1 captioned "Excellent"); both agent definitions now state the polarity explicitly and instruct the agent to self-check the rationale's adjective against the digit before posting (H-QC-SCALE), but that check is still self-discipline with no mechanical backstop. Proposal: a warn-level (non-blocking) lexicon check in `record_qc_audit.sh` or a companion linter — a small table of positive adjectives ("excellent", "exemplary", "clean") vs negative ones ("significant", "fundamental", "wrong") cross-checked against the extracted digit, emitting a warning (not a hard fail, to avoid false positives on nuanced rationale text) when a low digit pairs with a positive-lexicon word or vice versa. Scope note: keep it warn-level and narrow — this is a secondary backstop for a rare, already-mitigated-by-instruction failure mode, not a primary gate.
- [x] H-FOLLOWUP-COUNT: `trading/devtools/checks/deep_scan/check_05_followup_items.sh` reported "76 open items" in its Warnings line while the same report's Trends section (Check 8) said "No open followup items in either scan" (`dev/health/2026-07-27-deep.md` lines 10 vs 303) — self-contradictory in one report. Three named defects: (1) it counted every `- ` line under a `## Follow-up*`/`## Followup*` heading, including `- [x]` closed items and plain prose bullets, mislabeling the total "open"; (2) its heading match was `## Follow-up*`/`## Followup*` only, so a `### Follow-up` (H3) heading was invisible; (3) Check 5 → Check 8's sidecar handoff computed the sidecar path from each check's own findings-file basename (`05.findings.followup` vs `08.findings.followup`) instead of a shared location, so Check 8 always read an empty file Check 5 never wrote to. **A fourth defect found during the fix, not in the original filing — this is the load-bearing finding:** the heading-scoping premise itself is broken, independent of (1)/(2). Measured on main at fix time: zero `- [ ]` items anywhere under any `Follow-?up` heading across all of `dev/status/*.md`, while 39 `- [ ]` items exist unscoped (harness.md 15, cleanup.md 8, tuning-methods.md 4, all-eligible.md 3, +9 more files). Open work in this repo does not reliably live under a "Follow-up" heading at all — `dev/status/harness.md`'s open `H-*` items sit under a dated `## Added <date> (orchestrator run N)` heading, and `dev/status/cleanup.md`'s sit under `## Backlog`. Widening the heading set (as originally proposed) only reproduces the same failure mode against the next new heading name. **Fix: dropped heading-scoping entirely.** The counter now counts every `- [ ]` (open checkbox only) across the ENTIRE body of each `dev/status/*.md` file, unscoped by heading — this cannot regress by "the next new heading" because there is no heading dependency left. Documented tradeoff: this also counts open Tier 1-4 roadmap checkboxes in harness.md, i.e. the metric is now "total open checkbox work across all status files" rather than "ad-hoc follow-up notes only"; if that changes the practical `dev/config/merge-policy.json` `followup_threshold` calculus that is a separate retune decision. Also fixed the Check 5 → Check 8 sidecar handoff: both now key the sidecar off `$(dirname <findings-or-report-file>)/followup_per_file.sidecar` (shared directory + fixed filename) instead of the findings-file's own basename, so Warnings and Trends can no longer read different data. Per-file breakdown is still exported via the sidecar and printed in both the Warnings note and the Trends "Followup Count Detail" table, so a reader can see composition rather than trusting a bare integer. Pinned with a new change-detector test `trading/devtools/checks/deep_scan_followup_count_check.sh` (unlike the other `deep_scan_*_check.sh` structural smoke tests, this one actually invokes `check_05_followup_items.sh` + `check_08_trends.sh` against a synthetic fixture tree via the `REPO_ROOT` env-var override, with a known-correct answer) — confirmed RED under all three reintroduced defects (dropped `- [ ]` filter, reintroduced heading scoping, reverted sidecar path) and GREEN with the fix; wired into `dune runtest` via `trading/devtools/checks/dune`. Escalation: `.claude/agents/lead-orchestrator.md` Step 2b's prose ("Count total open items across all `## Followup / Known Improvements` sections") is now stale relative to this fix and should be updated by someone with write access to that file — this session's edit tool declined to touch it as a "sensitive file"; the corrected wording is drafted in this PR's description for whoever picks it up. Verify: `sh trading/devtools/checks/deep_scan_followup_count_check.sh`; `dune runtest devtools/checks/`.
- [x] H-RUNENV-WORKTREE-BLIND: `dev/lib/run-in-env.sh`'s in-container (`TRADING_IN_CONTAINER`) path pinned `PROJECT_ROOT` to `${GITHUB_WORKSPACE}/trading` unconditionally, ignoring the invoker's cwd entirely — an agent working inside a git worktree who ran `dev/lib/run-in-env.sh dune runtest` therefore silently built+tested the **main checkout** and reported exit 0 for code it never compiled. Hit three independent times in the 2026-07-27 orchestrator run (qc-structural worked around it, the orchestrator confirmed it from source, code-health hit it again); PR #2139's body claimed "Full `dune build && dune runtest` green" while CI `build-and-test` was red on that exact SHA with 8 nesting-linter violations — this bug's signature. Note the pre-existing asymmetry that made this a clear bug: the `else` (devcontainer) branch and the local docker-exec path both already resolved relative to the invoking tree; only the GHA branch didn't. **Fix:** derive two independent candidates — `git rev-parse --show-toplevel` from cwd (+`/trading`), and the script's own on-disk location (the pre-existing, already-correct derivation) — prefer the cwd candidate when it names a valid dune workspace, fall back to `$GITHUB_WORKSPACE` only when cwd isn't inside any git tree, and **fail loudly (non-zero exit, both candidates named in stderr) when the two derivations disagree** rather than silently picking one (covers the nastiest case: an agent invoking the *main checkout's* copy of the script by absolute path while cwd sits in a worktree — script-location derivation alone would still silently yield main there). Added a `RUN_IN_ENV_PRINT_ROOT=1` test-only seam. Regression test: `trading/devtools/checks/run_in_env_root_check.sh` (wired into `dune runtest`), 5 assertions covering the worktree-vs-fake-`$GITHUB_WORKSPACE` bug case, the normal-GHA case, the devcontainer fallback, the disagreement case, and the pre-existing missing-dune-workspace failure — all verified to go RED against the pre-fix script (4 of 5 fail) and back to green after restoring the fix. Local docker-exec path and devcontainer fallback are unmodified/unregressed (confirmed by dedicated test cases 2 and 3). Verify: `dune runtest devtools/checks/` (or `sh trading/devtools/checks/run_in_env_root_check.sh` directly). Follow-up filed below (H-RUNENV-DUNE-PROJECT-WARNING) for the cosmetic `No dune-project file` warning noticed while diagnosing this; out of scope here (would require adding a `dune-project` file at the `trading/` workspace root, an unrelated build-config change).
- [ ] H-RUNENV-DUNE-PROJECT-WARNING: `dune build` / `dune runtest` invoked via `dev/lib/run-in-env.sh` in-container emits `Warning: No dune-project file has been found in directory "."` on every invocation. Cosmetic — `trading/` has a `dune-workspace` but no `dune-project`, and some dune subcommands probe upward for a `dune-project` marker and warn when absent even though the workspace resolves and builds correctly. Harmless today, but has repeatedly read as a path-resolution failure to agents diagnosing `run-in-env.sh` issues (2026-06-01, 2026-06-03, 2026-06-11, 2026-07-27 run 6). Fix direction: add a `dune-project` file at the `trading/` workspace root (needs verification it doesn't change build semantics for the existing `dune-workspace` setup) — left as a follow-up rather than folded into H-RUNENV-WORKTREE-BLIND per that item's PR scope. **Tried and bailed out 2026-08-18 (worktree `harness/dune-project-root`, not shipped).** Measured on a clean worktree at `7ce138b9`: baseline `dune build`/`dune runtest`/`dune build @fmt` all exit 0 with the warning present, 0 `^FAIL:` lines, `linter_file_length.sh` reporting `17 declared-large of 456 total` / `0 declared-large of 445 total`, `check_universe_deps_test: 19 passed`, `posix-sh linter -- 68 scripts clean`, `record_qc_audit_test: 59 passed`. Adding `trading/dune-project` with `(lang dune 3.17)` (matching both `dune-workspace`'s declared lang and every one of the 21 pre-existing nested `dune-project` files) does remove the warning and reproduces all of those same counts unchanged — **but it also silently converts every `trading/devtools/checks/*.sh` and `trading/devtools/{cc_linter,fn_length_linter,list_active_exceptions,magic_numbers_linter,nesting_linter}` runtest rule (45 rule invocations, confirmed reproducible across three clean rebuilds, reverting and re-adding the file each time) from running dune-sandboxed (`_build/.sandbox/<hash>/default/devtools/...`) to running unsandboxed directly in `_build/default/devtools/...`.** `trading/devtools/checks` has no `dune-project` in its ancestry today (nor would it after this fix — it would newly fall under the proposed root `trading/dune-project`), and it is the one directory in the tree whose own `dune` file explicitly documents reliance on this: "scripts must declare `_check_lib.sh` as a dep so dune sandboxes it, then finds it at the sandboxed location" (devtools/checks/dune:7-9), plus multiple comments distinguishing "the sandboxed location" from "the real working tree" as load-bearing for the `(universe)`-deps hermeticity guarantee that `H-CHECK-CACHE-BLIND`/`H-CHECK-EXEMPTION-DRIFT`/`H-CHECK-RUNTARGET-PATHQUAL` above spent multiple sessions building. Losing forced sandboxing doesn't change today's output (all counts identical, 0 FAIL both ways) but removes the mechanism that turns an undeclared-dependency bug in a check script into an immediate sandboxed-run failure — exactly the bug class those items exist to catch — so it is a real safety-net regression, not cosmetic, and outside this task's mandate to ship. (A `test_csv_snapshot_builder_cleanup.exe` SIGTERM-cleanup flake appeared in two of four total `dune runtest` runs during this investigation, with and without `dune-project` present, and did not appear in the other two; concurrent-load flake on the shared runner, unrelated to this change — noted so it isn't mistaken for a regression by the next attempt.) Root cause not fully diagnosed (dune version 3.24.2): most likely dune's sandboxing default for actions whose deps reference paths outside the rule's own directory (e.g. `%{workspace_root}/analysis/dune`, `../cc_linter/cc_linter.exe`) differs between the implicit/default project dune assumes when no `dune-project` is found and an explicit `(lang dune 3.17)` project — but this was not traced into dune's source, only observed and reproduced. **Next attempt should either:** (a) find a way to add `dune-project` while explicitly forcing `(sandbox always)` (or equivalent) on the affected `devtools/checks`/`devtools/*_linter` rules to preserve the hermeticity guarantee, or (b) scope the fix to something narrower than a workspace-root `dune-project` (e.g. confirm whether an empty `trading/devtools/dune-project` alone removes the warning without touching sandboxing elsewhere — not tested here). Do not re-attempt the bare workspace-root fix without addressing this.
- [ ] H-FOLLOWUP-THRESHOLD-RETUNE: Filed from PR #2140 rework (qc-behavioral N1, 2026-07-27) — the H-FOLLOWUP-COUNT fix itself flagged this as "a separate decision" but never filed it as a tracked item, which is exactly the deferral `.claude/rules/code-health-discipline.md` disallows. Measured composition at fix time: 41 total open `- [ ] ` items across `dev/status/*.md`, of which **~11 sit above `followup_threshold: 10` even with all genuine ad-hoc debt closed** — 10 T2/T3/T4 tier roadmap items in this file (T2-B, T2-C, T2-D, T3-C, T3-H, T4-A, T4-B, T4-C, T4-D, T4-E) plus 1 template placeholder line in `dev/status/cleanup.md` (`- [ ] <finding type>: <file path> — ...`). Ten of those eleven are items Step 2c explicitly declares undispatchable (long-horizon roadmap, not actionable now). So the threshold is crossed by construction, independent of actual open-debt volume. Two candidate resolutions, either is acceptable — pick one deliberately: (a) retune `followup_threshold` in `dev/config/merge-policy.json` upward to account for the non-actionable floor; or (b) exclude tier/roadmap-shaped checkboxes (and template placeholder lines) from the `check_05_followup_items.sh` count, e.g. by convention (a distinct marker) or a denylist. Out of scope for PR #2140 itself — filed only.
- [x] H-CHECK-CACHE-BLIND: The systemic version of PR #2143's qc-behavioral N1 finding. Audited all 25 `trading/devtools/checks/*.sh` scripts whose body contains an actual `repo_root()`/`_repo_root()` call site (2 already covered: `_check_lib.sh` defines the helper and is never a run-target; `run_in_env_root_check.sh` already had `(universe)` from #2143). Of the remaining 23: **20 fixed** by adding `(universe)` to their owning dune rule's deps (`agent_compliance_check.sh`, `agent_compliance_test.sh`, `jj_workspace_smoke.sh`, `status_file_integrity.sh`, `index_size_linter.sh`, `orchestrator_plan_check.sh`, all 6 `deep_scan_*_check.sh`, `consolidate_day_check.sh`, `rule_promotion_check.sh`, `budget_rollup_check.sh`, `posix_sh_check.sh`, `no_python_check.sh`, `extract_metrics_gate_smoke.sh`, `sweep_worktrees_smoke.sh`, `perf_catalog_check.sh`); **3 provably exempt** with evidence recorded in `trading/devtools/checks/universe_deps_exceptions.conf` + inline dune comments (`record_qc_audit.sh`, `write_audit.sh` — every one of the 24 invocations of either script inside `record_qc_audit_test.sh`'s dune rule is preceded by an explicit `REPO_ROOT="${TMP_REPO}"` override to a `mktemp -d` fixture, verified mechanically, not just by inspection, and their real production use by the orchestrator's Step 5 happens entirely outside `dune runtest` so no dune rule's cache staleness applies to it; `deep_scan_followup_count_check.sh` — its `repo_root()`-derived reads resolve to `deep_scan/check_05_followup_items.sh` + `deep_scan/check_08_trends.sh`, both already declared as explicit deps on the same rule, and the rule always invokes them against a synthetic `mktemp -d` fixture). Added a new mechanical guard `trading/devtools/checks/check_universe_deps.sh` (+ self-test `check_universe_deps_test.sh`, 5/5 assertions), wired into `dune runtest`, that FAILs on any script with a `repo_root()` call site whose owning rule lacks `(universe)` and isn't in the exceptions list — the guard's own rule declares `(universe)` for itself. Verified the fix is real, not decorative, via a warm-`_build` re-run test: with `no_python_check.sh`'s rule temporarily reverted to no `(universe)`, added a throwaway `.py` file outside the dune workspace (no declared dep touched) — the rule was **silently skipped** (no invocation line at all, stale cached PASS), reproducing the exact #2143 bug class live; with `(universe)` restored under the same warm `_build`, the rule **re-executed** and correctly caught the violation. **Verify:** `sh trading/devtools/checks/check_universe_deps_test.sh` (5/5 pass); `sh trading/devtools/checks/check_universe_deps.sh` (all 23 resolve OK/SKIP, exit 0); `dune build && dune runtest` green. **Residual:** if a future edit to `record_qc_audit_test.sh` ever invokes `record_qc_audit.sh`/`write_audit.sh` without the `REPO_ROOT` override, that exemption goes stale silently — dune has no way to detect this on its own; see new `H-CHECK-EXEMPTION-DRIFT` item below. (source: 2026-07-28 qc-behavioral N1 on PR #2143)
- [ ] H-CHECK-EXEMPTION-DRIFT: Filed as a residual from H-CHECK-CACHE-BLIND; **partially closed** by the #2148 FLAG-1 follow-up (harness/check-universe-deps-residuals). Two distinct sub-concerns, tracked together:
  - **(a) Evidence-correctness of existing entries — STILL OPEN.** `universe_deps_exceptions.conf` exempts `record_qc_audit.sh`/`write_audit.sh`, `deep_scan_followup_count_check.sh`, and (as of the FLAG-2 recursive-scan fix) `deep_scan/_lib.sh` + `deep_scan/main.sh` from the `check_universe_deps.sh` guard based on a point-in-time audit that every call site in their governing dune rule's test script uses a `REPO_ROOT`/fixture override (or, for `deep_scan/main.sh`, that it's never a dune run-target at all). `check_universe_deps.sh` cannot re-verify this claim mechanically (it can detect *that* a script calls `repo_root()`, not *whether* every call site is fixture-scoped) — a future edit to either governing test script that adds a real (non-overridden) `repo_root()` read would silently invalidate the exemption with no linter catching it. Low priority (these scripts change rarely), but worth a periodic manual re-audit or a stronger mechanical check (e.g. grep for `repo_root()`/`_repo_root()` call sites in the governing script that are NOT preceded by a `REPO_ROOT=` assignment within N lines) if this class of drift is ever observed in practice.
  - **(b) Unconstrained future additions — CLOSED.** The original filing didn't address a *new* entry being added with no expiry mechanism at all, ever. `universe_deps_exceptions.conf` now requires every entry to carry a `# review_at: <never|M1-M7|YYYY-MM-DD>` annotation (same convention as `linter_exceptions.conf`); `check_universe_deps.sh` itself hard-FAILs on an entry with a missing or unparseable `review_at` (per-PR enforcement — cheap, blocks the hole at the point a bad entry would be added), and the weekly `deep_scan/check_11_linter_expiry.sh` now also scans `universe_deps_exceptions.conf` for entries whose `review_at` has actually expired (mirroring its existing `linter_exceptions.conf` handling), emitting a new `## Universe-Deps Exception Expiry` report section. Split rationale: presence/parseability is a hot-path per-PR concern (must never regress); expiry-passed is a slower "should someone look at this" signal that matches the deep scan's existing weekly cadence. **Verify:** `sh trading/devtools/checks/check_universe_deps_test.sh` (7/7 assertions, incl. new #6 recursive-subdir-catch and #7 missing-review_at-rejected); `sh trading/devtools/checks/check_universe_deps.sh` (exit 0 on the real tree).
- [x] H-CHECK-SETE-DIAGNOSTICS: Audited all pre-existing `trading/devtools/checks/*.sh` scripts for the `set -e` + bare `VAR=$(cmd); CODE=$?` shape. **22 scripts genuinely match the audited shape** (`set -e` present AND a real, non-arithmetic `VAR=$(cmd)` assignment) — **3 defects + 19 already-safe**, itemized exhaustively below (count reconciled 2026-07-29 rework, N3: the first pass under-enumerated by 2, see "Explicitly excluded" for the two names that were never real candidates).
  - **3 genuine, previously-unaudited defects, found and fixed:**
    - `jj_workspace_smoke.sh:56` — `WS_LIST=$(jj -R "$REPO" workspace list 2>&1)` was a bare assignment; a real `jj workspace list` failure (lock contention, corrupt workspace, version skew) would die silently with zero output. Fixed with the `&& CODE=0 || CODE=$?` idiom + an explicit `FAIL: jj_workspace_smoke — 'jj workspace list' failed (exit N)` diagnostic.
    - `linter_file_length.sh` and `linter_magic_numbers.sh` — `wc -l < "$ml_file"` and `while ... done < "$f"` were bare reads of a file found by an earlier `find`. **Rework note (N1, 2026-07-29 qc-behavioral):** the first pass "fixed" both with a blanket `\|\| continue`, which cannot distinguish "file vanished mid-scan (TOCTOU race)" from "file exists but is unreadable" — collapsing a real violation on an unreadable file into a false green (reviewer-verified: a 350-line violating file made unreadable went from exit 2 pre-fix to `OK ... exit 0` post-"fix"). Re-fixed to discriminate the two cases explicitly: `[ -e ]` is checked both before the read attempt (vanished -> skip) and again only if the read itself fails (still exists -> hard FAIL naming the file via `VIOLATIONS`, never silently skipped). `linter_magic_numbers.sh` additionally probes readability with `cat` before its `while` loop, since a compound loop's own exit status is not a reliable failure signal. No change to the pass/fail verdict for any file that is both present and readable.
    - New regression test `sete_diagnostics_check.sh` (wired into `dune runtest`) now covers all three fixes: Parts 1-2 prove the `jj_workspace_smoke.sh` fix (negative control: literal pre-fix shape dies with zero diagnostic output; fix: current script emits a named `FAIL:` line); Parts 3-4 (added in rework, N2) prove the **false-green** scenario specifically for both linters using a directory named to look like a `lib/*.ml` file (a read failure that is deterministic regardless of process privilege — chmod-000 is not sufficient here since this check may run as root, and root bypasses DAC permission checks per `access(2)`): negative control shows the pre-fix `\|\| continue` shape gives `OK ... exit 0` on the unreadable-but-present fixture; the fix shows both linters `FAIL` and name the file. Part 5 pins the H-WRITE-AUDIT-SHEBANG-MISMATCH N4 bash-only decision. Mutation-verified: reverting the linter fixes turns 2 of 7 assertions red (confirmed live during rework, matching the reviewer's Mutation 2).
  - **19 already-safe** (each read individually; the reason that actually applies is named, not a blanket assumption): `check_universe_deps.sh`, `check_universe_deps_test.sh` — bracketed with explicit `set +e`/`set -e`. `extract_metrics_gate_smoke.sh` — same `set +e`/`set -e` bracketing inside its `exit_of()` helper. `no_python_check.sh`, `record_qc_audit.sh`, `sweep_worktrees_smoke.sh`, `write_audit.sh` — every risky capture already ends in `\|\| true`. `record_qc_audit_test.sh` — every capture already uses the `2>&1) && rc=0 \|\| rc=$?` idiom. `rule_promotion_self_test.sh` — `actual=0` reset immediately before each `cmd \|\| actual=$?`. `status_file_integrity.sh` — its `awk`/`grep|sed` helpers exit 0 even when the searched-for field is absent (the pipeline's last stage governs, not the search's own match/no-match). `index_size_linter.sh` — `[ -f ] \|\| die` guard up front, plus `wc|tr` pipelines whose last stage (`tr`) always exits 0. `linter_mli_coverage.sh` — only uses `[ -f ]` tests, never a bare read. `arch_layer_test.sh`, `rule_promotion_check.sh` — `printf|awk`/`printf|sed`/`basename` pipelines, all exit 0 regardless of match. `agent_compliance_check.sh` — `basename` on an already-`[ -f ]`-checked path. `agent_compliance_test.sh` — its one risky invocation sits inside an explicit `if`, exempt from `set -e`. `posix_sh_check.sh` — same, `if err=$(dash -n ...); then`. `testing_only_check.sh` — the capture is a `find | while ... done` whose exit status is governed by the last command in the loop body (an `awk` pipeline), not by `find` itself. `perf_catalog_check.sh:73` (`workflow_paths=$(grep -oE ... \| sort -u)`) — **added 2026-07-29 rework, N3**: genuine candidate (the assignment sits in an `if` BODY, not its condition, so it is NOT `set -e`-exempt by that rule), safe only because the pipeline's exit status comes from the last stage (`sort -u`), which exits 0 even when `grep` finds nothing.
  - **Explicitly excluded (not real candidates, noted so a future re-audit doesn't re-flag them):** `deep_scan_followup_count_check.sh` — its only `$((...))` occurrences (`FAIL_COUNT + 1`, `i + 1`) are arithmetic expansion, not command substitution; a false positive in the first pass's coarse detection regex. `run_in_env_root_check.sh` — already fixed prior to this PR (PR #2143's rework); it is the reference pattern this whole audit generalizes from, not a newly-classified script.
  - **Verify:** `sh trading/devtools/checks/sete_diagnostics_check.sh` (7/7 assertions); `dune build && dune runtest devtools` green. (source: 2026-07-29 harness session, run 30458563291; original finding 2026-07-28 qc-behavioral on PR #2143; rework 2026-07-29 qc-behavioral NEEDS_REWORK on PR #2163, findings N1-N4)
- [x] H-CHECK-RUNTARGET-PATHQUAL: **Fixed 2026-08-14 (harness/runtarget-pathqual).** The run-target character class in `trading/devtools/checks/check_universe_deps.sh` is now `%\{dep:[A-Za-z0-9_./-]+\}` (was `[A-Za-z0-9_.]`), so a path-qualified `(run sh %{dep:subdir/foo_check.sh})` resolves via the run-target branch to its own rule. **The filed item understated the severity** (its closing claim — "the failure mode is a confusing FAIL message, not a false green" — is wrong, and the new fixtures demonstrate why): when the run-target is invisible the script falls through to the dep-list branch and inherits the `(universe)` status of whichever *other* rule happens to list it as a plain dep. That misattributes in **both** directions — a false FAIL when the run-target's own rule is clean, and a **false OK** when the run-target's own rule is the cache-blind one. The false-OK direction is the dangerous one. **Reachability — measured, and corrected per qc-behavioral CP2 on PR #2322 (an earlier draft of this entry claimed the false OK was "one path-qualified rule away, in the shape the real dune already uses"; that was overstated).** Scan of `trading/devtools/checks/dune`: **42 rules, 37 run-targets, 0 path-qualified `%{dep:...}` anywhere, 0 scripts dep-listed by a rule earlier in file order than their own run-target rule.** For the pair the earlier draft named, *both* rules already declare `(universe)` — own rule `dune:623-627`, dep-listing rule `dune:640-644` — so path-qualifying that run-target today would change nothing: the fallback lands on a rule whose answer is also `OK`, which is the *correct* answer. **The false OK is at minimum two independent changes away**, the second being the own rule losing `(universe)` — which is itself the cache-blindness this guard exists to catch. Only the *noisy* direction is one change away: three pairs do carry divergent `(universe)` (`rule_promotion_check.sh`, `posix_sh_check.sh`, `tracked_artifact_linter.sh` — own rule has it, dep-listing rule lacks it), so path-qualifying one of those under the old class would have produced a **visible false FAIL**, never a silent pass. Fixed pre-emptively, not reactively: the candidate scan is now recursive and therefore *emits* path-qualified names, so the first such rule anyone writes would arm the misattribution. **Pinned by 4 new fixtures** in `check_universe_deps_test.sh` (10 assertions -> 14): #11 run-target rule declares `(universe)` while an earlier dep-listing rule does not -> must PASS, attributed to `(run-target)`; #12 the mirror image (run-target rule lacks it, dep-listing rule has it) -> must FAIL; #13 a path-qualified run-target mentioned only inside a `;` dune comment must still be reported "not referenced by any runtest rule" — this pins **record classification** (the `/^\(rule/` paragraph guard), **not** the character class: its fixture record starts with `;` and is discarded before the run-target regex is ever consulted, so it stays green under the narrow, the widened, *and* an unbounded `[^}]` class alike; H-CHECK-DUNE-COMMENT-GLUED-RULE is the invariant it actually guards; #14 the genuine **over-match** pin — a `%{dep:$LEGACY_DIR/old check.sh}` blob (a `$` and a space, i.e. not a script name) sitting in *live* rule text, an `(echo ...)` argument that `strip_comments()` cannot remove, placed earlier in the record than the real run-target, must be **skipped** by the class; awk `match()` returns the first hit, so a wider class hijacks attribution and the real script falls through to the dep-list branch. **Measured red-before / green-after** (the real tree cannot show this — the item was right that it is inert there), all three class states against the same 14-assertion suite: pre-fix narrow `[A-Za-z0-9_.]` -> **11 passed, 3 failed** (#11 a false FAIL misattributed to `runtarget_wrapper_test.sh`'s rule; #12 a false GREEN — `exit 0`, printing `OK: subdir/runtarget_check.sh -- owning rule (dep of rule with run-target runtarget_wrapper_test.sh) declares (universe)` for a run-target rule declaring no `(universe)`; #14 no `/`); shipped `[A-Za-z0-9_./-]` -> **14 passed, 0 failed**; unbounded `[^}]` -> **13 passed, 1 failed** with **#14 the sole failure**, confirming it is the only assertion in the suite that constrains the class from above. Real-tree `check_universe_deps.sh` output is **byte-identical** before and after (32 lines, `diff` clean, exit 0), confirming inertness on current `main`. The sibling dep-list class at the `depsonly` gsub was deliberately **not** widened: doing so would also drop a path-qualified `%{dep:...}` written in a *deps* position, which the run-target branch never matches by construction, leaving that script resolvable to no rule at all — a comment now records the asymmetry. One residual, filed not fixed: `strip_comments()` strips only *whole-line* `;` comments, so a `%{dep:...}` inside a **trailing** same-line comment survives into the scanned block and can hijack a run-target — pre-existing for plain names, extended to path-qualified names by this widening, inert in the real tree (no trailing-comment `%{dep:` exists in it). Folded into H-CHECK-DUNE-COMMENT-GLUED-RULE below, which shares the root cause. **Verify:** `sh trading/devtools/checks/check_universe_deps_test.sh` (14 assertions). (source: 2026-07-28 qc-structural residual on PR #2155; built 2026-08-14, run 31781463085; claims corrected 2026-08-14 per qc-behavioral review 4935551683 on PR #2322)
- [x] H-CHECK-DUNE-COMMENT-GLUED-RULE: **Fixed 2026-08-14 (harness/dune-comment-glued-rule).** Both shapes fixed together in `trading/devtools/checks/check_universe_deps.sh`. **Shape 1 (leading glued comment hides a whole rule):** added `strip_leading_comments()`, applied to each paragraph-mode record BEFORE the `/^\(rule/` classification test (was applied nowhere; classification ran on raw `$0`). A record that is entirely comment lines (a genuinely commented-out rule, e.g. assertion 13's fixture) still reduces to the empty string and correctly fails classification — only a *glued* leading comment above a *live* rule is affected. **Shape 2 (trailing same-line comment can hijack run-target resolution):** `strip_comments()` gained a second, QUOTE-AWARE pass (`strip_trailing_comment_line()`, applied per physical line) after the existing whole-line pass, so a `;` surviving the first pass is only treated as a trailing-comment leader when it falls OUTSIDE a double-quoted dune string on its own line; a `;` inside a `"..."` string (dune permits this as literal string content, e.g. `(setenv MSG "step one; step two" ...)`) is preserved. Verified with mutation testing (each shape reverted independently while the other fix stayed active): shape-1-only-reverted → `subdir/glued_check.sh` reports `FAIL: ... not referenced by any runtest rule` (shape-2 fixture `trailing_comment_check.sh` still resolves `OK`); shape-2-only-reverted → `trailing_comment_check.sh` reports the same FAIL (shape-1 fixture still resolves `OK`); both-reverted → both FAIL. With the fix, both resolve `OK: <script> -- owning rule (run-target)`. New fixtures + assertions 15 (shape 1) and 16 (shape 2) added to `check_universe_deps_test.sh`; assertion 14's live-text over-match fixture (added by PR #2322) still discriminates unchanged, confirmed by rerunning the full suite. Corrected the stale "assertions 11-13" cross-reference in `check_universe_deps.sh` (H-CHECK-RUNTARGET-PATHQUAL note) to "11-14" to match the actual fixture count for that note (assertions 15-16 are a different bug and are cited separately). **Rework 2026-08-14 (rework iteration 1, qc-behavioral review 4937596567):** the FIRST version of the shape-2 fix used an unconditional `gsub(/;[^\n]*/, "", b)` second pass, which the reviewer proved unsafe — dune accepts a literal `;` inside a quoted string (measured via a throwaway `dune build @sub/runtest`), so the unconditional strip both destroyed live rule text (false FAIL) and, worse, silently misattributed a script whose OWN run-target rule genuinely lacked `(universe)` to a different, `(universe)`-declaring rule (a false OK — the exact "worse" direction this guard's own docstring at `check_universe_deps.sh:255-257` names). Unreachable on the real tree (no `;` in live dune text repo-wide) but the code and this entry both stated the opposite of the truth. Fixed by making the second pass quote-aware (see above) rather than retracting the claim, per the reviewer's "option 1 is strictly better" guidance. Two new fixtures pin the exact reviewer-measured shapes: assertion 17 (a quoted `;` on the run-target's own line must not truncate it — the false-FAIL direction) and assertion 18 (same shape, but the run-target's own rule genuinely lacks `(universe)` and a later dep-listing rule has it — the dangerous false-OK direction must still FAIL, attributed to the run-target). Also corrected `strip_leading_comments()`'s docstring: an all-comment record does not reduce to the empty string as previously claimed — awk paragraph mode strips the record's trailing newline, so it reduces to its FINAL comment line, which still starts with `;` and still fails the `/^\(rule/` classification test (same observable outcome, different mechanism; no code change, doc-only). Verify: `./dev/lib/run-in-env.sh dune runtest devtools/checks/ --force` → `check_universe_deps_test: 18 passed, 0 failed`. `harness_gap: LINTER_CANDIDATE` (resolved by this fix). (source: 2026-08-14 harness session, GHA run 31800659453; original filing from run 31781463085; rework per qc-behavioral review 4937596567 on PR #2327)
  - *Original filing text (2026-07-28, retained for provenance; its final sentence is superseded — see the false-OK finding above):* Now that `check_universe_deps.sh`'s candidate scan is recursive (FLAG-2 fix), candidate names below the top level come back **path-qualified** (`deep_scan/_lib.sh`). The awk dep-list matching and the exceptions-list lookup both handle `/` correctly — verified live, both new candidates resolve. But the **run-target** regex still reads `\(run[ \t\n]+(sh|bash)[ \t\n]+%\{dep:[A-Za-z0-9_.]+\}\)`, whose character class excludes `/`. So a future dune rule written as `(run sh %{dep:deep_scan/foo_check.sh})` would not match the run-target branch; the script would fall through to the dep-list branch (which does match `/`) or, failing that, be reported as "not referenced by any runtest rule". **Inert today** — no current rule uses a path-qualified `%{dep:...}` run-target; every subdirectory script is referenced as a plain dep or not at all. Fix is a one-character class edit (`[A-Za-z0-9_./-]`). Worth doing when the file is next touched rather than on its own; the failure mode is a confusing FAIL message, not a false green. (source: 2026-07-28 qc-structural residual on PR #2155)
- [x] H-AUDIT-MODE-0600: **Regression introduced by #2169 (H-AUDIT-ATOMIC-WRITE); fixed 2026-08-04 (harness/audit-mode-0644).** `trading/devtools/checks/write_audit.sh` had been writing audit records with mode `0600` where every record before #2169 was `0644` — `mktemp` creates its file `0600` by design (ignoring umask, a deliberate security property of mktemp), and `mv -f` preserves the source file's mode, so the atomic-write rename silently downgraded every record's permissions with no `chmod` in between. Functionally inert on its own (both consumers run as the same user that wrote the record), but composed with H-PREV-VERDICT-PIPEFAIL's "unreadable prior record" hardening to form a latent risk if the writing/reading identities ever diverged (CI artifact upload, a differently-configured container user). **Fix:** added `chmod 644 "$TMP_FILE"` in `write_audit.sh` right before the `mv -f "$TMP_FILE" "$OUTPUT_FILE"` rename — chmod'd on the temp file rather than the output file, so the record has its final correct mode from the instant it becomes visible at `$OUTPUT_FILE`, with no window where a reader could observe 0600. **Regression pin:** added scenario 23 to `record_qc_audit_test.sh`, forcing `umask 077` for the call (so a pass can't be a coincidence of the ambient umask) and asserting the resulting record is mode `644` via a portable `stat -c '%a' || stat -f '%Lp'` helper. **Mutation-tested:** reverting only the `chmod` line drops the suite from 25/25 to 24 passed / 1 failed, and the single failure is exactly scenario 23 (reported mode 600, expected 644); restoring the line returns to 25/25 with nothing else affected. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (now 25 assertions across 23 scenarios, was 24 assertions across 22 scenarios before this change; count corrected 2026-08-04 by the orchestrator per qc-behavioral finding F2 on #2199 -- the entry originally read "was ~59 assertions across 22 scenarios", which measured at `206cea4b` as 24 and, as written, implied a coverage regression). (source: found 2026-08-03 run 2 orchestrator verification; fixed 2026-08-04 harness-maintainer dispatch)
- [x] H-AUDIT-MODE-ORDER-UNPINNED: Filed by qc-behavioral on PR #2199 (2026-08-04) as an explicit non-blocking follow-up. The `chmod 644 "$TMP_FILE"` added by H-AUDIT-MODE-0600 carries a documented rationale for its *placement*: it targets the temp file **before** the `mv -f` rather than `$OUTPUT_FILE` after it, so the record has its final mode from the instant it becomes visible, with no window in which a concurrent reader could `open()` it at 0600. That placement claim was unpinned -- moving the chmod to after the `mv` left the suite green, since no existing scenario observed file state at the instant of first visibility (scenario 23 only checks the mode after the script finishes normally, which the end state reaches either way). **First pass (rework iteration 0) added a behavioral-only pin that was itself incomplete**, caught by qc-behavioral finding B1 on the rework review: a `WRITE_AUDIT_TEST_ABORT_AFTER_RENAME` hook placed as the literal next statement after `mv` is structurally blind to any mutation that inserts its own statement (e.g. a relocated `chmod` targeting `$OUTPUT_FILE`) *between* the `mv` and the hook -- the mutation runs and completes before the hook ever fires, so mutation M2b (chmod moved to directly below `mv`, the single most natural refactor shape) reproduced 26/26 green, zero signal, despite M2 (chmod moved below the whole hook comment block) correctly going red. No hook placed after the rename can close this gap; the information about statement order is gone by the time any runtime hook runs. **Fix (rework iteration 1):** kept the behavioral hook/scenario as Part A (still useful as a happy-path smoke check) and added Part B -- a static source-order check, read directly from `${WRITE_AUDIT}` with whole-line comments blanked out first (so a docstring merely describing the bad pattern can never be mistaken for the executable statement): (B1) the line number of `chmod 644 "$TMP_FILE"` must be strictly less than the line number of `mv -f "$TMP_FILE" "$OUTPUT_FILE"`, and (B2) the script must contain **zero** occurrences of any `chmod` targeting `$OUTPUT_FILE`, at any line, in any position relative to the rename. B2 is what actually closes the gap -- it is a source-level invariant independent of exactly where after the rename a mutated chmod is placed, so it catches M2 and M2b identically (both retarget to `$OUTPUT_FILE`) as well as M1 (chmod deleted, B1 finds no match). Also fixed a real bug surfaced while building this: the `grep -n ... | head -1 | cut -d: -f1` extraction pipelines were unguarded, and under this test script's own `set -euo pipefail`, a genuinely-absent pattern (M1) made `grep` exit 1, which propagated through the pipeline and silently killed the whole test run before it could report scenario 24 as a clean FAIL -- fixed by appending `|| true` to each extraction, mirroring the established guard pattern already used in `write_audit.sh` itself for the same reason. **Assertion/scenario counts:** before this rework (iteration 0's pin), 26 assertions across 24 scenarios; **after this rework, still 26 assertions across 24 scenarios** (scenario 24 gained a second, more thorough condition rather than becoming a new scenario). **Mutation-tested live, all three, each reverted before the next:** M1 (chmod deleted entirely) -- **24 passed, 2 failed** (scenarios 23 and 24, since full deletion also regresses H-AUDIT-MODE-0600's own pin). M2 (chmod relocated below the ~14-line hook comment block, retargeted to `$OUTPUT_FILE`) -- **25 passed, 1 failed**, sole failure scenario 24. **M2b (chmod relocated to the line directly below `mv -f "$TMP_FILE" "$OUTPUT_FILE"`, retargeted to `$OUTPUT_FILE`)** -- **25 passed, 1 failed**, sole failure scenario 24 (Part A's own behavioral assertion still read mode 644 here, confirming Part A alone would have missed it -- it was Part B's `output_chmod_count=1` that caught it). Reverting each mutation returned the suite to **26 passed, 0 failed** every time, confirmed live after each. **Judgement call on the interaction with H-AUDIT-CHMOD-FAIL-CLOSED** (a separate open item, not touched here): that item observes that under `set -euo pipefail` a failing `chmod` aborts before the `mv`, so no record is written at all on a chmod failure. Neither this fix nor the Part B static check changes that trade-off in any way -- Part B only reads the source text, and Part A's hook only observes state after a successful `mv`; neither interacts with the pre-mv `chmod` failure path. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (26 assertions across 24 scenarios); `dune runtest devtools/checks`. (source: 2026-08-04 run 1 qc-behavioral on PR #2199; built 2026-08-05, harness/audit-mode-order-pin; rework 2026-08-05 qc-behavioral B1 on PR #2211)

- [x] H-AUDIT-HOOK-GATE-TRUTHY: Filed by qc-behavioral on PR #2211 (2026-08-05, finding F1) as an explicit non-blocking follow-up; **pre-existing, not introduced by #2211**. Both `write_audit.sh` test hooks gate on `[ -n "${VAR:-}" ]`, so `VAR=0` and `VAR=false` **fire** the hook rather than disabling it. Verified live in both directions: `WRITE_AUDIT_TEST_ABORT_AFTER_RENAME=0` -> `rc=1`; `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=0` -> `rc=1`. The two hooks are symmetric, so #2211 introduced no new asymmetry -- but their **blast radii differ**, which is why this is worth recording rather than shrugging at: `BEFORE_RENAME` aborts before publishing (safe -- the prior record stays intact and no record is written), whereas `AFTER_RENAME` aborts **after** publishing, yielding `rc=1` with the record already on disk and no `OK:` line, so a caller under `set -e` would treat the audit as failed while the record actually exists. Cheap fix for both: `[ "${VAR:-0}" = "1" ]`. `harness_gap: LINTER_CANDIDATE`. (source: 2026-08-05 qc-behavioral on PR #2211, F1) **Fixed** in `trading/devtools/checks/write_audit.sh` (lines 455 / 507): both gates are now `[ "${VAR:-0}" = "1" ]`. **Contract decision (deliberate, not just the proposed one-liner): only the literal string `1` enables a hook; every other value -- `0`, `false`, `no`, `true`, `yes`, empty, unset -- disables it.** Rejected the wider `1|true|yes` spelling on asymmetric-cost grounds: the two failure modes are not equally bad. A guessed-wrong *enable* spelling (`VAR=true` fails to fire) is loud and self-correcting -- the scenario asserting the abort immediately goes red, which is precisely what scenarios 25b/26b now assert. A guessed-wrong *disable* spelling (`VAR=0` fires) is silent and, for the AFTER_RENAME hook, actively misleading: rc=1 with the record already published, so a caller under `set -e` treats the audit as failed while it in fact succeeded. Whitelisting one literal makes every misspelling fail toward the safe side; accepting synonyms widens the accidental-fire surface for zero real benefit, since the only in-repo caller is `record_qc_audit_test.sh`, which sets `=1`. Both hook sites now carry an `ACCEPTED SPELLING:` block naming the exact accepted value and the rationale, so the next person to set the variable does not have to guess or read this file. **Regression coverage** (`record_qc_audit_test.sh`, +2 scenarios / +4 assertions; **26 assertions across 24 scenarios -> 30 across 26**): scenario 25 (BEFORE_RENAME) and 26 (AFTER_RENAME), each asserting BOTH directions. (a) `VAR=0` and `VAR=false` must leave the hook inert -- 25a checks the record gets published at all (a spurious fire aborts pre-`mv`, so nothing lands), 26a checks rc=0 + the `OK:` line (this hook aborts post-`mv`, so the record is on disk either way and only the exit code distinguishes inert from fired). (b) `VAR=1` must still abort. The (b) half is not ceremonial: a one-sided test asserting only "0 does not fire" is fully satisfied by a hook that can never fire at all, which would silently disable the atomicity (scenario 19) and mode-order (scenario 24) pins those hooks exist to serve -- strictly worse than the bug being fixed. **Mutation-tested live, three mutations, each restored before the next: MG1** (BEFORE_RENAME gate reverted to `[ -n ... ]`) -- 28 passed, **2 failed**: 25a (`expected rc=0 + record + 'OK: wrote' for both =0 and =false; got rc(0)=1 record=no, rc(false)=1 record=no`) and 25b (`prior_record_present=no`). **MG2** (AFTER_RENAME reverted to `[ -n ... ]`) -- 29 passed, **1 failed**: 26a (`expected rc=0 + 'OK: wrote' for both =0 and =false; got rc(0)=1, rc(false)=1, record_present=yes` -- note `record_present=yes`, the exact blast-radius asymmetry this item describes). **MG3** (anti-over-correction: both gates changed to compare against a string that can never match, i.e. hooks permanently dead) -- 26 passed, **4 failed**: 25b, 26b, **and** 19 + 24, confirming the collateral damage a one-sided fix would have caused is real and now detected. Restoring after each returned 30 passed / 0 failed. **Test-harness bug found and fixed while mutation-testing** (same class as scenario 24's `|| true` lesson): 25b's `CONTENT_25_BEFORE="$(cat "${JSON25}")"` was unguarded, so under MG1 -- where no record exists -- the bare `cat` exited 1 and `set -euo pipefail` killed the entire run after a single FAIL line with no summary, hiding scenario 26 completely. Guarded with `2>/dev/null || echo MISSING`, plus a `[[ != "MISSING" ]]` precondition on 25b so the byte-identical comparison cannot pass vacuously against a nonexistent file. **No behaviour change to the records themselves** -- mode still 0644, still atomic, still chmod-before-`mv`; scenario 24's static order check passes unchanged. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (30 assertions across 26 scenarios); `dev/lib/run-in-env.sh dune runtest devtools/checks/ --force` (the `--force` matters: a full-repo `dune runtest` serves this rule from cache). **Rework iteration 1 (qc-behavioral F1 on PR #2221, blocking):** the first pass documented a contract quantified over seven values ("only the literal `1` enables; `0`, `false`, `no`, `true`, `yes`, empty, unset all disable") but pinned exactly two of them, so the pin was itself incomplete -- structurally the same defect #2211 was reworked for. Two widening mutations passed the two-value pin **30/30 green, exit 0**: **MW1** (gates widened to accept `1|true|yes` -- i.e. precisely the contract this item argues against) and, worse, **MW5** (gates changed to "fire on anything non-empty except `0`/`false`"), which **reinstates the original bug under a different spelling** -- `WRITE_AUDIT_TEST_ABORT_AFTER_RENAME=no` fires, publishing the record and returning rc=1, fully invisible to the suite. Fixed by hoisting a single shared `HOOK_DISABLE_VALUES=(0 false no yes true "")` array and looping 25a/26a over it, so both hooks are pinned against the identical set (two hand-maintained copies would be free to drift, and symmetry is the property being protected). **Judgement call 1 -- empty string in the loop: kept, with the accounting made explicit in the comment.** `VAR=""` and unset are distinct shell states; env-assigning `VAR=""` pins the EMPTY state only, while the UNSET state is already pinned by every non-hook scenario in the file (none of 1-24 sets either hook and all require normal completion; scenario 20 most directly). Between the two, the docstring's "empty, unset" pair is covered. The loop mechanics trap is real and guarded: the empty element survives only under a quoted `"${HOOK_DISABLE_VALUES[@]}"` expansion, so each loop carries an iteration counter asserted equal to `${#HOOK_DISABLE_VALUES[@]}` -- mutation **MT1** (expansion changed to unquoted, silently dropping the empty element) goes red with `exercised 5; offending values:none`, which is exactly the "the pin quietly shrank" signal a plain value-by-value check cannot produce. **Judgement call 2 -- grow the tests, do not shrink the docstring.** Shrinking would be right if some documented values were unpinnable or the claim speculative; neither holds, and every listed value earns its place in mutation-detection terms (`true`/`yes` kill MW1; `no`/`yes`/`true` kill MW5). The docstring was not over-promising -- the test set was under-delivering. **A sub-decision was made and then reversed on measurement:** two extra values (`TRUE`, `01`) were added to pin the word "literal" against a case-folding gate and an arithmetic `(( VAR == 1 ))` gate, on the hypothesis that no lowercase spelling would detect those. Measuring both mutations refuted it -- MW1-CI (case-insensitive `1|true|yes`) is caught by `true`/`yes` with `TRUE` adding nothing, and MW-ARITH is caught by `false`/`no`/`yes`/`true` alike (each is an unset name in bash arithmetic context, tripping `set -u`) with `01` adding nothing. Both were dropped rather than kept behind a rationale the data had refuted; the list is now exactly the documented spellings and no more, and the comment records the trial and its negative result so it is not re-attempted. **Post-rework mutation battery, each restored before the next: MW5** -- 28 passed, **2 failed**: 25a (`expected rc=0 + record + 'OK: wrote' for all 6 documented 'off' spellings; exercised 6; offending values: [no](rc=1,record=no) [yes](rc=1,record=no) [true](rc=1,record=no)`) and 26a (same three values, `record_present=yes` -- the published-record blast radius). **MW1** -- 28 passed, **2 failed**: 25a/26a via `[yes]`/`[true]`. **MG1+MG2** (both gates reverted to the original `[ -n ... ]`) -- 28 passed, **2 failed**: 25a/26a listing all five non-empty values. **MG3** (both hooks permanently dead) -- 26 passed, **4 failed**: 25b, 26b, 19, 24. **MT1** (test-side, empty element dropped) -- 28 passed, **2 failed**: 25a/26a with `exercised 5`. Restoring returned 30/0 each time. Assertion/scenario counts unchanged by the rework at **30 across 26** -- 25a/26a became stronger in place rather than multiplying into new scenarios. (built 2026-08-06, harness/audit-hook-gate-truthy; rework 2026-08-06 qc-behavioral F1 on PR #2221)
- [x] H-AUDIT-TEST-FAILS-OPEN-WORDING: Trivial doc defect, filed by qc-behavioral on PR #2211 (2026-08-05, finding F3). `trading/devtools/checks/record_qc_audit_test.sh:1119` reads "B1 alone already catches M1 (chmod deleted -- no match, order check **fails open**)". The check in fact fails **closed** (it goes red / rejects) -- the behaviour is correct and mutation-verified, only the phrase is inverted. Fold into whichever PR next touches the file. `harness_gap: NONE`. (source: 2026-08-05 qc-behavioral on PR #2211, F3) **Fixed**, folded into harness/audit-hook-gate-truthy alongside H-AUDIT-HOOK-GATE-TRUTHY as the item asked. **Finding independently confirmed before editing** (the instruction was to verify, not to comply): the phrase is wrapped across lines 1122-1123 in the shipped file (`fails` ending one comment line, `open)` starting the next), so a naive single-line grep for "fails open" returns nothing -- the finding is real, not stale. Traced what B1 actually does under mutation M1 (the `chmod 644 "$TMP_FILE"` line deleted): `grep` finds no match, the `|| true` guard degrades the extraction to the empty string, and the `[[ -n "${CHMOD_TMP_LINE_24}" ]]` guard in the `source_order_ok` condition then rejects -- `source_order_ok=0`, scenario 24 goes red. Reproduced by running the extraction pipeline against a chmod-deleted copy of `write_audit.sh`: `CHMOD_TMP_LINE=[] MV_LINE=[471] OUT_CNT=[0] -> source_order_ok=0 -> scenario 24 would FAIL`. That is fail-**closed** (the check rejects), so the comment was inverted, and it also contradicted its own containing sentence ("B1 alone already **catches** M1" is only coherent if the check rejects). Reworded to say fail CLOSED, naming the specific `[[ -n ... ]]` guard that does the rejecting and explicitly noting that the `|| true` only prevents an abort -- it does not let the check pass, which is the misreading that most plausibly produced the original inverted phrasing. Comment-only; no executable line touched. (built 2026-08-06, harness/audit-hook-gate-truthy)
- [x] H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED: Fixed 2026-08-18. The file had grown to 2729 lines by fix time; re-counting at that revision found **42** unguarded `find … | wc -l | tr -d ' '` sites (not the 20 recorded when this was filed — re-derived, not transcribed). All 42 replaced with calls to a new `_glob_count <dir> <pattern> [extra-find-predicate]` helper (`trading/devtools/checks/record_qc_audit_test.sh`, defined next to `pass`/`fail`) that captures the count before propagating `find`'s exit status, so a missing/deleted directory degrades to a correct `"0"` instead of aborting the suite under `set -euo pipefail`. Verified with a mutation (pointed one call site at a nonexistent directory): before the fix the suite died mid-run after scenario 7a with no summary line (raw `find … | wc -l`, exit 1); after the fix the same mutation yields a clean `58 passed, 1 failed` with a specific scenario-7b FAIL line (`audit_count=0`), completing orderly with a summary line rather than dying mid-run (the exit code is still 1, correctly, since a scenario failed — "orderly" describes reaching the summary line, not exit-0). Full-suite baseline unaffected: 59/0 before and after. `harness_gap: NONE`. (source: 2026-08-06 qc-behavioral on PR #2221, F2)
- [x] H-AUDIT-GLOB-COUNT-GUARD-UNPINNED: Fixed 2026-08-19. Added scenario 42 to `trading/devtools/checks/record_qc_audit_test.sh` — the pin the filing prescribed: it calls `_glob_count` **directly** (top-level, no `$( )` wrapper) against a nonexistent directory, via a fresh `bash` subprocess running a generated script file seeded with `declare -f _glob_count` (**corrected 2026-08-20, see H-AUDIT-SCENARIO42-DOC-CORRECTIONS below — this originally said "a fresh `bash -c` subprocess"; the code has always run `bash "${SCENARIO42_SCRIPT}"` against a script file, never `bash -c`**) (so the pin always tracks the function's *current* body, not a duplicated copy). This is the one call shape where `errexit` stays active in the caller's frame, so `|| true` is actually load-bearing there — unlike all 42 real call sites (`x="$(_glob_count …)"`), which run the body inside a command-substitution subshell where `errexit` is inactive regardless of the guard, per the diagnosis this entry originally recorded. **Mutation-tested against my own pin, not just declared correct:** baseline before adding scenario 42 was 59 passed/0 failed/exit 0 (confirmed M-A — stripping `2>/dev/null`/`|| true` from `_glob_count` — is invisible here too, reproducing the filed trap exactly). After adding scenario 42 with the guard intact: **60 passed, 0 failed, exit 0**. Reapplying mutation M-A on top of the new scenario: suite goes **RED — 59 passed, 1 failed, exit 1**, with `FAIL: scenario 42 — expected direct _glob_count call against a missing dir to print '0' and exit 0; got rc=1 output=find: '<tmp>/dev/audit/nonexistent-dir-42': No such file or directory`. Reverting M-A restores **60 passed, 0 failed, exit 0**. `harness_gap: NONE` (the pin now exists; LINTER_CANDIDATE from the filing is resolved by this scenario, not by a standalone linter — a shell linter can't distinguish "load-bearing guard" from "redundant guard" without knowing the call-site shape). (source: 2026-08-18 qc-behavioral R1 on PR #2372; fixed on `harness/glob-count-guard-pin`)
- [x] H-AUDIT-GLOB-COUNT-DOC-PRECISION: Fixed 2026-08-19, alongside the entry above. (a) Reworded the `_glob_count` docstring in `trading/devtools/checks/record_qc_audit_test.sh` to state plainly that at the 42 real call sites the abort-prevention comes from the command-substitution subshell (`errexit` inactive, `inherit_errexit` off) rather than from `|| true`, and points at scenario 42 as the one call shape where `|| true` is actually load-bearing. (b) Reworded the completion note on `H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED` above: it now says the post-fix mutation "complet[es] orderly with a summary line rather than dying mid-run" and explicitly notes the exit code is still 1 (a real scenario failure), instead of the previous "a normal exit" phrasing that read as exit-0. `harness_gap: NONE`. (source: 2026-08-18 qc-behavioral R2/R3 on PR #2372; fixed on `harness/glob-count-guard-pin`)

- [x] H-AUDIT-SCENARIO42-DECLARE-F-UNGUARDED: **Residual from the PR #2390 qc-behavioral six-mutation battery on the two entries above, never filed as a tracked item — closed retroactively 2026-08-20 per `.claude/rules/code-health-discipline.md` (a residual mentioned only in a daily summary / review body is undelivered follow-up, not deferral).** Scenario 42's own construction, `GLOB_COUNT_DEF="$(declare -f _glob_count)"` (`record_qc_audit_test.sh:2786` at #2390's tip), ran under this suite's own `set -euo pipefail` unguarded. If `_glob_count` were ever renamed or removed, `declare -f` exits non-zero, the assignment's command substitution propagates that exit status, and the entire suite dies right there with **no summary line** — the identical failure class this file has already been patched for twice (H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED; the scenario-25b `cat` guard under H-AUDIT-HOOK-GATE-TRUTHY) — reintroduced one line inside the very scenario meant to prevent this class of bug. **Fix:** guarded the read the same way as scenario 25b, `GLOB_COUNT_DEF="$(declare -f _glob_count 2>/dev/null || echo MISSING)"`, plus an explicit `[[ "${GLOB_COUNT_DEF}" == "MISSING" ]]` precondition that fails scenario 42 with a specific message instead of letting the suite abort. **Mutation-tested live:** pointed the read at a nonexistent function name (`_glob_count_renamed_away`) to simulate the rename/removal case without disturbing the other 41 real call sites (which call `_glob_count` directly and would break earlier in the file under a real rename, obscuring this specific failure mode). Before the fix: **rc=1** (`declare -f` on a nonexistent function returns 1; the standalone assignment propagates it under `errexit` — re-verified 2026-08-20 against `origin/main`, correcting an earlier `rc=127` transcription that was not reproducible), **suite dies after scenario 41 with no `record_qc_audit_test: N passed, M failed` line at all.** After the fix: **rc=1, 59 passed, 1 failed**, with `FAIL: scenario 42 — precondition failed: _glob_count is not defined (renamed or removed?); cannot construct the direct-invocation pin` and the summary line present. Reverted; baseline restored to **60 passed, 0 failed, rc=0**. `harness_gap: NONE`. (source: 2026-08-19 qc-behavioral six-mutation battery on PR #2390, unfiled residual; fixed 2026-08-20 on `harness/scenario42-residuals`; corrected 2026-08-20 rework per qc-behavioral CP2 finding)

- [x] H-AUDIT-SCENARIO42-VACUOUS-PASS: **Residual from the same PR #2390 battery, same filing gap as above.** Scenario 42's entire discriminating power rests on `SCENARIO42_MISSING_DIR` (`${TMP_REPO}/dev/audit/nonexistent-dir-42`) genuinely not existing, but the scenario never asserted that — it was positional only (a fresh `mktemp -d` `TMP_REPO` never happens to contain it), not a checked invariant. The qc-behavioral reviewer measured the consequence directly: with mutation M-A applied (the `2>/dev/null` + `|| true` guard stripped from `_glob_count`'s body) **and** that directory pre-created before the probe runs, the suite returned **60 passed, 0 failed, exit 0** — the guard fully stripped, and the pin built specifically to catch that stripping passed anyway. Not a live defect (`TMP_REPO` is a fresh `mktemp -d`, so the directory is genuinely absent today), but the guarantee was positional rather than asserted in a scenario whose entire purpose was fixing a pin that didn't pin what it claimed. **Fix:** added an explicit `elif [[ -e "${SCENARIO42_MISSING_DIR}" ]]` precondition (alongside the declare-f guard above, same if/elif/else block) that fails scenario 42 with a distinct message if the directory is ever found to exist, before the probe runs. **Mutation-tested live, both directions:** (1) M-A + directory pre-created (the exact vacuous-pass repro) — before the fix: 60 passed, 0 failed, exit 0 (confirmed vacuous). After the fix: **59 passed, 1 failed, exit 1**, `FAIL: scenario 42 — precondition failed: <tmp>/dev/audit/nonexistent-dir-42 unexpectedly exists; the pin requires a genuinely missing directory to exercise the guard`. (2) M-A alone, directory absent (confirms the fix didn't weaken the original pin) — both before and after the fix: **59 passed, 1 failed, exit 1** via the original scenario-42 assertion (`find: '<tmp>/…/nonexistent-dir-42': No such file or directory`). Reverted both; baseline restored to **60 passed, 0 failed, rc=0** each time. `harness_gap: NONE`. **Correction 2026-08-20 (rework iteration 1 of #2424, qc-behavioral CP4a finding):** the guarantee stated above as "assert it" only covered `-e`-visible existence — `[[ -e ]]` dereferences symlinks, so a **dangling symlink** at `SCENARIO42_MISSING_DIR` satisfied `! -e` while `find` on it still exits 0 with no stderr, leaving a narrowed vacuity route (measured: M-A + dangling symlink → 60 passed, 0 failed, rc=0 on the shipped tip). Widened the precondition to `-e "${SCENARIO42_MISSING_DIR}" || -L "${SCENARIO42_MISSING_DIR}"`, which covers exactly the states in which `find` exits 0 (any real path, or a symlink whether or not its target resolves); `-d` alone would leave a *different* route open since a regular file also satisfies `find -maxdepth 1 -name ...` exiting 0, so plain existence (not directory-ness) is the correct predicate. Mutation-tested: M-A + dangling symlink before → 60/0/rc=0; after → 59/1/rc=1. M-A + real directory and M-A + regular file both still 59/1/rc=1 (fix doesn't regress the existing checks). `harness_gap: NONE`. (source: 2026-08-19 qc-behavioral six-mutation battery on PR #2390, unfiled residual; fixed 2026-08-20 on `harness/scenario42-residuals`; corrected 2026-08-20 rework iteration 1)

- [x] H-AUDIT-SCENARIO42-HEREDOC-UNGUARDED: **Residual introduced by the `else`-branch fix above, found by qc-behavioral rework review of PR #2424 (finding CP4b), same session.** The `cat > "${SCENARIO42_SCRIPT}" <<EOF ... EOF` heredoc write inside the `else` block ran under the suite's own `set -euo pipefail` unguarded — the exact failure class `H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED` / `H-AUDIT-SCENARIO42-DECLARE-F-UNGUARDED` above already exist to prevent, reintroduced one line below the declare-f guard, inside the block those entries created. Measured (path pointed at a nonexistent subdirectory to force the write to fail): suite died after scenario 41 with rc=1 and no `record_qc_audit_test: N passed, M failed` line at all. **Fix:** guarded with `if ! cat > "${SCENARIO42_SCRIPT}" <<EOF ... EOF then fail ...; else ...; fi`, matching the house style used elsewhere in this file for guarded writes. Mutation-tested: same write-failure mutation against the fixed code now produces an orderly **rc=1, 59 passed, 1 failed**, `FAIL: scenario 42 — precondition failed: cannot write <path>`, with the summary line present. Reverted; baseline restored to 60 passed, 0 failed, rc=0. `harness_gap: NONE`. (source: 2026-08-20 qc-behavioral rework review of PR #2424; fixed 2026-08-20 on `harness/scenario42-residuals`, rework iteration 1)

- [x] H-AUDIT-SCENARIO42-DOC-CORRECTIONS: **Two one-line doc-precision residuals from the same PR #2390 battery, same filing gap, folded into one entry since neither changes executable behaviour.** (a) The `H-AUDIT-GLOB-COUNT-GUARD-UNPINNED` completion note above (this file) said scenario 42 runs "via a fresh `bash -c` subprocess seeded with `declare -f _glob_count`" — the code actually runs `bash "${SCENARIO42_SCRIPT}"`, a generated script **file**, not a `bash -c` string. Corrected the note to say "a fresh `bash` subprocess running a generated script file". (b) The `_glob_count` header comment (`record_qc_audit_test.sh`, directly above the function) said the abort-prevention at the 42 real call sites comes from "the function-call wrapping itself" — imprecise language left over from the H-AUDIT-GLOB-COUNT-DOC-PRECISION rewording two entries above, which fixed the causal claim (command substitution, not `|| true`) but not this residual phrase naming the wrong mechanism (function-call wrapping vs. the command-substitution subshell). Corrected to name the command-substitution subshell explicitly. Neither correction touches an assertion or a scenario; verified the suite is still 60 passed / 0 failed / exit 0 after both edits (same run that verified the two fixes above). `harness_gap: NONE`. (source: 2026-08-19 qc-behavioral six-mutation battery on PR #2390, unfiled residual; fixed 2026-08-20 on `harness/scenario42-residuals`)

- [x] H-AUDIT-TEST-SUT-READ-UNGUARDED: Fixed 2026-08-18. Added `2>/dev/null` + `|| true` to scenario 24 Part B's `sed -E … "${WRITE_AUDIT}"` read (`trading/devtools/checks/record_qc_audit_test.sh`), plus an explicit `[[ -n "${CODE_ONLY_24}" ]]` guard on the `source_order_ok` condition mirroring the existing `CHMOD_TMP_LINE_24` guard. Verified with a mutation (`rm -f "${WRITE_AUDIT}"` immediately before the read): before the fix the suite died mid-run at that line with no summary line (raw `sed`, exit 2, `sed: can't read …: No such file or directory`); after the fix the same mutation produces a clean scenario-24 FAIL (`chmod_tmp_line=`, `mv_line=` both empty, confirming the guard fires) and the suite completes with a full summary line. Full-suite baseline unaffected: 59/0 before and after. `harness_gap: NONE`. (source: 2026-08-06 qc-behavioral on PR #2221, F3)

- [x] H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL: Filed by qc-structural/qc-behavioral on PR #2221 (2026-08-06); recorded in `dev/daily/2026-08-06.md` §Follow-up Queue but never actually written into this file (lost to shared-tree churn during that run — filed here retroactively as part of the fix). `record_qc_audit_test.sh` scenarios 25a/26a compared `seen25`/`seen26` (the loop's own iteration count) against `${#HOOK_DISABLE_VALUES[@]}` — **the same array's own length**, so the coverage check could never detect the array itself being shrunk. `HOOK_DISABLE_VALUES=(0)` alone still satisfies `seen == ${#HOOK_DISABLE_VALUES[@]}` (1 == 1) and shipped the whole suite **30/30 green** while covering one of the six documented "off" spellings instead of six — measured live (see below). Compounding it, the pass/fail messages hardcoded the literal string `(0 false no yes true '')`, so the shrunk-array run printed the self-contradicting `all 1 documented 'off' spellings (0 false no yes true '')`. **Fix:** introduced `HOOK_DISABLE_EXPECTED_COUNT=6` as a second, independent source of truth — both `seen25`/`seen26` are now compared against this constant, not against the array's own length, so a shrunk (or padded) array can no longer satisfy its own check. Also added a `_disable_values_repr()` helper that renders the message's spelling list **from the array**, so the printed claim and what was actually exercised can never diverge again. **Mutation-tested live:** shrinking `HOOK_DISABLE_VALUES` to `(0)` against the pre-fix code reproduced the exact bug — 30/30 green, message read `all 1 documented 'off' spellings (0 false no yes true '')`. The identical mutation against the fixed code goes **28 passed, 2 failed** (25a, 26a; `exercised 1` against `HOOK_DISABLE_EXPECTED_COUNT=6`), exit 1. Reverted; full suite back to green after the fix. No new scenarios added for this item — 25a/26a were strengthened in place, per the house preference for growing existing pins over multiplying near-duplicates. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (32 assertions across 28 scenarios, count as of the H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE rework below). `harness_gap: NONE` (fixed, not deferred). (source: 2026-08-06 qc-structural/qc-behavioral on PR #2221; built harness/audit-test-count-and-repo-root)

- [x] H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE: **Test-harness trap, self-filed 2026-08-06 while working PR #2221** (bit both me and the reviewer independently in the same session, which is the argument for recording it). `write_audit.sh` locates its output via a private `_repo_root()` that walks up for `.git`/`.claude` and only falls back to `$REPO_ROOT` if that walk finds nothing. Inside the test suite this is invisible, because the suite copies the script into `${TMP_REPO}` — the walk-up then legitimately lands on `${TMP_REPO}` and everything is contained. But **an ad-hoc in-place invocation of `trading/devtools/checks/write_audit.sh` with `REPO_ROOT=/tmp/…` ignores the override entirely** and writes a real record into the repo's `dev/audit/`. Both of us hit this probing the hook gate by hand; both leaked a `dev/audit/2026-08-06-b-probe.json` into the working tree and had to remove it before committing. The hazard is that `dev/audit/` is a live data directory shared with concurrent agents, so a stray probe record is not merely litter — it is indistinguishable from a real QC audit record to the `dev/audit/` glob consumers (`consecutive_rework_count` in `write_audit.sh` itself, and `deep_scan/check_06_qc_calibration.sh`), and a probe with a plausible feature name could silently perturb a rework-streak count. **Fixed, shape (a):** `_repo_root()` now checks `$REPO_ROOT` first and only falls back to the `.git`/`.claude` walk-up if unset — smallest change, matches the documented-looking override's implied contract. **Caller-safety check performed before choosing (a):** grepped every caller of `write_audit.sh` and of the structurally-identical `_repo_root()` in `record_qc_audit.sh` (its own separate copy, not fixed here — see below). Every real caller in `record_qc_audit_test.sh` (39 sites) and `sete_diagnostics_check.sh`'s Part 5 (which invokes `write_audit.sh` under `sh`, expecting an immediate `pipefail` failure before `_repo_root()` is ever reached) already sets `REPO_ROOT="${TMP_REPO}"` where `${TMP_REPO}` itself contains its own `.claude` sentinel — so the walk-up and the override already agreed on every existing call site, and flipping precedence changes behaviour for the ad-hoc-invocation case only, which is exactly the case this fix targets. Also notable: the codebase's own shared `repo_root()` helper (`trading/devtools/checks/_check_lib.sh:53`, sourced by most other check scripts) already checks `$REPO_ROOT` **first** — `write_audit.sh`'s bespoke `_repo_root()` had the precedence backwards relative to the established in-repo pattern, not just relative to what the finding wanted. **New regression scenario 27:** two independent temp roots — `WALKUP_ROOT` (its own `.claude` sentinel a few directories above a copy of `write_audit.sh`, so the walk-up "succeeds" on its own terms) and `TARGET_ROOT` (passed via `REPO_ROOT`, otherwise unrelated). Asserts the record lands under `TARGET_ROOT/dev/audit` only, never under `WALKUP_ROOT/dev/audit`. **Mutation-tested live:** reverting `write_audit.sh` to the pre-fix walk-up-first order makes scenario 27 go red (`target_count=0, walkup_count=1` — the record lands in the wrong root); restoring the fix returns 31/31 green. **Test-authoring bug found and fixed while building scenario 27** (same class as prior `set -euo pipefail` traps in this file): the first draft counted matches with `ls .../*.json | wc -l`, which trips `pipefail` and silently kills the whole test run when the glob matches zero files — exactly the case `walkup_count27` is expected to hit on a passing run. Rewritten with `find -maxdepth 1 -name '*.json' -type f`, which returns 0 with empty output on no match.

**Rework iteration 1 (qc-behavioral B1, blocking):** scenario 27 only pinned that an explicit `REPO_ROOT` beats a *successful* walk-up — it never exercised the walk-up branch itself, since 27 (like every other caller in this file) sets `REPO_ROOT` explicitly. That branch is not a corner case: it is the **only path production uses** — `lead-orchestrator.md` invokes `write_audit.sh` with `REPO_ROOT` unset — so half of `_repo_root()`'s two-branch contract was entirely unpinned. Added **scenario 27b**, reusing the `WALKUP_ROOT` fixture from 27 (its `dev/audit/` is empty at that point — 27 itself asserts `walkup_count27 == 0`): invokes `write_audit.sh` via `env -u REPO_ROOT` (forcing the var unset regardless of ambient shell state) and asserts the walk-up still locates the root and publishes the record. **Mutation-tested live:** deleted the entire walk-up block (the `dir=...`/`while`/`done` loop) from `write_audit.sh`, leaving only the `REPO_ROOT`-set branch and the final `FAIL: could not locate repo root`. Result: **31 passed, 1 failed**, exit 1 — the sole failure is scenario 27b (`expected rc=0 + 'OK: wrote' + exactly 1 record under WALKUP_ROOT; got rc=1, walkup_count=0`, with `FAIL: could not locate repo root` in the captured output), exactly as predicted; scenario 27 itself still passes since it never touches the walk-up path. Restored the block; suite returns to **32 passed, 0 failed**.

**Rework iteration 1 (qc-behavioral B2, non-blocking but corrected):** the original note below claimed `record_qc_audit.sh`'s sibling `_repo_root()` bug was out of scope because "the two scripts' `REPO_ROOT` usage is independently overridable." **That rationale was false, measured and corrected:** `record_qc_audit.sh` L102 (`REPO_ROOT="$(_repo_root)"`) reassigns `REPO_ROOT` using its *own*, still-unfixed, walk-up-first `_repo_root()` — and because bash's export attribute persists across a plain (non-`export`) reassignment of an already-exported variable, the caller's original override does not survive: `record_qc_audit.sh` silently overwrites it with its own walked-up value, which **stays exported** and is exactly what `write_audit.sh`'s newly-REPO_ROOT-first branch then consumes when `record_qc_audit.sh` invokes it as a child process. Verified this export-persistence mechanism directly with a two-script toy repro (`REPO_ROOT="from-caller" bash mid.sh` where `mid.sh` does a plain `REPO_ROOT="from-mid-script"` before invoking `child.sh`: the child sees `from-mid-script`, not `from-caller`). So this PR's precedence fix in `write_audit.sh` does **not** close the leak when reached through `record_qc_audit.sh` — the value `write_audit.sh` sees was never the caller's real override to begin with. Confirmed this is **pre-existing, not a regression**: pre-fix, `write_audit.sh`'s own walk-up-first logic ignored whatever `REPO_ROOT` it received either way, so the through-`record_qc_audit.sh` path behaved identically before and after this PR. **Scope decision unchanged, rationale corrected:** still leaving `record_qc_audit.sh`'s sibling `_repo_root()` (lines ~85-100) unfixed here — the finding named `write_audit.sh` specifically, and closing the sibling properly would need its own mutation-tested regression coverage (the same bar applied above), which is new scope for a rework-mode PR. Filed as a candidate follow-up below (`H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING`) rather than silently left as a dangling "worth a follow-up" prose note. Option (b) (`WRITE_AUDIT_OUTPUT_DIR`) and (c) (docs-only) were considered and rejected for the `write_audit.sh` fix itself — (a) was sufficient and is the smallest, most consistent fix. `harness_gap: LINTER_CANDIDATE` (the shared `repo_root()`/`_repo_root()` precedence-order pattern would be a reasonable target for a mechanical consistency check, given two of three implementations in this file family had it backwards). **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (32 assertions across 28 scenarios). (source: self-filed 2026-08-06 during PR #2221 rework; independently reproduced by qc-behavioral in the same session; built harness/audit-test-count-and-repo-root; rework 2026-08-07 qc-behavioral B1/B2 on PR #2231)

- [x] H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING: `record_qc_audit.sh` had its own separate, structurally-identical `_repo_root()` (lines ~85-100) with the same walk-up-first-then-`REPO_ROOT`-fallback bug that `write_audit.sh` was fixed for above. Worse than a simple duplicate: because `record_qc_audit.sh` reassigns `REPO_ROOT="$(_repo_root)"` with a plain (non-`export`) assignment and bash's export attribute survives plain reassignment of an already-exported variable, an explicit caller override to `record_qc_audit.sh` got silently discarded and replaced by the sibling's own walked-up value, which then propagated through to `write_audit.sh` as a child process — so the earlier `write_audit.sh` precedence fix alone did not close the leak on the `record_qc_audit.sh` path. **Fixed:** applied the identical three-line reorder to `record_qc_audit.sh:_repo_root()` (REPO_ROOT check first, walk-up second), matching `write_audit.sh` and the shared `repo_root()` in `_check_lib.sh:53` — all three implementations in the file family now agree. **New regression coverage, `record_qc_audit_test.sh` scenarios 28/28b:** mirrors 27/27b but pins the STRONGER end-to-end claim — invokes `record_qc_audit.sh` directly (not just its own `_repo_root()` in isolation) with `REPO_ROOT` pointing at a `TARGET2_ROOT` fixture distinct from the script's walked-up `WALKUP2_ROOT`, and asserts the audit record produced by the `write_audit.sh` CHILD PROCESS lands under `TARGET2_ROOT/dev/audit` (with the quality score from `TARGET2_ROOT`'s own review file, proving `REVIEW_FILE` resolution also followed the override) — never under `WALKUP2_ROOT/dev/audit`. Scenario 28b pins the walk-up branch (`REPO_ROOT` unset, `env -u REPO_ROOT` guard) using its OWN fresh fixture (`WALKUP3_ROOT`) with an absolute post-run count, deliberately avoiding the cumulative-count pattern tracked separately as H-AUDIT-27B-CUMULATIVE-COUNT. **Mutation-tested live:** reverting the reorder in `record_qc_audit.sh` made the suite go **33 passed, 1 failed** (only scenario 28 — `target_count=0, walkup_count=1`, i.e. the record lands under the wrong root exactly as predicted; 28b unaffected since the walk-up branch itself was never touched by the bug); restoring the fix returned the suite to **34 passed, 0 failed**. `dev/audit/` file count unchanged by the fixture runs (106 before and after every run, confirmed across baseline/fixed/reverted/restored). **Linter interaction found and fixed during authoring:** the first draft of the scenario-28 comment quoted the literal call syntax `` `REPO_ROOT="$(_repo_root)"` `` inside a shell comment, which tripped `check_universe_deps.sh`'s `repo_root\)` substring scan (H-CHECK-CACHE-BLIND guard) — it doesn't distinguish comment text from real call sites, so `record_qc_audit_test.sh` itself became a flagged "candidate" not covered by `(universe)` or the exceptions list. Reworded the comment to describe the reassignment without literally spelling the `$(_repo_root)` call syntax; `check_universe_deps.sh` passes clean again. **Verify:** `bash trading/devtools/checks/record_qc_audit_test.sh` (34 assertions across 30 scenarios, up from 32/28); `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest` both exit 0. `harness_gap: LINTER_CANDIDATE` carries forward unchanged (the shared `repo_root()`/`_repo_root()` precedence-order pattern across the three implementations is now consistent, but a mechanical consistency check for future additions is still a reasonable target). (source: 2026-08-07 qc-behavioral B2 on PR #2231; fixed 2026-08-08 on harness/record-qc-audit-repo-root-sibling)

- [ ] H-AUDIT-TEST-DISABLE-COUNT-PAD-DIRECTION-WORDING (B3): Non-blocking wording finding from qc-behavioral on PR #2231's review of the H-AUDIT-TEST-DISABLE-COUNT-TAUTOLOGICAL fix. The *shrink* direction is now caught by `HOOK_DISABLE_EXPECTED_COUNT`, but the *pad* direction still self-contradicts in the message: adding a 7th spelling to `HOOK_DISABLE_VALUES` prints `for all 6 documented 'off' spellings` (the hardcoded `HOOK_DISABLE_EXPECTED_COUNT`) immediately followed by a 7-element list from `_disable_values_repr()`. Functionally harmless — the scenario still goes red on a pad because `seen != HOOK_DISABLE_EXPECTED_COUNT`, and the same line's `exercised 7` mitigates the confusion — but the wording itself is internally inconsistent the same way the pre-fix shrink-direction message was. Fix shape: word the message as "expected N documented spellings, exercised M" without asserting "all N ... (list of M)" as a single clause. `harness_gap: NONE`. (source: 2026-08-07 qc-behavioral on PR #2231)

- [x] H-AUDIT-HOOK-DISABLE-COUNT-DOCSTRING-DRIFT (B4): Non-blocking finding from qc-behavioral on PR #2231. `HOOK_DISABLE_EXPECTED_COUNT=6` has no mechanical tie to the documentation it's meant to encode, and that documentation already disagrees with itself: `write_audit.sh`'s BEFORE_RENAME `ACCEPTED SPELLING:` block (~L451-453) enumerates **six** accepted-disable spellings, while the AFTER_RENAME block (~L511-513) enumerates only **three**. `record_qc_audit_test.sh` applying the full six-value set to both hooks is a sound superset (nothing under-tested), so nothing is currently broken by this — but the constant matches one docstring and silently contradicts the other. Fix shape: either reconcile the two `ACCEPTED SPELLING:` blocks to enumerate the same six values, or add a comment at `HOOK_DISABLE_EXPECTED_COUNT`'s definition explaining why the test set is intentionally a superset of the narrower AFTER_RENAME docstring. `harness_gap: NONE`. (source: 2026-08-07 qc-behavioral on PR #2231) **Fixed:** read both hooks' actual gate code (`write_audit.sh`, BEFORE_RENAME at the `WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME` check and AFTER_RENAME at the `WRITE_AUDIT_TEST_ABORT_AFTER_RENAME` check) — both use the identical `[ "${VAR:-0}" = "1" ]` gate, so the two hooks are genuinely symmetric in behaviour: only the literal `1` enables either one. Since the code is symmetric, the AFTER_RENAME docstring's narrower 3-value list was the incomplete one; **reconciled it to enumerate the same six values as BEFORE_RENAME** (`0`, `false`, `no`, `yes`, `true`, empty string, plus unset), and added a short comment at `HOOK_DISABLE_EXPECTED_COUNT`'s definition in `record_qc_audit_test.sh` recording that the constant matches both hooks' now-identical spelling contract, not a superset applied to a narrower one. No test or code-path behaviour change — `dune runtest devtools/checks` unchanged at 54 passed, 0 failed. Verify: `dev/lib/run-in-env.sh dune runtest devtools/checks`. (fixed 2026-08-15 harness-maintainer on harness/audit-disable-count-docstring)

- [ ] H-AUDIT-27B-CUMULATIVE-COUNT: Filed by qc-behavioral on PR #2231 (residual R1, non-blocking). Scenario 27b asserts `walkup_count27b == 1` as a **cumulative** count over a `WALKUP_ROOT` fixture it shares with scenario 27. Robust today -- the reviewer's probe J2 (revert the precedence fix) reddens both scenarios rather than producing a false green, and J1 shows 27b passes even with 27's write neutralised, so it depends on the *fixture* rather than on 27's side effects. But it is sensitive to any **future** scenario that writes into `WALKUP_ROOT`. Fix shape: snapshot the count immediately before 27b and assert a delta of exactly 1, or give 27b its own fixture. `harness_gap: NONE`. (source: 2026-08-07 run 1 qc-behavioral on PR #2231)

- [ ] H-AUDIT-27B-LEAKS-UNDER-PWD-REGRESSION: Filed by qc-behavioral on PR #2231 (residual R2, non-blocking). Under a walk-up regression that resolves from `$PWD` instead of `dirname $0` (the reviewer's probe K4), scenario 27b goes red **and leaves a stray record in the live `dev/audit/`**. Inherent to exercising the unset-`REPO_ROOT` path with an in-tree script; the test does go red so a human looks, which is why this is a residual rather than a defect. Fix shape: `cd` to a scratch directory for the 27b invocation. `harness_gap: NONE`. (source: 2026-08-07 run 1 qc-behavioral on PR #2231)

- [ ] H-AUDIT-WALKUP-SENTINEL-NARROWING-UNPINNED: Filed by qc-behavioral on PR #2231 (residual R3, non-blocking). Probe K2 -- narrowing `_repo_root()`'s sentinel test to `.claude` only -- is **not** caught by scenario 27b, because the `WALKUP_ROOT` fixture carries only `.claude`. Low value: not a real regression in this repo, whose root has both `.git` and `.claude`, so narrowing to either alone changes nothing in production. Recorded so a future harness re-audit does not rediscover it as new. Closing it would need a `.git`-sentinel fixture variant. Note K1 (`.git` only), K3 (wrong ancestor) and K4 (wrong starting dir) **are** all caught -- 27b closes the contract, not merely the one mutation. `harness_gap: NONE`. (source: 2026-08-07 run 1 qc-behavioral on PR #2231)

- [ ] H-AUDIT-ATOMICITY-PARTIAL-PIN: Pre-existing residual in #2169's coverage, surfaced (not introduced) by the #2199 review and explicitly out of scope there. Scenarios 19/20 pin "abort *before* publish leaves the target intact", which is **not** the same claim as "publish is atomic". A mutation that keeps the temp file but publishes non-atomically (`cat "$TMP_FILE" > "$OUTPUT_FILE"; rm -f "$TMP_FILE"`) passes both 19 and 20; only a faithful full revert of #2169 is caught. The realistic regression shape *is* caught, so this is low priority -- recorded so a future harness re-audit does not rediscover it as new. Belongs to the H-AUDIT-ATOMIC-WRITE lineage. `harness_gap: LINTER_CANDIDATE`. (source: 2026-08-04 run 1 qc-behavioral on PR #2199, finding F4)

- [ ] H-AUDIT-CHMOD-FAIL-CLOSED: Weak-preference note from qc-behavioral on #2199 (finding F3), explicitly **not** a rework demand. Under `set -euo pipefail` a failing `chmod` aborts before the `mv`, measured rc=1 with an empty `dev/audit/` -- i.e. the script fails closed and writes **no record at all**. On any normal filesystem chmod on an owned file cannot fail, so this is near-hypothetical, but the trade is "lose the record entirely" vs "publish it at the wrong mode", and the record is the more valuable artifact since it drives the `>= 3` escalation. `chmod 644 "$TMP_FILE" || echo "WARNING: could not set mode on $TMP_FILE" >&2` would keep it. Current fail-loud form matches house style; decide deliberately rather than by default. `harness_gap: ONGOING_REVIEW`. (source: 2026-08-04 run 1 qc-behavioral on PR #2199)

- [ ] H-JJ-JST-BROKEN-GHA: **`jj` and `jst` are non-functional in the GHA orchestrator container**, so **no dispatched agent can open its own PR** — measured 2026-08-03 run 2. `jst submit <branch>` fails inside `jj git fetch --all-remotes` with `Git does not recognize required option: porcelain (note: supported version is 2.41.0)` — a jj/git version incompatibility, unrelated to any branch's content. `gh` is also absent from this image. Together these mean **every** agent-facing PR-creation path documented in `.claude/agents/lead-orchestrator.md` Step 4 (`GH_TOKEN=$GH_TOKEN jst submit feat/<feature>`) and in the `feat-*`/`ops-data` definitions is dead in GHA; the only working path is the orchestrator's own Step 4.5 `curl` REST fallback. **This is the mechanical root cause of the recurring "branch pushed, no PR" pattern** — most visibly `feat/picks-slices-bcd`, which sat invisible for a full day with 931 insertions and no PR until run 1 surfaced it, and again this run for `harness/prev-verdict-pipefail` and `fix/picks-slices-lint` (both recovered by the REST fallback). Prior runs recorded this as agents "forgetting" the step; it is not — the tool is broken. Fix direction, pick one: (a) install `gh` in the orchestrator image and switch agent definitions to `gh pr create`; (b) pin a jj/git pair that interoperate; or (c) accept it, delete the `jst` instructions from the GHA path in the agent definitions, and document the orchestrator REST fallback as the sole supported mechanism. (c) is cheapest and matches observed reality. Note (a) and (c) both require editing `.claude/agents/**`, currently refused in this runtime. (source: 2026-08-03 run 2, harness-maintainer + feat-weinstein dispatches)
- [x] H-REWORK-STREAK-ESCALATION-UNTESTED: Filed by qc-behavioral on PR #2184 (2026-08-03 run 2) as an explicit non-blocking follow-up, NOT built there. **The filed text above was stale in two ways, corrected during dispatch (2026-08-15) before any fix work started — recorded here so a future reader does not re-derive this:** (1) `record_qc_audit_test.sh` scenario 7e (landed after this item was filed) already regression-tests that `write_audit.sh` COMPUTES `consecutive_rework_count` correctly through 3 consecutive NEEDS_REWORK calls — the "no end-to-end test anywhere" claim was no longer accurate for the computation side. (2) `deep_scan/check_06_qc_calibration.sh` was **not** actually a consumer of the field at all — grepping the whole repo for `consecutive_rework_count` found zero comparisons against the field anywhere; the "its actual consumer is check_06" claim was aspirational, not descriptive. The real defect was narrower than filed: the `>= 3` escalation trigger (write_audit.sh:37) had **no consumer whatsoever** — a feature could stack 3+ consecutive NEEDS_REWORK verdicts and nothing mechanical would ever surface it. **Fixed:** added a rework-streak escalation scan to `trading/devtools/checks/deep_scan/check_06_qc_calibration.sh` — scans `dev/audit/*.json`, extracts `(feature, consecutive_rework_count)`, and emits an `add_warning` finding for any feature whose **latest** record (by `recorded_at_ns` write order, matching write_audit.sh's own reset-on-APPROVED semantics) has a count `>= REWORK_STREAK_THRESHOLD` (named constant, =3, citing write_audit.sh:37 as authority) — reporting one finding per feature, not per record. Runs unconditionally (not gated on `$DUNE_AVAILABLE`, since it only reads `dev/audit/*.json`, no dune invocation). Legacy records predating the field are skipped, not crashed on. Also added `add_metric REWORK_STREAK_COUNT` (wired into `deep_scan/main.sh`'s aggregation + `## Metrics` output alongside `QC_CAL_COUNT`/`DUNE_AVAILABLE`). **Test:** new `trading/devtools/checks/deep_scan_rework_streak_check.sh`, a FUNCTIONAL change-detector test (not a marker grep) that actually invokes `check_06_qc_calibration.sh` against a synthetic `dev/audit/` fixture via the `REPO_ROOT` override (same pattern as `deep_scan_followup_count_check.sh`). Fixture pins: count=3 fires (boundary), count=2 does not fire (catches `>` vs `>=`), count=4 fires (catches `==` vs `>=`), a legacy record with the field absent neither fires nor crashes the scan, two records for one feature sharing one timestamp (counts 2 and 3) produce exactly ONE warning at the higher tied count (3), not two, and a resolved streak (an earlier count=4 record followed by a later APPROVED count=0 record) does NOT fire — the latest-record keying that a max-across-history reading would have gotten wrong (rework iteration 1, 2026-08-16 qc-behavioral finding: max-keyed escalation could never clear once a streak resolved). Wired into `dune runtest` via `trading/devtools/checks/dune`, with `(universe)` declared (the scan reads a real, live outside-workspace directory, `dev/audit/*.json` — an exceptions-list entry would not hold up the way it does for the simpler `deep_scan_followup_count_check.sh` fixture). **Mutation-tested live** (`>= 3` → `> 3`: featureA(3) and featureE(max 3) stop firing, featureC(4) still fires, `REWORK_STREAK_COUNT` drops 3→1, 4 assertions red; `>= 3` → `== 3`: only featureC(4) stops firing, `REWORK_STREAK_COUNT` drops 3→2, 2 assertions red; scan deleted entirely: all 5 firing/count assertions red) — each mutation reddens exactly the predicted assertions, confirming the test discriminates rather than just existing. **Verify:** `dev/lib/run-in-env.sh dune runtest devtools/checks` (includes `deep_scan_rework_streak_check.sh`, `check_universe_deps_test.sh` 19/19, `record_qc_audit_test.sh` 54/54). Also corrected a stale "ONLY dune rule that lists `deep_scan/_lib.sh` as a dep" claim in `universe_deps_exceptions.conf` (now two rules do, both still fixture-overridden). (source: 2026-08-03 run 2 qc-behavioral on PR #2184; corrected + built 2026-08-15, harness/rework-streak-escalation) **Rework iteration 2 (2026-08-16):** qc-behavioral found the absent-`recorded_at_ns` default branch (`check_06_qc_calibration.sh`'s `[ -z "$streak_recorded_at" ] && streak_recorded_at=0`) unpinned — no fixture omitted `recorded_at_ns`, even though that shape is 81/121 (67%) of live `dev/audit/` records, and a one-token mutation of that default survived the suite. Added `featureG` (count=4 present, `recorded_at_ns` absent, later modern APPROVED reset — must NOT fire; `_audit_record`'s `$4` now supports an explicit `""` to omit the timestamp field, distinguished from "unset" via `${4-default}` not `${4:-default}`) and `featureH` (fire-direction mirror of featureF: earlier APPROVED reset then later NEEDS_REWORK — must fire at 3). `M: REWORK_STREAK_COUNT` moved 3→4 (A+C+E+H). Verified `featureG` reddens under the reviewer's exact mutation (`streak_recorded_at=0` → a large sentinel): before-fix mutant run showed 2 assertions red (featureG fires, count metric 4→5); after-fix (mutation reverted) clean. Also corrected the tie-break docstring's "only possible for legacy records" claim — `write_audit.sh`'s whole-second fallback (platforms without GNU `date +%s%N`) and `WRITE_AUDIT_RECORDED_AT_NS` can tie two *modern* records too; stated explicitly that an all-legacy tie set degenerates to max-across-history (accepted, no live impact — no new zero-timestamp records can be created and the live scan currently reports `REWORK_STREAK_COUNT=0`). P6 (`overall_qc` not read) intentionally left as-is per the reviewer's explicit note that not reading it is correct.
- [x] H-WRITE-AUDIT-SHEBANG-MISMATCH: **Fully closed — the "still open" half was a misreading, corrected 2026-07-29.** `trading/devtools/checks/write_audit.sh`'s usage block (was lines 11-24) documented invocation as `sh write_audit.sh --date ...`, which dies immediately under dash (`set: Illegal option -o pipefail`, exit 2) since the script requires bash for `set -o pipefail`. **Fixed** (harness/sete-diagnostics-audit): the usage comment now reads `bash write_audit.sh \` with an inline note explaining why `sh` fails. The entry previously claimed `.claude/agents/lead-orchestrator.md` Step 5 Stage 4 "copies the same wrong `sh write_audit.sh` invocation verbatim" and left that half open pending an orchestrator-side fix. **Verified false directly** (2026-07-29, this session): `grep -n 'write_audit' .claude/agents/lead-orchestrator.md` shows line 1404 reads `bash trading/devtools/checks/write_audit.sh \` — already correct, already bash. Root cause of the misreading: the string `bash trading/devtools/checks/write_audit.sh` *contains* the literal substring `sh trading/devtools/checks/write_audit.sh` (the tail of "ba**sh**"), so a grep/eyeball scan for the wrong `sh write_audit.sh` form matches the correct `bash ...` line as a false positive. No further fix needed in `lead-orchestrator.md`; nothing further escalated. Same class as H-CHECK-SETE-DIAGNOSTICS: a shell-portability defect whose symptom is a silent-ish failure in the one environment that actually runs it. (source: 2026-07-28 lead-orchestrator run 4, observed directly; usage-comment fix 2026-07-29; substring-trap correction 2026-07-29 run 2, harness/audit-atomic-write)

- [x] H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH: Filed by qc-behavioral on PR #2243 (residual R1, non-blocking, **pre-existing and shared by all three implementations**). When a caller exports `REPO_ROOT` to something that fails the `[ -d "$REPO_ROOT" ]` guard, the guard falls through to the walk-up, the record is written to the **walked-up** root with `rc=0` and no diagnostic, and that walked-up value is re-exported to the `write_audit.sh` child. Measured on a fixture repo: `REPO_ROOT='/definitely/not/a/dir'`, `REPO_ROOT=''`, and `REPO_ROOT=/etc/hostname` (a regular file) each produced `rc=0` with the record landing under `$WALKUP/dev/audit/`; an instrumented child printed `CHILD-SEES-REPO_ROOT=[$WALKUP]`. So the observable failure shape this whole H-* family exists to prevent — *an audit record landing in a root the caller did not choose* — remains reachable, just via **malformed** input rather than valid input. Not a regression and not introduced by #2243: `_check_lib.sh:repo_root()`, `write_audit.sh:_repo_root()` and `record_qc_audit.sh:_repo_root()` all share the `[ -n ] && [ -d ]`-then-walk-up shape, so #2243's stated consistency goal is met. Unpinned by any scenario. Fix shape: in all three, treat "`REPO_ROOT` set but not a directory" as a **hard error** (`FAIL: REPO_ROOT is set to '<v>' but is not a directory`) rather than a silent fallthrough — a set-but-invalid override is far more likely a typo than a request to fall back. Needs a scenario asserting non-zero exit and **zero** records written in either root. `harness_gap: LINTER_CANDIDATE` (same precedence-consistency check as the parent item). (source: 2026-08-08 qc-behavioral R1 on PR #2243) **Fixed:** all three `_repo_root()`/`repo_root()` implementations (`_check_lib.sh`, `write_audit.sh`, `record_qc_audit.sh`) now split the single `[ -n ] && [ -d ]` guard into two branches: `REPO_ROOT` **set and non-empty** but failing `[ -d ]` (nonexistent path, or a path that exists but is a regular file) is a hard error — `FAIL: REPO_ROOT is set to '<v>' but is not a directory`, `exit 1`, no walk-up attempted — while `REPO_ROOT` **unset or the empty string** still falls through to the walk-up exactly as before. **Empty-string decision (deliberate, documented in each function's own code comment):** `REPO_ROOT=''` is treated the SAME as unset, not as set-but-invalid. Rationale: `${REPO_ROOT:-}` is empty for both an unset and an empty-string `REPO_ROOT` (the `:-` operator triggers on null-or-unset), so the two cases already collapse into the walk-up branch by shell construction; an empty override is indistinguishable from "no override supplied," every existing caller relies on exactly that fallback (it's the only path production uses — `REPO_ROOT` is test-only plumbing), and a hard error on `''` would protect against nothing (an empty value can't carry a wrong path) while risking breaking a caller that clears the var to mean "no override." **Regression coverage** (`record_qc_audit_test.sh`, 40 → 49 scenarios/assertions, measured by running the suite, not quoted from memory): scenarios 29a-c pin `_check_lib.sh:repo_root()` in isolation via a new `_repo_root_probe.sh` fixture wrapper (nonexistent path / regular file / empty string); scenarios 30a-c pin `write_audit.sh:_repo_root()` end-to-end (rc + zero records under the walked-up root for the two hard-error shapes, one record for the empty-string walk-up); scenarios 31a-c pin `record_qc_audit.sh:_repo_root()` end-to-end through its `write_audit.sh` child process, with all three sub-scenarios' `dev/reviews/<feature>.md` fixtures created upfront so a guard regression is caught by an actual wrong-root *publish* (rc=0, record written) rather than an incidental later "review file not found" error. **Mutation-tested live, one implementation at a time (revert guard, run suite, restore, verify byte-identical):** (1) reverted `_check_lib.sh`'s guard only → 47 passed, 2 failed (exactly 29a, 29b — 29c and everything else green); (2) restored, reverted `write_audit.sh`'s guard only → 46 passed, 3 failed (exactly 30a, 30b, and 30c as collateral — 30c's "exactly 1 record" assertion fails because 30a/30b's silent writes polluted the walked-up root's count to 3, correctly showing the bug's blast radius); (3) restored, reverted `record_qc_audit.sh`'s guard only → 46 passed, 3 failed (31a/31b/31c, with 31a/31b showing `rc=0` + a real record published under the walked-up root — the full H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING shape, not just a secondary error). All three restores verified byte-identical to the shipped fix (diffed against saved copies). **"Before" measurement:** ran the pre-existing 40-scenario suite (no 29/30/31) against the pre-fix scripts — 40/40 passed, confirming the defect was invisible to the existing suite and that this fix changes no previously-tested behavior (the unset-`REPO_ROOT` path scenarios 27b/28b and every other pre-existing scenario are untouched). **Dune wiring:** `_check_lib.sh` added to the `record_qc_audit_test.sh` runtest rule's `(deps ...)` in `trading/devtools/checks/dune` — scenario 29's fixture copies `_check_lib.sh` into a temp dir and probes `repo_root()` directly, and without the dep dune's sandbox never copies the file in (`cp: cannot stat ... No such file or directory`) even though it's readable outside the sandbox; caught by running the dune-wired suite, not just the direct `bash` invocation. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (49/49) and `dune runtest devtools/checks/ --force` (also exercises the dune dep-wiring fix).

- [ ] H-AUDIT-TEST-SCENARIO-COUNT-UNRECONCILABLE: Filed by qc-behavioral on PR #2243 (residual R2, non-blocking, **cosmetic**). The "N scenarios" figure quoted in `record_qc_audit_test.sh`'s prose, in PR bodies, and in this file reconciles with **no** mechanical count of the file. Measured at `813a91e5`: distinct scenario labels appearing in pass/fail text = **34**; `# Scenario` comment headers = **29**; distinct numeric scenario numbers = **28**. The quoted figure is **30**. The assertion count (**34**) *is* accurate and is the half the suite actually prints and machine-checks. The pre-existing text already said "28 scenarios" (also unreconcilable) and #2243 incremented it consistently by +2, so this is carried-forward imprecision rather than a new error — but it means every "N/M" citation in this family is half-unverifiable. Fix shape: drop the scenario count from prose and cite only the assertion count the suite prints, **or** have the suite print both counts so the figure is derived rather than transcribed. `harness_gap: LINTER_CANDIDATE` (a count printed by the suite cannot drift from the suite). (source: 2026-08-08 qc-behavioral R2 on PR #2243)

- [x] H-UNIVERSE-DEPS-EXEMPTION-EVIDENCE-STALE: Filed by qc-behavioral on PR #2243 (residual R3, non-blocking, **docs-only**). `universe_deps_exceptions.conf:44-47` and `:50-53`, plus the dune comment at `trading/devtools/checks/dune:471-475`, justify the `record_qc_audit.sh` / `write_audit.sh` exemptions on the grounds that the governing test *"ALWAYS overrides REPO_ROOT to a freshly-created temp fixture repo before invoking this script — the real dev/reviews/ and dev/audit/ directories are never read."* That is now **literally false in two places**: `record_qc_audit_test.sh:1446` (scenario 27b, pre-existing from #2231) and `:1587` (scenario 28b, added by #2243) both invoke under `env -u REPO_ROOT` with no override. The exemption remains **substantively valid** — the walk-up terminates inside the fixture, which carries its own `.claude` sentinel, and `dev/audit/` measured **106 before and after every run** including a forced dune re-run — but the *recorded evidence* no longer matches the code. This is precisely the drift H-CHECK-EXEMPTION-DRIFT (above, ~line 442) already flags as mechanically uncatchable. Fix shape: reword both exemption comments and the dune comment to the accurate invariant — *"every invocation either overrides `REPO_ROOT` to a temp fixture, or runs `env -u REPO_ROOT` from a script located inside a temp fixture that carries its own `.claude` sentinel; the walk-up therefore terminates in the fixture, never the real repo."* Folds naturally into the H-CHECK-EXEMPTION-DRIFT re-audit. (source: 2026-08-08 qc-behavioral R3 on PR #2243) **Fixed:** re-enumerated every `record_qc_audit.sh`/`write_audit.sh` invocation in `record_qc_audit_test.sh` from source rather than trusting the filed line numbers (grepped all ~60 `REPO_ROOT` occurrences): every site either explicitly sets `REPO_ROOT` (including the deliberate `''`/malformed cases in scenarios 29-31, which still count as "override", just to an invalid/empty value) or runs via `env -u REPO_ROOT` — and the `env -u` shape occurs at **exactly two sites, scenarios 27b and 28b**, confirming the filed item's count. Confirmed mechanically that both `env -u` fixtures (`WALKUP_ROOT` for 27b, `WALKUP3_ROOT` for 28b) are `mktemp -d` trees carrying their own `.claude` sentinel, so the walk-up in the unset-REPO_ROOT case terminates inside the fixture, never the real repo. Reworded all three sites (`universe_deps_exceptions.conf`'s `record_qc_audit.sh` and `write_audit.sh` entries, and the dune file's "H-CHECK-CACHE-BLIND exemption" comment) to state the accurate two-branch invariant, citing scenario names (27b/28b) rather than line numbers per the drift lesson this item itself demonstrates. Ran the real safety check rather than reusing the prior filing's number: `dev/audit/` measured 128 and `dev/reviews/` measured 142 both before and after running `record_qc_audit_test.sh` (57/57 passed, `git status --porcelain dev/audit dev/reviews` clean) — no real-repo file was touched. Comment/config-prose-only change; verified `dune build devtools`, `dune runtest devtools`, and `dune build @fmt` all exit 0 with zero `FAIL:` lines and no unintended fmt diff. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (57 scenarios) and `dev/lib/run-in-env.sh dune runtest devtools/checks`. (fixed 2026-08-17 harness-maintainer on harness/universe-deps-evidence) **Rework (iteration 1, PR #2363):** qc-behavioral found the shipped two-branch wording under-enumerated — the invocation set has **four** shapes, not two, and six sites of the two exempted scripts (30a/b/c, 31a/b/c, plus 29a/b/c for the dune comment's `_check_lib.sh` mention) satisfied neither branch. The malformed-`REPO_ROOT` cases (29a/b, 30a/b, 31a/b) hard-error at `_repo_root()`'s `[ -d ]` guard before any override takes effect — the opposite of "a freshly-created temp fixture repo" — and `REPO_ROOT=''` (29c, 30c, 31c) is **not an override in effect either**: both `_repo_root()`s guard on `[ -n "${REPO_ROOT:-}" ]`, so `''` falls straight through to the walk-up. This also corrects this note's own prior claim that the malformed/`''` cases "still count as \`override\`" — they do not; malformed hard-errors before any override takes effect, and `''` is unset-equivalent. Reworded all three sites (`.conf` × 2, `dune` × 1) to a three-shape invariant: (a) override to a freshly-created fixture, (b) override to a deliberately malformed value that hard-errors before any path is computed, (c) walk-up reached via `env -u REPO_ROOT` or `REPO_ROOT=''`, seeded from the script's own directory so it terminates inside the fixture regardless of caller CWD. Dropped the exhaustive "(scenarios 27b and 28b)" framing in favor of "e.g. scenarios 27b/28b/..." so the prose doesn't re-acquire a drift-prone exhaustive site list. `.conf` non-comment lines remain a zero diff vs `main` (nothing added/removed/widened); `dune build devtools`, `dune runtest devtools` (57/57), `dune build @fmt` all exit 0. (reworked 2026-08-17 harness-maintainer, rework iteration 1 on PR #2363)

- [x] H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS: Filed by the harness-maintainer during PR #2243 authoring (side finding, **not** implemented there per scope discipline). `check_universe_deps.sh`'s candidate scan greps for the substring `repo_root)` without distinguishing comment prose from real call sites. While authoring scenario 28 the author quoted the literal call syntax `` `REPO_ROOT="$(_repo_root)"` `` inside an explanatory comment, and `record_qc_audit_test.sh` **itself** briefly became a flagged "candidate" missing `(universe)` / exceptions coverage. Worked around by rewording the comment to avoid the literal pattern — so the tripwire is currently disarmed by author discipline rather than by the linter. Real (if narrow) false-positive risk for any future comment quoting `$(_repo_root)` / `$(repo_root)` syntax, which is exactly the kind of comment this file family now needs to write. Fix shape: have the scanner strip `#`-comment lines before grepping, mirroring the `strip_comments()` helper **already used elsewhere in that same script** for dune-rule parsing. `harness_gap: LINTER_CANDIDATE`. (source: 2026-08-08 harness-maintainer, PR #2243) **Fixed:** `check_universe_deps.sh`'s `CANDIDATES` scan now pipes each candidate `.sh` file through a new `_strip_hash_comments()` helper (`awk '$0 !~ /^[ \t]*#/'`) before grepping for `repo_root\)`, stripping whole-line `#` comments only — never partial-line, so a real call site sharing a line with a trailing `# comment`, or a file also containing `${var#prefix}` / `${#arr[@]}` parameter-expansion noise, is still detected. **Not a literal call into the existing `strip_comments()` awk function** (documented in the new code comment): that function strips dune's `;`-led comments from a single rule-block string inside the one awk program that parses `DUNE_FILE` in paragraph mode; the candidate scan runs earlier, in `sh`, over individual `*.sh` files one at a time via `find`/`grep`, well before that awk program ever runs — there's no shared process/string to call the same function on. Same principle, separate implementation, adapted for `#` instead of `;`. **Regression coverage:** `check_universe_deps_test.sh` assertions 8-10 (new, 10 total, was 7) — 8: a script whose only `repo_root)` occurrence is inside a `#` comment never becomes a candidate; 9: a real call site on a line that also carries a trailing `#` comment, in a file that also has `${var#prefix}`/`${#arr[@]}` noise elsewhere, is still detected -> FAIL without `(universe)`; 10: same fixture with `(universe)` declared -> PASS. **Mutation-tested live:** reverted only `check_universe_deps.sh` (kept the new fixtures) -> 6/10 passed, 4 failed (assertions 2, 3, 8, 10 — the comment-only fixture's false-positive FAIL line polluted assertions 2/3 too, showing the bug's blast radius; assertion 9 still passed since a plain real call site was never mis-detected pre-fix). Restored the fix -> 10/10 green, byte-identical to the pre-mutation file (diffed). **Real-repo flagged-file set unchanged:** ran `check_universe_deps.sh` against the actual `trading/devtools/checks/` tree both before and after the fix — identical OK/SKIP/FAIL output, byte-for-byte, exit 0 both times (no new candidates flagged, none newly missed). Verify: `sh trading/devtools/checks/check_universe_deps_test.sh` (10/10) and `dune runtest devtools/checks`. **CP4 rework (PR #2303, qc-behavioral):** assertion 9's original fixture put `${var#prefix}`/`${#arr[@]}` noise only on *standalone* lines, so a strip-to-end-of-line mutation (`awk '{ sub(/#.*$/, ""); print }'`) still passed the full suite 10/10 — the guard was unpinned against that specific over-eager shape. Fixed by moving a `${var#prefix}` expansion onto the real call-site line itself (`risky_comment_repo_root.sh`'s `REAL=` line), making the discrimination load-bearing: shipped `_strip_hash_comments()` still passes 10/10; the strip-to-end-of-line mutation now fails assertion 9 (measured: 8 passed, 2 failed — 9 and 10); the drop-any-line-with-# mutation continues to fail assertion 9 as before. No change to `_strip_hash_comments()`'s shipped behaviour — test-only fix.

- [x] H-AUDIT-MALFORMED-SHAPE-COUNT-WORDING: Filed by qc-behavioral on PR #2328 (2026-08-14 run 2, sole finding, **non-blocking, wording-only — explicitly not a rework demand**). The PR body and the scenario-29 comment in `trading/devtools/checks/record_qc_audit_test.sh` both say "the three malformed `REPO_ROOT` shapes" and then enumerate **two** (nonexistent path, regular file). The third sub-case, `REPO_ROOT=''`, is deliberately **not** malformed — it is the documented no-op that behaves as unset, which is the whole point of the carve-out that scenarios 29c/30c/31c pin. So the sentence miscounts by folding a deliberate non-malformed case into the malformed set. **Behaviour and pinning are correct and were independently verified**: the reviewer ran 9 mutations (M1-M8 plus a full revert) and each reddened exactly the predicted cell, with `''`-is-unset pinned in all three implementations by M4/M5/M6. Fix shape: reword to "two malformed shapes plus the deliberate `''` no-op", in both places. Fold into whichever PR next touches the file. `harness_gap: NONE`. (source: 2026-08-14 run 2 qc-behavioral on PR #2328) **Fixed:** the miscount was confirmed still present on main at the time of this PR (only one in-repo occurrence, the scenario-29 comment preceding the `BOGUS_MISSING29`/`BOGUS_FILE29` fixture setup — the PR #2328 body itself is immutable and out of scope). Reworded to "The two malformed REPO_ROOT shapes filed against this defect, plus the deliberate `''` no-op: ... REPO_ROOT='' (pinned separately below as scenario 29c) is NOT malformed — it is the documented no-op that behaves as unset." Comment-only change, no behaviour or test change. Verify: `dev/lib/run-in-env.sh dune runtest devtools/checks`. (fixed 2026-08-15 harness-maintainer on harness/audit-disable-count-docstring)

## Added 2026-08-10 (harness-maintainer, harness/audit-record-fidelity)

- [x] H-AUDIT-HARNESS-GAP-DROPPED-ON-APPROVED: Filed in `dev/daily/2026-08-09-run2.md` (demonstrated live on #2251: qc-behavioral filed a real `LINTER_CANDIDATE` and the PR still ended APPROVED after rework, so the gap was discarded precisely because the review process worked). `write_audit.sh` silently dropped `--harness-gap` whenever `--overall` was `APPROVED` (a `WARNING:` to stderr, then `HARNESS_GAP=""`), even though the JSON body always emitted a `"harness_gap"` key — so the record was written with an empty field and no trace a value had been supplied. **Root-cause reframe (this fix, not the original filing):** a harness gap is a statement about the harness ("here is a check the automation should have but doesn't"), not about the verdict the review happened to land on. Dropping it on APPROVED biased the harness-gap corpus toward findings review never recovered from — the opposite of the population a "what should we automate" read wants to see. **Fix:** removed the drop-on-APPROVED block entirely in `trading/devtools/checks/write_audit.sh`; `--harness-gap` is now recorded verbatim regardless of `--overall`. **Read-side consumer check (per the brief's explicit instruction to verify before changing the writer):** grepped the tree for every reference to `harness_gap` outside this script, its test, and review-body prose — **no consumer reads the JSON `harness_gap` field at all today**. `deep_scan/check_06_qc_calibration.sh` never references it; `record_qc_audit.sh` never populates `--harness-gap` in the first place (confirmed by grep — the orchestrator's Step 5 Stage 4 call in `lead-orchestrator.md` doesn't pass it either). So there is no existing verdict-scoped assumption anywhere that needed updating in tandem — the "filter at read time instead" fallback the brief offered turned out to be moot because there is no read time yet. **Regression coverage:** `record_qc_audit_test.sh` scenario 18b (new) asserts a `--harness-gap` value passed alongside `--overall APPROVED` survives into the JSON record with no `WARNING:` line; scenario 18c (new, control) pins the pre-existing NEEDS_REWORK path is unaffected. **Mutation-tested live:** reverted only the `write_audit.sh` fix (keeping the new test scenarios) — 18b failed exactly as expected (`got rc=0` but the WARNING/empty-field regex matched, i.e. the gap was dropped); every other scenario, including 18c, still passed. Restored — 39/39 green. **"Before" measurement (per the brief):** ran the *original* (pre-this-PR) `record_qc_audit_test.sh` — which has no 18b/18c — against the *original* (pre-fix) scripts: exit 0, 34/34 passed. Confirms the bug was genuinely invisible to the existing suite, not merely under-asserted. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (39 assertions/scenarios, was 37 before this PR).

- [x] H-AUDIT-REWORK-COUNT-BLIND: Filed in `dev/daily/2026-08-09-run2.md` (demonstrated live on #2251: `consecutive_rework_count=0` recorded for a PR that took a rework). **Mechanism, re-derived from source for this fix (sharper than the daily-summary framing):** `write_audit.sh`'s `OUTPUT_BASENAME` is keyed on `<date>-<branch-sanitized>-<feature>.json` only (H-AUDIT-COLLISION's fix disambiguates two *different* branches on the same day, but not two *different reviews of the same branch* on the same day). A rework cycle — NEEDS_REWORK at tip A, fix pushed, APPROVED at tip B, same branch, same day, which is exactly what the orchestrator's Step 5 Stage 4 produces once per QC pass — computes the **identical** `$OUTPUT_FILE` for both calls, so the second (APPROVED) call's atomic `mv` silently destroys the first (NEEDS_REWORK) record before the `consecutive_rework_count` scan a few lines further down ever gets a chance to see it. Net effect: a same-day, same-branch rework streak can never exceed `consecutive_rework_count=1`, no matter how many times the branch is actually reworked — making Step 5a's `>=3` human-escalation trigger unreachable via intra-run reworks, exactly the signal it depends on. **Fix (SHA-keyed identity, chosen over the iteration-counter alternative):** both QC agents already guarantee `Reviewed SHA: <sha>` as the first line of every PR review comment body and every `dev/reviews/<feature>.md` review pass (`qc-structural.md`/`qc-behavioral.md` "Reviewed SHA" contract) — a pre-existing, load-bearing convention, not new plumbing. `record_qc_audit.sh` now extracts the LAST such occurrence (mirroring the existing "last occurrence wins" convention already used for `overall_qc`/quality-score), truncates to 12 chars, and passes it to `write_audit.sh` as a new optional `--sha` flag, unconditionally (both APPROVED and NEEDS_REWORK calls — same "identity metadata should never be gated on verdict" principle as the harness-gap fix above). `write_audit.sh` stores it in a new `"sha"` JSON field and, **before** writing, checks: if `$OUTPUT_FILE` already exists AND its stored `sha` is non-empty AND differs from the new non-empty `--sha`, the existing record is `cp -p`'d aside to a `<date>-<branch>-prev<old-recorded-at-ns>-<feature>.json` name (still ending `-<feature>.json`, preserving both `dev/audit/` glob consumers) **before** the canonical name is overwritten — this runs ahead of the `consecutive_rework_count` scan specifically so the scan picks up the preserved copy under its new name with zero changes to that scan's own logic. When either side's sha is empty or they match, behavior is the pre-fix overwrite (true idempotency for a retried invocation of the *same* review, e.g. a transient `gh` failure retry) — deliberately preserved, not broken. **Filename scheme left unchanged by default** (only what happens at an actual collision) — this is why the blast radius stayed small: **35 of the pre-existing suite's 37 scenarios were unaffected** (they never collide — unique branch/date per call); only scenario 7b (idempotency) and 7c (empty-branch fallback) needed updating, because their own fixtures already encoded a `Reviewed SHA` change between calls to the same branch/date, which is precisely the rework shape this fix protects. **Backward compatibility with existing `dev/audit/` records (~106 at last count):** the collision guard only activates when BOTH the existing record's `sha` field and the new `--sha` are non-empty — pre-fix records have no `"sha"` key at all, so `OLD_SHA` extracts empty and the guard falls through to the unchanged overwrite path; no existing record is renamed, reread, or reinterpreted by this change. Direct `write_audit.sh` callers that never pass `--sha` (any caller written before this PR, or any future ad-hoc invocation) are **100% unaffected** — pinned by new scenario 7f. **Regression coverage** (`record_qc_audit_test.sh`, +2 scenarios net over the pre-existing 28, restructured 7b, replaced 7c's assertions): 7b now specifically exercises SAME-branch-SAME-sha (true idempotency, unchanged outcome); 7d (new) exercises SAME-branch-DIFFERENT-sha (the actual bug) and asserts all three records survive (JSON7A now the rework's APPROVED content, JSON7B untouched, plus the preserved NEEDS_REWORK record found by content, not by a hardcoded filename); 7e (new) directly exercises the escalation-relevant case — three consecutive same-day NEEDS_REWORK calls on one branch (three distinct shas) and asserts `consecutive_rework_count=3` on the third, the exact case the daily summary says is unreachable pre-fix; 7f (new) pins the no-`--sha` backward-compat path; 7c's assertions were updated in place (from "1 file, second wins" to "2 files, both survive") since its own fixture already used two different shas — the fix incidentally narrows that scenario's previously-documented gap too (data no longer lost even without branch info, though the preserved filename still doesn't carry branch identity — noted honestly in the updated scenario comment, not claimed as fully closed). Also added scenario 18b/18c cross-references are unrelated (harness-gap fix, separate commit). **Mutation-tested live:** ran the FULL NEW test file against the ORIGINAL (pre-fix) `write_audit.sh` + `record_qc_audit.sh` — result **35 passed, 4 failed**, and the 4 failures were precisely `7d`, `7e`, `7c` (this defect) and `18b` (the other defect, confirming the two fixes are independently detected by their own scenarios and don't rely on each other); `7b` and `7f` still passed unmutated, confirming the mutation didn't collaterally break the idempotency/backward-compat paths it wasn't supposed to touch. **"Before" measurement:** ran the *original* (pre-this-PR) test file — which had no 7d/7e/7f and the old 7b/7c assertions — against the *original* (pre-fix) scripts: exit 0, 34/34 passed, confirming the bug was genuinely invisible to the existing suite. Restored the fix — 39/39 green, byte-identical to the intended fixed files (diffed against saved copies after the mutation round-trip). Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (39 assertions/scenarios). **Scope note:** left `H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH` and any audit-script rewrite untouched per explicit dispatch instructions — this PR is a two-defect fix, not the "eight known defects, rewrite both scripts" decision the 2026-08-09 daily summary raised; that question is still open for a human/orchestrator call.

## Added 2026-08-17 (harness-maintainer, harness/audit-sha-file-leak rework)

- [x] H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED: Filed by qc-behavioral as residual R1 on PR #2359's rework (2026-08-17), NOT built there — reviewer explicitly recommended filing rather than fixing, since the PR's scope is the extractor guard alone. `write_audit.sh` makes `--sha` the identity key for `consecutive_rework_count` (see the "The optional --sha ... is the identity key" docstring paragraph); the preserve-a-prior-record guard fires only when `[ -n "$OLD_SHA" ] && [ -n "$SHA" ] && [ "$OLD_SHA" != "$SHA" ]`. The counter itself is well pinned (scenarios 7e -> count 3, 8 -> streak broken -> 1, 9 -> 2, 21 -> 2), and the SHA-to-preservation-to-counter link is pinned by 7c/7d. **What was missing:** nothing pinned the *leak -> wrong streak* composition end-to-end — scenario 39 (H-AUDIT-SHA-FILE-LEAK) stopped at asserting the `sha` field is `""`, never carrying that empty value forward through a second/third NEEDS_REWORK pass to check the resulting `consecutive_rework_count`. **Fixed:** added scenario 40 to `record_qc_audit_test.sh` — three consecutive PR-mode `record_qc_audit.sh` calls (same feature/branch/date), each with a `STATE:CHANGES_REQUESTED` review body carrying no `Reviewed SHA:` line, with the same foreign-sha companion `dev/reviews/<feature>.md` present throughout. Asserts, on the third call's resulting JSON record: `sha` stays `""`, `overall_qc` is `NEEDS_REWORK`, exactly one audit file exists for the (date, branch, feature) triple (no preserved-aside copy), and — the composition claim — `consecutive_rework_count` stays **1**, not 3. That is the correct, honest result, not merely "what the code happens to do": an empty `--sha` on both sides of the identity check degrades to the pre-fix overwrite behavior (mirrors scenario 7f for a direct caller), so every one of the three calls computes the identical `$OUTPUT_FILE`, and the `consecutive_rework_count` scan explicitly excludes the file it is about to overwrite ("Skip the file we are about to write" in `write_audit.sh`) — so each call's immediate predecessor is invisible to the scan by construction, and the streak stays at 1 through this path **within a single date for a single branch** (`$OUTPUT_FILE` embeds `$DATE`, so this degrade is a same-date-only property — see below). This is `H-AUDIT-REWORK-COUNT-BLIND`'s pre-existing, documented empty-SHA gap, now pinned at the consumer field (`consecutive_rework_count`) instead of only at the producer field (`sha`). **Scope correction (this rework, iteration 1 of 2, qc-behavioral R2):** the original completion note here (and the PR body/commit message) stated the cap unqualified — "the streak can never exceed 1 through this path" — which is false outside the same-date cell and dropped the #2339 consequence the original *filing* text had correctly stated. qc-behavioral measured directly (mutation probe, not asserted by any scenario): 6 consecutive same-date empty-sha calls hold the streak at 1 every time (confirms scenario 40's 3-call cap is a real property, not a fixture artifact); the same calls spread across 4 successive dates accumulate 1 -> 2 -> 3 -> 4 — this rework's scenario 41 mechanically pins the 2-date slice of that (1 -> 2) — because `consecutive_rework_count`'s scan globs `*-<feature>.json` across *all* dates, not just the current one, so a different `$DATE` (different `$OUTPUT_FILE`) makes the prior date's record visible to the scan instead of self-excluded. **Correct statement: the empty-sha degrade caps the streak at 1 within a single date for a single branch, but the streak is NOT capped across dates — so #2339's `>=3` human-escalation trigger IS reachable through this path, firing on the third consecutive day of reworks (not the third consecutive call within a day).** Added scenario 41 to mechanically pin the cross-date half: two consecutive empty-sha PR-mode NEEDS_REWORK calls on successive dates, same branch — asserts `consecutive_rework_count` accumulates 1 -> 2, not staying pinned at 1. Also fixed a CP3 finding on scenario 40 itself (qc-behavioral R1): its `grep -q '"consecutive_rework_count": *1'` assertion was prefix-loose (matches `": 10"`, `": 11"`, ...) and passed even when the reviewer forced the streak to 10 live; anchored to the trailing comma the JSON always emits (`*1,`) and restored the companion stdout assertion (`consecutive_rework_count=1` in the CLI output) that every sibling count scenario (7e/8/9/21/22) pairs with its JSON grep — re-verified live that forcing the degrade-path streak to 10 now reddens scenario 40 (and 41). **Mutation-tested live:** changed the scan's self-basename-exclusion guard (`if [ "$basename_f" = "$OUTPUT_BASENAME" ]; then continue; fi`) to `if false; then continue; fi`, which lets each call's still-on-disk predecessor (same filename, pre-`mv`) count itself toward the streak. Result: 56 passed, 2 failed — scenario 40 (`consecutive_rework_count` came out 2, not the pinned 1) and the pre-existing scenario 7e (came out short of the pinned 3). Reverted (files byte-identical to the pre-mutation copy via `diff`) — full suite back to 58 passed, 0 failed (pre-rework baseline; 59 passed, 0 failed after this rework's scenario 41 addition). No production code changed; this is a test-only addition. Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (59 assertions/scenarios, was 57 before this PR, 58 before this rework). `harness_gap: NONE` (fixed, not deferred). (fixed 2026-08-17 harness-maintainer on harness/rework-count-composition; reworked 2026-08-17 iteration 1 of 2 per qc-behavioral R1/R2)

## Added 2026-08-20 (harness-maintainer, harness/sexp-default-drift-linter)

- [x] H-SEXP-DEFAULT-DRIFT-LINTER: New check — `trading/devtools/sexp_default_drift_linter/sexp_default_drift_linter.ml` — closes a defect class that compiles green and no prior linter/CI gate caught: `[@sexp.default ...]` attributes are invisible to OCaml signature matching, so a record type declared more than once (an `.mli` re-declaring another module's record via `include` + independent redeclaration, e.g. `weinstein_strategy.mli`'s `config` vs `weinstein_strategy_config.{ml,mli}`'s `config`; or an ordinary `.ml`/`.mli` pair) can carry a different default per copy while the build stays green. Hit twice: #2384 (`entry_order_max_rest_weeks`, promoted 0->26 in the `.ml`, `.mli` left stale — already reverted to 0 on `main` by the time this landed) and #2388 (`stale_exit_after_days`, `.mli` said `[@sexp.default None]` while both other copies said `[@sexp.default Some default_stale_exit_days]` = `Some 5`).
  - **Population scan (the ask's real deliverable):** the dispatcher's raw `grep -c '\[@sexp\.default'` per-file counts were claimed as 63/64/61 (`weinstein_strategy.mli`/`weinstein_strategy_config.mli`/`weinstein_strategy_config.ml`); re-measured live it's actually **63/63/61** (the dispatch prompt's 64 for `weinstein_strategy_config.mli` is off by one against the checked-out `main` tip). None of these raw counts are the record population — they count every `[@sexp.default ...]` attribute in each file across ALL record types declared there, not one record's field count. `liquidity_config.ml`/`.mli` is a **separate, single-declaration record** (`Liquidity_config.t`, opaque in its own `.mli` — 0 sexp.default there — referenced as a field *of* `Weinstein_strategy_config.config`, not a duplicate of it) — correctly excluded. The true duplicate-record population, computed AST-side (compiler-libs `Ptype_record` extraction) across every `lib/*.ml`+`lib/*.mli` in the repo, grouped by `(type_name, ordered field-name list)` — the exact invariant the compiler already enforces whenever two declarations are linked by `include`+redeclare or by a module's own `.ml`/`.mli` pair — found: **1 real value-drift bug** (`config.stale_exit_after_days`, the confirmed #2388), plus **19 field-presence mismatches** (attribute present in one declaring file, silently absent in a sibling) that turned out to be near-entirely a pre-existing, intentional documentation-style choice (many modules' `.mli`s never repeat `[@sexp.default ...]` at all for a given type) rather than drift — refining the check to only compare declarations that carry **at least one** real attribute on the type in question (filters out whole-type opt-outs, keeps partial-adoption cases where the type IS documented but one field's attribute was specifically dropped) cut this from 19 to **2** genuine findings, both in `trading/portfolio/lib/margin_config.ml`/`.mli` (`t.short_borrow_rate_tiers`, `t.short_maintenance_tiers` — feature code, not fixed here, see follow-up below). `entry_order_max_rest_weeks` (#2384) was NOT a live violation on `main` at dispatch time — it had already been reverted to `0` in all three copies.
  - **Fixed in this PR:** `trading/trading/weinstein/strategy/lib/weinstein_strategy.mli`'s `stale_exit_after_days` field — `[@sexp.default None]` -> `[@sexp.default Some default_stale_exit_days]` (matches `weinstein_strategy_config.{ml,mli}`), plus corrected docstring prose. Closes #2388. Purely decorative/documentation change — the attribute is not evaluated at compile time (confirmed: neither `.mli` needs the constant in scope), so this carries zero runtime-behaviour risk; `default_config.stale_exit_after_days` was already `Some 5` and remains unchanged.
  - **Exempted, not fixed (feature code, out of harness-maintainer scope):** `trading/portfolio/lib/margin_config.{ml,mli}` `short_borrow_rate_tiers`/`short_maintenance_tiers` — two `sexp_default_drift` entries added to `trading/devtools/checks/linter_exceptions.conf` with `review_at: 2026-09-20`; the `.ml` and its own `default_config` already agree with each other (`[@sexp.default []]`, `= []`), so this is an incomplete `.mli`, not a live contradiction. Tracked as a follow-up below.
  - **Design decisions (per the dispatch's explicit asks):** (1) grouping key is `(type_name, ordered field-name list)`, not path/filename — this is exactly what the OCaml compiler already forces to be byte-identical whenever two declarations are linked, so a group with >1 distinct declaring file is a confirmed duplicate, never a coincidence (verified: zero accidental cross-module collisions in the full-repo scan). (2) A field with no `[@sexp.default]` in one declaration vs. one in another IS treated as a mismatch (the #2384-if-dropped shape) — but only between declarations that are "opted in" (carry >=1 real attribute somewhere on that type); an all-fields-undocumented `.mli` is treated as a deliberate style choice, not silence-by-omission. (3) Named-constant defaults (e.g. `default_stale_exit_days`) are resolved via a repo-wide table of simple top-level `let name = <literal>` bindings before text comparison, specifically to avoid the false-positive class the dispatch flagged (`[@sexp.default 5]` vs `[@sexp.default default_stale_exit_days]` comparing unequal); a name defined with two different literal values anywhere is dropped from the table (unresolvable) rather than guessed at.
  - **Proof (all three acceptance points measured live, not asserted):** (a) fires on #2388 as it existed on `main` pre-fix (`config.stale_exit_after_days`, `.mli: Some 5` post-const-resolution vs `weinstein_strategy.mli: None`). (b) fires on a reconstructed #2384 — `weinstein_strategy.mli`'s `entry_order_max_rest_weeks` temporarily edited `0`->`26`, linter reddened citing the exact 3-file divergence, reverted, linter green again. (c) green on `main`-equivalent tree once #2388 is fixed and the 2 margin_config fields are exempted — `dune build && dune runtest` both exit 0, no `FAIL:` lines.
  - Wired into `dune runtest` via `trading/devtools/checks/dune` (scans `lib/*.ml` + `lib/*.mli` workspace-wide via `Sys.readdir`, same convention as `nesting_linter`/`fn_length_linter`). Verify: `dune runtest trading/devtools/checks/` — prints `OK: no sexp.default drift across duplicated record declarations.`; reintroducing either known-instance drift reddens it.
  - **Follow-up (not built here, feature-code scope):** fix `trading/portfolio/lib/margin_config.mli` to document `[@sexp.default []]` on `short_borrow_rate_tiers` and `short_maintenance_tiers` (matching the `.ml`), then remove the two `sexp_default_drift` exceptions from `linter_exceptions.conf`. `review_at: 2026-09-20`. No behaviour change expected (the `.ml` and `default_config` already agree with each other) — a portfolio-track or code-health pickup, not a harness item.
  - **Correction (this rework, iteration 1 of 2, qc-behavioral B1/B2 2026-08-20):** two claims above were wrong, both caught by measurement rather than assertion.
    - **B1 — the `min_group_fields = 6` size floor (undocumented in the original PR) has been REMOVED, not just documented.** Measured live: of 909 record declarations extracted from the shipped tree, the floor silently dropped 614 (67.5%) before grouping, cutting multi-file duplicate-group coverage from 402 groups (no floor) to 134 (floor 6) — for **zero** precision gain: running with no floor at all produces the exact same 2 live findings (both already-exempted `margin_config` fields) as running with the floor, on the shipped tree, on a reconstructed #2384 (attribute dropped from 1 of 3 copies), and on a reverted #2388 (value mismatch reintroduced) — all three re-verified live post-removal. The linter's own grouping key — `(type_name, ordered field-name list)`, plus the `has_any_default` opted-in filter (>=2 declarations must each carry a real attribute before any comparison happens) — already makes a false-positive collision require an implausible coincidence (same type name, same exact ordered field list, `[@sexp.default]` on the same field in >=2 unrelated declarations, with different values); a size floor bought no additional protection against that and cost two-thirds of the check's coverage. The module docstring now documents this removal and the measurement behind it in place of the removed constant.
    - **B2 — the `liquidity_config.ml`/`.mli` exclusion rationale above ("separate, single-declaration record", "opaque in its own `.mli`", "0 sexp.default there") is FACTUALLY WRONG on both grounds and is superseded by this paragraph, not corrected in place (kept above, verbatim, for audit trail).** `Liquidity_config.t` is declared in BOTH `liquidity_config.ml` (line 28) and `liquidity_config.mli` (line 37) — a two-declaration, 5-field record, exactly the shape this linter is designed to check. The `.mli` is not opaque: it exposes the full record with prose-documented defaults per field. It carries 0 `[@sexp.default ...]` attributes; the `.ml` carries 2 (`adv_aggregation`, `adv_trim_pct`). It is correctly excluded, but by **the `has_any_default` opted-in filter** (only 1 of its 2 declarations is opted-in; the filter requires >=2) — not by being single-declaration or opaque. This matters beyond bookkeeping: `Liquidity_config` shipped in the same 2026-07-10 realism-defaults flip that produced the #2388 bug this linter exists to catch, and a future promotion of one of the `.ml`'s two defaults (e.g. `default_adv_trim_pct`) without updating the `.mli`'s prose is exactly the #2384/#2388 shape, in the adjacent record family — and today's linter would not fire on it, because only 1 of 2 declarations is opted in. If a future change adds even one real `[@sexp.default ...]` to the `.mli`, `opted_in` reaches 2 and the type starts being checked automatically, no code change required. Measured distribution across all 402 no-floor duplicate groups: 376 opted_in=0 (never compared, intentional-style), **6 opted_in=1 (blind spot — `Liquidity_config.t` is one of the 6)**, 19 opted_in=2 (compared), 1 opted_in=3+ (compared). This distribution is now recorded directly in the linter's module docstring next to the `has_any_default` filter.

- [x] H-SEXP-DRIFT-VACUOUS-PASS: `sexp_default_drift_linter.ml` prints `OK:` and
  exits 0 when it scans **nothing**. `collect_lib_files` swallows a failed
  `Sys.readdir` (`| exception _ -> ()`, line 137) and the reporting branch keys
  only on `live_violations = []` (line 472) — so an empty root, a moved
  `trading/` dir, or a wrong-cwd invocation is indistinguishable from a clean
  tree. **Masking consequence:** the check would report green across a rename or
  a dune-rule path change while enforcing nothing, which is precisely the
  vacuity shape #2424 / #2390 hit. **Fix:** fail (or at minimum warn loudly) when
  the scanned-file count is 0, and assert a plausible floor. `review_at: 2026-09-20`.
  - **Fixed:** added `validate_root_readable` (explicit "does not exist" /
    "not a directory" / "not readable" messages for the `trading-root` CLI
    arg) and a `min_expected_lib_files = 500` floor, checked by
    `_check_scan_integrity` right after `collect_lib_files` runs and before
    any drift comparison. Floor was chosen from the measured current count
    on the shipped tree (862 `lib/*.ml` + `lib/*.mli` files, confirmed live
    via `find`), leaving ~40% headroom so ordinary file deletions don't
    trip it while an empty/absent-root scan (0 files) or a drastic
    wrong-cwd undercount still does. The `OK:` line now also prints the
    scanned file count on every green run. Mutation-verified live: with the
    fix reverted (`git stash`), both an absent root and an existing-but-empty
    root exited 0 with `OK:`; with the fix applied, both exit 1 with a
    specific message. Self-test:
    `devtools/sexp_default_drift_linter/test/test_scan_integrity.ml`
    (process-level smoke test following the pattern in
    `devtools/cc_linter/test/test_no_overwrite.ml` — shells out to the
    built `.exe`, asserts exit code + message substring on both failure
    modes). Verify: `dune runtest devtools/sexp_default_drift_linter/`.
    (fixed 2026-08-21 harness-maintainer on harness/sexp-drift-vacuity,
    commit `19910274`)
  - **Rework (CP4, qc-behavioral review 4993747068, 2026-08-21):** the fix
    above left one instance of the same disease alive. `walk`'s inner
    `Sys.readdir` failure handler (`| exception _ -> ()`) was untouched by
    the vacuity-guard fix, and the module docstring claimed "either way the
    run is loud, never a silent `OK: nothing to report`" — false for any
    partial loss that stayed above `min_expected_lib_files`. Reproduced
    live: an 820-file fixture (520 readable `lib/*.ml` + 300 behind an
    unreadable subdirectory) printed `OK: ... (scanned 520 files)` and
    exited 0, silently dropping 300 files' worth of coverage. **Fix (option
    (a), the reviewer's preferred fix):** `collect_lib_files` now returns
    the failed directories alongside the collected files instead of
    swallowing the exception; `_check_walk_failures`, wired into `main`
    right after `_check_scan_integrity` and before parsing, names every
    directory that failed to read and exits 1, independent of how many
    files were lost under it. The `min_expected_lib_files` and
    `validate_root_readable` docstrings were corrected to state the actual
    bound honestly (the floor alone tolerates a large partial loss; walk
    failures are now caught by a separate, unconditional mechanism instead)
    rather than repeating the "always loud" overclaim. Mutation-verified
    live: with `_check_walk_failures failed_dirs;` replaced by
    `ignore failed_dirs;` in `main`, the new self-test goes red (`FAIL:
    fixture with an unreadable directory exited 0`); restored, it passes.
    Self-test: `devtools/sexp_default_drift_linter/test/test_walk_failure_reporting.ml`
    (same process-level pattern as the sibling self-tests; invokes the
    linter as the unprivileged `nobody` account via `setpriv` when the test
    process itself is root, since `chmod 000` alone is a no-op under root —
    confirmed live by the reviewer's own repro). Verify:
    `dune runtest devtools/sexp_default_drift_linter/`. **Residual, by
    design, not filed as a new item:** a partial loss from some OTHER cause
    that never raises inside `walk` (i.e. not a readdir failure and not a
    parse failure) is still caught only by the floor, and only once it
    exceeds roughly `scanned - min_expected_lib_files` files. No known
    failure mode currently produces that shape (every named failure mode —
    absent root, empty root, wrong-cwd, walk failure, parse failure — now
    routes through an unconditional check), so this is documented in the
    `min_expected_lib_files` docstring rather than tracked as an open item.
    The floor's 500 constant is also not re-measured automatically as the
    tree grows; documented as a docstring note (not built as an active
    check — would require its own linter, out of scope for this rework).
    (fixed 2026-08-21 harness-maintainer on harness/sexp-drift-vacuity,
    rework commit follows this entry)

- [x] H-SEXP-DRIFT-SILENT-PARSE-SKIP: an unparseable file is dropped with no
  signal — `parse_ml` / `parse_mli` end `| exception _ -> ([], [])`
  (lines 257 / ~266), so a file that fails `Parse.implementation` contributes
  zero records and the linter still exits 0. **Masking consequence:** a live
  `[@sexp.default]` divergence inside a file that the linter cannot parse is
  invisible, and the greenness is indistinguishable from real coverage. Note
  the linter parses source the compiler has *already* accepted, so this should
  be unreachable in practice — which is the argument for making it loud rather
  than for tolerating it. **Fix:** collect parse failures and report them
  (non-zero exit, or a printed count alongside the `OK:` line).
  `review_at: 2026-09-20`.
  - Both residuals were raised by qc-behavioral at `394069be` and re-raised at
    `3ac33c28` (CP2) because the PR body claimed them "now tracked" while the
    diff filed nothing. They are the reason CP4 passes on precedent
    (`fn_length_linter` / `nesting_linter` also ship without self-tests); filing
    them is what keeps that precedent honest.
  - **Fixed:** `parse_ml`/`parse_mli` now return a `parse_outcome` record
    carrying `parse_error : string option` instead of swallowing the
    exception; `_check_parse_failures`, wired into `main` right after
    parsing and before any drift comparison, prints every failing file +
    its exception and exits 1 (non-zero exit chosen over a warn-only count,
    per the finding's own "should be unreachable — argument for loud"
    framing). **This was NOT a hypothetical exercise: making parse failures
    loud immediately surfaced a real, previously-hidden bug** —
    `collect_lib_files` excluded `.pp.ml` ppx-preprocessed build byproducts
    but not `.pp.mli` ones. This linter runs as a dune rule whose sandbox
    mirrors the relevant slice of `_build/default/`, where `.pp.mli` output
    sits alongside real source in the same `lib/` dir; plain `lib/*.mli`
    globbing picked it up (inflating the scanned count to 1277, silently,
    pre-fix) and vanilla `Parse.interface` cannot parse it. Post-fix this
    would have failed every `dune runtest` invocation of the rule until
    `.pp.mli` was added to the exclusion alongside the pre-existing
    `.pp.ml` one — done in the same commit; re-verified the sandboxed
    invocation now reports 862 (matching the real source-tree count from
    the vacuity-guard fix), and full-repo `dune build && dune runtest` are
    clean (exit 0, zero `FAIL:` lines). Mutation-verified live: a fixture
    root with 520 trivial parseable `lib/*.ml` files plus one syntactically
    invalid file exits 1 post-fix, naming the broken file; the genuine
    pre-fix binary (before this PR) on the identical 521-file fixture exits
    0 with the same `OK: no sexp.default drift ...` line but **no
    scanned-count suffix** — that print is itself new in this PR, so it
    never appears in real pre-fix output. `OK: ... (scanned 521 files)` is
    reproducible only by removing the parse-failure guard from the tip
    (post-fix mutation testing, not the genuine pre-fix binary) — corrected
    here after qc-behavioral flagged the original wording as not literally
    reproducible. Self-test:
    `devtools/sexp_default_drift_linter/test/test_parse_failure_reporting.ml`
    (same process-level pattern as the vacuity-guard test; builds its own
    520-file fixture to clear `min_expected_lib_files` so the parse-failure
    path is exercised in isolation from the floor check). Verify:
    `dune runtest devtools/sexp_default_drift_linter/`. (fixed 2026-08-21
    harness-maintainer on harness/sexp-drift-vacuity, commit `61921c86`)

## Added 2026-08-21 (harness-maintainer, harness/gate-reader-2432)

- [x] #2432 defect 1 -- `_gate` in `dev/scripts/pr_gate_status.sh` used to pick
  the LAST matching review at a gate outright and trust its verdict alone.
  That is unsafe in exactly one direction: an earlier NEEDS_REWORK followed by
  a LATER APPROVED **at the same sha** (nothing "stale" about it) read
  straight through as `ok` -- PR #2423 merged past an unresolved finding this
  way. **Fix:** `_gate` now aggregates every CURRENT-tip review per gate
  (`review_result` extracts each review's own verdict + Reviewed SHA; a
  `$current` filter drops reviews whose sha does not match the tip). If all
  current reviews agree, that verdict stands unchanged (covers the
  overwhelming common case -- one review -- and the pre-existing "escalate to
  rework" direction, APPROVED then NEEDS_REWORK, which was never unsafe). If
  they disagree and the LATEST is `rework`, report `rework` (unchanged,
  matches the old behaviour, since escalating to a fresh finding is safe to
  surface). If they disagree and the latest is `ok`, report **`unclear`** --
  the new state -- rather than guessing whether the later APPROVED
  legitimately superseded the earlier finding or silently overwrote it.
  Confirmed live that text-matching can't reliably tell the two apart: PR
  #2452 (found the same morning as #2423) has the identical NEEDS_REWORK-then-
  APPROVED-at-the-same-sha shape, but the later review explicitly cited the
  prior review by id and re-verified its finding -- a genuine, correctly
  cured body-only fix. Both shapes are pinned as `unclear` by design (not
  `ok`, and not a permanently stuck `rework`): NEXT-ACTION reads `ADJUDICATE
  -- conflicting verdicts at <sha> (structural|behavioral)`, routing to a
  ~2-minute human read of both bodies instead of an automated guess either
  way -- exactly how #2452 was actually resolved.
  **Correction to the dispatch framing (verified live, both dash and bash, `gh`
  genuinely absent, `set -eu` in effect):** defect 2's originally-described
  symptom ("prints an empty table and exits 0") does not reproduce --
  `PRS=$(gh pr list ...)` DOES trip `set -e` on a failed command substitution
  in a bare assignment, in both shells. What the OLD code actually does is
  arg-dependent and still bad, just a different shape: no args -> dies at the
  `gh pr list` line itself (exit 127, raw `gh: not found`, no table header
  ever printed -- already non-zero, but no diagnosis, easy to mistake for a
  transient glitch); explicit PR numbers -> prints the header + separator
  FIRST (that branch needs no `gh` call), THEN dies on the first PR's `gh pr
  view` -- a misleading partial table followed by a crash. Reproduced both
  shapes directly against `origin/main`'s script in this exact environment
  before writing the fix.
  **Fix:** `_detect_backend` (new) checks explicitly, before any output, for
  `gh` on PATH, then `curl` + `$GH_TOKEN`; if neither is available the script
  exits 2 with a clear stderr message citing #2432 and the two remediation
  paths, before printing anything -- no header, no partial table, no crash
  cryptic enough to be mistaken for infra flake. Nice-to-have also landed (not
  just the required loud failure): `_list_open_prs_curl` / `_pr_meta_curl` /
  `_pr_checks_curl` implement the same three GitHub reads via `curl` + REST
  when `gh` is absent, reshaping each response into the same field names the
  `gh --json` backend produces so every downstream consumer (`_gate`,
  `_is_docs_only`, the do-not-merge label check) is backend-agnostic.
  `PR_GATE_STATUS_BACKEND=gh|curl` overrides auto-detection for testing.
  **Regression coverage:** `dev/scripts/pr_gate_status_test.sh` grew from 26
  to 39 assertions -- all 26 pre-existing ones pass unchanged (no regression
  in the intra-body disagreement machinery #2421/#2425 shipped). New: 3 unit
  cases for the multi-review aggregation (#2423 shape -> unclear, #2452 shape
  -> unclear, clean single APPROVED -> ok unchanged); 4 unit cases for
  `_detect_backend` (gh preferred, curl fallback, curl-without-token fails,
  neither fails); 3 end-to-end probes running the REAL script (stubbed
  `gh`/`curl` on a controlled PATH, no network) proving gh-backend
  `#2423`-shape reaches `ADJUDICATE` never `MERGE`, gh-backend clean-approvals
  reaches `MERGE`, and curl-backend (gh entirely absent) also reaches `MERGE`
  end to end -- plus 3 more pinning the loud-failure path (non-zero exit,
  stderr message present, table header never printed). Verify: `sh
  dev/scripts/pr_gate_status_test.sh` (39 assertions); `dash -n dev/scripts/
  pr_gate_status.sh` (posix_sh_check.sh coverage, wired into `dune runtest`).

  **Rework iteration 1 (qc-behavioral NEEDS_REWORK, review 4991549803) --
  test-and-docs only, no code-path change:**
  - **B1 (fixed):** both e2e stubs hardcoded `labels: []`, so none of the 39
    assertions ever exercised a non-empty label list -- meaning the
    **do-not-merge HARD hold** (`.claude/rules/pr-merge-gates.md` Rule 0, the
    guard whose absence let #2384 merge 30 min after being drafted, a
    **-40.91pp regression**, #2396) was the one curl-reshape field left
    unpinned. Fix: both stubs now take the label array from
    `GATE_LABELS_JSON` (default `[]`); two new e2e cases assert `HOLD --
    do-not-merge label` (never `MERGE`) at `pass/ok/ok` on **both** backends.
    Rule 0 is a real consumer of the curl reshape (line 662 above already said
    so; it just wasn't tested).
  - **B2 (fixed, docs + fixtures):** the `_gate` docstring claimed a sha-less
    review being "always-current" is "same as the single-review behaviour this
    replaces." **That was inverted.** Under the old last-review-wins reader a
    sha-less review was harmless (a later review always superseded it); under
    aggregation, always-current means current at every tip forever -- it can
    disagree with a later review and pin the gate to `unclear` unclearably.
    Live instance: PR #2397 carries `Reviewed SHA: 9346b3b` (7 chars, one
    short of the `{8,40}` capture bound, so it parses as no sha at all). Fixed
    the docstring in `pr_gate_status.sh` to say what the code actually does,
    and added `pr_gate_status_test.sh` cases 37-38 pinning it: a sha-less
    review reads identically at two unrelated tips (never goes stale), and the
    exact #2397 shape (two 7-char-sha reviews disagreeing) reads `unclear` and
    **stays `unclear`** even after a third, real, current-tip APPROVED is
    added. **Left as a known, documented limitation, not fixed in code** --
    widening the sha bound (e.g. to `{7,40}`) or excluding sha-less reviews
    from aggregation instead of treating them as always-current are both real
    fixes, but both are behavior changes to `_gate`'s matching logic, out of
    scope for a test-and-docs rework. **Open follow-up:** pick one of those two
    fixes in a follow-on PR.
  - **B3 (documented, no new mechanism):** qc-behavioral replayed old vs. new
    `_gate` over 166 real gate-matching reviews across the 35
    most-recently-updated PRs and measured the `unclear` base rate: **5 of 70
    gate reads flip `ok` -> `unclear`, 5 of 35 PRs (~14%)**. That headline
    still stands. **Correction (rework iteration 2, qc-behavioral review
    4991759359, F1): the original writeup here claimed "all five are the
    healthy terminal state of a completed rework loop" -- that was false, and
    the reviewer's own prior review helped seed it.** Only **four** of the
    five (#2417, #2437, #2448, #2452) are genuine rework loops -- each a
    NEEDS_REWORK cured by a later APPROVED at the same sha, headed "final
    pass" / "confirmation pass" / "re-review, body-only change" /
    "re-verdict". **#2397 is NOT a rework loop; it is a parse artifact.** Its
    tip DID move (`9346b3b` -> `de734f2d1960`), exactly as the process
    intends -- its `unclear` came from two gate-matching reviews carrying a
    7-character "Reviewed SHA", one character short of the (then) `{8,40}`
    capture bound, so both parsed as sha-less and were treated as
    current-at-every-tip-forever, permanently disagreeing with a real
    current-tip APPROVED that should have superseded them cleanly. **Stated
    plainly because it cuts against the fix: 1 in 5 observed `unclear`s was a
    one-character parsing bug, not a design tension -- which makes the
    ~14% false-positive rate LESS defensible, not more.** Zero blind-supersedes
    (the real #2423 shape) appeared in the window either way. The mechanism
    behind the other four is structural: qc-behavioral's own CP2 row
    (`.claude/rules/qc-behavioral-authority.md`) routinely produces PR-body-only
    findings, and curing a body-only finding cannot move the tip -- so the
    repo's own review checklist manufactures the flagged shape on the
    *success* path more often than on the *failure* path (#2423) the rule was
    built for. This measurement, and the fact that **`unclear` is terminal**
    (no number of later current-tip APPROVEDs clears it; the only exits are a
    tip-moving commit or an `--admin` merge past the reader -- the latter being
    precisely the habit that produced #2384 and #2423), is now recorded in the
    script header (`pr_gate_status.sh`, above `set -eu`), corrected in place.
    **Deliberately NOT done:** no `gate-adjudicated` label or other new
    sentinel was added. That would give the reader an in-band exit but adds
    new automation vocabulary to the merge-gate contract (Rule 0's own
    domain) -- a design decision for a human to make explicitly, not something
    to slip in as part of a test-and-docs rework. **Open question for the
    human:** should `unclear` get an in-band adjudication exit (e.g. a label),
    or does documenting the base rate + terminal behavior suffice for now?
  - **F2 (fixed, rework iteration 2):** the #2397 parse artifact itself is now
    fixed -- `_gate`'s `Reviewed SHA` capture bound widened from `{8,40}` to
    `{7,40}` hex characters, a pure parsing fix with no interaction with the
    `unclear` aggregation design (that design question, and the separate
    "exclude sha-less reviews from aggregation" alternative fix, remain
    deliberately deferred to the human per B2 above). Verified against the
    real PR: #2397's behavioral gate now reads `ok`, not `unclear`. Test cases
    37-38 in `pr_gate_status_test.sh` retargeted: case 37 (no SHA field at
    all) is unaffected and still pins sha-less-is-current-forever; case 38's
    two assertions previously pinned the *buggy* `unclear` result and now pin
    the *fixed* result instead (`stale(9346b3b)` at an unrelated tip, `ok`
    once a real current-tip APPROVED is added) -- retargeted, not weakened,
    because the fix necessarily changes what those two assertions must assert.
  - **F3 (fixed, nit):** the suite's closing `printf` hardcoded the total
    assertion count as a literal (`45`), which could silently drift from the
    real count as cases are added/removed (43 literal `check` calls vs. 45
    printed, because `check_backend_fails` is also an assertion entry point
    but greps differently). Fix: both `check` and `check_backend_fails` now
    increment a shared `total` counter; the closing `printf` prints `$total`
    instead of a literal.
  - **Verify (rework iteration 2):** `sh dev/scripts/pr_gate_status_test.sh`
    (45 assertions, count now derived from the `total` counter, not a
    hardcoded literal); `dash -n dev/scripts/pr_gate_status.sh` and
    `dash -n dev/scripts/pr_gate_status_test.sh` (posix_sh_check.sh coverage).
  - **Post-review probe (2026-08-22, qc-behavioral at 489b34a2):** the
    unparseable-verdict shapes are fail-safe under the new aggregation,
    verified by execution against the real `_gate`: unparseable + APPROVED at
    one SHA → `unclear`; APPROVED + unparseable → `unclear`; unparseable +
    rework → `rework`. None can reach `MERGE`. The "latest is unclear" case
    is not fixture-pinned (the aggregation's three documented branches omit
    it) — folded into the standing open question above about `unclear`
    adjudication. Same review also surfaced the practical cost: a body-only
    rework finding at an approved SHA would aggregate rework+ok → `unclear`
    terminally, which is why this very note rides a tip-moving commit.

## Added 2026-08-23 (harness-maintainer, harness/design-doc-drift-check)

- [x] design_doc_drift_mechanization (`dev/status/cleanup.md`) — new
  PR-time linter closing the recurring appendix-drift gap in
  `dev/plans/backtest-scale-optimization-2026-04-17.md`. Before building
  anything, re-measured the claimed drift by hand
  (`comm -23` between `ls -1 trading/trading/backtest/` (minus
  `lib/`/`test/`/`scenarios/`) and the appendix table's row names, on
  `main@e64f8655`): **zero drift** — PR #2461 (2026-08-21) had already
  reconciled it, 27 on-disk subdirs / 27 rows, exact match. The dispatch
  brief's claimed third-drift set (`trade_audit_report`, `tuner`,
  `validation`, `walk_forward`, `warmup_gate` allegedly missing) did not
  reproduce; all five already have rows. So this PR adds no appendix rows
  — it lands the mechanized check on an already-clean tree, closing the
  gap *before* a fourth drift can happen rather than reacting to one.
  Files: `trading/devtools/checks/backtest_appendix_drift_check.sh` (the
  check, wired into `dune runtest` via `trading/devtools/checks/dune`),
  `trading/devtools/checks/backtest_appendix_drift_check_test.sh` (9
  fixture scenarios: clean, missing-row, no-heading, no-rows,
  empty-backtest-dir, exclusions, section-scoped, outside-appendix,
  exclusion-not-broad). Distinct from the pre-existing
  `deep_scan/check_02_design_doc_drift.sh` backtest block: that one runs
  only on the weekly deep-scan cadence and is warning-only (`add_warning`,
  never fails the build; loose substring grep against the whole doc
  text). This new check runs on every `dune runtest`, requires an actual
  appendix TABLE ROW under the appendix heading (not just a text mention
  anywhere in the doc), and FAILs the build. Three vacuous-pass guards
  (appendix heading not found / zero table rows parsed / zero on-disk
  subdirectories after exclusions), each mutation-tested by hand: guard
  deleted from a scratch copy, re-run against the fixture that guard
  exists to catch, confirmed the result flips from FAIL to a false OK.
  Guard 3 alone flips "FAIL: found ZERO subdirectories ... expected
  several" to "OK: backtest_appendix_drift_check — 0 on-disk
  subdirectories ... all have an appendix row" when deleted — the exact
  "0 drifted, all good" failure shape the dispatch brief warned about, now
  reproduced and closed. Guards 1+2 (heading/rows) turned out to have a
  natural backstop from guard 3 + the diff logic under most conditions
  (an empty appendix-rows set with non-empty on-disk dirs still fails via
  the normal diff, just with a less specific message) — verified this
  directly rather than assuming it, and kept both guards anyway for the
  clearer diagnostic and as defense-in-depth; the combined
  all-three-guards-removed mutant (heading absent, backtest dir with only
  excluded subdirs) does reproduce a genuine silent OK. Verify:
  `dune build @devtools/checks/runtest --force` from `trading/` (both
  rules print `OK:`), or directly: `sh
  trading/devtools/checks/backtest_appendix_drift_check.sh` and `sh
  trading/devtools/checks/backtest_appendix_drift_check_test.sh`.

  **2026-08-23 rework (qc-behavioral NEEDS_REWORK, iteration 1, quality
  score 2/5 → addressed):** the reviewer found a real vacuous-pass gap and
  an unpinned headline claim, both now fixed. (1) The original appendix-row
  extraction ran "heading to EOF" rather than to the next `## ` section
  boundary — a later section (e.g. an "Appendix B") containing an unrelated
  table row was silently credited as an appendix row. Fixed to stop at the
  next `## ` heading; pinned by new scenario 7 (`section-scoped`).
  Reproduced the reviewer's exact fixture before/after: old logic → `OK ...
  2 on-disk subdirectories ... all have an appendix row` (exit 0, silently
  crediting a smuggled row); new logic → `FAIL ... smuggled/` (exit 1). (2)
  The script's differentiating claim over `check_02` (table row under the
  appendix, not a prose/whole-doc match) was true but unpinned by any
  scenario — added scenario 8 (`outside-appendix`: prose mention + a table
  row in an unrelated table before the appendix, neither satisfies the
  check). Also addressed the four non-blocking findings: corrected the test
  file's own header (it previously claimed all three guard deletions flip
  to a false OK; only guard 3 does — guards 1/2 flip the message but the
  suite stays FAIL via the normal diff backstop, which the PR body and this
  entry already stated correctly); added a header line making the
  check's one-directionality (missing-row only, not stale-row) explicit
  and citing PR #2461's measurement that the reverse direction has never
  occurred; added scenario 9 (`exclusion-not-broad`) pinning that
  `EXCLUDED_SUBDIRS` matching is exact, not substring; widened the row-name
  character class from `[A-Za-z0-9_]` to `[A-Za-z0-9_.-]` so a hyphenated
  subdirectory with a correct row would not be misreported as missing.
  Verify: `sh trading/devtools/checks/backtest_appendix_drift_check_test.sh`
  (prints "all 9 scenarios passed").

## Added 2026-08-24 (harness-maintainer, harness/audit-scenario22-diagnosability-2440, issue #2440)

- [x] **Scenario 22 (and sibling scenario 21) failure diagnosability** —
  issue #2440 reported that scenario 22 of
  `trading/devtools/checks/record_qc_audit_test.sh` failed in the
  `build-and-test` CI job with only `rc=0/0` in the message, unable to say
  which of the `if`'s remaining conjuncts broke. Re-measured first: on
  this run's runner (`main@2b11c60d`, GNU grep 3.7, Ubuntu), scenario 22
  did **not** reproduce — `bash trading/devtools/checks/record_qc_audit_test.sh`
  → `record_qc_audit_test: 60 passed, 0 failed`, exit 0, matching the
  orchestrator's own pre-dispatch measurement. So the fix here addresses
  the diagnosability gap the issue asked for; it does not (and cannot)
  confirm the original CI failure's exact trigger, which never
  reproduced locally.
  Added a `report_conjuncts()` helper (next to `pass`/`fail`) that takes
  alternating `<label> <0-or-1>` pairs and prints one
  `conjunct FAILED: <label>` line per broken conjunct — the label carries
  the actual observed value, not just the restated expectation (e.g.
  `"consecutive_rework_count==2 in JSON22 (actual: \"consecutive_rework_count\": 1)"`).
  Rewrote scenarios 21 and 22 (the two H-PREV-VERDICT-PIPEFAIL siblings —
  21 is the silent-skip/no-warning case, 22 is the loud-WARNING case) to
  evaluate each conjunct into a named `0`/`1` variable first, combine them
  via string concatenation instead of a literal `&&` chain, and call
  `report_conjuncts` from the `else` branch on failure. Both scenarios
  still pass unchanged (60/60 green).
  **Mutation-tested every conjunct** via a standalone driver (not
  committed — built in `/tmp`, applied mutations only to a **copy** of
  `write_audit.sh`, real source untouched throughout): for scenario 22,
  6 mutations (bad first-call arg, bad third-call arg, broken
  `CONSECUTIVE` increment, dropped `WARNING` line, `WARNING` without the
  path) each produced a `report_conjuncts` output naming exactly the
  conjunct(s) that mutation breaks, with the actual observed value
  inline — confirmed no false positives/negatives across all 6. Same for
  scenario 21 (2 mutations: broken increment, spurious `WARNING` on the
  tolerated exit-1 path) — both correctly isolated to the right conjunct.
- [x] **Latent bug found while diagnosing: `write_audit.sh`'s
  `consecutive_rework_count` scan silently loses records when `ls -1
  glob` matches only ONE entry and that entry is a directory** — verified
  live on this runner (not fixed here; filed below). The scan does
  `for f in $(ls -1 "$AUDIT_DIR"/*-"$FEATURE".json 2>/dev/null || true)`.
  GNU `ls`'s output format for this changes with the NUMBER and TYPE of
  glob matches: with 2+ matches including a directory, `ls -1` prints a
  `<dirname>:` header line (colon-suffixed) for the directory entry,
  which the `for` loop's word-splitting picks up as a bogus filename
  (verified: the real WARNING text scenario 22 currently produces reads
  `...unreadable-record-warns.json: (grep exit 2)` — note the trailing
  colon before ` (grep exit 2)`, from `ls`'s header format, not the real
  path; `grep -qF` in the test still matches because it's a substring
  check). But when the glob matches ONLY the directory (no sibling
  record file present), `ls -1 <dir>` lists the directory's CONTENTS
  (empty), producing **zero words** — the `for` loop never iterates, the
  directory-shaped record is invisible to the scan entirely, no WARNING
  fires, and `consecutive_rework_count` comes out silently
  under-counted. Reproduced directly: with only the unreadable directory
  present (no `feat/old` sibling), the third `write_audit.sh` call
  returns `consecutive_rework_count=1` with **no** WARNING at all —
  exactly the "unsafe direction" (silently under-counting the escalation
  streak) H-PREV-VERDICT-PIPEFAIL's own design note says must never
  happen silently. This is a genuine, environment-**independent**
  fragility (same GNU coreutils `ls` this whole run), distinct from the
  issue's suspected grep-behavior-differs-across-images cause, and a
  stronger candidate explanation for a future occurrence of #2440 than
  pure image drift — but it requires a specific state shape (audit dir
  has ONLY a directory-shaped record for a feature, no sibling file) that
  the CURRENT scenario 22 fixture never produces (it always seeds the
  `feat/old` sibling file first), so it does not explain the originally
  reported failure either. **Filed as a follow-up below rather than
  fixed here** — the fix (replace the `ls -1 glob` enumeration with a
  `find`-based one that doesn't depend on `ls`'s multi-arg formatting)
  is a real behavior change to a carefully-reviewed H-PREV-VERDICT-PIPEFAIL
  code path and deserves its own PR + its own regression scenario, not a
  bundled fix inside a test-diagnosability PR.
- [x] **Survey of other blind multi-conjunct assertions** — grepped
  `record_qc_audit_test.sh` for `if (...) && (...) && ...; then` shaped
  assertions across all scenarios: **~50 `if` blocks combine 2 or more
  `&&`-joined conjuncts under one pass/fail**, the same diagnosability gap
  #2440 flagged for scenario 22. A crude line-count survey is unreliable
  here (false `&&` matches inside embedded strings, e.g. scenario 23's
  `bash -c 'umask 077 && exec "$0" "$@"'` throws off any naive grep/awk
  count), so no attempt was made to produce an exact per-scenario count —
  that would need a manual per-block read, which is out of scope for this
  PR per the bounded-scope instruction. Fixed the two directly implicated
  by #2440 (scenarios 21/22, above); the remaining ~48 are filed as a
  tracked follow-up item immediately below rather than bulk-edited here.

- [ ] **Follow-up: apply `report_conjuncts()` to the remaining multi-conjunct
  assertions in `record_qc_audit_test.sh`** (filed 2026-08-24, from the
  survey above). `report_conjuncts()` now exists in the file (added by
  the #2440 diagnosability fix) and is proven correct by mutation testing
  on scenarios 21/22. Apply the same pattern to the highest-conjunct-count
  remaining scenarios first (spot-checked candidates in the 5-8 conjunct
  range exist throughout the file — re-verify exact counts by hand per
  block, the crude grep/awk survey above is not reliable for this). Do
  this as its own PR, scenario-by-scenario, each with its own
  mutation-test proof per the standard this file's H-PREV-VERDICT-PIPEFAIL
  entry and the #2440 fix were held to — don't bulk-transform without
  per-conjunct verification.
- [x] **Follow-up: `write_audit.sh` `consecutive_rework_count` scan's
  `ls -1 glob` fragility** — fixed 2026-08-24 (harness-maintainer,
  harness/scenario22-race-2440, issue #2440). This turned out to BE the
  root cause investigated for #2440, not just an adjacent bug found while
  diagnosing it — see the write-up under "Added 2026-08-24 (harness-
  maintainer, harness/scenario22-race-2440, issue #2440)" below for the
  full mechanism. One-line summary: `write_audit.sh`'s
  `consecutive_rework_count` prior-record scan replaced `for f in $(ls -1
  "$AUDIT_DIR"/*-"$FEATURE".json 2>/dev/null || true)` with `for f in
  $(find "$AUDIT_DIR" -maxdepth 1 -name "*-$FEATURE.json" 2>/dev/null ||
  true)`, mirroring the `_glob_count` helper's established convention in
  `record_qc_audit_test.sh` (H-AUDIT-GLOB-COUNT-GUARD-UNPINNED). Fixes
  both: (a) the sole-directory-match silent under-count this item
  originally described, and (b) a previously-undetected fragility in
  scenario 22 itself — it was passing for an ACCIDENTAL reason (`ls -1`'s
  directory-argument header format happening to produce a bogus
  colon-suffixed path whose ENOENT also exits 2), not the documented
  "grep hits a real directory" mechanism. New regression: scenario 50
  (sole-directory-match, no sibling file) — mutation-verified red
  pre-fix, green post-fix. Verify:
  `bash trading/devtools/checks/record_qc_audit_test.sh` (68 scenarios,
  was 61).

## Added 2026-08-24 (harness-maintainer, harness/scenario22-race-2440, issue #2440)

- [x] **Diagnosed and fixed the mechanism behind #2440's intermittent
  scenario 22 CI failure** — issue #2440 reported that
  `record_qc_audit_test.sh` scenario 22 failed once in CI
  (`build-and-test` on PR #2436, sha `b8f7511a8`), then passed on a
  bit-identical re-run of the same job at the same sha, and never
  reproduced locally across three separate environments (`trading-1-dev`,
  the orchestrator's own sandbox, a later GHA run). The prior PR (#2504)
  shipped per-conjunct diagnostics for scenarios 21/22 so the *next*
  occurrence would be a fact instead of a guess, but explicitly did not
  attempt a fix and left #2440 open.

  **Root cause found by tracing scenario 22's fixture through
  `write_audit.sh`'s prior-record scan, not by reproducing the CI
  failure directly** (still never reproduced on demand — see honesty
  note below). `write_audit.sh`'s `consecutive_rework_count` computation
  enumerates prior records for a feature with:
  ```
  for f in $(ls -1 "$AUDIT_DIR"/*-"$FEATURE".json 2>/dev/null || true)
  ```
  Scenario 22's fixture seeds two glob matches for one feature: a real
  file (`feat/old`, a valid NEEDS_REWORK record) and a directory
  (`UNREADABLE_PATH_22`, simulating a corrupted/unreadable record). GNU
  `ls`, given MULTIPLE positional path arguments where at least one is a
  directory, groups all plain-file arguments into one unheaded listing
  block, then prints EACH directory argument as its own `<name>:`
  header line (colon attached) followed by that directory's contents.
  Verified directly in `trading-1-dev` (both as the default `opam` user
  and as `root` — identical): `ls -1 file.json dir.json` prints
  `file.json`, a blank line, then `dir.json:`. The test's `for f in
  $(...)` word-splits that colon-suffixed header line into a WORD that is
  NOT a real path — `.../unreadable-record-warns.json:`, trailing colon
  included — which does not exist on disk.

  Two consequences follow, both confirmed live:
  1. **Scenario 22 was passing for the wrong reason.** The subsequent
     `grep -o ... "$f"` call on that bogus, nonexistent path fails with
     ENOENT — also grep exit code 2, the SAME exit code the scenario's
     own comment claims to be testing ("genuinely unreadable... GNU grep
     refuses with exit 2 -- 'Is a directory'"). The WARNING message that
     `write_audit.sh` prints echoes `$f` verbatim, so it still contains
     `UNREADABLE_PATH_22` as a text substring (the colon is just
     appended), which is enough for the test's `grep -qF` check to pass.
     Both the exit-code coincidence AND the substring-match coincidence
     had to hold for scenario 22 to stay green — the scenario was never
     actually exercising "grep hits a real directory," it was exercising
     "grep hits a nonexistent colon-suffixed path that happens to share
     an exit code and a text substring with the real one." This is
     environment-fragile by construction: it depends on `ls`'s exact
     multi-argument grouping/header behaviour, which is a real
     cross-version, cross-locale, cross-coreutils-implementation
     surface — precisely the kind of thing that could differ between an
     ubuntu-latest GHA runner image refresh and a long-lived dev
     container without any change to this repository's own code.
  2. **A second, independently-real bug** (already filed as a follow-up
     from PR #2504's diagnosis, closed by this same fix): when the glob
     matches ONLY a directory (no sibling file), `ls -1 <that-directory>`
     lists the DIRECTORY'S OWN CONTENTS (empty) instead of printing the
     directory's name — the for-loop iterates zero times, the corrupted
     record vanishes from the scan with NO warning at all. Reproduced
     live pre-fix (see scenario 50 below).

  **Honesty about what this does and doesn't establish:** the exact
  original CI failure was never reproduced under controlled conditions
  (rc=0/0 with one of the OTHER three conjuncts false — which one is
  unknown, since #2436's original run predates #2504's per-conjunct
  diagnostics). What this session establishes is a CONCRETE,
  demonstrated defect in the mechanism scenario 22 depends on: the test
  was passing by coincidence, not by design, and the coincidence rests
  on `ls` formatting behaviour that is not guaranteed stable across
  environments or coreutils versions. Fixing it removes that entire
  fragility class regardless of whether it was the literal trigger of
  the one observed failure, and it independently fixes a second,
  already-filed, root-cause-verified bug in the same code path. No
  chmod/permission-based mechanism is involved anywhere in this fix (the
  directory-based "unreadable" fixture was already root-safe -- `grep`
  reports "Is a directory" identically for `root` and non-root, verified
  live in both users -- so the root-bypass hypothesis from the issue's
  "prime suspects" list does not apply to this scenario as built).

  **Fix** (`trading/devtools/checks/write_audit.sh`): replaced the
  `ls -1 <glob>` enumeration with `find "$AUDIT_DIR" -maxdepth 1 -name
  "*-$FEATURE.json" 2>/dev/null || true`, mirroring the `_glob_count`
  helper's established convention in `record_qc_audit_test.sh`
  (H-AUDIT-GLOB-COUNT-GUARD-UNPINNED, added for the exact same bug
  class). `find` prints one matched path per line regardless of entry
  type or match count — no header, no grouping, so neither failure mode
  above can occur. Tagged `H-AUDIT-LS-GLOB-HEADER-UNSAFE`.

  **Regression coverage:**
  - Scenario 22's own comment block updated to record the accidental
    pre-fix mechanism, so a future reader doesn't re-derive it.
  - New **scenario 50**: a corrupted (directory) record that is the
    ONLY glob match for its feature (no sibling file) — asserts rc=0,
    `consecutive_rework_count=1`, and a WARNING naming the real
    (non-colon-suffixed) path. Mutation-verified: reverted only
    `write_audit.sh` to its pre-fix `ls -1` shape (keeping the new
    scenario) — scenario 50 failed exactly as predicted (67 passed, 1
    failed; the failure showed ZERO WARNING output, confirming the
    silent-drop bug live), while scenario 22 stayed green throughout
    (confirming it passes for the accidental reason described above,
    not the fix). Re-applied the fix — 68/68 green.
  - Stability: ran the full suite 20x in a loop inside `trading-1-dev`
    as the default user, and 20x as `root` (`docker exec -u root`) —
    all 40 runs green, `record_qc_audit_test: 68 passed, 0 failed` every
    time.

  Verify: `bash trading/devtools/checks/record_qc_audit_test.sh` (68
  scenarios, up from 61 after PR #2504).

## Added 2026-08-28 (harness-maintainer, harness/2567-silent-null-effectiveness, issue #2567)

- [x] **Mechanical guard for the "silent-null config thread" defect
  class.** qc-behavioral on #2563 named a recurring pattern: a
  `Weinstein_strategy.config` field threads into a sub-config (`Rs.config`,
  `Volume.config`, ...) via a `field = config.field2` copy, the thread is
  severable with the WHOLE SUITE staying green, and the failure mode is a
  silent null — an armed axis sweep measures the baseline and the
  experiment ledger records a REJECT for a mechanism that never ran (three
  prior instances: `Volume.config` #2459, the rt anchor knob, and #2563's
  `enable_rs_positive_declining`, each caught only by manual review, never
  mechanically). Per `.claude/rules/experiment-flag-discipline.md` Rule 4
  a terminal REJECT can get the mechanism's code deleted — so this defect
  class can delete working code on false evidence.

  **Plan-first, per the dispatch's design fork:** wrote
  `dev/plans/silent-null-effectiveness-2026-08-28.md` before any code,
  deciding between the issue's two enforcement options (a linter vs. a
  `qc-structural` convention row) via a real census rather than intuition.
  Grepped the two domain roots (`trading/trading/weinstein/`,
  `trading/analysis/weinstein/`) for the literal field-copy shape:
  **17 occurrence sites, 15 distinct field names, across 6 files** — not a
  handful, and NOT confined to `_config_for`-named adapters (`_run_screener`
  threads 3 of the 17 with no `_config_for` in its name, which would have
  been a false-negative gap even for a name-keyed version of option (a)).
  The two files with the most copies had 42 and 23 commits in the prior 60
  days — high, rising churn. Doing the census by hand also found a 16th,
  then-live gap on `main` (`entry_freshness_basis`, F1) — concrete evidence
  that per-PR vigilance had already failed a 4th time. **Decision: (a), a
  linter** — the convention-only path (b) relies on exactly the mechanism
  that had already failed three (now four) times.

  **Built** (`trading/devtools/checks/adapter_effectiveness_check.sh`):
  scans both domain roots (excluding `*/test/*`, `*/bin/*`) for the shape
  `<module-prefix>?field = config.field2[;]` — SHAPE-based (any function,
  not just `_config_for`-named ones), matching the false-negative the
  census found. For every unique `field2`, requires either an
  `EFFECTIVENESS-PIN: <field2>` tag in some `*/test/*.ml` file repo-wide,
  or an entry in the new `adapter_effectiveness_exceptions.conf`
  (mandatory `review_at`, same convention as `universe_deps_exceptions.conf`
  / `linter_exceptions.conf`). Wired into `dune runtest` via
  `trading/devtools/checks/dune` (mirrors the `check_universe_deps.sh`
  rule pair, both `(universe)`).

  **Closed the real gap the census found**: added
  `test_threads_entry_freshness_basis` to
  `test_stock_analysis_config_wiring.ml` (arms
  `entry_freshness_basis = Range_top_breakout`, asserts the built
  `Stock_analysis.config` differs) — before this PR, nothing in the suite
  would have caught that thread being severed. Retrofitted
  `EFFECTIVENESS-PIN` tags onto 5 more fields with pre-existing adequate
  tests (`overhead_supply`, `virgin_crossing_readmission`,
  `entry_anchor_local_range_weeks`, `resistance_min_history_bars` in
  `test_stock_analysis_config_wiring.ml`; `enable_rs_positive_declining` in
  `test_rs_trend_live.ml`, already a real downstream-behavior pin).
  Grandfathered the remaining 9 fields in
  `adapter_effectiveness_exceptions.conf` with `review_at` dates 30-45 days
  out (`neutral_blocks_longs`, `neutral_blocks_shorts`,
  `enable_slow_grind_short_gate`, `stop_width_mode`,
  `stop_width_size_down_max_pct`, `match_fraction`, `ret_epsilon`,
  `require_breakout_volume`, `insufficient_score`) rather than blocking
  this PR on retrofitting all 17 sites — per
  `.claude/rules/code-health-discipline.md`'s allowance for a bounded
  exception paired with dated follow-up, not an open-ended bump.

  **Found and fixed a real bug in the checker's own first run**
  (H-ADAPTER-PIN-LINEWRAP): `dune build @fmt --auto-promote` reflowed the
  `virgin_crossing_readmission` doc comment so `EFFECTIVENESS-PIN:` and
  the field name landed on different physical lines — a naive per-line
  `grep -E` missed it (false FAIL on a field that WAS genuinely pinned).
  Fixed by joining each test file's content before the pin search (so
  ocamlformat's wrapping can never split a tag from its field name), and
  pinned the fix with a dedicated fixture assertion (11) reproducing the
  exact wrapped-comment shape.

  **Acceptance verification (all against the real repo AND a synthetic
  fixture root, per the dispatch's "must not be vacuously green" bar):**
  - Positive control, REAL production code: hand-severed
    `entry_freshness_basis = config.entry_freshness_basis` to a hardcoded
    `Entry_freshness.Ma_cross` in `weinstein_strategy_screening.ml` —
    `test_stock_analysis_config_wiring.exe` went RED (`FAILED: ... Failures:
    1`) exactly on `test_threads_entry_freshness_basis`. Reverted; reran
    green (8/8).
  - Positive control, linter fixture: an unpinned fixture field-copy pair
    -> FAIL naming field + file:line (assertion 1).
  - Fixture root has both a violating case (assertion 1) and multiple
    conforming cases (assertions 2, 3, 7, 11) — never just the live,
    already-clean repo.
  - Mutation table (3 independent break-directions, `adapter_effectiveness_check_test.sh`
    assertions 8-9 run against a WORKING COPY of the real script, never
    the fixture data):

    | mutation | direction | result |
    |---|---|---|
    | fixture: add an untested field-copy pair | positive control | RED (assertion 1) |
    | narrow the field-copy regex to a literal nonexistent field name ("matches nothing") | detector self-check | RED->false-PASS, distinguishable message ("no field-copy lines found" vs. the real audit-pass text) (assertion 8) |
    | corrupt the pin-lookup tag prefix | detector self-check | previously-pinned field reverts to FAIL (assertion 9) |

  - `adapter_effectiveness_check_test.sh`: 10/10 assertions pass.
  - Full `dune build`: exit 0 (~1 min, warm cache). Full `dune runtest`:
    exit 0, 0 `^FAIL:` lines (~1 min). `dune build @fmt`: exit 0, no diff.

  Verify: `sh trading/devtools/checks/adapter_effectiveness_check.sh` (OK
  against current main); `sh
  trading/devtools/checks/adapter_effectiveness_check_test.sh` (10
  passed); `dune runtest trading/weinstein/strategy/test/` (includes the
  new `test_threads_entry_freshness_basis`).

  **Follow-ups** (tracked via the exceptions file's `review_at` dates,
  2026-10-01 / 2026-10-13): retrofit real `EFFECTIVENESS-PIN` tests for
  the 9 grandfathered fields. Also documented, not fixed: (a) a
  derived/conditional thread (e.g. `require_breakout_volume = not (...)`)
  is invisible to the regex — syntactic, not semantic; (b) a field-copy
  whose two halves are split across two lines by ocamlfmt is invisible to
  the SCAN (as opposed to the PIN lookup, which is now line-wrap-safe) —
  confirmed live on `enable_slow_grind_short_gate` in
  `weinstein_strategy_screening.ml`, documented in the script header and
  as a comment (not an active entry) in the exceptions file.

- [x] **H-ADAPTER-ASSERT8-LOG-STRING (R-1a)**: filed by qc-behavioral on the
  #2585 re-review (2026-08-28, non-blocking — the sole reason the score was
  held at 4 rather than 5). The R-1 descriptive correction stopped one line
  short. `adapter_effectiveness_check_test.sh`'s header now correctly says
  *"Do NOT cite assertion 8 as the mutation-proof"*, but the **runtime `ok`
  string at line 323 still prints** *"proving the real regex is
  load-bearing"* — the original non-sequitur (a mutation producing a *false
  PASS* shows the regex is fragile, not load-bearing), and it is in the copy
  that appears in **every CI log**. So the file contradicts itself with the
  wrong claim in the louder place. Fix shape: reword that one `ok` string to
  match the header — e.g. "assertion 8 — MUTATION A (regex narrowed to a
  nonexistent field name) produces the expected false-PASS message;
  characterization only, NOT the mutation-proof (that is assertion 1)".
  One-line prose change to a log string; no logic change; goldens and exit
  codes unaffected. Deliberately **not** folded into #2585: the PR already
  held a clean CI + double-APPROVED gate pinned to `7aada7ec`, and touching
  a script would have invalidated both verdicts and consumed rework
  iteration 2 of 2 for a log string. `harness_gap: NONE`.
  (source: 2026-08-28 run 1, qc-behavioral re-review of PR #2585)
  **DONE (2026-08-28, harness/2585-residuals-r1a-r5):** re-measured the
  claim before editing — the header (lines 35-58) already carried the
  correct framing and the `ok` string at line 323 was confirmed to still say
  "proving the real regex is load-bearing", exactly as filed. Reworded to
  "assertion 8 — MUTATION A (regex narrowed to a nonexistent field name)
  produces the expected false-PASS message; characterization only, NOT the
  mutation-proof (that is assertion 1)" — the exact text the finding
  suggested. One-line change, no logic touched. Lives at
  `trading/devtools/checks/adapter_effectiveness_check_test.sh:323`. Verify:
  `sh trading/devtools/checks/adapter_effectiveness_check_test.sh` (or
  `dune runtest trading/devtools/checks/`) — all 9 assertions pass, exit 0.

- [x] **H-EXPIRY-ROLLUP-SHARED-FN-ASSUMED (O2)**: filed by qc-behavioral on
  PR #2589 (2026-08-28 run 2) — the **only green-while-broken evasion found in
  13 independent attacks** on the new R-5 assertions. `_scan_exceptions_conf()`
  is shared by all three conf files, and the R-5 test fixture arms only
  `adapter_effectiveness_exceptions.conf`. A **per-label special-case inside
  the shared function** — e.g. `case "${label}" in Adapter*) : ;; *) continue ;;
  esac` before `add_warning` — kills the roll-up for `linter_exceptions.conf`
  and `universe_deps_exceptions.conf` while the whole suite stays **exit 0**.
  The R-5 script header argues the break "drops identically for all three
  files (the function is shared)", which is true of the accidental shape R-5
  actually observed and is a fair explanation of why that bug was systemic —
  but it reads as though the AE fixture therefore protects all three, and it
  does not. Requires a deliberate targeted edit, not the accidental shape, so
  it is a real but narrow residual. Cheap to close: the fake root already
  creates an empty `linter_exceptions.conf` (`:158`); put one expired line in
  it and add a second `^W: ` assertion for the `Linter exception expiry` label.
  `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-28 run 2, qc-behavioral on PR #2589, attack E2)
  **DONE (2026-08-30, harness/2589-expiry-o2-o3):** confirmed the evasion by
  hand first — applied the exact `case "${label}" in Adapter*) : ;; *)
  continue ;; esac` guard (via `awk`, inserted before the date-branch
  `add_warning` call) to a working copy of the real
  `check_11_linter_expiry.sh`, ran it against a fixture with an expired entry
  in BOTH `adapter_effectiveness_exceptions.conf` and (now-populated)
  `linter_exceptions.conf`: exit 0, AE roll-up line present, LE roll-up line
  silently gone — the exact evasion. Also confirmed a naive fix (asserting
  only `^W: Linter exception expiry:` with no fixture-name anchor) would have
  been vacuous: that pattern still matches the unrelated "Design doc ... not
  found" milestone-parse-warning line, which carries the same label prefix
  and survives the mutation. Added `trading/devtools/checks/
  deep_scan_linter_expiry_check.sh` Part 5 (5a positive assertion anchored on
  label + fixture name `fixture_stale_le_entry` + "has passed"; 5b
  mutation-proof re-applying the exact case-guard shape as MUTATION E,
  confirming exit 0 / AE-line-survives / LE-line-gone). Re-verified: applying
  the mutation to the finished suite → 5b's new assertion FAILs (red);
  reverting → suite passes (green, all 16 `OK:` lines, exit 0). Vacuity
  double-check: reworded the date-branch `add_warning` message text while
  preserving behaviour → 5a correctly fails closed (red), not vacuously
  green. Verify: `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh`
  or `dune runtest trading/devtools/checks/`.

- [x] **H-EXPIRY-ADDWARNING-SITES-UNPINNED (O3)**: filed by qc-behavioral on
  PR #2589. #2589's completion note declares two uncovered branches
  (missing-`review_at`, and the milestone branch ~`:166`) and **both
  declarations were verified accurate** — credit for stating them. But the
  real uncovered set is **two branches wider**: `_scan_exceptions_conf` has
  two further `add_warning` call sites nothing exercises — conf-file-not-found
  (`:113`, all three files exist in the fixture) and unrecognised-`review_at`
  -format (`:184`). The note is phrased non-exhaustively so it is not false,
  but the accurate summary is: **the date-expired branch is the only one of
  the five `add_warning` sites in this function that is pinned.**
  `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-28 run 2, qc-behavioral on PR #2589, observation O3)
  **DONE (2026-08-30, harness/2589-expiry-o2-o3):** re-verified all four
  gaps by hand first (each confirmed exit 0 / silent before adding its
  assertion). Pinned all four of `_scan_exceptions_conf`'s remaining
  `add_warning` sites, each with a positive assertion + an independent
  mutation-proof (delete that site's `add_warning` call, confirm the specific
  finding disappears while its sibling in the same fixture survives) in
  `deep_scan_linter_expiry_check.sh`:
  - `:113` conf-file-not-found — Part 6, new fixture omitting
    `universe_deps_exceptions.conf` entirely (all prior fixtures require the
    file to exist, since a missing file short-circuits the function via
    `return 0` before any entry is read).
  - `:161` milestone-unknown (manual review) — Part 6a, reuses the existing
    `AE_FAKE_ROOT` (no design doc there, so `CURRENT_MILESTONE_NUM` is
    already 0/unknown, matching production's unparseable-doc path).
  - `:166` milestone-landed (expired) — Part 6c, new fixture with a fake
    `docs/design/weinstein-trading-system-v2.md` declaring `Current
    milestone: M3` (mutually exclusive with `:161`'s precondition in the same
    fixture, hence the separate root).
  - `:184` unrecognised-`review_at`-format — Part 6a, same `AE_FAKE_ROOT`.
  All four assertions vacuity-checked by hand (benign reword of the
  production message, same behaviour) and confirmed to fail closed rather
  than passing vacuously. **Correction to this file's own accounting:** the
  five `add_warning` sites are `:113`, `:161`, `:166`, `:176` (date-expired,
  already pinned), `:184` — "missing-`review_at`" from the original #2589
  completion note is a SIXTH, separate branch (`_SCAN_MISSING`, lines
  ~130-137) that never calls `add_warning` at all; it only ever surfaces in
  the per-file `REPORT_FILE` "Missing review_at annotation" section, never in
  the roll-up. It was never one of "the five `add_warning` sites" despite
  reading that way in prior notes; filed as a new residual below
  (H-EXPIRY-MISSING-REVIEWAT-UNPINNED) since it remains genuinely untested by
  this suite.
  **Rework iteration 1 (2026-08-30, PR #2595 qc-behavioral NEEDS_REWORK,
  quality score 2):** qc-behavioral independently constructed and ran the
  identical per-label case-guard evasion
  (`case "${label}" in Universe-deps*) : ;; *) continue|return 0 ;; esac`,
  the mirror image of Part 5's `Adapter*` guard) at each of the four
  Part-6 sites and confirmed all four left the suite green — because every
  Part-6 fixture before this iteration only ever populated
  `universe_deps_exceptions.conf`, so nothing distinguished "the site fires
  for every conf file" from "the site fires for universe-deps specifically."
  Confirmed each of the four evasions by hand first (exit 0, silent), then
  closed all four by extending Part 5's mutation-proof pattern rather than
  narrowing the PR's "pin all 5" claim:
  - `:161` / `:184` — added a second, differently-labelled fixture entry to
    the existing `AE_FAKE_ROOT`'s `linter_exceptions.conf` (already present
    for Part 5's date-expired fixture) hitting the same two branches, plus a
    same-shape case-guard mutation-proof (6a2/6b2) restricted to
    `Universe-deps*` for each site independently.
  - `:166` — added a milestone-landed `linter_exceptions.conf` entry to the
    existing `MS_FAKE_ROOT` (6c2), plus the matching case-guard
    mutation-proof (6d2).
  - `:113` — extended `NF_FAKE_ROOT` to omit `linter_exceptions.conf` in
    addition to `universe_deps_exceptions.conf` (two missing files instead
    of one), so both conf-not-found labels fire; added the matching
    case-guard mutation-proof (6f2), using `return 0` rather than
    `continue` since this site runs before the `while` loop.
  Every new assertion also vacuity-checked (benign reword of its production
  message, call left in place, confirmed to fail closed). End-to-end sanity
  check: applied the real four-site `Universe-deps*`-only case guard
  directly to the production `check_11_linter_expiry.sh` and confirmed the
  full suite goes RED with an actionable diagnosis (missing
  `fixture_unknown_milestone_le`); reverted and confirmed green again.
  Verify: `sh trading/devtools/checks/
  deep_scan_linter_expiry_check.sh` (28 `OK:` lines, exit 0) or
  `dune runtest trading/devtools/checks/`.
  **Rework iteration 2 (2026-08-30, PR #2595 qc-behavioral re-review at
  `d83d1243`, NEEDS_REWORK, quality score 2):** iteration 1's per-label
  evasion class was confirmed fully closed (both reviewers independently
  re-checked, including a `conf_path`-keyed variant — also caught). The
  re-review escalated to a DIFFERENT mutation shape: deleting ONLY the
  `_SCAN_COUNT` increment at a site (leaving `add_warning()` and
  `_SCAN_DETAILS` intact) desyncs the roll-up `W:` line (still correct)
  from the `REPORT_FILE`'s own per-entry detail line, because the report's
  "### Expired or due-for-review entries" block is gated on the
  per-conf-file COUNT, never on `_SCAN_DETAILS` non-emptiness. Confirmed
  the gap by hand for `:161` (milestone-unknown), `:166` (milestone-landed),
  and `:184` (unrecognised-format): with the corrupted entry as the ONLY
  expired entry in its conf file, the section falls back to printing "No
  expired or missing review_at annotations found" while the roll-up
  finding survives unchanged — the exact green-while-broken shape the
  guard exists to prevent, and none of Part 6's assertions (all roll-up-only
  for these sites) would have caught it. Also confirmed the shape is
  MASKED by a fixture with >1 entry per conf file (a sibling entry's
  increment keeps the report's print gate open, so the corrupted entry's
  detail line still prints via the shared `_SCAN_DETAILS` accumulator) —
  which is why none of Part 6's multi-entry `AE_FAKE_ROOT`/`MS_FAKE_ROOT`
  fixtures exposed it even though they share the same underlying function.
  **Fix (Part 7, new):** added three fresh, deliberately single-entry-per-
  conf-file fixtures (`MU_FAKE_ROOT` for `:161`, reused `MS_FAKE_ROOT` for
  `:166`, `UF_FAKE_ROOT` for `:184`) and, for each, a `REPORT_FILE`
  exact-text detail-line assertion, a count-only-removal mutation-proof
  (confirms exit 0 + roll-up survives + detail line vanishes + report
  falsely says "No expired..."), and a vacuity reword check (confirms the
  assertion fails closed on a benign text change, not just a functional
  one). `:113` (conf-file-not-found) is **not applicable** to this
  corruption class — that branch returns before the per-entry loop, so
  there is no per-entry `_SCAN_COUNT` to corrupt independently of the
  `add_warning()` call itself; it remains fully covered by Part 6's
  existing call-deletion + vacuity tests. `:176` (date-expired) was
  previously closed only INCIDENTALLY — Part 3a's `REPORT_FILE` assertion
  happens to run against `AE_FAKE_ROOT`'s single-entry
  `adapter_effectiveness_exceptions.conf`, so the same corruption already
  failed it — and this rework makes that deliberate with an explicit
  count-only mutation-proof plus vacuity reword against the same fixture
  (Part 7g-7i), rather than leaving the coverage as an accident of an
  unrelated fixture's shape. The production `check_11_linter_expiry.sh`
  was never edited in place — every mutation in this suite (Parts 3-7)
  reads it via `sed`/`awk` into a separate generated copy, matching the
  file's existing convention, so there was nothing to revert; confirmed
  with `git status --porcelain` showing only the test file changed.
  Verify: `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh`
  (40 `OK:` lines, exit 0) or `dune runtest trading/devtools/checks/`.

- [x] **H-EXPIRY-MISSING-REVIEWAT-UNPINNED**: filed while closing O2/O3
  (2026-08-30). `_scan_exceptions_conf`'s "missing `review_at` annotation"
  branch (`check_11_linter_expiry.sh:130-137`, populates `_SCAN_MISSING` /
  `_SCAN_MISSING_COUNT`) never calls `add_warning` — it is invisible to the
  roll-up `W:` findings line entirely and only ever surfaces in the per-file
  `REPORT_FILE` "### Missing review_at annotation — policy violation T1-K"
  section. `deep_scan_linter_expiry_check.sh` has no assertion pinning this
  branch at all (structurally or functionally) for any of the three conf
  files. Note this is a different failure mode than the five `add_warning`
  sites O3 closed: a regression here would silently drop the per-file
  MISSING section from the report, not the roll-up warning — `main.sh`'s
  top-level "## Warnings" would stay unaffected either way since this branch
  was never wired into it. `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-30, harness-maintainer while closing PR #2589's O2/O3)
  **DONE (2026-09-01, harness/expiry-missing-reviewat):** confirmed the gap
  by hand first — deleted the two lines that populate `_SCAN_MISSING_COUNT`
  / `_SCAN_MISSING` inside the missing-review_at branch of a working copy
  of the real `check_11_linter_expiry.sh` (leaving its `continue` and every
  other branch untouched), reran the pre-existing
  `deep_scan_linter_expiry_check.sh` suite (Parts 1-7, 39 assertions)
  against that mutated copy, and it stayed fully green at exit 0 — none of
  the existing assertions touch this branch. Reverted before writing any
  fix (`git status --porcelain` showed no diff on the production file
  afterward). Added Part 8 (assertions 8a-8d) to
  `deep_scan_linter_expiry_check.sh`, using a **two-entry**
  `linter_exceptions.conf` fixture:
  - 8a (functional pin): an entry with no `# review_at:` annotation at all
    surfaces via the per-file "### Missing review_at annotation — policy
    violation T1-K" `REPORT_FILE` section, naming the entry.
  - 8b (break direction 1 — population removed): mutating a copy to drop
    the `_SCAN_MISSING_COUNT` / `_SCAN_MISSING` population (the exact gap
    confirmed above) makes the T1-K section vanish while the report still
    renders its "No expired or missing review_at annotations found"
    fallback and exits 0 — proving the mutation is isolated to this branch,
    not a wholesale script crash.
  - 8c (break direction 2 — message content corrupted, population left in
    place): rewording the `_SCAN_MISSING` append text keeps the header/count
    intact but the exact detail text no longer matches, proving 8a pins the
    entry's text and not merely "the header count is > 0."
  - 8d: verified (not assumed) the item's own caveat — the `FINDINGS_FILE`
    for the 8a run contains no `W:` line mentioning the fixture entry,
    confirming `main.sh`'s "## Warnings" section is genuinely unaffected by
    this branch, both before and after this fix.
  **Fixture cardinality — corrected during QC rework 1** (qc-behavioral on
  PR #2624, review 5075929429). The first revision used a SINGLE-entry
  fixture and justified it as a "masking-hazard guard, per Part 7's
  precedent." That justification was measured and is **false, and
  inverted**: 8b and 8c produce byte-identical outcomes at one entry and at
  two (this branch has no per-entry state to corrupt independently of the
  call — one branch, one accumulator pair), so Part 7's hazard does not
  apply here at all. Worse, single-entry was the *sole* reason a real
  mutation escaped: **hardcoding the header's count to `(1)`** is invisible
  against a one-entry fixture. Re-measured both ways during the rework —
  1-entry check vs that mutation: **exit 0 (MISSED)**; 2-entry check vs the
  same mutation: **exit 1 (CAUGHT)**. The fixture is now two entries and
  `MR_HEADER_TEXT` pins the count as `(2)`.

  **This Part does NOT close the last unpinned branch of
  `_scan_exceptions_conf`** — an earlier draft of this note and of #2624's
  PR body both claimed it did. See `H-EXPIRY-NEVER-BRANCH-UNPINNED` below,
  filed from the same review.

  Production `trading/devtools/checks/deep_scan/check_11_linter_expiry.sh`
  is untouched by this PR — `git status --porcelain` shows only
  `deep_scan_linter_expiry_check.sh` and this status file changed.
  Verify: `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh`
  (44 `OK:` lines, exit 0) or `dune runtest trading/devtools/checks/`.
  ⚠ **Count-drift note (folds in the O5 class, below):** this file now
  carries **three** different `Verify: (N OK: lines)` figures for this one
  script — 28 at the BQ-1 entry, 40 at R-5, 44 here — because each was
  written when true and never revisited. **Only 44 is true as of
  2026-09-01.** A stale figure in a *verification instruction* is the
  number a future reader uses to decide whether the check still works, so
  the earlier two now read as failures. Same class as
  `H-EXPIRY-NOTE-OFFBYONE-COUNTS (O5)`; whoever closes O5 should sweep all
  three rather than fixing one.

- [x] **H-EXPIRY-NEVER-BRANCH-UNPINNED**: filed by qc-behavioral on PR #2624
  (review 5075929429), non-blocking. The `never*) continue` branch at
  `check_11_linter_expiry.sh:141` — which intentionally exempts permanent
  exceptions from expiry reporting — was unpinned **in both directions**:
  deleting the branch entirely left the whole suite green. It was also the
  first **over-reporting** gap recorded on this surface: every existing
  assertion was a false-*negative* pin (checks that a violation IS
  surfaced), and **nothing pinned that a clean entry produces no finding**.

  **Count correction:** the filed item's "44 assertions" figure (and this
  file's own prior habit of quoting `OK:` line counts as the assertion
  count) is off by one — `echo "OK: ..."` appears 44 times pre-fix, but one
  of those is the unconditional final summary line
  (`echo "OK: deep scan Linter Exception Expiry section (T1-K) ... passed."`),
  not a `fail`-branch assertion. Measured directly:
  `grep -c 'echo "OK:' deep_scan_linter_expiry_check.sh` = 44,
  `grep -c '  fail "'` = 43. **43 real assertions pre-fix, not 44.**

  Closed by adding Part 9 (assertions 9a-9d) to
  `deep_scan_linter_expiry_check.sh`, using ONE fixture (a
  `linter_exceptions.conf` with a valid future-dated entry plus a
  `review_at: never` entry — both clean, no separate all-`never` fixture
  needed) to pin the absence direction and kill all three swept mutations:
  - 9a (positive/functional pin): the real script produces no finding for
    either entry — neither fixture name appears anywhere in `REPORT_FILE`
    or the roll-up `FINDINGS_FILE`, and the section falls back to
    "No expired or missing review_at annotations found."
  - 9b/9c/9d: mutation-proofs for the three swept mutations (table below).

  **RED/GREEN proof — mutation applied directly to the production file
  `check_11_linter_expiry.sh`, suite run, then reverted (`git diff` on the
  production file empty afterward, verified by sha256sum match each time;
  file mode `644` also restored after an incidental `chmod +x`):**

  | mutation | suite on origin/main (pre-fix) | suite with Part 9 | killing assertion |
  |---|---|---|---|
  | (i) delete `never*) continue` branch entirely (the filed mutation) | exit 0 (GREEN — unpinned, confirms the filed claim) | exit 1 (RED) | 9a: never-entry surfaces as `[UNRECOGNISED format]` |
  | (ii) invert — `never*` entries actively reported as a T1-K missing-review_at violation | exit 0 (GREEN) | exit 1 (RED) | 9a: `Missing review_at on: fixture_never_permanent` appears |
  | (iii) blanket over-report — force every entry through the missing-review_at branch (`if [ -z "$review_at_val" ]` → `if true`) | exit 1 (RED) — **already caught pre-fix**, but incidentally: it also breaks the unrelated `adapter_effectiveness_exceptions.conf` fixture used by pre-existing Part 3a, so the suite fails there first, before ever reaching where Part 9 would sit | exit 1 (RED) | pre-fix: Part 3a (`expired fixture_expired_field entry was NOT surfaced`); with Part 9: same Part 3a fires first (script order, `set -e`) — **verified independently** that 9a alone also catches it in isolation (ran the fixture standalone against the mutated production script, outside the full suite: finding present, would fail 9a) |

  No equivalent mutant: all three mutations are killed, (iii) by a
  pre-existing assertion for an unrelated reason plus Part 9 independently
  in isolation — see the isolation note above, not asserted new because
  Part 3a's `set -e` exit pre-empts it when running the full suite in
  order.

  **Rework iteration 1 (qc-behavioral on PR #2636, quality 2) — 9a-9d did
  NOT close the item as filed; the closure above was premature until 9e.**
  Two findings, both measured, both fixed in this same PR:

  - **A FOURTH live mutation: `never*) continue` → `never*) break`.** The
    whole suite, Part 9 included, stayed **GREEN** with it applied. `break`
    exits the enclosing `while read` loop, so **every entry after the first
    `review_at: never` is silently never scanned**. Not a corner case in
    the live conf: **28 active entries, first `never` at line 15, so 24 of
    28 (86%) fall after it.** 9a-9d could not catch it because their
    fixture puts the `never` entry **last**, where `break` and `continue`
    are indistinguishable. This is the **under**-reporting half of the
    "unpinned in both directions" that the item, the PR body and this entry
    all claimed to close — 9a-9d pinned only the over-reporting half.
    Closed by **9e**, which needs its own fixture (a `never` entry followed
    by an expired entry) because 9a's fixture is asserted to produce *no*
    finding at all. Control, measured directly:

    | suite | + `break` mutation |
    |---|---|
    | pre-rework (9a-9d only) | **exit 0 — GREEN, missed** |
    | with 9e | **exit 1 — RED** at 9e-1 |

    9e carries a `cmp -s` vacuity guard: a `sed` that stopped matching
    would leave the "mutant" byte-identical to production and 9e-2 would
    test nothing, so that now fails loudly instead of passing.

  - **9a's fallback grep was itself vacuous.** `check_11` emits the
    sentence "No expired or missing review_at annotations found." **three
    times**, once per conf file (Linter `:233`, Universe-Deps `:257`,
    Adapter-Effectiveness `:284`), and this fixture leaves the two sibling
    confs empty, so both of those emit it unconditionally. An unscoped
    `grep -q` therefore passed regardless of what the Linter section did —
    measured by changing **only** line 233: suite stayed **GREEN, 48/48**.
    The claim "the section falls back to …" appeared in the PR body, the 9a
    code comment, and this entry. Fixed by scoping the grep to the Linter
    section (heading → next `## ` heading) with a small `awk` helper; with
    only line 233 mutated the suite now exits **1**. 9a's other
    discriminating power was never in doubt — its name-scoped negative
    greps already worked.

  Production `trading/devtools/checks/deep_scan/check_11_linter_expiry.sh`
  is untouched by this PR — `git diff --stat` shows only
  `deep_scan_linter_expiry_check.sh` and this status file changed.
  Verify: `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh`
  (**50** `OK:` lines / 49 real assertions + 1 summary line, exit 0) or
  `dune runtest trading/devtools/checks/`.

  ⚠ **Counting convention, for the O5 sweep.** The 43 / 47 / 50 figures in
  this entry are all `echo "OK:"` counts minus the single unconditional
  summary line. **None of them counts the 12 silent `grep … || fail`
  structural assertions in Parts 1-2** (qc-behavioral, #2636). O5 must
  state which convention it uses, or these numbers will diverge a fifth
  time — which is exactly how this surface accumulated 28 / 40 / 44 / 16.

  `harness_gap: LINTER_CANDIDATE` — closed by this fix.
  (source: 2026-09-01 qc-behavioral on PR #2624, residuals O-A / O-B;
  closed: 2026-09-02, branch `harness/expiry-never-branch-pin`, after one
  rework iteration driven by qc-behavioral on PR #2636)

- [ ] **H-EXPIRY-MUTATION-DIAGNOSTIC-MISLEADS (O1)**: filed by qc-behavioral on
  PR #2589, non-blocking. Assertions 3c/3d/3e **fail closed** on a benign
  reword of the call site (verified: three separate rewordings all go RED, none
  goes vacuously green — the safe direction, and the #2580 shape specifically
  attacked). But the printed diagnosis misleads: 3c prints "expired
  fixture_expired_field entry was NOT surfaced in the roll-up W: findings line"
  while the dumped findings file two lines below plainly shows the correct `W:`
  line, and 3e prints "MUTATION D did not produce the expected split" without
  naming the real cause (its own `sed` pattern no longer matches the source).
  Recoverable in seconds because the assertions dump the findings/report
  contents, so this costs a future reworder minutes, not correctness. Fix
  shape: have 3d/3e assert their `sed` actually changed the file
  (`! diff -q "$CHECK_11" "$AE_MUT_CHECK2"`) and fail with "the mutation's sed
  pattern no longer matches — update the pattern, the protection may be fine".
  `harness_gap: NONE`.
  (source: 2026-08-28 run 2, qc-behavioral on PR #2589, observation O1)

- [ ] **H-EXPIRY-CONSUMER-HALF-UNPINNED (O4)**: filed by qc-behavioral on PR
  #2589, non-blocking, and **out of R-5's declared scope** (the header does not
  claim otherwise). Part 4 models `deep_scan/main.sh`'s calling convention but
  pins only the **producer** half: nothing asserts that `main.sh:47` still
  passes a findings file as `$2`, nor that `main.sh:110-111` still routes
  `W: ` into the `## Warnings` section (`:174`). Breaking either would silently
  drop check_11's roll-up in production with Part 4 fully green. Mitigating and
  the reason this is low priority: `_run_check` is shared by all 12 deep-scan
  checks, so that break is far broader and louder than the one R-5 targets.
  `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-28 run 2, qc-behavioral on PR #2589, observation O4)

- [ ] **H-EXPIRY-NOTE-OFFBYONE-COUNTS (O5)**: filed by qc-behavioral on PR
  #2589, cosmetic. Two off-by-one counts in this file's own #2589 completion
  notes: the R-1a note says "all 9 assertions pass" but the runner reports
  **10** (assertions 1-9 plus 11); the R-5 note says the check "prints 5 `OK:`
  lines" but it prints **6** (five assertions plus the trailing summary). Both
  are in *verification instructions* — the numbers a future reader would use to
  decide whether the check still works — not contract claims. Everything else
  in both notes was checked line by line against the tree and is accurate.
  Noting rather than silently fixing, since this file is the durable record and
  four consecutive runs have now found a record disagreeing with the tree.
  `harness_gap: NONE`.
  (source: 2026-08-28 run 2, qc-behavioral on PR #2589, observation O5)

- [ ] **H-EXPIRY-GLOB-CLOSES-CLASS (R-4)**: recorded by qc-behavioral on the
  #2585 re-review as explicitly non-blocking. `check_11_linter_expiry.sh` now
  scans **all three** `*exceptions*.conf` files that exist repo-wide, so there
  is **zero** currently-unprotected surface — but the list is three hardcoded
  `_scan_exceptions_conf()` calls, so a **fourth** exceptions file added later
  would again be silently unscanned. That hardcoded-list shape is exactly what
  allowed BQ-1. The author's reason for not globbing holds on inspection: each
  block carries its own accumulator quartet *and* file-specific report prose
  naming a *different* sibling guard, so a glob needs a data-driven
  `(path, label, guard)` table — a refactor, not two lines. Closes the
  instance, not the class. Fix shape: that table. `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-28 run 1, qc-behavioral re-review of PR #2585)

- [x] **H-EXPIRY-ROLLUP-WARNING-UNPINNED (R-5)**: pre-existing, surfaced (not
  introduced) by #2585's review and out of scope there. Deleting `add_warning`
  in the date branch of `_scan_exceptions_conf()` leaves the report section
  intact and every test green — so the **roll-up warning path is unpinned for
  all three conf files**, identically before and after #2585. The per-file
  `[EXPIRED]` detail lines *are* pinned; it is only the roll-up that is not.
  Fix shape: assert the `W:` roll-up line, not just the detail line, in
  `deep_scan_linter_expiry_check.sh`. `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-08-28 run 1, qc-behavioral re-review of PR #2585)
  **DONE (2026-08-28, harness/2585-residuals-r1a-r5):** confirmed the gap by
  hand first (mutating the real `check_11_linter_expiry.sh`, deleting the
  date-branch `add_warning` call — the pre-fix suite stayed fully green).
  Added Part 4 to `trading/devtools/checks/deep_scan_linter_expiry_check.sh`
  (assertions 3c-3e): 3c runs `check_11_linter_expiry.sh` with a
  `FINDINGS_FILE` argument (`deep_scan/main.sh`'s real calling convention)
  and asserts a `^W: .*fixture_expired_field.*has passed` line is present —
  the roll-up, not just the `[EXPIRED]` detail line. 3d mutates a working
  copy by deleting the date-branch `add_warning` call (the exact finding
  repro) and asserts the detail line survives but the `W:` line vanishes.
  3e is a second, independent break direction — corrupts the `add_warning`
  message content (keeps the call) so the field name drops out of the
  roll-up text while the call still fires; asserts the same split. Both
  mutations were also re-verified by hand directly against the real
  `check_11_linter_expiry.sh` (not just the test's internal copies): RED on
  mutation, clean revert (`diff` identical to pre-mutation), GREEN again.
  **Known gap NOT covered** (found during this fix, not asked for in R-5,
  left as-is per scope): the *missing-review_at* branch of
  `_scan_exceptions_conf()` never calls `add_warning` at all (only the
  per-file `### Missing review_at annotation` detail section is populated)
  — so a missing-review_at roll-up warning has never existed and this PR
  does not add one. Similarly, 3c/3d/3e's fixture is date-based only; a
  break in the **milestone** branch's `add_warning` (line ~166, "was due
  for review at ... — retire or re-annotate") is not exercised by these
  assertions. Both are candidates for a follow-up in the same shape as R-5
  if they turn out to matter. Verify:
  `sh trading/devtools/checks/deep_scan_linter_expiry_check.sh` (or `dune
  runtest trading/devtools/checks/`) — prints 5 `OK:` lines, exit 0.

- [x] **H-GATEPARSER-SHALESS-REVIEW-NEVER-STALE** (issue #2626): `pr_gate_status.sh`
  recovers each review's SHA by parsing a `Reviewed SHA:` line out of the review's
  **prose body**. When the line is absent the review parses as sha-less, and the
  script's own header documents the result: *"a sha-less review was simply
  current-at-every-tip-forever — it can never go stale and can never be outvoted."*
  So a QC verdict whose author forgot one line of prose can never be invalidated by
  a rework, and if BOTH gates are sha-less the script prints `MERGE` for a tip
  nobody reviewed. **Observed live on PR #2625 itself, 2026-09-01:** both reviews
  sat at `7b1adb5b` after a rework moved the tip to `a9e32f87`, and the script
  printed `ok` for structural (body had no `Reviewed SHA:`) alongside
  `stale(7b1adb5b)` for behavioral (body had it) — two verdicts, one superseded
  SHA, two different staleness answers. Only the behavioral reviewer's having
  included the line kept it from reading `MERGE`; both agents were dispatched with
  prompts that required it. Root cause is that the SHA is being recovered from
  prose when the API already supplies it structurally: every review object carries
  **`commit_id`**, the commit it was submitted against — authoritative, always
  present, impossible for an agent to forget. Fix shape: fall back to
  `$review.commit_id` when the body yields no match, which makes the sha-less
  branch unreachable; plus a fixture asserting a sha-less review against a moved
  tip reads `stale(...)`, not `ok`. Note this is the **fourth** independent defect
  on this one parser (after the 7-vs-8 hex-length bug #2397, the fence-quoting
  misattribution, and #2620's interior-heading leak) and the **third** to arise
  specifically from parsing prose. `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-09-01 orchestrator run 33482398132, found while re-QCing PR #2625)

  **DONE (2026-09-01, PR stacked on #2625, branch `harness/gate-sha-from-commit-id`).**
  What shipped: in `dev/scripts/pr_gate_status.sh`'s `_gate` function, the
  `review_result` jq helper now computes `$body_sha` from the `Reviewed SHA:`
  prose match as before, then falls back to the review's `.commit_id` field
  ONLY when `$body_sha == ""` — body stays primary, `commit_id` is strictly the
  fallback, so a review can still explicitly declare it reviewed a sha other
  than the one it was POSTed against. `_pr_meta_curl` (the REST backend the GHA
  orchestrator actually runs under) was widened to project `commit_id` into
  each review object alongside `body`, since the prior projection dropped the
  field before `_gate` ever saw it. **Scoped gap, documented in both the code
  comment and here:** `gh pr view --json reviews` does supply the per-review
  sha, but under the key `.commit.oid`, whereas the reader looks for
  `.commit_id` — the gap is a key-name mismatch, not a missing field
  (measured on gh 2.89.0 during #2628's QC: `.reviews[].commit.oid` present
  and correct). Closing it needs only a normalisation on data `_pr_meta_gh`
  already receives (e.g. reading `(.commit_id // .commit.oid // "")`), not a
  switch to the REST endpoint.
  Until then a sha-less review under a *local* `gh`-backed session still
  falls through to the pre-existing always-current path. The curl/REST
  backend is fully covered; that is the backend the orchestrator cron runs
  under, which is where the live #2625 incident happened. **Residual, filed
  below as H-GATEPARSER-CURL-PROJECTION-UNPINNED:** the projection half of
  this fix is unpinned — reverting the `_pr_meta_curl` widening alone leaves
  the suite green — so this entry is not fully closed by tests.

  Non-vacuity proof (RED/GREEN), both measured directly by reverting only the
  production fallback line and re-running the full suite:

  | state | fixture (case 43, sha-less body + STALE `commit_id`) | full suite |
  |---|---|---|
  | RED (fallback reverted, fixture present) | `want stale(aaaaaaaa), got ok` | exit 1 (1 failed of 54 total) |
  | GREEN (fallback restored) | `stale(aaaaaaaa)` — matches | exit 0 (54 tests clean) |

  Before this PR (base tip `b2950471`, PR #2625): 51 tests clean, exit 0.
  After: 54 tests clean, exit 0 — 3 new cases (43: sha-less + stale commit_id
  → `stale(...)`; 44: sha-less + current-tip commit_id → `ok`; 45: body SHA
  line present takes precedence over a disagreeing `commit_id` →
  `stale(deadbeef)`, pinning that the fallback is strictly secondary).
  Verify: `sh dev/scripts/pr_gate_status_test.sh`. Files touched:
  `dev/scripts/pr_gate_status.sh`, `dev/scripts/pr_gate_status_test.sh`, this
  entry. Mutations (k)/(f)/(g) from H-GATEPARSER-NO-MUTATION-COVERAGE below are
  deliberately out of scope here — left to that item's own PR.

- [ ] **H-GATEPARSER-CURL-PROJECTION-UNPINNED** (from #2628's review): the
  `_pr_meta_curl` `commit_id` projection widening — the half of the #2626 fix
  that makes the fallback reachable — has no regression pin: reverting that
  one line alone leaves the suite exit 0 / 54 clean (measured during #2628's
  QC), silently restoring the #2626 defect behind a green suite. Closing this
  needs a fixture that drives the REST projection itself (mock `curl` JSON →
  assert the review objects reaching `_gate` carry `commit_id`), not just the
  `review_result` fallback the current cases 43-45 pin.

- [x] **H-GATEPARSER-NO-MUTATION-COVERAGE**: `pr_gate_status.sh` is the merge-gate
  reader, yet its suite is verified only by hand. A ~30-line mutation harness
  around the existing `PR_GATE_STATUS_LIB=1` seam, run in CI against a fixed
  mutation list, would surface the unkilled mutations **mechanically**. For the
  file that *is* the merge gate, mutation coverage is the check that matches the
  stakes. `harness_gap: LINTER_CANDIDATE`.
  (source: 2026-09-01 qc-behavioral on PR #2622, corrected by qc-behavioral on
  PR #2625)

  **The mutation list is the load-bearing part of this item, so it is recorded
  in full — a harness seeded from a short list goes green and the omitted
  mutations are never rediscovered.** This entry *is* that seed list, and it
  has now been undercounted **twice, in the same direction**, by successive
  reviews:

  - #2622's sweep said in prose "8 of 11 killed, 3 survivors"; its own table
    carried **5 GREEN rows**. #2625 corrected it to *"5 survivors, every one
    live."*
  - **That corrected figure was also wrong.** qc-behavioral on PR #2635
    (2026-09-02) swept degrees of freedom no prior review had listed — `(?m)`,
    the heading regex's own `^`/`$`, the `.*` capture, the **lower** bound of
    `#{1,4}`, `(?i)`, the `(qc[- ])?` group — and found **four more live
    survivors**. Its sweep is calibrated, not lucky: 7 sibling mutations were
    killed loudly (drop `(?m)` → 37 failures, first→last match → 34, drop
    `(?i)` → 35, require `(qc[- ])` → 35, `#{1,4}`→`#+` → 2).

  So the honest statement is **not a survivor count**. It is that **nobody has
  yet enumerated this regex exhaustively, and every attempt so far has
  undercounted.** That is the argument for the automated harness. Treat the
  tables below as a floor, not a census.

  ### Killed (pinned by a regression case)

  | mutation | status |
  |---|---|
  | (d) drop `strip_fences` inside `first_heading_text` | **killed** (case 41) |
  | (j) drop the `^` anchor in the **kind test** (line ~325) | **killed** (case 42) |
  | (k) drop `\b` from the kind test | **killed** (case 46) |
  | (f) `#{1,4}` → `#{1,6}` | **killed**, both directions (case 47 false-`ok`, case 48 false-`none`) |
  | (g) required space `" +"` → `" *"` | **killed**, both directions (case 49 false-`ok`, case 50 false-`none`) |
  | (m) drop the `^` from the **heading regex** (line ~237) | **killed** by cases 47/48 — found live on main by #2635's sweep. Distinct from (j), which is the line-325 anchor. #2635 closes **four** mutations but was credited for three |

  (k)/(f)/(g) were measured RED/GREEN by hand (2026-09-02): the pre-existing
  54-case suite stayed GREEN with each applied (each was a genuine live
  survivor, not incidentally caught); cases 46-50 turn each RED; reverting
  restores a clean `git diff` on the production script and a GREEN 59-case
  suite. Confirmed independently by qc-structural and qc-behavioral on #2635.

  **Overlap, recorded because a future editor will otherwise get it wrong:**
  mutation (g) *also* flips case 48, which was built for (f)'s false-`none`
  direction — both relax the same `first_heading_text` line, so once the space
  requirement is dropped a bare `"###### scratch note"` partially matches.
  **Case 48 therefore pins two mutations, not one**; deleting it as
  "(f)-redundant" would silently unpin (g) as well. (f) does *not* reciprocally
  trip cases 49/50.

  ### LIVE and unpinned — found by #2635's sweep, 2026-09-02

  | mutation | live effect (production → mutant) |
  |---|---|
  | **`#{1,4}` → `#{1,3}`** | **both directions.** false-MERGE: `#### scratch note` masking a real `## Behavioral QC` → `none` → **`ok`**. false-BLOCK: a real `#### Behavioral QC` → `ok` → **`none`** |
  | **`(?<h>.*)` → `(?<h>.+)`** | **false-MERGE**: a bare `## ` line (no text) masks the real heading → `none` → **`ok`** |
  | **`" +"` → `" "`** (exactly one space) | false-BLOCK: `##  Behavioral QC` (two spaces) → `ok` → **`none`** |
  | **`[- ]` → `[-]`** | false-BLOCK: `## QC Behavioral notes` → `ok` → **`none`** |

  The first is the **mirror image of (f)**: cases 47/48 pin the *upper* bound
  of `#{1,4}`, and **nothing pins the `4` from below** — and it is the unpinned
  half that carries a false-MERGE. That asymmetry is the strongest single
  argument in this entry for building the harness rather than continuing to
  enumerate by hand.

  Note (k) especially: with the `^` anchor restored by case 42, `\b` is the
  **sole** remaining guard against a first heading that merely *starts with*
  the gate word.

  **Still open: the harness itself, and the four survivors above.** Cases 46-50
  pin the *known* survivors by hand, the same way cases 41-45 pin (d)/(j)/etc.
  They are not the ~30-line automated `PR_GATE_STATUS_LIB=1`-seam harness this
  item asks for, which would surface *future, unlisted* mutations mechanically
  instead of requiring a human to enumerate them — and the fact that the
  enumeration has now been wrong twice is the evidence that humans should stop
  doing it. Fixtures for the four live survivors are deliberately **not** in
  #2635 (that PR's scope was (k)/(f)/(g)); they belong to the harness work.

  Two scoping notes for whoever builds this. First, "mechanically" above is
  deliberate and narrower than the original wording ("with no inferential
  judgment", now removed): a harness surfaces an unkilled mutation
  mechanically, but classifying a survivor as **defect vs. equivalent mutant**
  is exactly an inferential step — and it was performed imperfectly here, since
  (f) and (g) were originally dismissed as not-real. Second, a related gap the
  harness would *not* catch: the false-negative surface #2622 introduced —
  a review opening with a preamble heading (`# Review of PR #N`, `## Context`,
  `# Summary`) attributes to **no** gate, a false-BLOCK. It is fail-safe and
  currently unrealised (27/27 real review bodies across 10 recent PRs attribute
  correctly, in 3 heading families), so it is recorded here rather than pinned.

  **CLOSED (2026-09-04).** Built `trading/devtools/checks/pr_gate_status_mutation_test.sh`
  (the harness) and `trading/devtools/checks/pr_gate_status_mutation_test_selftest.sh`
  (a fixture-driven self-test of the harness's own non-vacuity guard), both wired
  into `dune runtest` via `trading/devtools/checks/dune` with `(universe)` deps
  (they read `dev/scripts/pr_gate_status.sh` / `pr_gate_status_test.sh` via
  `repo_root()` at run time, outside the dune workspace root — see
  H-CHECK-CACHE-BLIND). Verify:
  `dev/lib/run-in-env.sh dune runtest trading/devtools/checks/` (or the standalone
  `sh trading/devtools/checks/pr_gate_status_mutation_test.sh`).

  **How it works:** copies the real `pr_gate_status.sh` to a scratch `mktemp -d`
  dir alongside the real (unmodified) `pr_gate_status_test.sh`, applies one `sed`
  mutation per pinned entry, asserts the mutation actually changed the file
  (`cmp -s` — a no-op sed hard-fails with the distinct message
  `MUTATION DID NOT APPLY`, never silently reads as a result), then re-runs the
  existing offline suite (its pre-existing `PR_GATE_STATUS_LIB=1` seam, unmodified
  — no new sourcing mechanism invented) against the mutant. Suite exits non-zero
  → KILLED; suite stays green → SURVIVOR. The real, tracked `pr_gate_status.sh`
  is never written to (mutations only ever touch the scratch copy); a final `cmp`
  against a pristine snapshot taken at the start is a tripwire proving that held,
  since `git diff --quiet` was avoided deliberately (unreliable under GHA's
  safe.directory setup — see `_check_lib.sh`'s own `repo_root()` comment).

  **Gating shape: (b), a pinned expected-outcome list**, not WARN-only. 5 of
  the 16 pinned mutations are expected to SURVIVE today (s1–s5): 4 are live
  defects (s1–s4) and 1 (s5) is a verified equivalent mutant, not a live
  defect — see its own table row below. The check fails only when an OBSERVED
  KILLED/SURVIVOR outcome diverges from its PIN, in either direction — a pinned
  KILLED mutation newly surviving is a live regression (hard stop); a pinned
  SURVIVOR newly killed means this file's own pin is stale (fix the pin in the
  same PR). This tolerates the documented backlog by name rather than a blanket
  exception, per `.claude/rules/code-health-discipline.md`.

  **Mutation table — 16 total, seeded from the FULL record above plus this
  harness's own further enumeration of the same three regexes** (first_heading_text's
  heading match, review_result's verdict/sha capture, the kind test):

  | id | expected | mutation | source |
  |---|---|---|---|
  | d1 | killed | (d) drop `strip_fences` in `first_heading_text` | record |
  | j1 | killed | (j) drop `^` anchor, kind test | record |
  | k1 | killed | (k) drop `\b`, kind test | record |
  | f1 | killed | (f) `#{1,4}` → `#{1,6}` | record |
  | g1 | killed | (g) `" +"` → `" *"` (heading) | record |
  | m1 | killed | (m) drop `^` from heading regex | record |
  | s1 | survivor | `#{1,4}` → `#{1,3}` (lower bound) | record (#2635 sweep) |
  | s2 | survivor | `(?<h>.*)` → `(?<h>.+)` | record (#2635 sweep) |
  | s3 | survivor | `" +"` → `" "` (heading) | record (#2635 sweep) |
  | s4 | survivor | `[- ]` → `[-]` (kind test) | record (#2635 sweep) |
  | x1 | killed | drop `(?m)` flag entirely, heading regex | new (this PR) |
  | x2 | killed | drop `(?i)` flag, kind test | new (this PR) |
  | x3 | killed | require `(qc[- ])` (drop the `?`) | new (this PR) |
  | x4 | killed | `#{1,4}` → `#+` (unbounded) | new (this PR) |
  | x5 | killed | sha bound `{7,40}` → `{8,40}` (the #2397 regression) | new (this PR) |
  | s5 | survivor | drop `$` end-anchor, heading regex | new (this PR) — **verified equivalent mutant**: what bounds `.` at end-of-line is the absence of dot-all (`(?s)`), not `(?m)` — confirmed directly (`"a\nb" | test("(?m)a.b")` → false, `"a\nb" | test("(?ms)a.b")` → true, this container's jq-1.6/Oniguruma), so the trailing `$` is redundant and no test can ever distinguish the two readings. Also a jq-semantics tripwire: a future jq making `.` dot-all by default would make s5 a live defect. |

  Total: **11 killed / 5 survivor**, of which **4 (s1–s4) are live defects and
  1 (s5) is a verified equivalent mutant** — all 16 independently re-measured against
  current `main` while building this harness (not transcribed from the record
  blindly) — every record-sourced entry reproduced its documented outcome
  exactly. Of the record's own two tables (6 killed + 4 survivor = 10 named
  mutations), all 10 are represented; the 6 new entries (x1–x5, s5) are this
  harness's own sweep and were not previously named anywhere, per the item's
  instruction that new findings are "a success, not scope creep." x1–x4 cover
  4 of the "7 sibling mutations killed loudly" the #2635 review mentions but
  does not fully enumerate (drop `(?m)`, drop `(?i)`, require `(qc[- ])`,
  `#{1,4}`→`#+`) — **the 6th and 7th remain unnamed anywhere**, alongside a
  structural "first→last match wins" mutation (a rewrite of the multi-match
  disagreement-detection logic, not a single-line `sed`) that was left out as
  not mechanically expressible within this harness's `sed`-based design —
  noted here rather than silently dropped, future work if wanted.

  **RED/GREEN non-vacuity proof**, both measured directly against the final
  files: (RED) flipping `d1`'s pin from `killed` to `survivor` in a scratch
  copy → `FAIL d1: pinned survivor, observed killed` + `FAIL: pr_gate_status
  mutation harness -- 1/16 mutation(s) off-pin.`, exit 1. (GREEN) the real,
  unmodified file → all 16 `ok`, `OK: pr_gate_status mutation harness -- 16
  mutation(s) match pin.`, exit 0. The self-test
  (`pr_gate_status_mutation_test_selftest.sh`) separately proves the
  non-vacuity guard itself: an injected unmatchable `sed` (via the harness's
  opt-in `PR_GATE_STATUS_MUTATION_SELFTEST_NOOP`/`_ONLY` hooks) reports the
  distinct `MUTATION DID NOT APPLY` message and a non-zero exit, confirmed
  both ways (present under the hook, absent under the harness's normal run).

  **Out of scope, left for follow-up:** fixing any of the 4 live survivors
  (s1–s4 — s5 is a verified equivalent mutant, not a defect, and cannot be
  "fixed") (that is separate work, not this item — H-GATEPARSER-CURL-PROJECTION-UNPINNED
  remains untouched too), and the "first→last match" structural mutation noted
  above. `pr_gate_status.sh`'s production logic was not modified by this PR.
