#!/bin/sh
# Apply the full pit-v12 rename-twin dedupe (#3388) to the composition lists. POSIX sh + awk, host-only.
#
# Usage: sh apply-full-dedupe.sh            (from anywhere; paths resolve from this script's location)
#   env DROPS (default ../v12-twin-scan-2026-10-22/results/drops.txt), EXCLUDE (default ../v12-twin-scan-2026-10-22/
#   exclude-pairs.txt), PIT (default trading/test_data/backtest_scenarios/pit-v12).
#
# Steps:
#   1. Filter drops.txt ("LIST DROPPED SURVIVOR") against exclude-pairs.txt, in both orders. drops.txt predates the
#      BML-P-* exclusion (distinct preferred series), so its 6 BML-P-G/H/J/L rows drop out here; nothing else does.
#   2. Resolve survivor chains per list. A row (L, D, S) whose survivor S is itself dropped from L (a (L, S, S2) row
#      exists) would leave L with neither leg, and pit_twin_cooccur_check.sh fails it ("survivor missing"; e.g.
#      top-1000-1998 BAC-WS-B BAC-WS-A, where BAC-WS-A leaves for BAC). So S is replaced by its own survivor until it is
#      not a dropped key of L; the first row of a key, in file order, names its survivor. A cycle aborts. A re-pointed
#      row carries a 4th field via=<original S>, which the check ignores.
#   3. Apply (apply-drops.sh) the rows whose (LIST, DROPPED) is not already in PIT/twin-drops.txt. One symbol can be the
#      loser of several rows in one list (BAC-WS-B twins BAC and BAC-WS-A); apply-drops.sh removes the entry once.
#   4. Rewrite PIT/twin-drops.txt with every resolved row under a short header.
# Re-running after a successful run applies nothing (every row is already in twin-drops.txt) and rewrites the same file.
# Afterwards: regenerate PIT/composition.md5 and run trading/devtools/checks/pit_twin_cooccur_check.sh.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
SCAN=$REPO/dev/experiments/v12-twin-scan-2026-10-22
DROPS=${DROPS:-$SCAN/results/drops.txt}
EXCLUDE=${EXCLUDE:-$SCAN/exclude-pairs.txt}
PIT=${PIT:-$REPO/trading/test_data/backtest_scenarios/pit-v12}
TD=$PIT/twin-drops.txt
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. exclusion filter (pairs file: "A B" per line, '#' comments; a pair matches in either order)
awk 'NR == FNR { if ($0 !~ /^#/ && NF >= 2) { ex[$1 " " $2] = 1; ex[$2 " " $1] = 1 } next }
     NF == 3 && !(($2 " " $3) in ex)' "$EXCLUDE" "$DROPS" > "$TMP/filtered.txt"
echo "filtered: $(wc -l < "$DROPS" | tr -d ' ') rows -> $(wc -l < "$TMP/filtered.txt" | tr -d ' ') ($(($(wc -l < "$DROPS") - $(wc -l < "$TMP/filtered.txt"))) excluded)"

# 2. survivor-chain resolution, per list
awk '
  { row[NR] = $0; L[NR] = $1; D[NR] = $2; S[NR] = $3; k = $1 " " $2; if (!(k in surv)) surv[k] = $3 }
  END {
    for (i = 1; i <= NR; i++) {
      s = S[i]; hops = 0; delete seen; seen[D[i]] = 1
      while ((L[i] " " s) in surv) {
        if (s in seen) { printf "apply-full-dedupe: survivor cycle in %s at %s (row: %s)\n", L[i], s, row[i] > "/dev/stderr"; exit 1 }
        seen[s] = 1; s = surv[L[i] " " s]; hops++
      }
      if (hops) print L[i], D[i], s, "via=" S[i]; else print L[i], D[i], s
    }
  }' "$TMP/filtered.txt" > "$TMP/resolved.txt"
echo "resolved: $(grep -c ' via=' "$TMP/resolved.txt" || true) rows re-pointed to their survivor's survivor"

# 3. apply the rows not yet in twin-drops.txt
awk 'NR == FNR { if ($0 !~ /^#/ && NF >= 3) have[$1 " " $2] = 1; next } !(($1 " " $2) in have) { print $1, $2, $3 }' \
  "$TD" "$TMP/resolved.txt" > "$TMP/new.txt"
if [ -s "$TMP/new.txt" ]; then
  echo "applying $(wc -l < "$TMP/new.txt" | tr -d ' ') rows: $(awk '{ print $1 " " $2 }' "$TMP/new.txt" | LC_ALL=C sort -u | wc -l | tr -d ' ') entries in $(awk '{ print $1 }' "$TMP/new.txt" | LC_ALL=C sort -u | wc -l | tr -d ' ') lists"
  sh "$SCAN/apply-drops.sh" "$TMP/new.txt" "$PIT/composition" > "$TMP/apply.log"
  tail -1 "$TMP/apply.log"
else
  echo "nothing to apply: every row is already in $TD"
fi

# 4. rewrite twin-drops.txt
{
  echo "# Per-list rename-twin drops (#3266, #3388): LIST DROPPED SURVIVOR [via=ORIGINAL_SURVIVOR]. Checked by"
  echo "# trading/devtools/checks/pit_twin_cooccur_check.sh. Produced by dev/experiments/v12-twin-scan-2026-10-22/ (window-drops.sh),"
  echo "# applied in full by dev/experiments/twin-dedupe-26y-2026-10-29/apply-full-dedupe.sh: exclude-pairs.txt filtered out,"
  echo "# survivor chains resolved per list (via= names the survivor drops.txt gave before it was itself dropped)."
  cat "$TMP/resolved.txt"
} > "$TD.tmp"
mv "$TD.tmp" "$TD"
echo "wrote $TD: $(grep -c -v '^#' "$TD") rows"
