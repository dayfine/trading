#!/bin/sh
# Instrumented record-convention paired run — arms: instr-null, instr-unfreeze.
# Serves issues #2486 (ratchet-freeze real-data split), #2489 (representative
# trades), #2490 (monster capture funnel). One run, three analyses.
#
# scenario_runner CLI (verified on main 2026-08-23): takes --dir <scenario-dir>
# (runs every .sexp in it), no --spec/--out-dir; output root is
# <repo_root>/dev/backtest/scenarios-<timestamp>/<scenario-name>/ — inside the
# PINNED worktree here, so parent jj ops cannot touch it. universe_path in a
# spec resolves against $TRADING_DATA_DIR/backtest_scenarios.
#
# Per .claude/rules/sweep-hygiene.md: pinned worktree build; flock; disk
# guard; run-tree HEAD logged; dirty-abort; per-arm metric reads scoped to the
# arm's own actual.sexp (never the chain log); --parallel 1 = sequential arms.
#
# Usage: sh run_chain.sh <pinned-main-sha>
set -eu

SHA="${1:?usage: run_chain.sh <pinned-main-sha>}"
REPO=/Users/difan/Projects/trading-1
WT_REL=.claude/worktrees/sweep-instr-0823
WT="$REPO/$WT_REL"
C=trading-1-dev
LOCK=/tmp/instr-record-0823.lockdir

if ! mkdir "$LOCK" 2>/dev/null; then echo "another chain instance is live ($LOCK exists); abort" >&2; exit 1; fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

avail_gb=$(df -g / | awk 'NR==2{print $4}')
[ "$avail_gb" -ge 15 ] || { echo "host disk ${avail_gb}G < 15G; abort" >&2; exit 1; }

if [ ! -d "$WT" ]; then
  git -C "$REPO" worktree add --detach "$WT_REL" "$SHA"
fi
echo "RUN TREE HEAD=$(git -C "$WT" rev-parse --short HEAD)"

STAGE_REL="$WT_REL/trading/test_data/backtest_scenarios/instr-staging"
mkdir -p "$REPO/$STAGE_REL"
cp "$REPO/dev/experiments/instrumented-record-2026-08-23/specs/instr-null.sexp" "$REPO/$STAGE_REL/"
cp "$REPO/dev/experiments/instrumented-record-2026-08-23/specs/instr-unfreeze.sexp" "$REPO/$STAGE_REL/"
# staged specs are untracked inside the pinned worktree; assert tracked files clean
[ -z "$(git -C "$WT" status --porcelain | grep -v '^??')" ] || { echo "run tree dirty (tracked files); abort" >&2; exit 1; }

docker exec "$C" bash -c "cd /workspaces/trading-1/$WT_REL/trading && eval \$(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe" \
  || { echo "build failed; abort" >&2; exit 1; }

echo "[$(date '+%F %T')] launching paired run detached (sequential, --parallel 1)"
docker exec -d "$C" bash -c "
  mkdir -p /tmp/sweeps &&
  cd /workspaces/trading-1/$WT_REL/trading && eval \$(opam env) &&
  SNAPSHOT_CACHE_MB=1024 TRADING_DATA_DIR=/workspaces/trading-1/$WT_REL/trading/test_data \
  nohup dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /workspaces/trading-1/$STAGE_REL \
    --snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj \
    --parallel 1 \
    --no-emit-all-eligible \
    --emit-candidates \
    > /tmp/sweeps/instr-record-0823.log 2>&1"
echo "[$(date '+%F %T')] launched. Log: container:/tmp/sweeps/instr-record-0823.log"
echo "Output root will appear under: $WT/dev/backtest/scenarios-<timestamp>/"
