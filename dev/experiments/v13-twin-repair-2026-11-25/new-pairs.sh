#!/bin/sh
# One line per twin pair this repair drops that pit-v12/twin-drops.txt does not name (the pairs only the v13 scan
# found), with its evidence. A row re-pointed by a survivor chain counts
# under its scan pair (DROPPED, via= leg). POSIX sh + awk, host-only.
#
# Usage: sh new-pairs.sh <scan-out-dir> > results/new-pairs.txt
#   env DATA (bar store, default /Users/difan/Projects/trading-1/data; its delisted_symbols.sexp is EODHD's
#   /api/exchange-symbol-list/US?delisted=1), V12 (pit-v12 dir).
# Columns: DROPPED SURVIVOR lists=<n lists the leg leaves> new_to_lists=<legs absent from every pit-v12 list, or ->
#   dropped_delisted=<yes|no: DROPPED is in EODHD's delisted list> then twins.txt's whole-history evidence (overlap,
#   return pairs, match fraction, longest matching run and its span, identical raw closes, each leg's bar span, rule).
set -eu

SCANOUT=${1:?usage: new-pairs.sh <scan-out-dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
DATA=${DATA:-/Users/difan/Projects/trading-1/data}
V12=${V12:-$REPO/trading/test_data/backtest_scenarios/pit-v12}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat "$V12"/composition/*.sexp | grep -o '(symbol [^)]*)' | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$TMP/v12.txt"
grep -o '(code [^)]*)' "$DATA/delisted_symbols.sexp" | sed 's/(code //; s/)$//' | LC_ALL=C sort -u > "$TMP/delisted.txt"

awk -v v12f="$TMP/v12.txt" -v delf="$TMP/delisted.txt" -v twf="$SCANOUT/twins.txt" -v v12d="$V12/twin-drops.txt" '
  BEGIN {
    while ((getline l < v12f) > 0) in12[l] = 1
    while ((getline l < delf) > 0) del[l] = 1
    while ((getline l < twf) > 0) { split(l, f, " "); ev[f[1] " " f[2]] = substr(l, length(f[1] f[2]) + 3) }
    while ((getline l < v12d) > 0) if (l !~ /^#/) { split(l, f, " "); v12p[f[2] " " f[3]] = 1; if (f[4] ~ /^via=/) v12p[f[2] " " substr(f[4], 5)] = 1 }
  }
  $NF == "src=scan" { s = ($4 ~ /^via=/) ? substr($4, 5) : $3; if (($2 " " s) in v12p || (s " " $2) in v12p) next; k = $2 " " s; n[k]++; if (!(k in seen)) { seen[k] = 1; order[++m] = k } }
  END {
    for (i = 1; i <= m; i++) {
      k = order[i]; split(k, p, " "); nl = ""
      if (!(p[1] in in12)) nl = nl (nl ? "," : "") p[1]
      if (!(p[2] in in12)) nl = nl (nl ? "," : "") p[2]
      e = (k in ev) ? ev[k] : "evidence=not-in-twins.txt"
      printf "%s lists=%d new_to_lists=%s dropped_delisted=%s %s\n", k, n[k], (nl ? nl : "-"), ((p[1] in del) ? "yes" : "no"), e
    }
  }' "$HERE/results/new-rows.txt"
