# Status: harness

## Last updated: 2026-04-05

## Status
IN_PROGRESS

## Design doc
`docs/design/harness-engineering-plan.md`

---

## Tier 1 — Immediate

- [ ] T1-A: Add `dune fmt --check` as hard gate (document in CLAUDE.md)
- [ ] T1-A: Add architecture layer test (`analysis/` cannot import `trading/trading/`)
- [ ] T1-A+: Custom linter — function length (>50 lines = test failure)
- [ ] T1-A+: Custom linter — magic numbers in `analysis/weinstein/` not in config
- [ ] T1-A+: Custom linter — public `.ml` functions missing from `.mli`
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
- [ ] T3-B: AVR loop closure in `lead-orchestrator` (auto-dispatch QC on READY_FOR_REVIEW)
- [ ] T3-C: Cross-feature context injection (beyond T1-E baseline — superseded for basic case)
- [ ] T3-D: Audit trail — `dev/audit/YYYY-MM-DD-<feature>.json` with `harness_gap` field on NEEDS_REWORK
- [ ] T3-E: Cost/token budget visibility in daily summary + budget cap in `merge-policy.json`
- [ ] T3-F: Create `docs/design/dependency-rules.md` with initial known boundaries + state lifecycle
- [ ] T3-F: Architecture graph analyzer in health-scanner deep scan (import graph vs. rules doc)
- [ ] T3-F: Rule promotion path — generate dune checks from `enforced` rules automatically

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
