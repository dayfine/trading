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

_(None yet.)_

---

## Notes for Specific Agents

_(Add per-agent notes here as needed, prefixed with the agent name.)_
