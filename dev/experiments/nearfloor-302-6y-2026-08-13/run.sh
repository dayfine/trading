#!/bin/sh
# Nearfloor at 302 symbols / 6y (2018-2023), 3 path-seed salts per arm.
#
# WHY: dev/notes/ladder-v4-read-2026-08-12.md and
# project_nearfloor_is_risk_not_return cite a "302/6y, 3 salts, decisive at this
# scale" context with NO committed artifact (qc-behavioral finding on PR #2288).
# This run either produces that artifact or falsifies the claim.
#
# Arms differ in exactly one knob: stops_config.support_floor_anchor_scope
#   00-core       = Window_extreme (baseline)
#   09-nearfloor  = Nearest
set -e
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/v4-fixed
SPECS=/private/tmp/claude-501/-Users-difan-Projects-trading-1/fb5eee5b-32ea-4e7b-9429-8f3f1f94d659/scratchpad/nfsmall
LOG=/tmp/nfsmall.log
log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }

: > "$LOG"
log "start — 302sym/6y nearfloor verification, 2 arms x 3 salts"

for cell in 00-core 09-nearfloor; do
  for salt in 0 1 2; do
    # Capacity guard (.claude/rules/container-capacity-scheduling.md): a run
    # needs headroom; refuse rather than get OOM-killed silently.
    # docker stats reports MiB or GiB depending on magnitude -- normalise to MiB
    # before comparing, or "327.4MiB" reads as 327 GiB and aborts every time.
    used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
      | sed 's|/.*||' \
      | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
             /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
             {print 0}')
    if [ "${used_mib:-0}" -ge 5120 ]; then
      log "ABORT: container already at ${used_mib}MiB — refusing to launch (would risk an OOM kill)"
      exit 1
    fi
    d=/tmp/nfsmall-${cell}-s${salt}
    docker exec $C sh -c "mkdir -p $d && rm -rf $d/* "
    docker cp "$SPECS/nf-small-${cell}.sexp" $C:$d/
    log "running ${cell} salt ${salt} (container at ${used_mib}MiB)"
    docker exec $C bash -c "cd $WT/trading && eval \$(opam env) && \
      TRADING_DATA_DIR=$WT/trading/test_data TRADING_PATH_SEED_SALT=${salt} \
      ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
        --dir $d --fixtures-root $WT/trading/test_data/backtest_scenarios \
        --no-emit-all-eligible --parallel 1 --progress-every 26 \
        > /tmp/nfsmall-${cell}-s${salt}.log 2>&1; echo \"exit=\$?\" >> /tmp/nfsmall-${cell}-s${salt}.log"
    r=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+' \$(grep 'Output root' /tmp/nfsmall-${cell}-s${salt}.log | sed 's/.*: //')/*/actual.sexp 2>/dev/null | head -1")
    dd=$(docker exec $C sh -c "grep -hoE 'max_drawdown_pct [0-9.-]+' \$(grep 'Output root' /tmp/nfsmall-${cell}-s${salt}.log | sed 's/.*: //')/*/actual.sexp 2>/dev/null | head -1")
    tr=$(docker exec $C sh -c "grep -hoE 'total_trades [0-9]+' \$(grep 'Output root' /tmp/nfsmall-${cell}-s${salt}.log | sed 's/.*: //')/*/actual.sexp 2>/dev/null | head -1")
    log "RESULT ${cell} s${salt} => ${r:-<no result>} | ${dd:-?} | ${tr:-?}"
  done
done
log "ALL DONE"
