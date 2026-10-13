#!/bin/sh
# Fixture-driven test for dev/scripts/wait_for.sh (issue #2738 Ask 2).
#
# Drives every condition through its seams -- a stub `gh` (WAIT_FOR_GH) that
# prints canned JSON-query output, and a stub `ps` (WAIT_FOR_PS) -- so nothing
# here touches GitHub or the live process table. Timeouts use
# --max-seconds 0/1 with --interval 1, so the suite takes a few seconds.

set -u

WAIT_FOR="$(dirname "$0")/wait_for.sh"
if [ ! -f "$WAIT_FOR" ]; then
  echo "FAIL: wait_for_test -- script not found at $WAIT_FOR" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stub gh: `gh api <path> --jq ...` prints the already-jq-shaped fixture for
# that REST path (the PR head SHA, its check runs, or the review count).
cat >"$TMP/gh" <<'EOF'
#!/bin/sh
case "$2" in
  */pulls/42) echo abc123 ;;
  */commits/abc123/check-runs*) cat "$STUB_DIR/checks" ;;
  */pulls/42/reviews*) cat "$STUB_DIR/reviews" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TMP/gh"

failures=0

_run() {
  # $1 = scenario name, $2 = expected exit, $3 = expected output substring,
  # rest = wait_for.sh arguments.
  name=$1 want=$2 needle=$3
  shift 3
  out=$(STUB_DIR="$TMP" WAIT_FOR_GH="$TMP/gh" WAIT_FOR_PS="cat $TMP/ps" \
    sh "$WAIT_FOR" "$@" 2>&1)
  got=$?
  if [ "$got" -ne "$want" ] || ! printf '%s' "$out" | grep -q -- "$needle"; then
    echo "FAIL: wait_for_test -- $name: want exit $want + '$needle', got $got"
    echo "  output: $out"
    failures=$((failures + 1))
  fi
}

T="--max-seconds 1 --interval 1"

# log
printf 'cell 1 started\nRESULT s0-null (wall 12s)\n' >"$TMP/chain.log"
_run "log fires on a matching line" 0 "wait_for: fired at .* after [0-9]*s" \
  $T log "$TMP/chain.log" '^RESULT s0-'
_run "log times out without a match" 2 "wait_for: timeout at .* (limit 1s)" \
  $T log "$TMP/chain.log" '^LANE B DONE'
_run "log times out on a missing file" 2 "timeout" \
  $T log "$TMP/absent.log" 'x'

# checks
printf 'completed success\nin_progress null\n' >"$TMP/checks"
_run "checks wait while any is running" 2 "timeout" $T checks 42
printf 'completed success\nqueued null\n' >"$TMP/checks"
_run "checks wait while any is queued" 2 "timeout" $T checks 42
printf 'completed success\ncompleted failure\ncompleted skipped\n' >"$TMP/checks"
_run "checks fire when all completed, naming fails" 0 "at abc123 (fail=1)" \
  $T checks 42
_run "an unknown PR keeps waiting" 2 "timeout" $T checks 7
: >"$TMP/checks"
_run "checks with no checks yet keep waiting" 2 "timeout" $T checks 42

# reviews
echo 1 >"$TMP/reviews"
_run "reviews below the count keep waiting" 2 "timeout" $T reviews 42 2
echo 2 >"$TMP/reviews"
_run "reviews at the count fire" 0 "fired" $T reviews 42 2

# proc: a zombie dune does not count as running
printf 'Ss bash\nZ [dune] <defunct>\n' >"$TMP/ps"
_run "proc ignores zombies" 0 "fired" $T proc 'dune'
printf 'Ss bash\nRl dune build @runtest\n' >"$TMP/ps"
_run "proc waits on a live match" 2 "timeout" $T proc 'dune'

# proc through the REAL default `ps` (no WAIT_FOR_PS stub): a pattern that
# matches its own text and no live process must fire. A filter running in the
# same pipeline as `ps` would see its own args and never fire (#3300 QC).
out=$(unset WAIT_FOR_PS; sh "$WAIT_FOR" --max-seconds 3 --interval 1 \
  proc 'zzqqnotaprocess' 2>&1)
got=$?
if [ "$got" -ne 0 ] || ! printf '%s' "$out" | grep -q -- "fired"; then
  echo "FAIL: wait_for_test -- proc with the real ps fires on an absent" \
    "pattern: want exit 0 + 'fired', got $got"
  echo "  output: $out"
  failures=$((failures + 1))
fi

# usage
_run "unknown condition is a usage error" 1 "usage" $T bogus
_run "non-numeric PR is a usage error" 1 "usage" $T checks abc
_run "non-numeric limit is a usage error" 1 "usage" --max-minutes x log f p

if [ "$failures" -gt 0 ]; then
  echo "FAIL: wait_for_test -- $failures scenario(s) failed"
  exit 1
fi
echo "OK: wait_for_test"
