#!/bin/sh
# breadth-fix-rb1-2026-10-11 driver (started by launch.sh). One 26y cell at a time:
#   1. lane O s0 (old tree), then the replay check against rebaseline-v12's rb1-26-s0 (trades.csv, actual.sexp,
#      equity_curve.csv). Identical: rebaseline-v12's rb1 s1/s2 stand as the old arm's same-build partners.
#      Not identical: lane O also runs s1 and s2, and only lane O's cells pair with lane N.
#   2. lane N s0, s1, s2 (fixed tree), each V6-diffed against its same-salt old-arm partner.
set -u
H=/Users/difan/Projects/trading-1/.sweep-output   # host side of the container's /tmp/sweeps bind-mount
C="env CELL_TIMEOUT=36000 EXPECT_WH=$EXPECT_WH"
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a /tmp/bp-run/driver.log; }
$C BUILD=1 PREFLIGHT=1 EXPECT_HEAD=$HEAD_O WTREL=.claude/worktrees/sweep-bp-O sh /tmp/bp-run/chain-bp.sh O rb1-26:0
same=1
for f in trades.csv actual.sexp equity_curve.csv; do
  cmp -s "$H/breadth-pair-O/rb1-26-s0-v12-$f" "$H/rebaseline-v12/rb1-26-s0-v12-$f" || same=0
done
if [ $same = 1 ]; then
  log "REPLAY rb1-26-s0-v12 identical to rebaseline-v12: its s1/s2 stand as old-arm partners"
  pair=/tmp/sweeps/rebaseline-v12
else
  log "REPLAY rb1-26-s0-v12 differs from rebaseline-v12: running old-arm s1 and s2 in lane O"
  $C EXPECT_HEAD=$HEAD_O WTREL=.claude/worktrees/sweep-bp-O sh /tmp/bp-run/chain-bp.sh O rb1-26:1 rb1-26:2
  pair=/tmp/sweeps/breadth-pair-O
fi
$C BUILD=1 PREFLIGHT=1 PAIR_ART=$pair EXPECT_HEAD=$HEAD_N WTREL=.claude/worktrees/sweep-bp-N \
  sh /tmp/bp-run/chain-bp.sh N rb1-26:0:rb1-26 rb1-26:1:rb1-26 rb1-26:2:rb1-26
log "DRIVER DONE"
