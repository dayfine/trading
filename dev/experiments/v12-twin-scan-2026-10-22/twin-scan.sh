#!/bin/sh
# Whole-universe rename-twin scan of the pit-v12 composition lists (#3266, #3057). Host-only, POSIX sh + awk. It reads
# the CSV store directly: no warehouse, no container, no chunks. A twin whose legs sit in different build chunks (the
# class the chunked builds miss, project_pit_chunked_twin_miss) is seen like any other pair.
#
# Usage: sh twin-scan.sh <out-dir>
#   env DATA (bar store, default /Users/difan/Projects/trading-1/data), LISTS (composition dir, default the pit-v12 one
#   in this checkout), MIN_SHARED (prefilter: shared fingerprints to become a candidate, default 8).
#
# Criterion = Twin_detector, [Returns] basis (trading/trading/backtest/snapshot_warehouse/twin_detector.mli), applied
# to the whole list union at once:
#   unit     a return pair on consecutive SHARED dates: ra = adj_a(t)/adj_a(t-1) - 1, the same for b
#   match    |ra - rb| <= RET_EPS (1e-3)
#   twin     overlap >= MIN_OVERLAP (200, the v11/v12 analyze-pair bar) AND
#            (match fraction >= MATCH (0.95)  OR  longest run of consecutive matches >= MIN_RUN (250, #3057's N))
#   survivor the leg with the later last bar (ties: the lexically smaller symbol), the detector's rule
# Prefilter (perf only): every symbol emits one fingerprint per anchor date (a fixed 1-in-7 subset of dates, the same
# subset for every symbol) = date + its next 3 adjusted-close returns rounded to 1e-3. Windows whose 3 returns are all
# under 0.3 % are skipped (the flat-series hub class, #2823). Fingerprints shared by 2..6 symbols vote for each pair;
# a pair with >= MIN_SHARED votes gets the full compare. A 250-day run carries ~36 anchors, so 8 is loose.
#
# Outputs (<out-dir>): symbols.txt, missing-csv.txt, candidates.txt ("votes a b"), compare.txt (every candidate, full
# stats), twins.txt (confirmed: "DROPPED SURVIVOR <evidence>"), cooccur.txt (per confirmed pair, the lists holding
# both legs). The fingerprint scratch file is deleted at the end.
set -eu

OUT=${1:?usage: twin-scan.sh <out-dir>}
HERE=$(cd "$(dirname "$0")/../../.." && pwd)
DATA=${DATA:-/Users/difan/Projects/trading-1/data}
LISTS=${LISTS:-$HERE/trading/test_data/backtest_scenarios/pit-v12/composition}
MIN_SHARED=${MIN_SHARED:-8}
RET_EPS=1e-3; MIN_OVERLAP=200; MATCH=0.95; MIN_RUN=250
mkdir -p "$OUT"
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

# CSV path of a symbol in the store: <first char>/<last char>/<SYM>/data.csv
csv_of() {
  f=$(printf %s "$1" | cut -c1)
  l=$(printf %s "$1" | sed 's/.*\(.\)$/\1/')
  echo "$DATA/$f/$l/$1/data.csv"
}

# 1. the union of every list (top-1000 and top-3000, every year)
cat "$LISTS"/top-*.sexp | grep -o '(symbol [^)]*)' | sed 's/(symbol //; s/)$//' | grep -v -x GSPC.INDX \
  | LC_ALL=C sort -u > "$OUT/symbols.txt"
: > "$OUT/missing-csv.txt"; : > "$OUT/files.txt"
while read -r s; do
  p=$(csv_of "$s")
  if [ -f "$p" ]; then echo "$p" >> "$OUT/files.txt"; else echo "$s" >> "$OUT/missing-csv.txt"; fi
done < "$OUT/symbols.txt"
log "union $(wc -l < "$OUT/symbols.txt" | tr -d ' ') symbols, $(wc -l < "$OUT/missing-csv.txt" | tr -d ' ') without a CSV"

# 2. fingerprints. Day number = y*372 + m*31 + d: not calendar-exact, but a fixed function of the date string, which is
# all a shared anchor subset needs.
FP=$OUT/fp.tmp
xargs awk -F, '
  function flush(   i, r1, r2, r3) {
    for (i = 1; i + 3 <= n; i++) {
      if ((substr(d[i], 1, 4) * 372 + substr(d[i], 6, 2) * 31 + substr(d[i], 9, 2)) % 7 != 0) continue
      if (a[i] <= 0 || a[i+1] <= 0 || a[i+2] <= 0) continue
      r1 = a[i+1] / a[i] - 1; r2 = a[i+2] / a[i+1] - 1; r3 = a[i+3] / a[i+2] - 1
      if (r1 < 0.003 && r1 > -0.003 && r2 < 0.003 && r2 > -0.003 && r3 < 0.003 && r3 > -0.003) continue
      printf "%s|%.3f|%.3f|%.3f %s\n", d[i], r1, r2, r3, sym
    }
    n = 0
  }
  FNR == 1 { if (sym != "") flush(); m = split(FILENAME, p, "/"); sym = p[m - 1]; next }
  $1 ~ /^[0-9][0-9][0-9][0-9]-/ { n++; d[n] = $1; a[n] = $6 + 0 }
  END { if (sym != "") flush() }' < "$OUT/files.txt" > "$FP"
