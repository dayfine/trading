#!/bin/sh
# Symbols each scheduled top-3000 list loses to the dedupe: "<list year> <symbol>" for 1999..2025, cur vs dd composition.
# Usage: sh removed-by-list.sh <cur composition dir> <dd composition dir> > removed.txt
set -eu
CUR=$1; DD=$2; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
y=1999
while [ "$y" -le 2025 ]; do
  grep -o '(symbol [^)]*)' "$CUR/top-3000-$y.sexp" | sed 's/(symbol //;s/)//' | LC_ALL=C sort -u > "$T/c"
  grep -o '(symbol [^)]*)' "$DD/top-3000-$y.sexp" | sed 's/(symbol //;s/)//' | LC_ALL=C sort -u > "$T/d"
  LC_ALL=C comm -23 "$T/c" "$T/d" | sed "s/^/$y /"
  y=$((y + 1))
done
