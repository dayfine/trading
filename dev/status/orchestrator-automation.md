# Status: Orchestrator Automation

## Last updated: 2026-04-18

## Status
IN_PROGRESS

Phase 1 live; Phase 2 (background execution) pending.

Phase 1 (scheduled daily orchestrator on GHA) has been producing daily
summary PRs since 2026-04-16. See `.github/workflows/orchestrator.yml`
and daily summary PRs #422/#423/#427 etc. All five §Open blockers below
are resolved — section retained as the implementation record.

## Blocked on
- None. Phase 2 items are scoped-work, not blockers.

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

## Phase 1 blockers — RESOLVED (2026-04-18)

All five items below are done. Retained as implementation record so
future maintainers can see what the v1 gating set was and how each was
addressed.

### 1. GitHub token for jj push — DONE

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

**Resolved:** `BOT_GITHUB_TOKEN` is configured; `actions/checkout@v4`
uses it (`orchestrator.yml:107`, landed in PR #424) so subagent pushes
authenticate as the PAT owner and trigger downstream CI.

### 2. `docker exec <container-name>` in agent prompts — DONE

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

**Resolved:** `dev/lib/run-in-env.sh` landed; workflow sets
`TRADING_IN_CONTAINER=1` (`orchestrator.yml:86`) so agents take the
native path when running in GHA.

### 3. Publish `trading-devcontainer` image to GHCR — DONE

See [#325](https://github.com/dayfine/trading/pull/325) — already adds
publishing for `trading-devcontainer:latest`. Orchestrator workflow will
reference this image via `container:`.

**Resolved:** #325 merged; workflow pulls
`ghcr.io/dayfine/trading-devcontainer:latest` (`orchestrator.yml:73`).

### 4. Subscription OAuth token — DONE

Create `CLAUDE_CODE_OAUTH_TOKEN` GitHub repo secret (one-time setup).
The OAuth token gives us subscription-based rate-limits as the effective
cost ceiling. Document the setup in `dev/config/README.md`.

**Resolved:** `CLAUDE_CODE_OAUTH_TOKEN` is configured and consumed by
`anthropics/claude-code-action@v1` (`orchestrator.yml:135`).

### 5. Partial-failure reporting — DONE

The orchestrator returns 0 even when some subagents fail (by design — it
writes findings to the daily summary). For GHA to surface a yellow/red run,
add a post-step that parses `dev/daily/<date>.md` for the Escalations
section and fails the job if it's non-empty.

**Resolved:** `Fail on escalations` step in `orchestrator.yml:180-231`
greps the daily summary's §Escalations for top-level `[critical]`
bullets and exits 1 if any match. Anchoring was tightened in PR #425
after two regressions (see that PR for the pattern history).

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

All Phase 1 steps below are complete. Retained as implementation record.

1. Land #325 (publishes `trading-devcontainer:latest`) — **DONE**
2. Human, one-time setup — **DONE**: `BOT_GITHUB_TOKEN` and
   `CLAUDE_CODE_OAUTH_TOKEN` repo secrets configured.
3. Strip `docker exec` from agent prompts — **DONE**: `dev/lib/run-in-env.sh`
   wrapper landed; workflow sets `TRADING_IN_CONTAINER=1` so agents
   take the native path in GHA.
4. Add `.github/workflows/orchestrator.yml` with `workflow_dispatch` —
   **DONE**: escalations post-step included (`Fail on escalations`).
5. Verify manual run end-to-end — **DONE**: first successful run
   observed 2026-04-16; rate-limit behavior empirically exercised
   during subsequent runs.
6. Enable cron — **DONE**: three daily runs at `:17` past the hour
   (UTC 08/14/19), see `orchestrator.yml:50-53`.

(Parallel-trackable pieces for pre-secrets work — historical, all
landed with Phase 1.)

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
   **EODHD bulk refresh is the same pattern, different source** —
   weekly full-universe pull (~10k symbols) drives sector-data Item 3
   and ops-data preflight cadence. Wire as a **separate weekly GHA
   workflow** (not the daily orchestrator: different cadence, different
   blast radius, different failure mode). `EODHD_API_KEY` is in the
   repo secrets (added 2026-04-19). Rollout: adapt
   `.github/workflows/orchestrator.yml` into a stripped-down
   `.github/workflows/ops-data-weekly.yml` that dispatches only the
   `ops-data` agent with the secret injected; PR summary on completion.

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

## Completed work

### Orchestrator idempotency — Step 1.5 dispatch guard + structured summary format

**Status:** DONE (2026-04-16) — `harness/orchestrator-idempotency`

Changes landed:
- `.claude/agents/lead-orchestrator.md`:
  - **Step 1b**: cross-reference last summary for drift detection (parse `## Pending work` table in prior run; flag tracks where status file hasn't advanced since dispatch)
  - **Step 1.5**: PR-open dispatch guard — for each eligible track, query `gh pr list` for open PRs; skip feat-agent re-dispatch if PR is in-flight with no new commits; dispatch re-QC only if READY_FOR_REVIEW and SHA changed; include ops-data sentinel check against data-gaps.md content
  - **Step 7**: restructured summary format — `Run timestamp:` + `Run ID:` header lines; `## Pending work` table (parseable: Track | State | Branch | PR | Next step); `## Dispatched this run` table (Track | Agent | Outcome | Notes); `[drift]` labels in Escalations section
  - **Step 5**: qc-structural dispatch prompt now instructs SHA capture and `Reviewed SHA:` as first line of `dev/reviews/<feature>.md`; qc-behavioral dispatch updated to not overwrite the SHA line
- `.claude/agents/qc-structural.md`: Step 5 added — SHA capture + write as first line of review file; `Writing the review file` section updated to require Reviewed SHA line first
- `.claude/agents/qc-behavioral.md`: Step 2 note + writing section note — do not modify `Reviewed SHA:` line; append below existing structural checklist

Verify: `grep -n "Step 1.5\|Pending work\|Dispatched this run\|Reviewed SHA\|Run timestamp\|Run ID:" .claude/agents/lead-orchestrator.md` — all should match; `grep "Reviewed SHA" .claude/agents/qc-structural.md .claude/agents/qc-behavioral.md` — both should match.

## Resolved escalations log

### 2026-04-17

- **§2 (orphan `dev/reviews/backtest-infra-behavioral@origin`)**: qc-behavioral agent pushed its review file as a separate branch to origin (instructions in `qc-behavioral.md` "Writing the review file" section told it to `jj git push`). Branch was deleted manually. Root cause fixed: both `qc-structural.md` and `qc-behavioral.md` now explicitly say "do NOT push" and instruct agents to write the file in-place for the orchestrator to read directly. See `harness/orchestrator-summary-cleanup-2026-04-17`.

- **§3 (carried-forward `harness/t3g-trend-analysis@origin`, `ops/daily-2026-04-16-run4@origin`)**: both already gone (HTTP 404 on origin) before this run. Resolved by the originating session cleanup.

### 2026-04-18

Retrospective close-out of `dev/daily/2026-04-18.md` run-1 escalations.
Logged here so the next plan-mode run (once Step 1c verification is
operational) has a clean reference instead of inheriting stale text.

- **§1 `[critical]` Main baseline red — function-length linter (2 violations).** Accurately reported at the time (`run` in `fetch_finviz_sectors_lib.ml:167` was 102 lines; `test_keep_if_sector_rescues_reits` was 69 lines). **Resolved by PR #404** (merged 2026-04-17) which refactored both under the 50-line cap. Current main `dune build @runtest` exits 0. The 2026-04-18 run-2 nesting-linter numbers (49 fn + 6 file) are **not** a gate — nesting_linter prints FAIL lines but exits 0 per its `dune` rule (warnings-only). Later summaries that cited "nesting linter gating exit 1" conflated fn_length (real gate, fixed) with nesting (advisory, pre-existing).

- **§2 `[medium]` `linter_magic_numbers.sh` comment-skip heuristic — root cause of #409 P2 NEEDS_REWORK.** The reviewer suggested three options (a) reword comment (b) relocate date (c) fix linter. **Partially resolved** — #409 was reviewed under option (a)/(b) but later commits (through #414) re-introduced date + PR-number tokens in new block comments (`weinstein_strategy.ml:122,126`, `runner.ml:30,214`). The linter still prints `FAIL:` lines for these but its dune rule returns exit 0, so CI stays green — it's advisory noise, not a gate. Stripped the offending tokens from the affected comments in this PR (dates/PR numbers dropped; `git blame` recovers the same info when needed). **The underlying linter weakness remains** (multi-line comment state tracking) — harness follow-up, non-blocking.

- **§3 `[info]` Orchestrator under-utilized (~16% of $50 cap).** Non-actionable by design — queue-depth bound. Label was correct (`[info]`), carried because the pattern persists. Still current; still `[info]`. No action needed.

- **§4 `[info]` #399 merge timing after re-QC.** **Resolved** — PR #399 merged 2026-04-18 on current tip.

- **Retrospective-note addendum.** The 2026-04-17-plan.md run on 2026-04-18 propagated §1 as "nesting linter gating exit 1" — a **paraphrase** that changed the linter and gate semantics. Step 1c (PR #415) was introduced as the durable fix: verify carried-forward `[critical]` items before propagating, and quote the original finding verbatim rather than rewriting. The plan-mode verification gap (Step 1c currently skipped under "plan mode is read-only") is tracked separately.

## References

- Research transcript: research agent run 2026-04-14 (see Escalations in
  today's daily summary if it was logged, otherwise rerun the research prompt)
- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
- [Claude Code GHA docs](https://code.claude.com/docs/en/github-actions)
- [Setup guide](https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Scheduled tasks](https://code.claude.com/docs/en/scheduled-tasks)
