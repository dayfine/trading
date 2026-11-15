#!/bin/sh
# obs_read_check.sh -- fixture test of dev/experiments/observatory/obs_read.sh, the axis observatory's pair reader
# (dev/plans/axis-observatory-2026-11-14.md §3). fixtures/obs_read/gen_fixture.sh writes a synthetic five-seed run
# (made-up NAVs, no bars) with eleven arms against S (table in its header); the eleven appended surface.tsv rows must
# equal the golden expected_surface.tsv, and:
#   - the flag rule: the slope arm flags UP and the harm arm HARM; an UP and a HARM arm sitting on every boundary
#     (median D_end +-0.2000, exactly 4 seeds at >= 60 % with three at 5/7, step share 0.499) flag; and for each
#     clause, in each direction, one arm that misses only that clause by a hair (D_end +-0.1999; 3 seeds with two at
#     4/7 = 0.571; step share 0.500, or the 0.85 lottery) does not flag;
#   - a zero year counts as neither sign; the top step is traced to the trade that made it;
#   - the private out dir holds the weekly D(t) table and the per-seed steps, years and keyed diff;
#   - refusals leave the target surface byte-identical: a failed V6 log, unpaired equity curves, a level-sized
#     max-drawdown delta (end to end), a header from another reader version, and an out dir git would track.
# Run: sh trading/devtools/checks/obs_read_check.sh
set -eu
. "$(dirname "$0")/_check_lib.sh"

ROOT=$(repo_root); OBS=$ROOT/dev/experiments/observatory; FIX=$ROOT/trading/devtools/checks/fixtures/obs_read
[ -f "$OBS/obs_read.sh" ] || die "obs_read_check: script under test not found: $OBS/obs_read.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
fails=0
ok() { echo "OK: obs_read_check: $1"; }
bad() { echo "FAIL: obs_read_check: $1" >&2; fails=$((fails + 1)); }
expect() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected '$2', got '$3'"; fi; }
same() { if cmp -s "$2" "$3"; then ok "$1"; else bad "$1: $3 changed"; fi; }
# rd ARM LABEL OUT SURFACE [YEARS] -> exit code of obs_read.sh on $TMP/run (output discarded)
rd() { rc=0; sh "$OBS/obs_read.sh" -r "$TMP/run" -p obs -a "$1" -l "$2" -v "(($2 1))" -c fixture0 -O "$3" -t "$4" \
  ${5:+-y "$5"} > "$TMP/last.log" 2>&1 || rc=$?; echo "$rc"; }
# cols ROW COL... -> those columns of a surface row, space-separated
cols() { r=$1; shift; awk -F'\t' -v r="$r" -v c="$*" 'NR == r + 1 { n = split(c, k, " "); o = $k[1]
  for (i = 2; i <= n; i++) o = o " " $k[i]; print o }' "$TMP/surface.tsv"; }

sh "$FIX/gen_fixture.sh" "$TMP/run"
ARMS="U:slope L:lottery H:harm P:edge-up Q:edge-harm D:dend-up N:seeds-up T:step-up E:dend-harm M:seeds-harm K:step-harm"
for p in $ARMS; do a=${p%%:*}; y=$FIX/spy_years.tsv; [ "$a" = L ] && y=
  expect "arm $p reads" 0 "$(rd "$a" "${p#*:}" "$TMP/out-$a" "$TMP/surface.tsv" "$y")"; done
if diff -u "$FIX/expected_surface.tsv" "$TMP/surface.tsv"; then ok "surface rows equal the golden"
else bad "surface rows differ from the golden"; fi
expect "flags" "UP none HARM UP HARM none none none none none none" "$(awk -F'\t' 'NR > 1 { printf "%s%s", s, $29; s = " " }' "$TMP/surface.tsv")"
# columns: 29 flag, 8 median D_end, 12 seeds_pos60, 13 seeds_neg60, 19 median largest step share
expect "P: UP on every boundary" "UP 0.2000 4 0.499" "$(cols 4 29 8 12 19)"
expect "Q: HARM on every boundary" "HARM -0.2000 4 0.499" "$(cols 5 29 8 13 19)"
expect "D: stopped by the D_end clause alone" "none 0.1999 5 0.007" "$(cols 6 29 8 12 19)"
expect "N: stopped by the seeds clause alone" "none 0.3500 3 0.006" "$(cols 7 29 8 12 19)"
expect "T: stopped by the step clause alone" "none 0.3000 5 0.500" "$(cols 8 29 8 12 19)"
expect "E: stopped by the D_end clause alone" "none -0.1999 5 0.007" "$(cols 9 29 8 13 19)"
expect "M: stopped by the seeds clause alone" "none -0.3500 3 0.006" "$(cols 10 29 8 13 19)"
expect "K: stopped by the step clause alone" "none -0.3000 5 0.500" "$(cols 11 29 8 13 19)"
expect "L: the lottery is stopped by the step clause alone" "none 0.4700 5 0.850" "$(cols 2 29 8 12 19)"
expect "L's top step is its one arm-only trade" "2013-03-08 +0.850 [MONSTR@2013-01-07/A]" "$(cols 2 22 | cut -d';' -f1)"
expect "K's top step is the base-only trade it lacks" "2013-03-08 +0.500 [BIGWIN@2013-01-07/S]" "$(cols 11 22 | cut -d';' -f1)"
expect "N k0's 2010 is a zero year" "+0.0000" "$(awk -F'\t' '$1 == 2010 { print $3 }' "$TMP/out-N/years-k0.tsv")"
expect "a zero year counts as neither sign (27 up + 7 down of 35)" "0.771 0.200" "$(cols 7 10 11)"
expect "arms-run counter" "1 2 3 11" "$(cols 1 1) $(cols 2 1) $(cols 3 1) $(cols 11 1)"
expect "v6 column" "ok unchecked" "$(cols 1 7) $(cols 3 7)"
expect "no SPY years file -> NA bull/bear split" "NA NA" "$(cols 2 17 18)"
expect "private D(t) table: a column per seed" "date k0 k1 k2 k3 k4" "$(head -1 "$TMP/out-U/D.tsv" | tr '\t' ' ')"
expect "private per-seed steps, years and keyed diff" 15 "$(ls "$TMP/out-H" | grep -c -E '^(steps|years|firstdiff)-k[0-4]\.tsv$')"
levels() { # numbers of magnitude >= 10,000 past the label columns: a NAV or price would be one
  awk -F'\t' 'NR > 1 { for (i = 5; i <= NF; i++) { n = split($i, v, /[ ,;]+/); for (k = 1; k <= n; k++)
    if (v[k] ~ /^[-+]?[0-9.]+$/ && (v[k] + 0 >= 10000 || v[k] + 0 <= -10000)) c++ } } END { print c + 0 }' "$1"; }
