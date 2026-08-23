# Triage labels — canonical defaults

This file maps the five canonical triage roles to the GitHub label strings the `triage` skill applies on `dayfine/trading`. The defaults below match the role names verbatim — no overrides for this repo.

| Role | Label string | Meaning |
|---|---|---|
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate. Default for any new bug / feature request. |
| `needs-info` | `needs-info` | Waiting on the reporter for more info — repro steps, version, scope clarification. |
| `ready-for-agent` | `ready-for-agent` | Fully specified, AFK-ready. An autonomous agent (`lead-orchestrator` or hand-dispatched) can pick it up with no human context. |
| `ready-for-human` | `ready-for-human` | Needs human implementation (sensitive change, design call, external dep, etc.). |
| `wontfix` | `wontfix` | Will not be actioned. |

## Label creation

If the labels don't yet exist on `dayfine/trading`, create them via:

```bash
gh label create --repo dayfine/trading needs-triage      --color FBCA04 --description "Maintainer needs to evaluate"
gh label create --repo dayfine/trading needs-info        --color D4C5F9 --description "Waiting on reporter"
gh label create --repo dayfine/trading ready-for-agent   --color 0E8A16 --description "Fully specified, AFK-ready"
gh label create --repo dayfine/trading ready-for-human   --color 1D76DB --description "Needs human implementation"
gh label create --repo dayfine/trading wontfix           --color CCCCCC --description "Will not be actioned"
```

(Idempotent — `gh label create` exits non-zero if the label already exists; suppress with `|| true` when scripting.)

## Grading taxonomy (added 2026-08-22, user-requested)

Orthogonal to the triage roles above. Every open issue carries **one label from
each of the four dimensions**; the triage roles continue to track workflow
state independently.

| Dimension | Labels | Meaning |
|---|---|---|
| Nature | `kind/bug` | Defect in trading/analysis code |
| | `kind/feat` | New capability |
| | `kind/harness` | Process / CI / agent-infra fix or improvement |
| | `kind/research` | Experiment or measurement question |
| | `kind/data` | Data provisioning / integrity |
| Urgency | `P0` | Drop everything (red main / blocking all work) |
| | `P1` | Next session(s) — schedule deliberately |
| | `P2` | Queued, agent-sized |
| | `P3` | Backlog |
| | `P4` | Someday / parked |
| Impact | `impact/H` | Moves decisions, correctness, or measurement materially |
| | `impact/M` | Meaningful but bounded |
| | `impact/L` | Nicety / hygiene |
| Complexity | `size/S` | One sitting |
| | `size/M` | Agent + gates |
| | `size/L` | Multi-PR project |

Conventions:

- **Urgency ≠ impact.** A `P3 impact/H` item (e.g. a heavy data project) is
  real but not scheduled; a `P2 impact/L` quick fix may ship first because it
  is nearly free. Priority ordering for a session: P-level first, then
  impact within it, with `size/S` items usable as gap-fillers.
- **One `kind/*` per issue** — pick the dominant nature. A CI bug is
  `kind/harness` (the area), not `kind/bug` (reserved for trading/analysis
  code defects).
- **Re-grade on new evidence** — a blocked item keeps its P-level with the
  blocker named in a comment (e.g. #2405 is P3 while blocked by #2403).
- Apply via REST (`gh api -X POST repos/dayfine/trading/issues/<N>/labels`)
  — this repo's token lacks the GraphQL scopes `gh issue edit` needs.

## Adjacent state outside the label system

- **PR review verdicts** (APPROVED / CHANGES_REQUESTED / COMMENTED) are tracked separately via `gh pr review` — see `docs/agents/issue-tracker.md` and `.claude/agents/qc-structural.md` for the contract.
- **CI gates** (`build-and-test` + `perf-tier1-smoke`) are tracked via GitHub's check-runs API; the merge-gate discipline lives in `.claude/rules/pr-merge-gates.md`.

## Where this is referenced

- `CLAUDE.md` §"Agent skills" → "Triage labels"
- The `triage` skill reads this file to decide which label to apply at each state-machine transition.
