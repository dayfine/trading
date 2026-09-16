#!/bin/sh
# Offline: real local Git repository, with push intercepted to capture argv.
set -eu
. "$(dirname "$0")/_check_lib.sh"
SCRIPT="$(repo_root)/dev/scripts/codex_push.sh"
REAL_GIT=$(command -v git)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir "$TMP/bin" "$TMP/repo"
PUSH_CAPTURE="$TMP/push"
export REAL_GIT PUSH_CAPTURE
cat > "$TMP/bin/git" <<'EOF'
#!/bin/sh
if [ "$1" = push ]; then
  printf '%s\n' "$@" > "$PUSH_CAPTURE"
  exit "${MOCK_PUSH_RC:-0}"
fi
exec "$REAL_GIT" "$@"
EOF
chmod +x "$TMP/bin/git"
PATH="$TMP/bin:$PATH"
export PATH
cd "$TMP/repo"
git init -q -b fixture-base
git -c user.name=Fixture -c user.email=fixture@example.com commit -qm seed --allow-empty
git checkout -qb codex/x-y
total=0
fails=0
check() {
  total=$((total + 1))
  if "$@"; then :; else printf 'FAIL: %s\n' "$*"; fails=$((fails + 1)); fi
}
run() {
  : > "$PUSH_CAPTURE"
  rc=0
  sh "$SCRIPT" "$@" > "$TMP/out" 2> "$TMP/err" || rc=$?
}
CODEX_PUSH_DRY_RUN=1
export CODEX_PUSH_DRY_RUN
run
check test "$rc" -eq 0
check grep -qx 'git push -u origin HEAD:refs/heads/codex/x-y' "$TMP/out"
check test ! -s "$PUSH_CAPTURE"
CODEX_PUSH_DRY_RUN=0
# Configured upstream must not choose the destination.
git config branch.codex/x-y.remote origin
git config branch.codex/x-y.merge refs/heads/main
run
check test "$rc" -eq 0
printf '%s\n' push -u origin HEAD:refs/heads/codex/x-y > "$TMP/expected"
check cmp -s "$TMP/expected" "$PUSH_CAPTURE"
MOCK_PUSH_RC=7
export MOCK_PUSH_RC
run
check test "$rc" -eq 7
MOCK_PUSH_RC=0
run HEAD:main
check test "$rc" -ne 0
check test ! -s "$PUSH_CAPTURE"
git checkout -qb main
run
check test "$rc" -ne 0
check test ! -s "$PUSH_CAPTURE"
git checkout -q --detach
run
check test "$rc" -ne 0
check test ! -s "$PUSH_CAPTURE"
printf '%s/%s checks passed\n' "$((total-fails))" "$total"
test "$fails" -eq 0
