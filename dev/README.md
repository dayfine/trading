# dev/ — Agent Workflow

This directory coordinates daily parallel development by a team of Claude agents
building the Weinstein Trading System.

## EODHD bar fixtures (private, fetched)

The 650 `trading/test_data/<A-Z>/**/data.csv` bar files (+ `data.metadata.sexp`) and the 10
`trading/test_data/split_corpus/<case>/bars.csv` are not tracked here (EODHD terms, #3676); they live in the private
repo `dayfine/trading-results` at the same paths, pinned by `dev/test_bars.pin`, with `trading/test_data/test-bars.md5`
(the md5 of every bar file) beside them. The fetch script checks every md5 after extraction and fails on a mismatch.
`trading/devtools/checks/no_tracked_bars_check.sh` fails CI if a bar file is tracked again.

- **Local**: keep a sibling checkout at `~/Projects/trading-results` (`git clone git@github.com:dayfine/trading-results.git`),
  then run `sh dev/scripts/fetch_test_bars.sh` in each checkout or worktree before `dune runtest` or a backtest. It
  extracts the pinned commit (`git -C ~/Projects/trading-results pull` if the pin is missing); set `TRADING_RESULTS_DIR`
  for another location. The docker dev container sees the files because they sit under the checkout.
- **Cloud sessions**: clone trading-results next to the repo, then `TRADING_RESULTS_DIR=<clone> sh dev/scripts/fetch_test_bars.sh`.
- **CI**: every workflow that reads the bars runs the same script with `TRADING_RESULTS_TOKEN` set from the read-only
  `TRADING_RESULTS_READ_TOKEN` secret (a fine-grained token with Contents: read on trading-results only), falling back
  to `BOT_GITHUB_TOKEN` while that secret is unset. Fork PRs get no secrets, so the step fails with a message instead
  of skipping tests.
- **Bump the pin** (new or refreshed bars): commit them to trading-results with a regenerated `test-bars.md5` (command in
  its README), then put that commit in `dev/test_bars.pin`.

## Where agents run

**Agents run on the host machine, not inside Docker.**

`claude` is a CLI tool installed on your host. `run.sh` calls it directly.
The agents use `docker exec <container>` to run build and test commands inside
the container, but the agent processes themselves (and all file I/O) happen on
the host.

This is why `claude` is not found inside the container — it doesn't need to be.

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

## Monitoring a running session

**Watch the live log:**
```bash
tail -f dev/logs/$(date +%Y-%m-%d).log
```

**Check if a session is currently running:**
```bash
ls dev/logs/*.running 2>/dev/null && echo "running" || echo "not running"
# or
ps aux | grep 'claude -p' | grep -v grep
```

**Check what agents are active** (subagent processes):
```bash
ps aux | grep claude | grep -v grep
```

## Stopping a running session

```bash
# Find the lead orchestrator process:
ps aux | grep 'claude -p' | grep -v grep

# Kill it (subagents will also stop):
kill <PID>

# Or kill all claude processes on the host:
pkill -f 'claude -p'
```

The lock file (`dev/logs/YYYY-MM-DD.running`) is cleaned up automatically on
exit. If a session was killed uncleanly, remove it manually:
```bash
rm dev/logs/*.running
```

## Directory layout

```
dev/
  run.sh              # Start a session now
  run-if-needed.sh    # Start only if not yet run today (idempotent)
  decisions.md        # Human → agent communication (you write here)
  status/             # Agents update their feature status each session
  daily/              # Lead writes daily summaries here (you read here)
  reviews/            # QC agent writes approval/rework decisions here
                      #   Each review is on its own branch: dev/reviews/<feature>
                      #   NEVER inside a feature branch
  logs/               # Raw claude -p output logs (gitignored)
```

## Review → rework cycle

This is the full lifecycle from feature development to merge:

```
1. Feature agent develops on feat/<feature> and stacked PR branches
   → marks status READY_FOR_REVIEW when done

2. QC agent reviews each READY_FOR_REVIEW feature:
   → builds and tests on the feature branch (read-only)
   → writes dev/reviews/<feature>.md on a SEPARATE dev/reviews/<feature> branch
     based on main@origin — never committed inside the feature branch
   → outputs a session summary listing: approved PRs, rework needed, open decisions

3. Human reviews the QC session summary (in daily/<date>.md or direct output):
   → approves APPROVED PRs for merge
   → reads NEEDS_REWORK findings and either:
       a. directs the feature agent to fix specific issues, or
       b. overrides the review if the finding is not a real blocker
   → answers any BLOCKED/open decisions in dev/decisions.md

4. Feature agent does rework on the same branch
   → updates PR, marks status READY_FOR_REVIEW again

5. QC agent re-reviews — checks blockers specifically, upgrades to APPROVED if resolved

6. Human merges APPROVED PRs in dependency order
```

**Cross-references**: every review file includes the PR number; every daily summary
lists which reviews were written and which PRs they cover.

## Human workflow

**To give direction between sessions:** edit `decisions.md`. Agents read it at
the start of every session. Use it for answers to open questions, priority
changes, or architecture decisions.

**To see what happened:** read `daily/YYYY-MM-DD.md`. The lead summarizes what
each agent did, what's blocked, and any open questions for you.

**To see feature progress:** check `status/<feature>.md`. Each agent keeps this
up to date with current phase, what's done, what's next, and any blockers.

**To see QC findings:** check `dev/reviews/<feature>.md` (on branch
`dev/reviews/<feature>`). Each review includes the PR number, status
(APPROVED / NEEDS_REWORK / BLOCKED), and specific findings.

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

You can still use git for anything not covered by jj (e.g. viewing GitHub PRs).
The two coexist cleanly.

### Viewing pending agent work (not yet a PR)

```bash
# See all feature branches and their tip commits:
jj log -r 'bookmarks()' --no-graph

# See what a feature branch has that main doesn't:
jj log -r 'main@origin..feat/data-layer@origin' --no-graph

# Diff a feature branch against main:
jj diff --from main@origin --to feat/data-layer@origin

# See all changes across all feature branches at once:
jj log -r 'main@origin..bookmarks()' --no-graph
```

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
