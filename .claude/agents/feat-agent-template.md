---
name: feat-agent-template
description: Template and contract for all feat-* agent definitions. Every feat-agent must include the required sections below. This file is read by the health-scanner to verify compliance.
---

# Feat-Agent Definition Template

This document defines the required structure for every `feat-*.md` agent definition.
When creating a new feature agent, copy this template and fill in the feature-specific
sections. Do not omit required sections — the health-scanner checks for their presence.

---

## Required sections (every feat-agent must have all of these)

### 1. Frontmatter

```yaml
---
name: feat-<feature-name>
description: <one-line description of what this agent builds>
---
```

### 2. Session startup sequence

The agent must read these at the start of every session, in order:

1. `dev/agent-feature-workflow.md` — shared workflow
2. `CLAUDE.md` — code patterns and idioms
3. `dev/decisions.md` — human guidance
4. `dev/status/<feature>.md` — resume from where you left off
5. `docs/design/<eng-design-N-feature>.md` — the feature's design doc
6. Any additional design docs relevant to this feature
7. **If the dispatch prompt mentions an "Approved plan" under the
   pre-flight context, read `dev/plans/<name>-<date>.md` first — its
   §Approach and §Out of scope are binding.** See
   `.claude/agents/lead-orchestrator.md` §Step 3.5 for when plans
   are produced.
8. State the session plan before writing any code

### 3. Branch and status file

```
Your branch: feat/<feature-name>
Status file: dev/status/<feature>.md
```

### 4. Allowed Tools (required, verbatim or adjusted)

```markdown
## Allowed Tools

Read, Write, Edit, Glob, Grep, Bash (build/test commands only), WebFetch.
Do not use the Agent tool (no subagent spawning).
```

### 5. Max-Iterations Policy (required, verbatim)

```markdown
## Max-Iterations Policy

If after **3 consecutive build-fix cycles** `dune build && dune runtest` is still
failing: stop, report your partial state and the specific blocker, update
`dev/status/<feature>.md` to BLOCKED, and end the session. Do not continue
looping — diminishing returns set in quickly and looping wastes budget.
```

### 6. Acceptance Checklist (required, feature-specific items)

```markdown
## Acceptance Checklist

QC agents will verify all of the following. Satisfy every item before setting
status to READY_FOR_REVIEW.

- [ ] <feature-specific item derived from the engineering design doc>
- [ ] <...>
- [ ] Every public function in every `.ml` is exported in the corresponding `.mli` with a doc comment
- [ ] No function exceeds 50 lines
- [ ] All configurable parameters routed through config record — no magic numbers
- [ ] `dune build && dune runtest` passes with zero warnings
- [ ] `dune fmt --check` passes (or: `dune fmt` produces no diff)
- [ ] `Interface stable: YES` is set in `dev/status/<feature>.md` once `.mli` is finalized
```

### 7. Status file format (required, feature-specific fields)

Document the canonical format for `dev/status/<feature>.md` that this agent must
maintain. The canonical sections are:

```markdown
## Last updated: YYYY-MM-DD
## Status
IN_PROGRESS | READY_FOR_REVIEW | MERGED

## Interface stable
YES | NO

## Completed
(what is merged and done — no done items belong in Follow-up)

## In Progress
(current session work)

## Blocking Refactors
(items that must be resolved before downstream features can depend on this one;
the lead-orchestrator dispatches these before feat-agents on each run)

## Follow-up
(non-blocking open items; the orchestrator counts these for maintenance cycles;
remove items once addressed — this is a backlog, not a ledger)

## Known gaps
(long-horizon items with no immediate action needed; informational only;
the orchestrator does not act on this section)
```

**Rules:**
- Remove done items from `## Follow-up` immediately — do not accumulate history there
- Omit `## Recent Commits` — git log is authoritative; PR numbers belong in `## Completed`
- `## Blocking Refactors` takes priority over feature work on the next run
- `## Known gaps` is never empty-checked by automation; it is for human awareness only

### 8. Index row update (required)

At the end of every session, in addition to updating the track's own
status file, update the corresponding row in `dev/status/_index.md`:

- **Status** cell — mirrors the status file's `## Status`
- **Owner** cell — this agent's name (usually unchanged)
- **Open PR(s)** cell — PRs currently open against this track
- **Next task** cell — the top-of-queue item from the status file's
  `## Next Steps`

Agents only touch their own row. Adding a new track to the system means
creating the status file **and** adding a row to the index in the same
commit. `lead-orchestrator` reconciles the index against all status
files at end-of-run and flags drift, but agents should keep the row
fresh so the index is usable between orchestrator runs.

---

## Architecture constraint

Every feat-agent must respect the layer boundary:

- Weinstein-specific logic belongs in new modules alongside the existing ones
  (`trading/weinstein/`, `analysis/weinstein/`) — **not** inside the shared modules
  (`Portfolio`, `Orders`, `Position`, `Strategy`, `Engine`)
- If a change to a shared module is genuinely strategy-agnostic (i.e., it would
  benefit any strategy, not just Weinstein), it is permitted — but the agent must
  note it explicitly in its status file and qc-behavioral will assess it
- When in doubt: build alongside, don't modify

---

## Extensibility notes (for harness maintainers)

When adding a new feat-agent for a future feature:

1. Copy this template as `.claude/agents/feat-<name>.md`
2. Fill in the feature-specific parts: design doc path, branch name, acceptance
   checklist items derived from the design doc
3. Add a status file at `dev/status/<name>.md` using the standard format
4. Add the feature to `dev/decisions.md` if there are priority or sequencing notes
5. The lead-orchestrator will pick it up automatically on the next run (T4-C)
6. The health-scanner will verify the agent definition contains all required sections

The harness practices (tool subset, iteration cap, checklist format, structured QC
output) are defined here and in the QC agent definitions — they apply to all feat-agents
automatically. No changes to the QC agents or orchestrator are needed for new features.
