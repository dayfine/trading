#!/bin/sh
# make_superset.sh <vintage-year> <out.sexp>
# Emits the plain (Pinned (...)) universe the warehouse builder expects, from the
# top-3000-<vintage> composition file (which carries per-symbol metadata and an
# aggregate tail the builder cannot parse), plus GSPC.INDX as the benchmark.
# Never top up a warehouse with -incremental over a partial universe (#2669).
set -eu
V=$1; OUT=$2
COMP=trading/test_data/goldens-custom-universe/composition/top-3000-$V.sexp
[ -f "$COMP" ] || { echo "missing $COMP" >&2; exit 1; }
{
  printf '(Pinned (\n'
  grep -oE '\(symbol [A-Za-z0-9._-]+\)' "$COMP" | sed -E 's/\(symbol ([^)]+)\)/\1/' | sort -u \
    | awk '{ printf "  ((symbol %s) (sector \"Unknown\"))\n", $1 }'
  printf '  ((symbol GSPC.INDX) (sector "Index"))\n))\n'
} > "$OUT"
echo "$OUT: $(grep -c '(symbol ' "$OUT") symbols"
