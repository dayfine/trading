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

## Adjacent state outside the label system

- **PR review verdicts** (APPROVED / CHANGES_REQUESTED / COMMENTED) are tracked separately via `gh pr review` — see `docs/agents/issue-tracker.md` and `.claude/agents/qc-structural.md` for the contract.
- **CI gates** (`build-and-test` + `perf-tier1-smoke`) are tracked via GitHub's check-runs API; the merge-gate discipline lives in `.claude/rules/pr-merge-gates.md`.

## Where this is referenced

- `CLAUDE.md` §"Agent skills" → "Triage labels"
- The `triage` skill reads this file to decide which label to apply at each state-machine transition.
