#!/bin/sh
# obs_read_check.sh -- fixture test of dev/experiments/observatory/obs_read.sh, the axis observatory's pair reader
# (dev/plans/axis-observatory-2026-11-14.md §3). fixtures/obs_read/gen_fixture.sh writes a synthetic five-seed run
# (made-up NAVs, no bars) with three arms against S; the three appended surface.tsv rows must equal the golden
# expected_surface.tsv, and:
#   - the slope arm flags UP, the one-step lottery arm does not flag (its step clause alone blocks it), the harm arm
#     flags HARM; the lottery's top step is traced to its one arm-only trade;
#   - the private out dir holds the weekly D(t) table and the per-seed steps, years and keyed diff;
#   - refusals append nothing: a failed V6 log, an out dir git would track, unpaired equity curves, a header from
#     another reader version, and a level-sized number in a row.
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
# read ARM LABEL OUT SURFACE [YEARS] -> exit code of obs_read.sh (output discarded)
rd() { rc=0; sh "$OBS/obs_read.sh" -r "$TMP/run" -p obs -a "$1" -l "$2" -v "(($2 1))" -c fixture0 -O "$3" -t "$4" \
  ${5:+-y "$5"} > "$TMP/last.log" 2>&1 || rc=$?; echo "$rc"; }
col() { awk -F'\t' -v r="$1" -v c="$2" 'NR == r + 1 { print $c }' "$TMP/surface.tsv"; }

sh "$FIX/gen_fixture.sh" "$TMP/run"
expect "slope arm reads" 0 "$(rd U slope "$TMP/out-U" "$TMP/surface.tsv" "$FIX/spy_years.tsv")"
expect "lottery arm reads (no SPY years file)" 0 "$(rd L lottery "$TMP/out-L" "$TMP/surface.tsv")"
expect "harm arm reads" 0 "$(rd H harm "$TMP/out-H" "$TMP/surface.tsv" "$FIX/spy_years.tsv")"
if diff -u "$FIX/expected_surface.tsv" "$TMP/surface.tsv"; then ok "surface rows equal the golden"
else bad "surface rows differ from the golden"; fi
expect "flags" "UP none HARM" "$(col 1 29) $(col 2 29) $(col 3 29)"
expect "lottery passes every clause but the step share" "0.4754 5 0.843" "$(col 2 8) $(col 2 12) $(col 2 19)"
expect "lottery's top step is its one arm-only trade" "2013-03-08 +0.843 [MONSTR@2013-01-07/A]" "$(col 2 22 | cut -d';' -f1)"
expect "arms-run counter" "1 2 3" "$(col 1 1) $(col 2 1) $(col 3 1)"
expect "v6 column" "ok unchecked" "$(col 1 7) $(col 3 7)"
expect "no SPY years file -> NA bull/bear split" "NA NA" "$(col 2 17) $(col 2 18)"
expect "private D(t) table: a column per seed" "date k0 k1 k2 k3 k4" "$(head -1 "$TMP/out-U/D.tsv" | tr '\t' ' ')"
expect "private per-seed steps, years and keyed diff" 15 "$(ls "$TMP/out-H" | grep -c -E '^(steps|years|firstdiff)-k[0-4]\.tsv$')"
levels() { # numbers of magnitude >= 10,000 past the label columns: a NAV or price would be one
  awk -F'\t' 'NR > 1 { for (i = 5; i <= NF; i++) { n = split($i, v, /[ ,;]+/); for (k = 1; k <= n; k++)
    if (v[k] ~ /^[-+]?[0-9.]+$/ && (v[k] + 0 >= 10000 || v[k] + 0 <= -10000)) c++ } } END { print c + 0 }' "$1"; }
expect "no level-sized number in the public rows" 0 "$(levels "$TMP/surface.tsv")"

# Refusals: each must leave the surface unchanged.
cp "$TMP/surface.tsv" "$TMP/before.tsv"
cp -R "$TMP/run" "$TMP/run.keep"
echo "exit=1" > "$TMP/run/k2/obs-U-k2-s0.v6diff-S.log"
expect "failed V6 log refused" 1 "$(rd U slope "$TMP/out-U" "$TMP/surface.tsv")"
rm -rf "$TMP/run"; cp -R "$TMP/run.keep" "$TMP/run"
sed '$d' "$TMP/run.keep/k3/obs-H-k3-s0-equity_curve.csv" > "$TMP/run/k3/obs-H-k3-s0-equity_curve.csv"
expect "unpaired equity curves refused" 2 "$(rd H harm "$TMP/out-H" "$TMP/surface.tsv")"
rm -rf "$TMP/run"; cp -R "$TMP/run.keep" "$TMP/run"
printf 'M\tk0\t0.1\t6\t3\t3\t0\t0\t0\t0\tNA\tNA\t0.1\t-\t2412000.00\t0\t0\t0\t0\t0\t-\n' > "$TMP/leak.tsv"
rc=0; awk -v arms_run=9 -v v6=ok -f "$OBS/read/lib/common.awk" -f "$OBS/read/lib/row.awk" "$TMP/leak.tsv" \
  > /dev/null 2>&1 || rc=$?
expect "a level-sized delta is refused" 3 "$rc"
cut -f1-28 "$TMP/before.tsv" > "$TMP/other.tsv"
expect "a surface with another header refused" 1 "$(rd L lottery "$TMP/out-L" "$TMP/other.tsv")"
diff -q "$TMP/before.tsv" "$TMP/surface.tsv" > /dev/null && ok "refusals appended nothing" || bad "a refusal changed the surface"
if command -v git > /dev/null 2>&1 && git init -q "$TMP/repo" 2> /dev/null; then
  expect "out dir git would track refused" 1 "$(rd L lottery "$TMP/repo/obs/out" "$TMP/s2.tsv")"
  expect "refused out dir not created" no "$([ -d "$TMP/repo/obs" ] && echo yes || echo no)"
  echo "obs/" > "$TMP/repo/.gitignore"
  expect "git-ignored out dir accepted" 0 "$(rd L lottery "$TMP/repo/obs/out" "$TMP/s2.tsv")"
else echo "SKIP: obs_read_check: no git; out-dir guard not exercised"; fi

[ "$fails" -eq 0 ] || die "obs_read_check: $fails check(s) failed"
echo "OK: obs_read_check: all checks passed"