log "fingerprints: $(wc -l < "$FP" | tr -d ' ')"

# 3. vote: pairs sharing a fingerprint (groups of 2..6), counted
LC_ALL=C sort -T "$OUT" -S 512M "$FP" | awk '
  function emit(   i, j) {
    if (k >= 2 && k <= 6) for (i = 1; i < k; i++) for (j = i + 1; j <= k; j++) print (s[i] < s[j] ? s[i] " " s[j] : s[j] " " s[i])
  }
  $1 != key { emit(); key = $1; k = 0 } { s[++k] = $2 } END { emit() }' \
  | LC_ALL=C sort -T "$OUT" -S 256M | uniq -c | awk -v t="$MIN_SHARED" '$1 >= t { print $1, $2, $3 }' \
  | sort -k1,1nr -k2,2 > "$OUT/candidates.txt"
rm -f "$FP"
log "candidates (>= $MIN_SHARED shared fingerprints): $(wc -l < "$OUT/candidates.txt" | tr -d ' ')"

# 4. full compare of each candidate (the detector criterion, on the CSVs)
compare() {
  awk -F, -v A="$1" -v B="$2" -v eps="$RET_EPS" '
    FNR == 1 { f++ }
    f == 1 && $1 ~ /^[0-9]/ { aa[$1] = $6 + 0; ca[$1] = $5; lasta = $1; if (firsta == "") firsta = $1; next }
    f == 2 && $1 ~ /^[0-9]/ {
      lastb = $1; if (firstb == "") firstb = $1
      if (!($1 in aa)) next
      ov++; if ($5 == ca[$1]) same++
      if (pd != "") {
        pa = aa[pd]
        if (pa > 0 && pbv > 0) {
          u++; x = (aa[$1] / pa - 1) - (($6 + 0) / pbv - 1)
          if (x <= eps && x >= -eps) {
            mt++; run++; if (run == 1) rs = pd
            if (run > best) { best = run; bstart = rs; bend = $1 }
          } else run = 0
        } else run = 0
      }
      pd = $1; pbv = $6 + 0
    }
    END {
      printf "%s %s overlap=%d pairs=%d match=%.4f run=%d run_span=%s..%s same_close=%d a=%s..%s b=%s..%s\n",
        A, B, ov, u, (u ? mt / u : 0), best, bstart, bend, same, firsta, lasta, firstb, lastb
    }' "$(csv_of "$1")" "$(csv_of "$2")"
}
: > "$OUT/compare.txt"
while read -r v a b; do echo "votes=$v $(compare "$a" "$b")"; done < "$OUT/candidates.txt" >> "$OUT/compare.txt"

# 5. confirm + pick the survivor (later last bar; tie -> smaller symbol); write "DROPPED SURVIVOR <evidence>"
awk -v mo="$MIN_OVERLAP" -v mf="$MATCH" -v mr="$MIN_RUN" '{
    for (i = 4; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
    a = $2; b = $3
    if (v["overlap"] + 0 < mo || (v["match"] + 0 < mf && v["run"] + 0 < mr)) next
    split(v["a"], ra, /\.\./); split(v["b"], rb, /\.\./)
    if (ra[2] > rb[2] || (ra[2] == rb[2] && a < b)) { s = a; dr = b } else { s = b; dr = a }
    print dr, s, $4, $5, $6, $7, $8, $9, "a=" a ":" v["a"], "b=" b ":" v["b"], (v["match"] + 0 >= mf ? "rule=fraction" : "rule=run")
  }' "$OUT/compare.txt" | LC_ALL=C sort > "$OUT/twins.txt"
log "confirmed twins: $(wc -l < "$OUT/twins.txt" | tr -d ' ')"

# 6. co-occurrence: the lists holding both legs (a held twin needs both legs in the same year's list)
: > "$OUT/cooccur.txt"
while read -r d s _; do
  both=""
  for f in "$LISTS"/top-*.sexp; do
    if grep -q -F "(symbol $d)" "$f" && grep -q -F "(symbol $s)" "$f"; then both="$both $(basename "$f" .sexp)"; fi
  done
  echo "$d $s:${both:- none}" >> "$OUT/cooccur.txt"
done < "$OUT/twins.txt"
rm -f "$OUT/files.txt"
log "done: $OUT/twins.txt, $OUT/cooccur.txt"
