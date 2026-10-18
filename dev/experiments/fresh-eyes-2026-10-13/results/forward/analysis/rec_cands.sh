#!/bin/sh
# rec_cands.sh AUDIT_DIR: the record's weekly decision-list entries for the reader's finished symbols, per salt.
# Reads <AUDIT_DIR>/rb1-26-s{0,1,2}-v12-trade_audit.sexp (not committed; same runs as the committed N-rb1-26
# artifacts) and writes rec_cands-s<k>.csv (date,symbol,outcome) next to this script. Decision-list entries only:
# lines carrying (outcome ...) under a weekly ((date D) (total_stocks ...) record. alternatives_considered blocks of
# entered trades are a different base and are not counted.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
syms=$(awk -F, 'NR > 1 { print $1 }' "$dir/../decisions.csv" | sort -u | paste -sd' ' -)
for k in 0 1 2; do
  awk -v syms="$syms" '
    BEGIN { n = split(syms, a, " "); for (i = 1; i <= n; i++) want[a[i]] = 1; print "date,symbol,outcome" }
    /\(\(date [0-9-]+\) \(total_stocks/ { match($0, /date [0-9-]+/); d = substr($0, RSTART + 5, 10) }
    /\(outcome \(/ { if (match($0, /symbol [^)]+/)) { s = substr($0, RSTART + 7, RLENGTH - 7)
        if (s in want) { match($0, /outcome \([^)]+\)/); print d "," s "," substr($0, RSTART + 9, RLENGTH - 10) } } }
  ' "$1/rb1-26-s$k-v12-trade_audit.sexp" > "$dir/rec_cands-s$k.csv"
done
