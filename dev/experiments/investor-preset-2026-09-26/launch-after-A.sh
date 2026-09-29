#!/bin/sh
# Waits for obvious-fixes chain A to finish, then launches the investor chain (lane I) with BUILD=1.
A=/tmp/fixes-run/chain-A.log; n=0
until grep -q 'LANE A DONE' $A; do n=$((n+1)); [ $n -gt 2160 ] && { echo "gave up waiting (18h)"; exit 1; }; sleep 30; done
docker exec trading-1-dev sh -c 'pgrep -f scenario_runner.exe' && { echo "a scenario_runner is still live; not launching"; exit 1; }
cd /Users/difan/Projects/trading-1
BUILD=1 PREFLIGHT=1 EXPECT_HEAD=1c2647743 sh /tmp/investor-run/chain-investor.sh I \
  inv5-hybrid:0 inv5-investor:0:inv5-hybrid inv5-hybrid:1 inv5-investor:1:inv5-hybrid inv5-hybrid:2 inv5-investor:2:inv5-hybrid
