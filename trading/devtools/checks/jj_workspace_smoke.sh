#!/bin/sh
# Smoke test: pin the runtime semantics of the jj workspace add boilerplate
# used in every jj-writing agent's ## Pre-Work Setup section.
#
# Mirrors the exact boilerplate from feat-agent-template.md:
#   AGENT_ID="${HOSTNAME}-$$-$(date +%s)"
#   AGENT_WS="/tmp/agent-ws-${AGENT_ID}"
#   jj workspace add "$AGENT_WS" --name "$AGENT_ID" -r main@origin
#
# If a future jj version changes the syntax of `jj workspace add` or
# `jj workspace list`, this test catches it in CI rather than silently
# breaking agent dispatches at runtime.
#
# Skips cleanly when jj is not on PATH (GHA runners don't have jj installed).

set -e

. "$(dirname "$0")/_check_lib.sh"

LABEL="jj_workspace_smoke"

# --- Skip if jj is not available ---
if ! command -v jj >/dev/null 2>&1; then
  echo "OK: ${LABEL} — SKIPPED (jj not on PATH)."
  exit 0
fi

REPO="$(repo_root)"

# Verify we are inside a jj repo; if not, skip gracefully.
if ! jj -R "$REPO" root >/dev/null 2>&1; then
  echo "OK: ${LABEL} — SKIPPED (repo root is not a jj repo)."
  exit 0
fi

# --- Generate a unique workspace ID (mirrors the agent boilerplate) ---
AGENT_ID="smoke-$$-$(date +%s)"
AGENT_WS="/tmp/agent-ws-${AGENT_ID}"

# Ensure cleanup on exit, success or failure
cleanup() {
  # Forget the workspace from jj's perspective (ignore errors — may already be cleaned)
  jj -R "$REPO" workspace forget "$AGENT_ID" >/dev/null 2>&1 || true
  rm -rf "$AGENT_WS"
}
trap cleanup EXIT INT TERM

# --- Step 1: exec the canonical boilerplate ---
if ! jj -R "$REPO" workspace add "$AGENT_WS" --name "$AGENT_ID" -r "main@origin" >/dev/null 2>&1; then
  echo "FAIL: ${LABEL} — 'jj workspace add \$AGENT_WS --name \$AGENT_ID -r main@origin' failed."
  echo "  This means the boilerplate in feat-agent-template.md ## Pre-Work Setup is broken."
  exit 1
fi

# --- Step 2: assert jj workspace list shows the new entry ---
WS_LIST=$(jj -R "$REPO" workspace list 2>&1)
if ! echo "$WS_LIST" | grep -qF "$AGENT_ID"; then
  echo "FAIL: ${LABEL} — 'jj workspace list' does not include '$AGENT_ID' after workspace add."
  echo "  workspace list output:"
  echo "$WS_LIST" | sed 's/^/    /'
  exit 1
fi

# --- Step 3: cleanup (done via trap, but verify forget works explicitly) ---
if ! jj -R "$REPO" workspace forget "$AGENT_ID" >/dev/null 2>&1; then
  echo "FAIL: ${LABEL} — 'jj workspace forget $AGENT_ID' failed."
  exit 1
fi
rm -rf "$AGENT_WS"

# Disarm the trap (already cleaned up manually)
trap - EXIT INT TERM

echo "OK: ${LABEL} — boilerplate exec + workspace_list + cleanup all passed."
