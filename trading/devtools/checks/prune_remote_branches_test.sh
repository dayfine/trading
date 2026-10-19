#!/bin/sh
set -eu

. "$(dirname "$0")/_check_lib.sh"

SCRIPT="$(repo_root)/dev/scripts/prune_remote_branches.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create fake gh
cat << 'FAKEGH' > "$TMPDIR/gh"
#!/bin/sh
if [ "$1" = "api" ]; then
  if [ "$2" = "-X" ]; then
    # `gh api -X DELETE repos/.../git/refs/heads/<branch>`: record the target, delete nothing.
    echo "$4" >> "$FAKEGH_LOG"
    exit 0
  elif [ "$2" = "repos/dayfine/trading/branches" ]; then
    printf 'main\nmerged_unchanged\ntip_moved\nclosed_30_days_ago\nclosed_today\nopen_pr\nno_pr\nwith/slash\nmerged/slash\n'
  elif echo "$2" | grep -q "/branches/merged_unchanged$"; then echo 'c1'
  elif echo "$2" | grep -q "/pulls.*merged_unchanged"; then echo '1 closed true 2023-01-01T00:00:00Z c1'
  elif echo "$2" | grep -q "/branches/tip_moved$"; then echo 'c_new'
  elif echo "$2" | grep -q "/pulls.*tip_moved"; then echo '2 closed true 2023-01-01T00:00:00Z c_old'
  elif echo "$2" | grep -q "/branches/closed_30_days_ago$"; then echo 'c3'
  elif echo "$2" | grep -q "/pulls.*closed_30_days_ago"; then echo '3 closed false 2000-01-01T00:00:00Z c3'
  elif echo "$2" | grep -q "/branches/closed_today$"; then echo 'c4'
  elif echo "$2" | grep -q "/pulls.*closed_today"; then
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "4 closed false $now c4"
  elif echo "$2" | grep -q "/branches/open_pr$"; then echo 'c5'
  elif echo "$2" | grep -q "/pulls.*open_pr"; then echo '5 open false - c5'
  elif echo "$2" | grep -q "/branches/no_pr$"; then echo 'c6'
  elif echo "$2" | grep -q "/pulls.*no_pr"; then echo ''
  elif echo "$2" | grep -q "/branches/with/slash$"; then echo 'c7'
  elif echo "$2" | grep -q "/pulls.*with/slash"; then echo ''
  elif echo "$2" | grep -q "/branches/merged/slash$"; then echo 'c8'
  elif echo "$2" | grep -q "/pulls.*merged/slash"; then echo '8 closed true 2023-01-01T00:00:00Z c8'
  fi
fi
FAKEGH
chmod +x "$TMPDIR/gh"
export PATH="$TMPDIR:$PATH"
export FAKEGH_LOG="$TMPDIR/deleted.log"

# Test 1: standard list
OUT=$(sh "$SCRIPT")
echo "$OUT" | grep -q "prune   merged_unchanged (merged PR #1)" || { echo "FAIL: merged_unchanged"; exit 1; }
echo "$OUT" | grep -q "keep    tip_moved (tip moved after PR #2)" || { echo "FAIL: tip_moved"; exit 1; }
echo "$OUT" | grep -q "prune   closed_30_days_ago (closed PR #3)" || { echo "FAIL: closed_30_days_ago"; exit 1; }
echo "$OUT" | grep -q "keep    closed_today (PR #4 closed 0d ago (< 7d))" || { echo "FAIL: closed_today"; exit 1; }
echo "$OUT" | grep -q "keep    open_pr (open PR #5)" || { echo "FAIL: open_pr"; exit 1; }
echo "$OUT" | grep -q "keep    no_pr (no PR)" || { echo "FAIL: no_pr"; exit 1; }
echo "$OUT" | grep -q "keep    with/slash (no PR)" || { echo "FAIL: with/slash"; exit 1; }
echo "$OUT" | grep -q "prune   merged/slash (merged PR #8)" || { echo "FAIL: merged/slash"; exit 1; }
[ ! -s "$FAKEGH_LOG" ] || { echo "FAIL: dry run issued a DELETE"; exit 1; }

# Test 2: --closed-days 0
OUT=$(sh "$SCRIPT" --closed-days 0)
echo "$OUT" | grep -q "prune   closed_today (closed PR #4)" || { echo "FAIL: --closed-days 0 didn't prune closed_today"; exit 1; }

# Test 3: --apply deletes exactly the rows marked prune (whole-set equality on the DELETE targets).
: > "$FAKEGH_LOG"
sh "$SCRIPT" --apply > /dev/null
want=$(printf '%s\n' closed_30_days_ago merged/slash merged_unchanged | sed 's|^|repos/dayfine/trading/git/refs/heads/|' | LC_ALL=C sort)
got=$(LC_ALL=C sort "$FAKEGH_LOG")
[ "$got" = "$want" ] || { printf 'FAIL: --apply DELETE targets\nwant:\n%s\ngot:\n%s\n' "$want" "$got"; exit 1; }

# Test 4: bad arg -> exit 2
set +e
sh "$SCRIPT" --bad 2>/dev/null
rc=$?
set -e
[ $rc -eq 2 ] || { echo "FAIL: bad arg exited with $rc, expected 2"; exit 1; }

echo "OK"
