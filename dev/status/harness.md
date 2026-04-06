# Status: harness

## Last updated: 2026-04-06

## Status
IN_PROGRESS

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
- [ ] T1-M: "Done" definition — add explicit acceptance criteria to each Tier 1 item's completion note (harness items should state what was built, where it lives, and how to verify)

## Maintenance Cycles

- [ ] M1: Add `## Blocking Refactors` section to all feat-agent status files
- [ ] M1: Update `lead-orchestrator` to read blocking refactors and dispatch before feat-agents
- [ ] M1: Update `lead-orchestrator` to count followup items and schedule maintenance cycles (threshold: 10 items, every 3rd run)
- [ ] M1: Add `## Refactor Mode` prompt variant to feat-agent definitions
- [ ] M2: Cyclomatic complexity linter — extend `fn_length_linter` via `compiler-libs`; CC > 10 = warning; output to `dev/metrics/cc-YYYY-MM-DD.json`
- [ ] M2: qc-behavioral quality score — add `## Quality Score` (1–5 + rationale) to output; tracked in audit trail
- [ ] M3: T3-A deep scan extension — followup-item count + CC trend analysis in weekly report
- [ ] M3: T3-D audit trail — include quality score in audit records

## Tier 2 — Milestone-gated

- [ ] T2-A: Golden scenario test suite — screener regression tests (after M4)
- [ ] T2-A: Golden scenario test suite — stop state machine regression tests (after M4)
- [ ] T2-B: Performance gate test (`trading/weinstein/simulation/test/performance_gate_test.ml`) (at M5)
- [ ] T2-B: Reference backtest config + expected metrics (`dev/benchmarks/reference_backtest.json`) (at M5)
- [ ] T2-C: Walk-forward regression gate (`dev/benchmarks/best_config.json`) (at M7)
- [ ] T2-D: Live trading gate + paper-trading validation period in `dev/milestones/m6-paper-trading.md` (before M6)

## Tier 3 — After M5 stable

- [ ] T3-A: `health-scanner` agent — fast scan (post-run: stale status, new magic numbers, main build health)
- [ ] T3-A: `health-scanner` agent — deep scan (weekly: dead code, design doc drift, TODO accumulation, size violations)
- [ ] T3-A: `health-scanner` deep scan — QC calibration audit (verdicts vs regression history)
- [ ] T3-A: `health-scanner` deep scan — harness scaffolding review (flag unused harness components)
- [ ] T3-A: `health-scanner` deep scan — feat-agent template compliance check
- [x] T3-B: AVR loop closure in `lead-orchestrator` (auto-dispatch QC on READY_FOR_REVIEW)
- [ ] T3-C: Cross-feature context injection (beyond T1-E baseline — superseded for basic case)
- [ ] T3-D: Audit trail — `dev/audit/YYYY-MM-DD-<feature>.json` with `harness_gap` field on NEEDS_REWORK
- [ ] T3-E: Cost/token budget visibility in daily summary + budget cap in `merge-policy.json`
- [x] T3-F: Create `docs/design/dependency-rules.md` with initial known boundaries + state lifecycle
- [ ] T3-F: Architecture graph analyzer in health-scanner deep scan (import graph vs. rules doc)
- [ ] T3-F: Rule promotion path — generate dune checks from `enforced` rules automatically
- [ ] T3-G: Status file integrity check in health-scanner fast scan — verify required fields present (Status, Last updated, Interface stable) in each `dev/status/<feature>.md`; flag missing or malformed entries
- [ ] T3-H: Commit-level QC mode — spawn `qc-structural` on individual commits (not whole branches) to catch violations earlier; low priority, adds cost; explore when golden scenarios (T2-A) are stable

## Tier 4 — Continuous development loop (target end state)

- [ ] T4-A: Automated PR creation (orchestrator runs `gh pr create` on APPROVED)
- [ ] T4-B: Auto-merge on clean pass + `dev/config/merge-policy.json` + `automation-enabled.json` kill switch
- [ ] T4-C: Requirements intake workflow (design doc → agent def → decisions.md → auto-pickup)
- [ ] T4-D: Milestone evaluation reports (M4, M5, M7)
- [ ] T4-E: Rollback/recovery protocol + health-scanner regression check against baseline

---

## Completed

- [x] Harness plan drafted and committed (`docs/design/harness-engineering-plan.md`)
- [x] Automation goals and target state defined (Target State + Tier 4)
- [x] Added audit trail, rollback/recovery, live trading gate, QC non-determinism policy, cost visibility
- [x] Incorporated learnings from Anthropic, Fowler, Stripe Minions, and OpenAI harness articles (T1-A+, T1-E through T1-H, T3-A fast/deep split, T3-D harness_gap field)
- [x] Refined architecture checks: A1 FLAG not FAIL in qc-structural; generalizability judgment in qc-behavioral; feat-agent-template.md for extensibility
- [x] Added T3-F: architecture graph analyzer + dependency-rules.md lifecycle
- [x] Created `docs/design/engineering-principles.md` — living document of guiding principles
- [x] T1-B: Created `qc-structural` and `qc-behavioral` agents; updated `lead-orchestrator` with two-stage QC pipeline (#171)
- [x] T1-C: Added `## Acceptance Checklist` and `feat-agent-template.md` (#171, #174)
- [x] T1-D: Structured per-item PASS/FAIL/FLAG checklist format in qc-structural and qc-behavioral (#171)
- [x] T1-E: Pre-flight context injection documented in `lead-orchestrator` (#171)
- [x] T1-F: Blueprint format (deterministic → agentic sequence) documented in `lead-orchestrator` (#171)
- [x] T1-G: Added `## Max-Iterations Policy` (cap build-fix cycles at 3) to all four feat-agent definitions (#174)
- [x] T1-H: Added `## Allowed Tools` subset to all four feat-agent definitions (#174)
- [x] Documented jj and jst workflow in `CLAUDE.md` (#173)
- [x] Deleted `qc-reviewer.md` — superseded by `qc-structural` + `qc-behavioral`
- [x] T1-A: Architecture layer test + magic numbers + mli coverage linters in `trading/devtools/checks/` with `linter_exceptions.conf` for documented path exceptions
- [x] T1-A: File length linter — 300-line soft limit, 500-line declared-large (`@large-module`), 11% cap
- [x] T1-A+: Function length linter — `devtools/fn_length_linter/` OCaml AST via `compiler-libs`; 5 annotated exceptions with `@large-function`
- [x] T3-B: AVR loop closure already implemented in `lead-orchestrator` Step 5 — auto-dispatches QC for any READY_FOR_REVIEW feature in the same run
- [x] qc-structural: P1/P2/P4 updated to "verified by linter (H3)" — QC no longer manually re-scans; linters are deterministic
- [x] T3-F: Created `docs/design/dependency-rules.md` — R1–R6 rules with lifecycle states; R1, R4, R6 enforced; R2, R3 monitored; R5 proposed
- [x] T1-I: `devtools/checks/agent_compliance_check.sh` — verifies ## Acceptance Checklist, ## Max-Iterations Policy, ## Allowed Tools in all feat-*.md; wired into dune runtest
- [x] T1-J: `qc-structural` Step 1 — stale branch FLAG check: counts commits on main@origin not reachable from feature branch; FLAG if > 10
- [x] T1-K: `linter_exceptions.conf` — all entries now carry `# review_at:` annotations; format docs updated with retirement guidance
- [x] T1-L: `lead-orchestrator` Step 4 — parallel write conflict policy: shared files read-only during parallel feat-agent runs; proposed changes surface in return values
