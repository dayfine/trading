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

---

## Direction Changes

_(None yet.)_

---

## Notes for Specific Agents

_(Add per-agent notes here as needed, prefixed with the agent name.)_
