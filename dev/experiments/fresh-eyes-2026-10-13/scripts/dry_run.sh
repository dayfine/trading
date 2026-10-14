#!/bin/sh
# dry_run.sh <SYM> [<run root>]: the whole forward loop for one symbol with dummy_agent.awk in place of the reader,
# to show it end to end and time it. Prints checkpoints, trades and wall time. Run from the repo root (DATA as in
# step.sh). The dummy is not a strategy; its trades mean nothing.
set -e
s=$1; ROOT=${2:-.sweep-output/fresh-eyes/dry}; R=$ROOT/$s
S=dev/experiments/fresh-eyes-2026-10-13/scripts; WEEKLY=${WEEKLY:-.sweep-output/fresh-eyes/weekly}; export WEEKLY
rm -rf "$R"; t0=$(date +%s)
sh $S/step.sh "$s" "$R" init auto
n=1; rc=0
while :; do
  awk -F, -f $S/dummy_agent.awk "$R/state" "$WEEKLY/$s.csv" > "$R/next.txt"
  rc=0; sh $S/step.sh "$s" "$R" apply "$R/next.txt" || rc=$?
  [ $rc = 4 ] && break
  if [ $rc = 3 ]; then echo "rejected at $(sed -n 's/^cut=//p' "$R/state"): $(grep REJECTED "$R/pending.txt")"; printf 'action=none\n' > "$R/next.txt"; sh $S/step.sh "$s" "$R" apply "$R/next.txt" || rc=$?; [ $rc = 4 ] && break; fi
  [ $rc = 0 ] || [ $rc = 3 ] || { echo "dry_run: step.sh exit $rc" >&2; exit $rc; }
  n=$((n + 1))
done
t1=$(date +%s)
echo "$s: $n checkpoints, $(($(wc -l < "$R/trades.csv") - 1)) trades, $((t1 - t0)) s wall ($(( (t1 - t0) * 1000 / n )) ms per checkpoint)"
