#!/bin/sh
# Repair the pit-v13 rename-twin dedupe (#3721 D1, #3713). POSIX sh + awk, host-only.
#
# Usage: sh repair.sh <scan-out-dir>
#   <scan-out-dir> holds the v13 whole-union scan: twin-scan.sh + window-drops.sh (LAST_YEAR=2026) run with LISTS set
#   to pit-v13/composition (see README.md). Its drops.txt is "LIST DROPPED SURVIVOR".
#   env PIT (default trading/test_data/backtest_scenarios/pit-v13), PREV (default .../pit-v12/twin-drops.txt),
#   EXCLUDE (default dev/experiments/v12-twin-scan-2026-10-22/exclude-pairs.txt).
#
# Steps:
#   1. Inherited cells: every v12 row (L, D, S) against every v13 list of L's year (top-3000-Y and top-4000-Y) that
#      holds both D and S. The v12 decision (D leaves, S stays) is kept as is: the window, the pair and the loser rule
#      are the same.
#   2. Scan cells: the v13 scan's drops.txt rows, less exclude-pairs.txt. A row for a v12 pair is turned to v12's
#      direction (v12's loser leaves), so a re-drawn survivor can never drop both legs of one list.
#   3. One row per (LIST, DROPPED), inherited first. Survivor chains resolved per list as in
#      ../twin-dedupe-26y-2026-10-29/apply-full-dedupe.sh (via= names the first survivor when it is itself dropped).
#   4. apply-drops.sh cuts the entries; existing pit-v13 rows whose survivor this repair drops from that list are
#      re-pointed to the new survivor (via=<old survivor>), so the own-rows check still describes the list.
#   5. twin-drops.txt is rewritten: header, existing rows (re-pointed), then the new rows.
# Cells whose two legs are not both members are skipped, so a re-run on repaired lists applies nothing.
# Writes results/new-rows.txt (LIST DROPPED SURVIVOR [via=] src=v12|scan) beside this script (env ROWS_OUT overrides).
# Afterwards: regenerate PIT/composition.md5, run trading/devtools/checks/pit_twin_cooccur_check.sh.
set -eu

SCANOUT=${1:?usage: repair.sh <scan-out-dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
PIT=${PIT:-$REPO/trading/test_data/backtest_scenarios/pit-v13}
PREV=${PREV:-$REPO/trading/test_data/backtest_scenarios/pit-v12/twin-drops.txt}
EXCLUDE=${EXCLUDE:-$REPO/dev/experiments/v12-twin-scan-2026-10-22/exclude-pairs.txt}
TD=$PIT/twin-drops.txt
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
NEW=$TMP/new-rows.txt

# membership "LIST SYMBOL"
for f in "$PIT"/composition/*.sexp; do
  awk -v l="$(basename "$f" .sexp)" '{
      s = $0
      while (match(s, /\(symbol [^)]*\)/)) { print l, substr(s, RSTART + 8, RLENGTH - 9); s = substr(s, RSTART + RLENGTH) }
    }' "$f"
done > "$TMP/mem.txt"

# 1. inherited cells
awk 'function year(l,   n, p) { n = split(l, p, "-"); return p[n] }
     NR == FNR { m[$1 " " $2] = 1; if (!seen[$1]++) by[year($1)] = by[year($1)] " " $1; next }
     $1 == "" || $1 ~ /^#/ { next }
     { n = split(by[year($1)], ls, " ")
       for (i = 1; i <= n; i++) if (((ls[i] " " $2) in m) && ((ls[i] " " $3) in m)) print ls[i], $2, $3, "src=v12" }' \
  "$TMP/mem.txt" "$PREV" > "$TMP/inherited.txt"

# 2. scan cells, exclusions out; a v12 pair keeps v12's direction (its loser leaves)
awk 'FILENAME == ARGV[1] { if ($0 !~ /^#/ && NF >= 2) { ex[$1 " " $2] = 1; ex[$2 " " $1] = 1 } next }
     FILENAME == ARGV[2] { if ($0 !~ /^#/ && NF >= 3) v12[$2 " " $3] = 1; next }
     NF < 3 || (($2 " " $3) in ex) { next }
     ($3 " " $2) in v12 { print $1, $3, $2, "src=scan"; next }
     { print $1, $2, $3, "src=scan" }' \
  "$EXCLUDE" "$PREV" "$SCANOUT/drops.txt" \
  | awk 'NR == FNR { m[$1 " " $2] = 1; next } (($1 " " $2) in m) && (($1 " " $3) in m)' "$TMP/mem.txt" - > "$TMP/scan.txt"

# 3. one row per (LIST, DROPPED), chains resolved
cat "$TMP/inherited.txt" "$TMP/scan.txt" | awk '!seen[$1 " " $2]++' > "$TMP/cells.txt"
awk '
  { L[NR] = $1; D[NR] = $2; S[NR] = $3; src[NR] = $4; surv[$1 " " $2] = $3 }
  END {
    for (i = 1; i <= NR; i++) {
      s = S[i]; hops = 0; delete seen; seen[D[i]] = 1
      while ((L[i] " " s) in surv) {
        if (s in seen) { printf "repair: survivor cycle in %s at %s\n", L[i], s > "/dev/stderr"; exit 1 }
        seen[s] = 1; s = surv[L[i] " " s]; hops++
      }
      print L[i], D[i], s, (hops ? "via=" S[i] " " : "") src[i]
    }
  }' "$TMP/cells.txt" | LC_ALL=C sort > "$NEW"
echo "new rows: $(wc -l < "$NEW" | tr -d ' ') ($(grep -c 'src=v12' "$NEW" || true) inherited from v12, $(grep -c 'src=scan' "$NEW" || true) from the v13 scan)"
if [ ! -s "$NEW" ]; then echo "nothing to apply: no twin cell has both legs in a list"; exit 0; fi

# 4. apply, then re-point existing rows whose survivor left the list
awk '{ print $1, $2, $3 }' "$NEW" > "$TMP/apply.txt"
sh "$REPO/dev/experiments/v12-twin-scan-2026-10-22/apply-drops.sh" "$TMP/apply.txt" "$PIT/composition" > "$TMP/apply.log"
echo "applied: $(wc -l < "$TMP/apply.log" | tr -d ' ') lists changed"
awk 'NR == FNR { surv[$1 " " $2] = $3; next }
     $0 ~ /^#/ || NF < 3 { next }
     ($1 " " $3) in surv { print $1, $2, surv[$1 " " $3], "via=" $3; n++; next }
     { print }
     END { print n + 0 > "/dev/stderr" }' "$NEW" "$TD" > "$TMP/old.txt" 2> "$TMP/repointed"
echo "existing rows re-pointed: $(cat "$TMP/repointed")"

# 5. rewrite twin-drops.txt
{
  grep '^#' "$TD"
  echo "# Repaired 2026-11-25 (#3721 D1, #3713) by dev/experiments/v13-twin-repair-2026-11-25/repair.sh: the rows after the"
  echo "# first block re-apply every pit-v12 drop whose two legs were back in a same-year v13 list, and add the new pairs a"
  echo "# whole-union v13 scan confirmed; existing rows whose survivor left the list point at its survivor (via=)."
  cat "$TMP/old.txt"
  awk '{ print $1, $2, $3 ($4 ~ /^via=/ ? " " $4 : "") }' "$NEW"
} > "$TD.tmp"
mv "$TD.tmp" "$TD"
cp "$NEW" "${ROWS_OUT:-$HERE/results/new-rows.txt}"
echo "wrote $TD: $(grep -c -v '^#' "$TD") rows"
