#!/bin/sh
# Exercise the workflow's actual REST fragment with no GitHub or Git writes.
set -eu
ROOT=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
awk '/# REST publication:/ {copy=1} copy {sub(/^          /, ""); print}' \
  "$ROOT/.github/workflows/weekly-start-sweep.yml" > "$TMP/fragment.sh"
test -s "$TMP/fragment.sh"
cat > "$TMP/curl" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" > "$CAPTURE_ARGS"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --data ]; then printf '%s' "$2" > "$CAPTURE_PAYLOAD"; shift; fi
  shift
done
printf '%s' "$REPLY"
exit "$CURL_RC"
EOF
chmod +x "$TMP/curl"
PATH="$TMP:$PATH"
CAPTURE_ARGS="$TMP/args" CAPTURE_PAYLOAD="$TMP/payload"
DATE=2026-09-16 BRANCH=ops/weekly-start-sweep-2026-09-16
# Literal JSON-input fixture, not shell arguments to be evaluated.
# shellcheck disable=SC2089
BODY='Quoted "report" with a backslash \
and another line.'
REPO=dayfine/trading GH_TOKEN=fixture-token
# shellcheck disable=SC2090
export PATH CAPTURE_ARGS CAPTURE_PAYLOAD DATE BRANCH BODY REPO GH_TOKEN
total=0
fails=0
check() {
  total=$((total + 1))
  if "$@"; then :; else echo "FAIL: $*"; fails=$((fails + 1)); fi
}
run() {
  export REPLY CURL_RC
  rc=0
  bash -e -o pipefail "$TMP/fragment.sh" > "$TMP/out" 2> "$TMP/err" || rc=$?
}
CURL_RC=0 REPLY='{"number":42,"html_url":"https://github.com/dayfine/trading/pull/42"}'
run
check test "$rc" -eq 0
check grep -qx 'https://github.com/dayfine/trading/pull/42' "$TMP/out"
check jq -e --arg body "$BODY" --arg head "$BRANCH" --arg title "ops(sweep): weekly-start BAH SPY $DATE" \
  '.body == $body and .head == $head and .title == $title and .base == "main"' "$CAPTURE_PAYLOAD"
check grep -qx -- '-fsS' "$CAPTURE_ARGS"
check grep -qx 'POST' "$CAPTURE_ARGS"
check grep -qx 'Authorization: Bearer fixture-token' "$CAPTURE_ARGS"
check grep -qx 'https://api.github.com/repos/dayfine/trading/pulls' "$CAPTURE_ARGS"
for CURL_RC in 22 6; do
  run
  check test "$rc" -ne 0
done
CURL_RC=0
for REPLY in '{}' 'not-json' '{"number":42}' '{"number":0,"html_url":"https://github.com/x"}'; do
  run
  check test "$rc" -ne 0
done
printf '%s/%s checks passed\n' "$((total - fails))" "$total"
test "$fails" -eq 0
