# Status: Orchestrator Automation

## Last updated: 2026-04-16

## Status
IN_PROGRESS

## Interface stable
NO

## Ownership
Harness-adjacent. Implementation will likely be a mix of
`harness-maintainer` (workflow file, Dockerfile updates) and prompt-template
work across `.claude/agents/*.md` (strip `docker exec` wrappers). No dedicated
feat-agent yet.

## Goal

Run the daily `lead-orchestrator` session automatically on GitHub Actions
instead of requiring a human to fire `dev/run.sh` locally. The daily summary
lands as a branch + PR for human review, same read-model as today.

## Research done (2026-04-14 + 2026-04-15)

Initial investigation (2026-04-14):

- **Official action exists**: [`anthropics/claude-code-action@v1`](https://github.com/anthropics/claude-code-action).
  Supports `schedule:` cron + `workflow_dispatch:`, passes `--agent` and
  `--allowedTools` through `claude_args`.
- **Subagent spawning works**: `Agent`/`Task` tool invocations are in-process
  to the single `claude -p` runtime, not separate jobs. The orchestrator's
  core capability is preserved.
- **Auth**: `ANTHROPIC_API_KEY` secret. `CLAUDE_CODE_OAUTH_TOKEN` (Pro/Max
  subscription) also supported — this is what we'll use, since the
  subscription caps act as a natural cost ceiling (see §Cost below).
- **Cost**: no hard per-run token budget in the action itself. `--max-turns N`
  + job `timeout-minutes` are the only guardrails. But using OAuth (Pro/Max)
  rather than pay-per-token API key means the subscription's session limits
  bound spend.

### Follow-up research (2026-04-15)

Six specific questions sent to the Claude Code guide. Results:

- **Per-subagent `model:` frontmatter works under the Action.** Same keys
  (`opus` / `sonnet` / `haiku`) we already pinned locally (#362). The
  Action does NOT force a single model via `--model` in `claude_args`.
  Per-agent routing is honored end-to-end.
- **`CLAUDE_CODE_OAUTH_TOKEN` confirmed** as the correct secret name for
  Pro/Max OAuth (vs `ANTHROPIC_API_KEY` for API-key billing). Generated
  via `claude setup-token`. Docs don't publish a "CI disallowed in prod"
  restriction — fine for personal / side-project use.
- **GitHub App path is the recommended auth** for jj push + downstream-
  CI triggering. The action repo ships an HTML [Quick Setup
  Tool](https://github.com/anthropics/claude-code-action/blob/main/docs/create-app.html)
  that automates the App-registration form. `actions/create-github-app-token@v2`
  provides the tokens in-workflow. PAT also works but needs manual
  rotation. SSH deploy key is not in official guidance.
- **Rate-limit behavior at quota exhaustion: UNKNOWN.** The Action docs
  don't specify whether mid-run quota exhaustion fails fast, hangs, or
  retries. We have local evidence (2026-04-14 run killed with
  `"error":"rate_limit"` message) that at least the `claude -p` process
  exits with is_error=true when the 5-hour cap is hit, but how that
  surfaces inside the Action wrapper is not documented. **Test this
  empirically on first manual `workflow_dispatch` run.**
- **Cost / token observability: UNKNOWN.** Action docs don't publish
  structured outputs for token counts. Budget assertions would have to
  parse free-form logs. **Gap; file an issue on action repo after v1.**
- **Partial-failure signalling: UNKNOWN.** No documented "neutral /
  soft-fail" status convention. Our orchestrator already writes findings
  to the daily summary file; we'll handle this with a post-step that
  greps `dev/daily/<date>-run*.md` for §Escalations and `exit 1` if
  non-empty (plain GHA idiom).

## Decisions (2026-04-14)

| Question | Decision |
|---|---|
| Cadence | **Nightly** cron |
| Scope | **Full orchestrator** (not harness-only) |
| Output | Daily summary lands as a **branch + PR**, not committed to main |
| Container | Reuse `trading-devcontainer` image (already needed for jj, jst, opam env) |
| Cost ceiling | Rely on **subscription-based caps via OAuth token**, not per-run API budget |

## Open blockers (must solve before v1)

### 1. GitHub token for jj push

The default `GITHUB_TOKEN` can push branches but won't trigger downstream
workflows (CI won't run on `feat/*` branches created by the orchestrator's
subagents). Need a token whose pushes DO trigger downstream workflows.

**Chosen approach: fine-grained Personal Access Token.** Simpler than a
custom GitHub App for a single-developer setup; swap to an App later if
the manual rotation burden (1 year expiration) becomes annoying.

Setup steps (human, one-time):
1. https://github.com/settings/tokens?type=beta → Generate new token
2. Scope: `dayfine/trading` only
3. Permissions: Contents R+W, Pull requests R+W
4. Expiration: 1 year (set calendar reminder to rotate)
5. Store as repo secret `BOT_GITHUB_TOKEN`

### 2. `docker exec <container-name>` in agent prompts

Every feat-agent / QC-agent prompt template bakes in
`docker exec <container-name> bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && ...'`.
In the GHA runner the runner IS the container, so these commands fail. Needs
a systematic refactor of the prompt templates in:

- `.claude/agents/lead-orchestrator.md` Step 4 (feat-agent prompt template)
- `.claude/agents/feat-weinstein.md` Verification section
- `.claude/agents/feat-backtest.md`
- `.claude/agents/harness-maintainer.md` Verification section
- `.claude/agents/ops-data.md`
- `.claude/agents/health-scanner.md`
- `.claude/agents/qc-structural.md`

**Chosen approach: wrapper script**, not an env-var prefix. The env-var
prefix (earlier plan) is fragile: it can't cleanly hold the `cd` +
`eval $(opam env)` context, the single-quote shell wrapping changes
between the two modes, and agents may "helpfully" expand or omit the
prefix in ways that drift silently.

New plan — add `dev/lib/run-in-env.sh`:

```bash
#!/bin/bash
set -euo pipefail
TRADING_ROOT="/workspaces/trading-1/trading"
if [ -z "${TRADING_IN_CONTAINER:-}" ]; then
  exec docker exec -e EODHD_API_KEY trading-1-dev bash -c \
    "cd $TRADING_ROOT && eval \$(opam env) && $*"
else
  cd "$TRADING_ROOT"
  eval "$(opam env)"
  exec "$@"
fi
```

Every agent prompt replaces:

```
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && dune build'
```

with:

```
dev/lib/run-in-env.sh dune build
```

- `dev/run.sh` does not set `TRADING_IN_CONTAINER`; the script defaults
  to the `docker exec` path.
- The GHA workflow sets `TRADING_IN_CONTAINER=1` at the step level; the
  script takes the native path.
- Agents see one pattern across environments. Context-setting
  (cd + opam env) is centralized in the script, not repeated per prompt.

### 3. Publish `trading-devcontainer` image to GHCR

See [#325](https://github.com/dayfine/trading/pull/325) — already adds
publishing for `trading-devcontainer:latest`. Orchestrator workflow will
reference this image via `container:`.

### 4. Subscription OAuth token

Create `CLAUDE_CODE_OAUTH_TOKEN` GitHub repo secret (one-time setup).
The OAuth token gives us subscription-based rate-limits as the effective
cost ceiling. Document the setup in `dev/config/README.md`.

### 5. Partial-failure reporting

The orchestrator returns 0 even when some subagents fail (by design — it
writes findings to the daily summary). For GHA to surface a yellow/red run,
add a post-step that parses `dev/daily/<date>.md` for the Escalations
section and fails the job if it's non-empty.

## Recommended workflow sketch (not for commit)

```yaml
# .github/workflows/orchestrator.yml
name: Daily orchestrator
on:
  schedule:
    - cron: "0 14 * * *"   # 07:00 Pacific
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  orchestrator:
    runs-on: ubuntu-latest
    timeout-minutes: 180
    container:
      image: ghcr.io/${{ github.repository_owner }}/trading-devcontainer:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
      options: --user 0
    env:
      HOME: /home/opam
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.BOT_GITHUB_TOKEN }}
          prompt: |
            Run the daily orchestrator session. Today is $(date +%Y-%m-%d).
            Read .claude/agents/lead-orchestrator.md and follow it.
          claude_args: |
            --agent lead-orchestrator
            --allowedTools Agent,Bash,Read,Write,Edit,Glob,Grep
            --max-turns 200
      - name: Push daily summary branch
        run: |
          eval $(opam env)
          DATE=$(date +%F)
          jj bookmark set ops/daily-$DATE -r @
          jj git push --bookmark ops/daily-$DATE --allow-new
          # Open PR: `gh pr create --base main --head ops/daily-$DATE ...`
```

## Implementation sequencing

1. Land #325 (publishes `trading-devcontainer:latest`) — **DONE**
2. Human, one-time setup:
   - Create fine-grained PAT at https://github.com/settings/tokens?type=beta
     (scope: `dayfine/trading`, perms: Contents R+W + Pull requests R+W)
     → store as repo secret `BOT_GITHUB_TOKEN`.
   - Run `claude setup-token` on a subscription-authenticated machine
     → store result as repo secret `CLAUDE_CODE_OAUTH_TOKEN`.
3. Strip `docker exec` from agent prompts — add `dev/lib/run-in-env.sh`
   wrapper (see blocker §2), replace every hardcoded docker-exec +
   cd + opam-env prelude in the 7 agent definitions with a call to
   the wrapper. Single PR, wide but mechanical diff. Works locally
   (default: docker-exec path) and in GHA (when `TRADING_IN_CONTAINER=1`
   is set at the job env level, takes native path).
4. Add `.github/workflows/orchestrator.yml` with `workflow_dispatch` only
   (no cron yet) — dogfood manually. Include a post-step that parses
   the daily summary for §Escalations and fails the job if non-empty.
5. Verify one successful manual run end-to-end, check cost + timing.
   **Also test rate-limit behavior** by artificially exhausting the
   quota (run several full sessions locally same-day, then trigger the
   Action). Record what happens — fail-fast, hang, or clean error —
   and harden the workflow around it.
6. Enable nightly cron once manual run is reliable.

Parallel-trackable pieces an agent can pick up before the human
completes step 2:
- Step 3 (strip docker exec) — `harness-maintainer` track. Small diff,
  no secrets needed.
- Draft `.github/workflows/orchestrator.yml` as a PR without enabling
  it — `harness-maintainer` track. Workflow file with `workflow_dispatch`-
  only trigger is safe to land before secrets exist; the first dispatch
  attempt will just fail authorization until the human finishes step 2.

## Phase 2: adopt background execution

Once Phase 1 (the manual `workflow_dispatch` path above) is reliably
producing daily summary PRs, move from "orchestrator does one thing at
a time" to "orchestrator fires independent work concurrently." Phase 2
cuts wall-time by running scrapes, backtests, and some QC steps in
parallel instead of serial.

### Research findings (2026-04-16)

From a Claude Code guide research session:

- **`Agent` tool `run_in_background: true`** is documented in Claude
  Code docs. Subagents run concurrently while the parent continues;
  parent is notified on completion. Works with `isolation: "worktree"`.
  Experimentally confirmed in this repo (earlier today we dispatched
  parallel subagents via the non-background path; background mode is
  the same tool shape with a flag).
- **`Bash` tool `run_in_background`** is present in the in-harness tool
  schema but **not documented in public Claude Code docs**. The
  documented alternative is the **Monitor tool** (v2.1.98+), which
  runs a script in background and streams stdout back line-by-line
  so the agent can react mid-conversation.
- **`anthropics/claude-code-action@v1` (GHA) background behavior:
  UNKNOWN** — docs are silent on whether the action supports
  background tool use or forces serial execution. Needs empirical
  test on a dogfood run with `show_full_output: true`.

### Three concrete wins (same pattern, same shape, both environments)

1. **Scraper dispatches (ops-data).** The Finviz sector scrape is
   ~2.2h; today it blocks a terminal. Background `Bash` + Monitor
   tool lets the orchestrator kick it off and keep working.

2. **Golden backtest re-runs (backtest-infra).** Three buffer
   variants × ~40 min each. Today they serialize (~2h total). As
   three background subagents with worktree isolation: ~40 min total.

3. **QC pipeline cross-feature parallelism.** The current serial
   gate is correct WITHIN a feature (qc-behavioral waits on
   qc-structural APPROVED for the same feature). Across features,
   QC for feature A can run in parallel with implementation for
   feature B — that's the pattern background Agent dispatch enables.

### Environment split (hypothesis — confirm before committing)

| Env | Background `Bash` | Background `Agent` | Confidence |
|---|---|---|---|
| Local (`claude -p`) | Works (in tool schema; empirically used today) | Works (documented; empirically used today) | High |
| GHA (`claude-code-action@v1`) | Unknown | Unknown | Zero |

If GHA forces serial tool use, we fall back to the same env-split
pattern used elsewhere: background locally, sequential in GHA. If
GHA supports background execution, we get the wall-time wins in both.

### Rollout sequence

Test before commit — pattern is the same, feasibility differs by env.

1. **Empirical test locally first.** Convert ONE existing slow op
   (suggest Finviz scraper) to `Bash run_in_background: true` +
   Monitor. Confirm: (a) the command runs, (b) the agent gets a
   completion notification, (c) the agent can read the output after.
   Document findings in `dev/notes/background-execution.md` (new file).
2. **Empirical test in GHA.** Run the same op via the action with
   `show_full_output: true` (landing in #371). Watch the log: does
   the tool call return before the op completes, or does the action
   block? Record the result.
3. **Roll out based on findings.** For confirmed envs: update the
   three concrete wins above (scraper → background; golden re-runs →
   background subagents; QC cross-feature → background). For
   unconfirmed envs: keep serial as today's behavior.

### Prerequisites
- Phase 1 stable (Phase 2 depends on being able to observe what the
  orchestrator does in GHA — #371's `show_full_output: true` is the
  enabler).
- One successful daily-summary PR round-trip first.

## References

- Research transcript: research agent run 2026-04-14 (see Escalations in
  today's daily summary if it was logged, otherwise rerun the research prompt)
- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
- [Claude Code GHA docs](https://code.claude.com/docs/en/github-actions)
- [Setup guide](https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Scheduled tasks](https://code.claude.com/docs/en/scheduled-tasks)
