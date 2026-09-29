#!/bin/sh
# Post-code-wave launcher (2026-09-27). Usage: sh launch-post2996.sh <short-sha of main after #2996>
# 1. pinned worktree sweep-post2996 at that sha (sweep-hygiene.md)
# 2. lane I (5y, ~1 h/cell): inv5-hybrid s0 -> flag screen 9a-9e paired vs it (QUEUE item 9, 9a = P0 #2982 first)
#    -> investor preset vs hybrid, salts 0/1/2 (QUEUE item 3)
# 3. then f1-stoplimit-fresh s0 26y (QUEUE item 1b) on the SAME build via chain-fixes.sh
set -u
SHA=${1:?short sha of main after #2996}
REPO=/Users/difan/Projects/trading-1; WTREL=.claude/worktrees/sweep-post2996
cd $REPO
docker exec trading-1-dev sh -c 'pgrep -f [s]cenario_runner.exe' && { echo "a scenario_runner is live; not launching"; exit 1; }
[ -d $WTREL ] || git worktree add --detach $WTREL "$SHA" || { echo "worktree add failed"; exit 1; }
WTREL=$WTREL BUILD=1 PREFLIGHT=1 EXPECT_HEAD=$SHA sh /tmp/investor-run/chain-investor.sh I \
  inv5-hybrid:0 \
  f9a-ma-basis:0:inv5-hybrid f9b-corr-peak:0:inv5-hybrid f9c-tight-ratchet:0:inv5-hybrid \
  f9d-suspend:0:inv5-hybrid f9e-stops-all:0:inv5-hybrid \
  inv5-investor:0:inv5-hybrid \
  inv5-hybrid:1 inv5-investor:1:inv5-hybrid inv5-hybrid:2 inv5-investor:2:inv5-hybrid
grep -q 'LANE I DONE' /tmp/investor-run/chain-I.log || { echo "lane I did not finish; not starting f1"; exit 1; }
WTREL=$WTREL EXPECT_HEAD=$SHA sh /tmp/fixes-run/chain-fixes.sh F1 f1-stoplimit-fresh:0   # V6 vs f2-fills-faithful-s0 by hand (no pair support in chain-fixes)
