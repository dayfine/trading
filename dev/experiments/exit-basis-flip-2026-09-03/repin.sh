#!/bin/sh
# repin.sh — rewrite a golden spec's (expected ...) metric bands to the
# ±15%-around-actuals convention from a new-arm actual.sexp.
#
#   sh repin.sh <golden.sexp> <actual.sexp> "<comment line>"
#
# Only metric keys present in BOTH the spec's expected block and the actual
# are rewritten; wall_seconds (and any key absent from actual) is left as is.
# For integer-valued keys (total_trades, force_liquidations) the band is still
# ±15% of the value — the runner compares floats. A value of 0 gets the
# [0, 0.5] pin idiom the BAH goldens use. Negative values swap min/max so the
# band still contains the value. Edits in place; prints old→new per key.
set -eu
spec=$1; actual=$2; comment=${3:-}
[ -f "$spec" ] && [ -f "$actual" ] || { echo "usage: repin.sh spec actual [comment]" >&2; exit 2; }

# key value pairs from actual.sexp: "(total_return_pct 38.8)" -> "total_return_pct 38.8"
vals=$(tr '\n' ' ' <"$actual" | grep -oE '\([a-z_]+ -?[0-9][0-9.eE+-]*\)' | tr -d '()' | tr '\n' ' ')

tmp=$(mktemp)
awk -v vals="$vals" -v comment="$comment" '
BEGIN {
  n = split(vals, arr, " ")
  for (i = 1; i + 1 <= n; i += 2) have[arr[i]] = arr[i+1]
  inexp = 0; commented = 0
}
function band(v, key,   hw, lo, hi) {
  if (v == 0) return "0 0.5"
  hw = (v < 0 ? -v : v) * 0.15
  # total_return_pct: absolute floor of 5pp so a near-zero return does not
  # get a sub-1pp band (still deterministic, but tighter than the convention)
  if (key == "total_return_pct" && hw < 5.0) hw = 5.0
  lo = v - hw; hi = v + hw
  return sprintf("%.4f %.4f", lo, hi)
}
{
  line = $0
  if (line ~ /^ *\(expected/) inexp = 1
  if (inexp && comment != "" && !commented && line ~ /^ *\(\(/) {
    print "  ;; " comment
    commented = 1
  }
  if (inexp && match(line, /\([a-z_]+ +\(\(min [^)]*\) +\(max [^)]*\)\)\)/)) {
    key = substr(line, RSTART + 1); sub(/ .*/, "", key)
    if (key in have && key != "wall_seconds") {
      split(band(have[key] + 0, key), bb, " ")
      pre = substr(line, 1, RSTART - 1)
      post = substr(line, RSTART + RLENGTH)
      newl = pre "(" key " ((min " bb[1] ") (max " bb[2] ")))" post
      printf("%-22s %s  ->  [%s, %s]\n", key, have[key], bb[1], bb[2]) > "/dev/stderr"
      line = newl
    }
  }
  print line
}' "$spec" >"$tmp"
mv "$tmp" "$spec"
