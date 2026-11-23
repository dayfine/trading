#!/bin/sh
# no_tracked_bars_check_test.sh -- pins no_tracked_bars_check.sh (#3701).
#
# Builds a throwaway git repo as REPO_ROOT. Cases:
#   1. clean tree (a tracked non-bar fixture only) -> OK, exit 0
#   2. a tracked bar fixture -> FAIL naming it, exit 1
#   3. same, under forced different ownership with an empty HOME (CI's
#      dubious-ownership mode, where an unguarded git ls-files errors out and
#      used to pass vacuously) -> still FAIL naming it
#   4. git itself failing (REPO_ROOT not a repo) -> FAIL, never OK

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
CHECK="$HERE/no_tracked_bars_check.sh"
T=$(cd "$(mktemp -d)" && pwd -P)  # physical path: safe.directory compares realpaths
trap 'rm -rf "$T"' EXIT
fails=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fails=$((fails + 1)); }

R="$T/repo"
mkdir -p "$R/trading/test_data/S/Y" "$T/home"
git init -q "$R"
echo '(m)' >"$R/trading/test_data/S/Y/manifest.sexp"
git -C "$R" add -A
git -C "$R" -c user.name=t -c user.email=t@t commit -q -m base

out=$(REPO_ROOT="$R" sh "$CHECK" 2>&1); rc=$?
{ [ $rc -eq 0 ] && echo "$out" | grep -q '^OK'; } && ok "clean tree OK" || bad "clean tree: rc=$rc $out"

mkdir -p "$R/trading/test_data/A/L/AAPL"
echo 'date,close' >"$R/trading/test_data/A/L/AAPL/data.csv"
git -C "$R" add -f trading/test_data/A/L/AAPL/data.csv

out=$(REPO_ROOT="$R" sh "$CHECK" 2>&1); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'AAPL/data.csv'; } && ok "tracked bar FAILs naming it" || bad "tracked bar: rc=$rc $out"

out=$(REPO_ROOT="$R" HOME="$T/home" GIT_TEST_ASSUME_DIFFERENT_OWNER=1 sh "$CHECK" 2>&1); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'AAPL/data.csv'; } && ok "tracked bar FAILs under different owner" || bad "different owner: rc=$rc $out"

mkdir -p "$T/notrepo"
out=$(REPO_ROOT="$T/notrepo" HOME="$T/home" GIT_CEILING_DIRECTORIES="$T" sh "$CHECK" 2>&1); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL'; } && ok "git error FAILs loudly" || bad "git error: rc=$rc $out"

[ "$fails" -eq 0 ] || { echo "FAIL: no_tracked_bars_check_test: $fails case(s)"; exit 1; }
echo "OK: no_tracked_bars_check_test"
