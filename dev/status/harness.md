# Status: harness

## Last updated: 2026-04-14

## Status
IN_PROGRESS

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

## Tier 2 — Milestone-gated

- [ ] T2-B: Performance gate test (`trading/weinstein/simulation/test/performance_gate_test.ml`) (at M5)
- [x] T2-B: Reference backtest config + expected metrics — landed at `trading/test_data/backtest_scenarios/goldens/` via #316 (sexp, not json; different location than originally planned). See `dev/status/backtest-infra.md`.
- [ ] T2-C: Walk-forward regression gate (`dev/benchmarks/best_config.json`) (at M7)
- [ ] T2-D: Live trading gate + paper-trading validation period in `dev/milestones/m6-paper-trading.md` (before M6)

## Tier 3 — After M5 stable

- [x] T3-A: `health-scanner` agent — deep scan (weekly: dead code, design doc drift, TODO accumulation, size violations) — DONE: see completion note below
- [ ] T3-A: `health-scanner` deep scan — QC calibration audit (verdicts vs regression history)
- [ ] T3-A: `health-scanner` deep scan — harness scaffolding review (flag unused harness components)
- [x] T3-A: `health-scanner` deep scan — feat-agent template compliance check (covered by T1-I: `agent_compliance_check.sh`)
- [x] T3-B: AVR loop closure in `lead-orchestrator` (auto-dispatch QC on READY_FOR_REVIEW)
- [ ] T3-C: Cross-feature context injection (beyond T1-E baseline — superseded for basic case)
- [x] T3-D: Audit trail — `dev/audit/YYYY-MM-DD-<feature>.json` with `harness_gap` field on NEEDS_REWORK
- [ ] T3-E: Cost/token budget visibility in daily summary + budget cap in `merge-policy.json`
- [x] T3-F: Create `docs/design/dependency-rules.md` with initial known boundaries + state lifecycle
- [ ] T3-F: Architecture graph analyzer in health-scanner deep scan (import graph vs. rules doc)
- [ ] T3-F: Rule promotion path — generate dune checks from `enforced` rules automatically
- [x] T3-G: Status file integrity check in health-scanner fast scan — verify required fields present (Status, Last updated, Interface stable) in each `dev/status/<feature>.md`; flag missing or malformed entries (part of T1-O fast scan). Done: see Completed section.
- [ ] T3-G: `health-scanner` deep scan extension — followup-item count + CC trend analysis in weekly report (extends T1-Q CC linter output)
- [ ] T3-G: Audit trail — include qc-behavioral quality score in `dev/audit/` records (extends T3-D)
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

- **`.claude/worktrees/` gitignore gap** — `EnterWorktree` creates git worktrees
  jj can't track. Either ignore the directory or teach jj to ignore the paths.
  Source: `dev/daily/2026-04-11.md`.
