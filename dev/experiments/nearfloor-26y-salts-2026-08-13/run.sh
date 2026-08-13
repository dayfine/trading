#!/bin/sh
# 26y cell-09 (nearfloor) x 3 path-seed salts — the arm the 2026-08-12 chain lost.
#
# Cell 00 already has its three draws on this same build: 281.71 / 397.95 /
# 265.44 (spread 132pp). This run supplies cell 09's three so the two arms can
# be compared as distributions rather than single draws.
#
# WHAT KILLED THE LAST ATTEMPT: cell 09 salt 0 died 1h53m in with no exception,
# no stack, an empty child log and `<no result>` — OOM, from six concurrent
# agents pushing the 7.75GB container to 5.6GB while this held ~3.3GB.
# See .claude/rules/container-capacity-scheduling.md.
#
# Guards added since: a memory pre-check before every run (abort loudly rather
# than get killed silently) and per-run RSS logging.
set -e
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/v4-fixed
LOG=/tmp/chain_26y_cell09.log
MIN_FREE_MIB=4096
TOTAL_MIB=7936             # 7.75GiB container limit
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }

: > "$LOG"
log "start — cell 09-nearfloor x 3 salts at 26y (top-3000 PIT-2000, 2000-2026)"
log "reference arm (already collected): cell 00 = 281.71 / 397.95 / 265.44"

for salt in 0 1 2; do
  # docker stats reports MiB or GiB depending on magnitude. Normalise to MiB
  # before comparing -- stripping only "GiB" leaves "502.6MiB", which `bc` then
  # chokes on, yielding free=0 and a spurious abort. (Fails safe, but wrong.)
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
    | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
           /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
           {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  if [ "$free_mib" -lt "$MIN_FREE_MIB" ]; then
    log "ABORT before salt ${salt}: only ${free_mib}MiB free (need ${MIN_FREE_MIB}) — container is busy; a launch here would be OOM-killed silently"
    exit 1
  fi

  d=/tmp/v4fixed-09-nearfloor-s${salt}
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/* && \
    cp /tmp/sweeps/ladder-v4/top3000-2000-2026-v4-09-nearfloor.sexp $d/"
  log "running cell 09 salt ${salt} (container at ${used_mib}MiB, ${free_mib}MiB free)"

  docker exec $C bash -c "cd $WT/trading && eval \$(opam env) && \
    TRADING_DATA_DIR=$WT/trading/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $WT/trading/test_data/backtest_scenarios \
      --snapshot-dir /tmp/snap_top3000_dedup_v5thin_adj \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > /tmp/v4fixed-09-nearfloor-s${salt}.log 2>&1; echo \"exit=\$?\" >> /tmp/v4fixed-09-nearfloor-s${salt}.log" &
  RUNPID=$!

  # Sample peak RSS while it runs, so a near-miss on memory is visible even when
  # the run survives.
  peak=0
  while kill -0 $RUNPID 2>/dev/null; do
    rss=$(docker exec $C sh -c "ps -eo rss,comm | grep scenario_runner | sort -rn | head -1 | awk '{print \$1}'" 2>/dev/null || echo 0)
    [ "${rss:-0}" -gt "$peak" ] && peak=$rss
    sleep 60
  done
  wait $RUNPID || true

  out=$(docker exec $C sh -c "grep 'Output root' /tmp/v4fixed-09-nearfloor-s${salt}.log | sed 's/.*: //'")
  r=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  log "RESULT cell 09 salt ${salt} => ${r:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} (peak RSS $((peak / 1024))MB)"
done
log "ALL DONE — cell 09 x 3 salts complete; compare against cell 00's 281.71 / 397.95 / 265.44"
