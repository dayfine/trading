#!/bin/sh
# where_is_work.sh [--quota]
#
# One screen of "what is running where": every delegation lane in one place (dev/plans/delegation-lanes-2026-10-18.md).
#   1. open PRs by lane (label author/<agent>, else branch prefix, else local) with their gate next-action
#   2. issues handed to a lane (env/cloud, agent/codex, agent/cursor, agent/copilot) and whether a PR exists
#   3. long local jobs on this machine and in the container (chains, readers, backtests)
#   4. Codex cloud tasks, when the codex CLI supports `codex cloud list`
#   5. the last GHA orchestrator / perf runs
#   --quota: also print dev/scripts/quota_status.sh (one ~$0.02 probe call)
# Read-only. Run at session start and after each agent wave.
set -eu
REPO=${REPO:-dayfine/trading}
here=$(cd "$(dirname "$0")" && pwd)

echo "== open PRs by lane"
gh pr list --repo "$REPO" --state open --limit 100 --json number,title,headRefName,labels,isDraft,updatedAt \
  --jq '.[] | (.labels | map(.name)) as $l
        | ([$l[] | select(startswith("author/"))][0] // ( .headRefName | split("/")[0] )) as $lane
        | "\($lane)\t#\(.number)\t\(.updatedAt[0:10])\t\(if .isDraft then "draft " else "" end)\(.title[0:70])"' \
  | sort | awk -F'\t' 'BEGIN { OFS = "  " } { print $1, $2, $3, $4 }'
if [ -x "$here/pr_gate_status.sh" ] || [ -f "$here/pr_gate_status.sh" ]; then
  echo; echo "== gate next-actions"; sh "$here/pr_gate_status.sh" 2>/dev/null | tail -n +1 || true
fi

echo; echo "== issues handed to a lane"
for lane in env/cloud agent/codex agent/cursor agent/copilot; do
  gh issue list --repo "$REPO" --state open --label "$lane" --limit 50 --json number,title,updatedAt \
    --jq '.[] | "#\(.number)  \(.updatedAt[0:10])  \(.title[0:70])"' 2>/dev/null | sed "s|^|$lane  |" || true
done

echo; echo "== long local jobs"
host_jobs=$(ps -axo pid=,etime=,command= | grep -E 'forward\.sh|reader\.sh|staged\.sh|chain[^ ]*\.sh|codex exec|claude -p' \
  | grep -v grep | cut -c1-150 || true)
echo "${host_jobs:-(none on the host)}"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^trading-1-dev$'; then
  docker exec trading-1-dev ps -axo pid=,etime=,args= 2>/dev/null \
    | grep -E 'scenario_runner|panel_runner|bayesian_runner|dune (build|runtest)' | grep -v grep | cut -c1-150 \
    || echo "(container idle)"
fi

echo; echo "== Codex cloud tasks"
if command -v codex >/dev/null 2>&1 && codex cloud list --help >/dev/null 2>&1; then
  codex cloud list 2>/dev/null | head -20 || echo "(codex cloud list failed)"
else
  echo "(codex cloud not available in this CLI)"
fi

echo; echo "== recent GHA runs (orchestrator, perf)"
for wf in orchestrator.yml perf-nightly.yml perf-weekly.yml; do
  gh run list --repo "$REPO" --workflow "$wf" --limit 1 --json conclusion,status,createdAt \
    --jq '.[] | "\(.createdAt[0:16])  \(.status) \(.conclusion // "")"' 2>/dev/null | sed "s|^|$wf  |" || true
done

if [ "${1:-}" = --quota ]; then echo; echo "== quota"; sh "$here/quota_status.sh" || true; fi
