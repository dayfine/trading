#!/bin/sh
# 26y investor preset salts 1, 2, then s0 again as a same-build reproduction check of #3048 (built 650b18e2a).
cd /Users/difan/Projects/trading-1
WTREL=.claude/worktrees/sweep-investor26 BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=60000 EXPECT_HEAD=6d84ff1c3 sh /tmp/investor-run/chain-investor.sh L3 inv26sc-investor:1 inv26sc-investor:2 inv26sc-investor:0
