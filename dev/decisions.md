# Decisions & Guidance

**Agents: read this at the start of every session.**
**Lead: summarize new decisions in each daily summary.**

This file is the primary channel for human → agent communication between sessions.
Write answers, decisions, and direction changes here. Agents will pick them up the next morning.

---

## Open Questions

_(None yet — system just initialized.)_

---

## Decisions Log

### Architecture

- Do not modify existing `Portfolio`, `Orders`, or `Position` modules. Build alongside them.
- All thresholds and parameters must live in config, never hardcoded.
- All analysis functions must be pure (same input → same output, no hidden state).
- The Weinstein strategy implements the existing `STRATEGY` module type.

### Development

- Follow TDD workflow from CLAUDE.md: interface first → tests → implementation.
- Mark "Interface stable: YES" in status file as soon as `.mli` is finalized, even before full impl.
- QC approval required before any feature merges to main.
- Merge order: data-layer → portfolio-stops → screener → simulation.

### order_gen — correct design (two prior attempts closed for violating this)

- **Location:** `trading/weinstein/order_gen/` — NOT `analysis/weinstein/order_gen/`
- **Input:** `Position.transition list` from `strategy.on_market_close` — NOT screener candidates
- **Role:** pure formatter only — translates transitions into broker order suggestions; no sizing decisions, no `Position.t` dependency, no `Portfolio_risk` calls
- **Rationale:** sizing decisions are already made by the strategy; order_gen is strategy-agnostic so any strategy using Position.transition gets order formatting for free
- **Reference:** `docs/design/eng-design-3-portfolio-stops.md` §"Order Generation" — see the `.mli` sketch and the decision table at the bottom of that section
- PRs #203 and #214 were both closed for putting order_gen in `analysis/` and making it take screener candidates with sizing logic

---

## Direction Changes

### 2026-04-14 — Backtest infrastructure has its own agent + Plan-first dispatch

- **`feat-backtest` agent now owns the backtest-infra track.** Previously
  human-driven. Definition at `.claude/agents/feat-backtest.md`. Status
  file at `dev/status/backtest-infra.md`. Scope: experiments + strategy-
  tuning features (stop-buffer tuning, drawdown circuit breaker,
  per-trade stop logging, segmentation-based stage classifier, universe
  filter, sector-data scrape integration). Distinct from `feat-weinstein`
  (which owns the base strategy code, currently complete).

- **Flagship Immediate item: stop-buffer tuning experiment.** The entire
  #306/#315/#316 infrastructure was built specifically to unblock it.
  See `dev/status/backtest-infra.md` §Next Actions.

- **Plan-first applies to feat-backtest's first deliverable.** Per
  `.claude/agents/lead-orchestrator.md` §Step 3.5 (triggers 1 "first
  deliverable from a new agent" and 4 "experiment design"), the
  orchestrator dispatches the built-in `Plan` subagent to produce
  `dev/plans/stop-buffer-<YYYY-MM-DD>.md` BEFORE dispatching feat-backtest.
  Human reviews the plan PR and merges it; feat-backtest is then
  dispatched on the next run with the approved plan as binding pre-flight
  context.

- **Lead-orchestrator has Plan Mode.** `./dev/run.sh --plan` short-circuits
  Steps 2-6 and emits a dispatch plan to `dev/daily/<DATE>-plan.md`
  without spawning any subagents. Use for dry runs.

- **`dev/run.sh` is now hardened**: pre-flight asserts (`claude` on PATH,
  agent file present, `## Allowed Tools` lists Agent), live event ticker
  via stream-json + jq, heartbeat every 30s. Helpers in `dev/lib/`.

- **Orchestrator daily summary drift is a known issue.** Sections like
  `## Integration Queue` get copied forward from prior dailies rather
  than reconciled against current GH state. Fix tracked in
  `dev/status/harness.md` Follow-up; gated on `gh` auth in the runtime
  environment (see `dev/status/orchestrator-automation.md`).

---

## Notes for Specific Agents

### feat-backtest

- Your first session must check the dispatch prompt for `### Approved plan`.
  If present, treat the referenced `dev/plans/...md` file's §Approach and
  §Out of scope as binding; QC will verify. If absent and the item you're
  about to work on matches a Step 3.5 trigger, **stop and return an
  escalation** instead of implementing.
- Don't modify `weinstein_strategy.ml` or core stop-machine code — build
  alongside, or surface the proposed change in your status file for
  feat-weinstein review.

### lead-orchestrator

- Per §Step 3.5: invoke the `Plan` subagent before dispatching any feat-agent
  whose status file §Completed is empty (e.g. feat-backtest today),
  whose item is tagged `plan_required: true`, has prior closed/rejected
  PR attempts, or is an empirical experiment.
- Plan-mode invocations (`--plan` token in prompt) MUST NOT dispatch
  any subagent. Read state, write `dev/daily/<DATE>-plan.md`, exit.
