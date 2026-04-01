# Status: harness

## Last updated: 2026-04-04

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
- [ ] T1-B: Create `qc-structural` agent (refactored from `qc-reviewer`)
- [ ] T1-B: Create `qc-behavioral` agent (new, domain-focused)
- [ ] T1-B: Update `lead-orchestrator` to spawn both QC agents (structural gates behavioral)
- [ ] T1-C: Add `## Acceptance Checklist` to each `feat-*.md` agent definition
- [ ] T1-D: Define structured QC checklist output format (per-item PASS/FAIL, not prose)
- [ ] T1-E: Pre-flight context injection on every feat-agent dispatch (test failures, last QC, open follow-ups)
- [ ] T1-F: Define lead-orchestrator blueprint format (explicit deterministic vs agentic nodes)
- [ ] T1-G: Add max-iterations policy to each feat-agent definition (cap build-fix cycles at 3)
- [ ] T1-H: Specify allowed tool subsets per agent type in agent definitions

## Tier 2 — Milestone-gated

- [ ] T2-A: Golden scenario test suite — screener regression tests (after M4)
- [ ] T2-A: Golden scenario test suite — stop state machine regression tests (after M4)
- [ ] T2-B: Performance gate test (`trading/weinstein/simulation/test/performance_gate_test.ml`) (at M5)
- [ ] T2-B: Reference backtest config + expected metrics (`dev/benchmarks/reference_backtest.json`) (at M5)
- [ ] T2-C: Walk-forward regression gate (`dev/benchmarks/best_config.json`) (at M7)
- [ ] T2-D: Live trading gate + paper-trading validation period in `dev/milestones/m6-paper-trading.md` (before M6)

## Tier 3 — After M5 stable

- [ ] T3-A: `health-scanner` agent definition (`.claude/agents/health-scanner.md`)
- [ ] T3-B: AVR loop closure in `lead-orchestrator` (auto-dispatch QC on READY_FOR_REVIEW)
- [ ] T3-C: Dynamic context injection into feat-agent prompts (last QC findings, failing tests)
- [ ] T3-D: Audit trail — `dev/audit/YYYY-MM-DD-<feature>.json` per auto-merge action
- [ ] T3-E: Cost/token budget visibility in daily summary + budget cap in `merge-policy.json`

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
