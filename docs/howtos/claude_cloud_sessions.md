# Claude Code cloud sessions

How the cloud environment is set up, how to rebuild it from nothing, and how a
local session launches work in it. Cloud sessions are a second worker beside the
local `trading-1-dev` container, which fits one backtest at a time and nothing
beside it (`.claude/rules/container-capacity-scheduling.md`).

**Backtests run here by default** (since 2026-11-09, when the 26y record cell `rk-k0` reproduced
byte-identically from the R2 warehouse, #3535): chains, seeds and grids launch as cloud sessions with
the warehouse and corporate actions pulled from R2 as below. The local container is for QC builds,
interactive debugging and the Weinstein book, and is the fallback when a run needs data not yet in R2.

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

## Pulling the snapshot warehouse (#3535)

Building the v12 PIT warehouse inside a session takes about 5.5 h and yields a
different construction (9,181 symbols) from the local 9,236-symbol one (`v12wk`). Pull the
local warehouse instead. It lives in the private R2 bucket under
`warehouse/<name>/` (not `bars/`), one object per file (`.snap`, `.weekly`, `manifest.sexp`) plus a
`SHA256SUMS` manifest. The credentials are the same as for the bars
(`dev/scripts/r2_bars.sh` header).

Put it **inside the bind-mounted checkout**, not `/tmp`: a session-worker restart
wipes `/tmp` (about 53 min were lost to this on the 26y kill + resume run), while
the checkout survives. Use `.sweep-output/` (gitignored); check with
`git status` that the pulled files do not show up, and never commit them.

```sh
# local, once: uploads ~3.6 GB; never in a cloud session
sh dev/scripts/r2_bars.sh push-dir --dir /tmp/snap_top3000_pit_v12wk --name v12wk-9236
# cloud session: downloads, verifies every file, then moves into place
sh dev/scripts/r2_bars.sh pull-dir --dest "$PWD/.sweep-output/warehouse/snap_top3000_pit_v12wk" --name v12wk-9236
# after a restart, re-check without downloading again
sh dev/scripts/r2_bars.sh verify-dir --dir "$PWD/.sweep-output/warehouse/snap_top3000_pit_v12wk" --name v12wk-9236
```

Both transfer 16 files at a time (`--jobs N` to change) and print a line every 1,000 files. A killed `push-dir` is rerun with `--resume`, which skips objects already uploaded at the same size. `--resume` compares sizes only, so a rebuilt source needs `--force`; `pull-dir` and `verify-dir` check every object against `SHA256SUMS` and catch any stale one.

`pull-dir` exits 1 and names each file that is corrupted, missing or extra, and
leaves the destination absent; a warehouse that did not verify must not be run.
The destination must be empty or absent.

Point runs at it by passing that directory wherever a local run uses
`/tmp/snap_top3000_pit_v12wk` (the snapshot directory argument of the spec or
chain script). The container needs the path under the mount: run docker with
`-v $PWD:/w` as below and give the in-container path `/w/.sweep-output/warehouse/...`.
No symlink to the build path is needed: `manifest.sexp` still records the paths the
warehouse was built at (`/tmp/snap_top3000_pit_v12wk/A.snap`), but every reader resolves
each file by name inside the directory it was given (`Snapshot_manifest.resolve_path`,
#3535). A build older than #3547 (such as the record's `fc78391dd`) still opens the recorded paths
and reads no bars (`n_symbols_touched=0`, then `Window_filter: no trading day`); for those, add
`-v $PWD/.sweep-output/warehouse/snap_top3000_pit_v12wk:/tmp/snap_top3000_pit_v12wk:ro`.

Locally, run `r2_bars.sh` on the host: from inside `trading-1-dev` R2 answers 403 even with the
same credentials (seen 2026-11-08, cause not traced); copy the warehouse out with `docker cp`
first.

### Dividends and splits come separately

The warehouse holds bars only. The simulator credits dividends and reads splits from
`$TRADING_DATA_DIR/<A>/<B>/<SYM>/dividends.csv` and `splits.csv`, which local chain scripts copy
from the gitignored `data/` into the run tree's `trading/test_data/` (for example
`record-kseed-2026-10-27/chain.sh`, the `rsync … dividends.csv … splits.csv` line). A cloud run
without them credits no dividends and silently diverges: the first rk-k0 cloud run lost FR's
$1,767.00 dividend on 2000-06-28 and ended at 1251.35 % against the record's 1312.79 % (#3535).

They are in R2 as one tarball, `warehouse/corpact-2026-10-27/corpact.tar.gz` (23,760 files,
2 MB; `files.txt` lists them):

```sh
# local, once per refresh of data/: pack and upload (bump the name's date)
D=.sweep-output/warehouse/corpact; mkdir -p $D
(cd data && find . \( -name dividends.csv -o -name splits.csv \) | LC_ALL=C sort > ../$D/files.txt \
  && tar -czf ../$D/corpact.tar.gz -T ../$D/files.txt)
sh dev/scripts/r2_bars.sh push-dir --dir "$PWD/$D" --name corpact-2026-10-27
# cloud session: pull, then unpack into the run tree's test_data before the run
sh dev/scripts/r2_bars.sh pull-dir --dest "$PWD/.sweep-output/warehouse/corpact" --name corpact-2026-10-27
tar -xzf .sweep-output/warehouse/corpact/corpact.tar.gz -C <run-tree>/trading/test_data
```

Check `find <run-tree>/trading/test_data -name dividends.csv | wc -l` against the local chain's
`staged N dividends.csv` line (11,880 for corpact-2026-10-27).

**A build from before #3510 (2026-11-02) needs one more step.** Shard folders use the symbol's first
and last character, upper-cased since #3510 (`LZ_old` in `L/D/LZ_old`, as packed). Older builds, such
as the record SHA `fc78391dd`, use the raw last character and look in `L/d/LZ_old`; on Linux they find
none of the 235 `*_old` symbols' files and credit no dividend for them, with no error
(`dividendmissingfilecount` 8 and a 1311.40 % vs 1312.79 % rk-k0 run, #3535). For such a build, after
unpacking:

```sh
(cd <run-tree>/trading/test_data && for p in */D/*_old; do
  mkdir -p "${p%%/*}/d" && mv "$p" "${p%%/*}/d/"; done)
```

With that step the rk-k0 cloud run matched the record byte-identically (2026-11-09).

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
