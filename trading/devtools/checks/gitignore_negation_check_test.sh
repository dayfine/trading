#!/bin/sh
# Fixture test for gitignore_negation_check.sh: RED on the PR #3321 first-draft
# shape, GREEN on a re-ignored shape and on the repo's real .gitignore.
. "$(dirname "$0")/_check_lib.sh"
here="$(cd "$(dirname "$0")" && pwd)"
chk="$here/gitignore_negation_check.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0

expect() { # name want_rc file [grep-pattern]
  out=$(sh "$chk" "$3" 2>&1); rc=$?
  if [ "$rc" != "$2" ]; then echo "FAIL: $1: rc=$rc want $2"; echo "$out"; fail=1; return; fi
  if [ -n "$4" ] && ! echo "$out" | grep -q "$4"; then
    echo "FAIL: $1: output lacks '$4'"; echo "$out"; fail=1; return
  fi
  echo "ok: $1"
}

cat > "$tmp/red" <<'X'
dev/backtest/scenarios-*/
!dev/backtest/scenarios-X/*/
X
expect "first-draft glob negation, no re-ignore" 1 "$tmp/red" 'scenarios-X/\*/'

cat > "$tmp/red2" <<'X'
!dev/experiments/foo/out/
dev/experiments/foo/out/*
!dev/experiments/bar/
X
expect "second dir lacks re-ignore (named)" 1 "$tmp/red2" 'experiments/bar/'

cat > "$tmp/red3" <<'X'
dev/backtest/s/*
!dev/backtest/s/
X
expect "re-ignore before negation does not count" 1 "$tmp/red3"


cat > "$tmp/red4" <<'X2'
!dev/backtest/X/
!dev/backtest/X/actual.sexp
dev/backtest/X/actual.sexp
dev/backtest/Y/*
foo/
X2
expect "negation followed by near-miss and other-dir lines" 1 "$tmp/red4" 'backtest/X/'

cat > "$tmp/red5" <<'X2'
!dev/experiments/e/
foo/
X2
expect "negation followed by unrelated line" 1 "$tmp/red5" 'experiments/e/'
cat > "$tmp/green" <<'X'
!dev/backtest/scenarios-X/
dev/backtest/scenarios-X/*
!dev/backtest/scenarios-X/stop-buffer-*/
dev/backtest/scenarios-X/stop-buffer-*/*
!dev/backtest/scenarios-X/stop-buffer-*/actual.sexp
!docs/elsewhere/
X
expect "narrowed shape; out-of-scope negation ignored" 0 "$tmp/green"

expect "real repo .gitignore" 0 "$(repo_root)/.gitignore"
exit $fail
