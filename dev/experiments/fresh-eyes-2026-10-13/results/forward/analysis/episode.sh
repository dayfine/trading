#!/bin/sh
W=/private/tmp/claude-501/-Users-difan-Projects-trading-1/0bdb1704-90a7-4760-bb6e-40335d5259c0/scratchpad/fe-analysis
WK=/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes/forward/weekly
ST=/Users/difan/Projects/trading-1/.sweep-output/short-setup-map/stages
F=/Users/difan/Projects/trading-1/.claude/worktrees/fe-forward/dev/experiments/fresh-eyes-2026-10-13/results/forward
S=/Users/difan/Projects/trading-1/.claude/worktrees/fe-forward/dev/experiments/fresh-eyes-2026-10-13/scripts
s=$1; a=$2; b=$3
echo "--- weekly"
awk -F, -v a=$a -v b=$b -v s=$s -f $S/days.awk -f $W/episode.awk $ST/$s.csv $F/decisions.csv $WK/$s.csv
if [ -z "$4" ]; then
echo "--- reader decisions"
awk -F, -v s=$s -v a=$a -v b=$b '$1==s && $2>=a && $2<=b' $F/decisions.csv | cut -c1-600
fi
echo "--- trades"
awk -F, -v s=$s -v a=$a -v b=$b '$1==s && $3>=a && $3<=b' $F/trades.csv
