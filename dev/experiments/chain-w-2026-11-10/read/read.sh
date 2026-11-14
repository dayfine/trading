#!/bin/sh
# read.sh -- regenerates every read/*.txt quoted in README §Results from the committed artifacts (run from the repo
# root). The #3136 reads need a bar store for the divisor (data.csv + splits.csv per symbol); the chain's td-full is
# not kept, so DATA_DIR stands in for bars/data-20261102 and SPLITS_ROOT for corpact-2026-10-27 (the reading used the
# gitignored data/ and the local copy of corpact.tar.gz unpacked; every differing symbol's splits.csv matched).
#   levels.txt        P0, T1, T2, T4                       (read/levels.sh)
#   t3.txt            T3 table, F, hold-exit check, decision-level list   (read/t3.sh, read/divisor.awk)
#   impact.txt        the level gap by class and year      (read/impact.sh, from t3.txt)
#   tdfull_check.txt  what td-full's committed short data.csv files did to the divisor   (read/tdfull_check.sh)
#   m3183.txt         #3183 M1-M4                          (read/m3183.sh)
# usage: sh dev/experiments/chain-w-2026-11-10/read/read.sh DATA_DIR [SPLITS_ROOT]
set -u
D=${1:?usage: sh read.sh DATA_DIR [SPLITS_ROOT]}; SP=${2:-$1}
E=dev/experiments/chain-w-2026-11-10; O=$E/read; RES=$E/results; REC=dev/experiments/record-kseed-2026-10-27/results
TD=trading/test_data
sh "$O/levels.sh" "$RES" "$REC" > "$O/levels.txt"
sh "$O/t3.sh" "$RES" "$D" "$TD" "$SP" > "$O/t3.txt"
sh "$O/impact.sh" "$RES" "$O/t3.txt" > "$O/impact.txt"
sh "$O/tdfull_check.sh" "$RES" "$D" "$TD" "$SP" > "$O/tdfull_check.txt"
sh "$O/m3183.sh" "$RES/3183" "$TD/backtest_scenarios/pit-v12/composition" "$REC/rk-k0-s0-trades.csv" "$RES/cw-W0-s0-entries.tsv" > "$O/m3183.txt"
echo "wrote $O/levels.txt t3.txt impact.txt tdfull_check.txt m3183.txt"
