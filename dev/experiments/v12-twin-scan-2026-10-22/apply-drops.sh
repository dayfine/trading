#!/bin/sh
# Remove the per-list twin losers from the composition lists (#3266). POSIX sh + awk.
#
# Usage: sh apply-drops.sh <drops.txt> <composition-dir>
#   drops.txt: "LIST DROPPED SURVIVOR" per line (window-drops.sh output); LIST is the file name without .sexp.
#
# Each named entry `((symbol DROPPED) ...)` is cut out of that one list by paren depth (strings skipped), so an entry
# that wraps over several lines, or opens / closes the entries list, is removed without touching its neighbours.
# Nothing else in the file changes: weights are not renormalised (the same as alias-lists.pl's per-list dedupe; the
# schedule reads membership only). Fails when a named entry is absent, when the survivor is absent from that list, or
# when the entry count does not drop by exactly the number of removals.
set -eu

DROPS=${1:?usage: apply-drops.sh <drops.txt> <composition-dir>}
DIR=${2:?usage: apply-drops.sh <drops.txt> <composition-dir>}

for L in $(awk '{ print $1 }' "$DROPS" | LC_ALL=C sort -u); do
  f=$DIR/$L.sexp
  [ -f "$f" ] || { echo "apply-drops: no list $f" >&2; exit 1; }
  syms=$(awk -v l="$L" '$1 == l { print $2 }' "$DROPS" | LC_ALL=C sort -u | tr '\n' ' ')
  for x in $syms; do grep -q -F "(symbol $x)" "$f" || { echo "apply-drops: $L has no $x" >&2; exit 1; }; done
  for s in $(awk -v l="$L" '$1 == l { print $3 }' "$DROPS" | LC_ALL=C sort -u); do
    grep -q -F "(symbol $s)" "$f" || { echo "apply-drops: $L lacks survivor $s" >&2; exit 1; }
  done
  before=$(grep -c '(symbol ' "$f")
  awk -v syms="$syms" '
    BEGIN { n = split(syms, a, " "); for (i = 1; i <= n; i++) drop["((symbol " a[i] ")"] = 1 }
    # walk s from position p with depth d; returns the index just past the entry end, or 0 if it does not close here
    function walk(s, p,   c) {
      for (; p <= length(s); p++) {
        c = substr(s, p, 1)
        if (instr) { if (c == "\"") instr = 0; continue }
        if (c == "\"") instr = 1
        else if (c == "(") depth++
        else if (c == ")") { depth--; if (depth == 0) return p + 1 }
      }
      return 0
    }
    function emit(s) { if (s !~ /^[ \t]*$/) print s }
    {
      line = $0
      if (cutting) {
        e = walk(line, 1)
        if (e) { cutting = 0; emit(substr(line, e)) }
        next
      }
      if (match(line, /\(\(symbol [^)]*\)/) && (substr(line, RSTART, RLENGTH) in drop)) {
        pre = substr(line, 1, RSTART - 1); depth = 0; instr = 0
        e = walk(line, RSTART)
        if (e) emit(pre substr(line, e))
        else { emit(pre); cutting = 1 }
        next
      }
      print line
    }' "$f" > "$f.tmp"
  after=$(grep -c '(symbol ' "$f.tmp")
  n=$(echo "$syms" | wc -w | tr -d ' ')
  [ "$((before - after))" = "$n" ] || { echo "apply-drops: $L entries $before -> $after, expected -$n" >&2; rm -f "$f.tmp"; exit 1; }
  bal=$(tr -cd '()' < "$f.tmp" | awk '{ o = gsub(/\(/, ""); c = gsub(/\)/, ""); print o - c }')
  [ "$bal" = 0 ] || { echo "apply-drops: $L parens unbalanced ($bal)" >&2; rm -f "$f.tmp"; exit 1; }
  mv "$f.tmp" "$f"
  echo "$L: removed $n ($syms) entries $before -> $after"
done