expect "no level-sized number in the public rows" 0 "$(levels "$TMP/surface.tsv")"

# Refusals: each must leave the surface it targets byte-identical.
cp "$TMP/surface.tsv" "$TMP/before.tsv"
cp -R "$TMP/run" "$TMP/run.keep"
fresh() { rm -rf "$TMP/run"; cp -R "$TMP/run.keep" "$TMP/run"; }
echo "exit=1" > "$TMP/run/k2/obs-U-k2-s0.v6diff-S.log"
expect "failed V6 log refused" 1 "$(rd U slope "$TMP/out-U" "$TMP/surface.tsv")"
same "failed V6 log appended nothing" "$TMP/before.tsv" "$TMP/surface.tsv"
fresh; sed '$d' "$TMP/run.keep/k3/obs-H-k3-s0-equity_curve.csv" > "$TMP/run/k3/obs-H-k3-s0-equity_curve.csv"
expect "unpaired equity curves refused" 2 "$(rd H harm "$TMP/out-H" "$TMP/surface.tsv")"
same "unpaired curves appended nothing" "$TMP/before.tsv" "$TMP/surface.tsv"
fresh; for k in 0 1 2 3 4; do f=$TMP/run/k$k/obs-U-k$k-s0-summary.sexp
  sed 's/maxdrawdown [0-9.]*)/maxdrawdown 2412000.00)/' "$TMP/run.keep/k$k/obs-U-k$k-s0-summary.sexp" > "$f"; done
expect "a level-sized max-drawdown delta is refused" 3 "$(rd U slope "$TMP/out-U" "$TMP/surface.tsv")"
same "the leaked level appended nothing" "$TMP/before.tsv" "$TMP/surface.tsv"
fresh; cut -f1-28 "$TMP/before.tsv" > "$TMP/other.tsv"; cp "$TMP/other.tsv" "$TMP/other.before"
expect "a surface with another header refused" 1 "$(rd L lottery "$TMP/out-L" "$TMP/other.tsv")"
same "the foreign-header surface is unchanged" "$TMP/other.before" "$TMP/other.tsv"
if command -v git > /dev/null 2>&1 && git init -q "$TMP/repo" 2> /dev/null; then
  expect "out dir git would track refused" 1 "$(rd L lottery "$TMP/repo/obs/out" "$TMP/s2.tsv")"
  expect "refused out dir not created" no "$([ -d "$TMP/repo/obs" ] && echo yes || echo no)"
  echo "obs/" > "$TMP/repo/.gitignore"
  expect "git-ignored out dir accepted" 0 "$(rd L lottery "$TMP/repo/obs/out" "$TMP/s2.tsv")"
else echo "SKIP: obs_read_check: no git; out-dir guard not exercised"; fi

[ "$fails" -eq 0 ] || die "obs_read_check: $fails check(s) failed"
echo "OK: obs_read_check: all checks passed"
