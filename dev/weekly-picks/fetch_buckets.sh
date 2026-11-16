#!/bin/sh
# fetch_buckets.sh -- the parallel fetch of weekly.sh's `fetch` step. Runs INSIDE the dev
# container (weekly.sh calls it through dev/lib/run-in-env.sh).
#
# usage: fetch_buckets.sh <fetch_symbols.exe> <data-dir> <bucket-dir> <log-dir>
#
# One fetch_symbols.exe per <bucket-dir>/batch_NN.txt (one symbol per line), all in parallel.
# The buckets are shard-disjoint (weekly.sh buckets by first + last letter, Csv_storage's
# shard key): Csv_storage's per-shard manifest read-modify-write is not safe across
# processes (#3645). The API key comes from $EODHD_API_KEY and is never printed.
# Exit 0 only when every process exited 0 and every log ends in a "Done:" line (a process
# that died on the manifest race leaves no such line).
set -u

[ $# -eq 4 ] || { echo "usage: fetch_buckets.sh <exe> <data-dir> <bucket-dir> <log-dir>" >&2; exit 2; }
EXE=$1
DATA=$2
BUCKETS=$3
LOGS=$4
[ -n "${EODHD_API_KEY:-}" ] || { echo "fetch_buckets: EODHD_API_KEY is not set" >&2; exit 1; }

mkdir -p "$LOGS"
rm -f "$LOGS"/batch_??.log
pids=""
n_buckets=0
for b in "$BUCKETS"/batch_??.txt; do
  [ -f "$b" ] || continue
  n=$(basename "$b" .txt)
  "$EXE" -symbols "$(paste -sd, "$b")" -data-dir "$DATA" -api-key "$EODHD_API_KEY" \
    > "$LOGS/$n.log" 2>&1 &
  pids="$pids $!"
  n_buckets=$((n_buckets + 1))
done

rc=0
for p in $pids; do wait "$p" || rc=1; done

unfinished=0
errors=0
for l in "$LOGS"/batch_??.log; do
  [ -f "$l" ] || continue
  e=$(tail -n 3 "$l" | sed -n 's/^Done: [0-9]* fetched, \([0-9]*\) errors\./\1/p')
  if [ -n "$e" ]; then errors=$((errors + e)); else unfinished=$((unfinished + 1)); fi
done
echo "fetch_buckets: $n_buckets buckets, $unfinished without a Done line, $errors per-symbol errors"
[ "$rc" -eq 0 ] && [ "$unfinished" -eq 0 ]
