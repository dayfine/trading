# dev/ — Agent Workflow

This directory coordinates daily parallel development by a team of Claude agents
building the Weinstein Trading System.

## How to run

```bash
# Run today's session immediately:
./dev/run.sh

# Run only if it hasn't already run today (idempotent — safe to hook into startup):
./dev/run-if-needed.sh
```

`run.sh` launches the `lead-orchestrator` agent non-interactively via `claude -p`.
It spawns up to 4 parallel feature agents and any needed QC agents, then exits.

`run-if-needed.sh` wraps `run.sh` with a guard: skips if today's summary already
exists or a run is in progress. Hook this into container startup or shell login.

## What happens each run

1. Lead reads `decisions.md` and all `status/*.md` files
2. Lead spawns eligible feature agents in parallel (respecting dependency order)
3. Lead spawns QC agents for any features marked `READY_FOR_REVIEW`
4. Lead writes a daily summary to `daily/YYYY-MM-DD.md`

## Directory layout

```
dev/
  run.sh              # Start a session now
  run-if-needed.sh    # Start only if not yet run today (idempotent)
  decisions.md        # Human → agent communication (you write here)
  status/             # Agents update their feature status each session
  daily/              # Lead writes daily summaries here (you read here)
  reviews/            # QC agent writes approval/rework decisions here
  logs/               # Raw claude -p output logs (gitignored)
```

## Human workflow

**To give direction between sessions:** edit `decisions.md`. Agents read it at
the start of every session. Use it for answers to open questions, priority
changes, or architecture decisions.

**To see what happened:** read `daily/YYYY-MM-DD.md`. The lead summarizes what
each agent did, what's blocked, and any open questions for you.

**To see feature progress:** check `status/<feature>.md`. Each agent keeps this
up to date with current phase, what's done, what's next, and any blockers.

## Version control (jj)

The repo uses [Jujutsu (jj)](https://github.com/jj-vcs/jj) in colocated mode on
top of git. `jj` is installed in the devcontainer and initialized automatically
on container start (`postStartCommand` in `devcontainer.json`).

Agents use jj instead of raw git for all VCS operations. Key differences:

| git | jj |
|-----|-----|
| `git add && git commit -m "..."` | `jj describe -m "..."` (no staging area) |
| `git status` | `jj status` |
| `git diff` | `jj diff` |
| `git log` | `jj log` |
| `git push -u origin feat/x` | `jj git push --bookmark feat/x` |
| `git diff main...feat/x` | `jj diff --from main@origin --to feat/x@origin` |

The main benefit for parallel agents: jj stores merge conflicts as first-class
commits rather than blocking the push. Conflicts can be resolved later without
losing work.

You can still use git for anything not covered by jj (e.g. `git fetch`, viewing
GitHub PRs). The two coexist cleanly.

## Dependency order

Feature agents run in this order (earlier features must have stable interfaces
before later ones can start):

```
data-layer ─┐
             ├─→ screener ─┐
portfolio-stops ─┘           ├─→ simulation
                              ┘
```

`data-layer` and `portfolio-stops` run in parallel from day one.
`screener` starts once `data-layer` interface is stable.
`simulation` starts once all three are stable.
