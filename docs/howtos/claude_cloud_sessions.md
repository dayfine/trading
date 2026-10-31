# Claude Code cloud sessions

How the cloud environment is set up, how to rebuild it from nothing, and how a
local session launches work in it. Cloud sessions are a second worker beside the
local `trading-1-dev` container, which fits one backtest at a time and nothing
beside it (`.claude/rules/container-capacity-scheduling.md`).

## The environment

One environment, **Default** (`env_011CV2KYxeXLs26U85qQo3rV`), configured in the
Claude Code web UI under the environment's settings. Everything below is the whole
configuration; nothing else is set.

| setting | value | why |
|---|---|---|
| Setup script | none | the CI image is already present (see "Building") |
| Environment variable `EODHD_API_KEY` | the owner's EODHD key | data fetches (#3476) |
| Network access | default allowlist **plus `eodhd.com`** | without it the egress proxy refuses EODHD (`connect_rejected`, curl `http=000`) |

What a session gets: a clone of `dayfine/trading`, `gh` authenticated as the
owner, `dockerd`, and the image `ghcr.io/dayfine/trading-ci:latest`.

What it does not get: `data/` (2.1 GB of bars), the snapshot warehouse
(`/tmp/snap_top3000_pit_v*`), `.sweep-output/` artifacts, and the Weinstein book,
which never leaves the local machine (`.claude/rules/book-as-authority.md`).

### Rebuilding it from nothing

1. Create an environment (any name), with no setup script.
2. Add the environment variable `EODHD_API_KEY`.
3. Add `eodhd.com` to the allowed network domains.
4. Put the new environment ID in the RemoteTrigger body below, then in this file
   and in `dev/agent-memory/project_env_cloud_label.md`.
5. Run the probe below. It must print `KEY_SET`, then `http=200` twice.

### Probe (verifies key + network, never prints the key)

Launch a session with this prompt:

```
Probe only. Never print, echo, log or write the value of EODHD_API_KEY.
1. [ -n "$EODHD_API_KEY" ] && echo KEY_SET len=${#EODHD_API_KEY} || echo KEY_MISSING
2. curl -s -o /tmp/spy.csv -w 'http=%{http_code}\n' "https://eodhd.com/api/eod/SPY.US?from=2026-10-20&to=2026-10-30&fmt=csv&api_token=$EODHD_API_KEY"; wc -l < /tmp/spy.csv; head -1 /tmp/spy.csv; rm -f /tmp/spy.csv
3. curl -s -o /dev/null -w 'delisted http=%{http_code}\n' "https://eodhd.com/api/exchange-symbol-list/US?delisted=1&fmt=json&api_token=$EODHD_API_KEY"
Reply with the outputs only. Do not push, comment or open anything.
```

Last passed 2026-10-31: `KEY_SET len=23`, SPY `http=200` (9 rows), delisted `http=200`.

## Launching a session from a local session

Use the `RemoteTrigger` tool (`action: create`), a run time a minute or two ahead
(`date -u -v+2M +%Y-%m-%dT%H:%M:00Z`):

```json
{"name": "<short-name>", "run_once_at": "<UTC time>",
 "job_config": {"ccr": {
   "environment_id": "env_011CV2KYxeXLs26U85qQo3rV",
   "session_context": {
     "allowed_tools": ["preset:default","Task","Bash","Glob","Grep","Read","Edit","Write",
                       "TodoWrite","BashOutput","KillBash","Skill","Monitor"],
     "sources": [{"git_repository": {"url": "https://github.com/dayfine/trading"}}]},
   "events": [{"data": {"isSynthetic": true, "type": "user",
     "message": {"role": "user", "content": "<the brief>"}}}]}}}
```

Follow it with `list_runs` / `get_run_log` on the trigger to read the result.
Sessions take 2-4 minutes to start.

## Building and testing inside a session

```sh
docker run --rm -v $PWD:/w -w /w/trading ghcr.io/dayfine/trading-ci:latest \
  bash -c 'eval $(opam env) && dune build @fmt && dune build && dune runtest <dirs>'
```

Spell this out in every brief. A session told nothing assumes there is no
toolchain and falls back to a read-only review (seen 2026-10-08).

## Briefs that work

- **QC review.** Fetch `pull/<N>/head`, record `SHA`, post nothing unless
  `gh pr checks <N>` is all pass at that SHA, build as above, then post the
  review with
  `jq -n --rawfile body review.md --arg sha "$SHA" '{body:$body,event:"COMMENT",commit_id:$sha}' | gh api repos/dayfine/trading/pulls/<N>/reviews --input -`.
  The review heading and verdict format come from `.claude/agents/qc-*.md`.
- **Feature PR.** Name the issue, the branch, the scope, and "open the PR; do not
  merge". The authoring session also answers review comments posted on its PR.
- Every brief: never merge, label or push to `main`; never write an at-sign before
  a username. Cloud sessions end their turn when idle, so a brief that must wait
  on CI should poll it with a Monitor until-loop.

The local dispatcher merges on green gates (`.claude/rules/pr-merge-gates.md`).

## Data rules

- The EODHD terms allow a Non-Professional user to store and analyse the data
  privately and forbid redistributing it or granting access to others
  (#3476). Bar data therefore never goes into the repo, a PR, an artifact, a
  log or a shared link. Hashes of it may be committed (the manifest in #3476).
- Never print the key. Pass it only through `$EODHD_API_KEY` in a URL whose
  output is not echoed.
- Anyone with sessions in this environment can read the key. If other
  repositories start using cloud sessions, move the key and the `eodhd.com`
  rule to a dedicated environment and update the ID here.

## Related

- #3476: backtests on cloud (data fetch, hash manifest, parity run).
- #3477: pausable / resumable backtests, needed for runs longer than a session.
- `dev/agent-memory/project_env_cloud_label.md`: the `env/cloud` issue label.