- **Pre-existing nesting linter failures** — `fetch_universe.ml:main`,
  `test_data_loader.ml:load_daily_bars`, `weinstein_strategy.ml` exceed the
  nesting threshold. Grandfathered via `linter_exceptions.conf` or refactor.
  Source: `dev/daily/2026-04-11.md`.
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
- **Deep scan heuristic gaps** — `trading/devtools/checks/deep_scan.sh`
  (T3-A, see #331) is missing several useful checks. Today's manual
  audit found four real issues the script didn't surface:
  1. **Drift coverage too narrow** — only checks `analysis/weinstein/`,
     `trading/weinstein/`, `analysis/weinstein/data_source/` against
     specific eng-design docs. New subsystems like
     `trading/trading/backtest/` (added today via #315/#316) are
     invisible. Either generalise the check or add per-subsystem
     coverage.
  2. **Status file template enforcement** — three status files
     (`portfolio-stops.md`, `screener.md`, `simulation.md`) had stale
     `## Recent Commits` sections in violation of the template's
     "omit" rule. Stripped in this PR; deep scan should grep for the
     forbidden heading and warn.
  3. **Linter exception expiry** — `linter_exceptions.conf` entries
     with `review_at: <milestone>` (e.g. M5) are never re-surfaced
     when the milestone lands. Add a check that compares current
     milestone in `weinstein-trading-system-v2.md` against the
     `review_at:` values.
  4. **Stale local jj bookmarks** — bookmarks left around after PRs
     merge accumulate. Surface them with
     `jj bookmark list 'glob:*'` filtered against origin.
  Source: `dev/daily/2026-04-14.md` end-of-day audit.

---

## Completed

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

### T3-A: Deep scan

- [x] T3-A: Deep scan deterministic script — `trading/devtools/checks/deep_scan.sh`; standalone shell script (not wired into `dune runtest` — runs weekly, not on every PR). Covers 5 checks: (1) dead code detection (`.ml` files not in any dune library), (2) design doc drift (`analysis/weinstein/` and `trading/weinstein/` modules vs `eng-design-{1,2,3}` docs), (3) TODO/FIXME/HACK accumulation across `.ml`/`.mli` files, (4) size violations (files >300 lines without `@large-module`), (5) follow-up item count across `dev/status/*.md`. Writes report to `dev/health/YYYY-MM-DD-deep.md`. Health-scanner agent definition updated with Phase 1 (deterministic script) and Phase 2 (agentic steps: architecture drift, QC calibration, harness scaffolding review). Verify: `sh trading/devtools/checks/deep_scan.sh` from repo root produces `dev/health/YYYY-MM-DD-deep.md` with Metrics section.

### T3-D: Audit trail

- [x] T3-D: Audit trail writer — `trading/devtools/checks/write_audit.sh`; standalone shell script (not wired into `dune runtest` — operational tool, not a test gate). Takes `--date`, `--feature`, `--branch`, `--structural`, `--behavioral`, `--overall`, and optional `--harness-gap`, `--quality-score`, `--pass-count`, `--fail-count`, `--flag-count`, `--notes` arguments. Writes structured JSON to `dev/audit/YYYY-MM-DD-<feature>.json`. Computes `consecutive_rework_count` by reading prior audit files for the same feature (newest-first, counting contiguous NEEDS_REWORK verdicts). Idempotent (overwrites on same date+feature). Creates `dev/audit/` if missing. Validates date format, verdict values, and required arguments. Verify: `sh trading/devtools/checks/write_audit.sh --date 2026-04-14 --feature test --branch feat/test --structural APPROVED --behavioral APPROVED --overall APPROVED` — writes `dev/audit/2026-04-14-test.json` with valid JSON.

### T3-B and T3-F

- [x] T3-B: AVR loop closure already in `lead-orchestrator` Step 5 — auto-dispatches QC for any READY_FOR_REVIEW feature in the same orchestrator run. Verify: grep "READY_FOR_REVIEW\|auto.*QC\|Step 5" in `lead-orchestrator.md`.
- [x] qc-structural: P1/P2/P4 items updated to "verified by linter (H3)" — QC no longer manually re-scans these; linters are the deterministic gate. Verify: read `qc-structural.md` checklist — P1/P2/P4 items reference linter gates.
- [x] T3-F: `docs/design/dependency-rules.md` created — R1–R6 rules with lifecycle states (`proposed` / `monitored` / `enforced`); R1, R4, R6 enforced via dune tests; R2, R3 monitored; R5 proposed. Verify: file exists; `dune runtest trading/devtools/checks/` enforces R1.

### run-sh hardening

- [x] `dev/run.sh` pre-flight — fast-fails at the shell (not inside the orchestrator) if `claude` isn't on PATH, `.claude/agents/lead-orchestrator.md` is missing, or its `## Allowed Tools` section no longer lists `Agent`. Each failure prints `FAIL: <what>` to stderr and exits 1. Block is placed immediately after `REPO_ROOT=...` and uses only POSIX-compatible constructs (works with `set -euo pipefail`). Verify: `sh -n dev/run.sh` passes syntax check; temporarily rename `.claude/agents/lead-orchestrator.md` and re-run `dev/run.sh` — it exits 1 with a clear `FAIL:` message.
- [x] `dev/config/merge-policy.json` — default merge-policy config committed with inline defaults (`followup_threshold: 10`, `maintenance_cycle_ratio: 3`, `auto_merge_enabled: false`). Matches the inline defaults previously embedded in `lead-orchestrator.md` Step 2b — now visible and tweakable without editing the agent definition. Intent documented in `dev/config/README.md`. Verify: `jq . dev/config/merge-policy.json` parses cleanly.
- [x] Orchestrator `## Plan Mode` — added to `.claude/agents/lead-orchestrator.md`; triggered by a `--plan` token in the prompt, short-circuits Steps 2–6, writes `dev/daily/<YYYY-MM-DD>-plan.md` with `(plan mode)` marker, never mutates branches or status files. Structural smoke test at `trading/devtools/checks/orchestrator_plan_check.sh` wired into `dune runtest` — grep-asserts the required Plan Mode contract pieces in the agent definition. Does NOT invoke `claude -p` from dune runtest (credentials/network/flakiness). Verify: `dune runtest trading/devtools/checks/` — prints `OK: lead-orchestrator plan mode contract present.`
