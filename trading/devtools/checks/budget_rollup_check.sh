#!/usr/bin/env bash
# Smoke test for dev/lib/budget_rollup.sh
#
# Uses temp-dir fixtures so it does not touch real dev/budget/ data.
# Wired into dune runtest via trading/devtools/checks/dune.
#
# Tests:
#   1. Single-record rollup emits expected table headers and columns
#   2. Multi-record rollup sums costs correctly
#   3. Empty range emits "No budget records" message (exit 0)
#   4. Missing dev/budget dir exits 0 with informative message
#   5. Invalid date argument exits 1
#   6. Zero records in range exits 0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ROLLUP="$REPO_ROOT/dev/lib/budget_rollup.sh"
PASS=0
FAIL=0

_pass() { PASS=$((PASS + 1)); echo "  OK: $1"; }
_fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# --- Fixture helpers ---

_make_record() {
  local dir="$1" run_id="$2" cost="$3" model="${4:-sonnet}"
  cat > "${dir}/${run_id}.json" <<EOF
{
  "run_id": "${run_id}",
  "timestamp": "2026-04-21T00:00:00Z",
  "commit_sha": "abc123",
  "measurement_source": "test fixture",
  "fallback_branch": "1b",
  "notes": "test",
  "subagents": [{"name": "test", "model": "${model}", "input_tokens": null, "output_tokens": null, "cache_read_input_tokens": null, "cache_creation_input_tokens": null, "estimated_cost_usd": null}],
  "totals": {"input_tokens": null, "output_tokens": null, "cache_read_input_tokens": null, "cache_creation_input_tokens": null, "total_cost_usd": ${cost}}
}
EOF
}

echo "budget_rollup_check — smoke tests"

# ---- Test 1: single record ----
TMPDIR1="$(mktemp -d)"
trap 'rm -rf "$TMPDIR1"' EXIT

_make_record "$TMPDIR1" "2026-04-21-run1" "1.50" "sonnet"

OUTPUT="$(REPO_ROOT_OVERRIDE="$TMPDIR1" bash "$ROLLUP" <<< "" 2>/dev/null || true)"
# Override: temporarily swap BUDGET_DIR by patching via env var — script uses REPO_ROOT
# We can't override easily without a second wrapper; instead call directly with modified REPO_ROOT.
# Trick: create a fake REPO_ROOT with the right structure.
FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR1" "$FAKE_ROOT"' EXIT
mkdir -p "${FAKE_ROOT}/dev/budget"
_make_record "${FAKE_ROOT}/dev/budget" "2026-04-21-run1" "1.50" "sonnet"

OUTPUT="$(REPO_ROOT="${FAKE_ROOT}" bash "$ROLLUP" 2>/dev/null || true)"

if printf '%s' "$OUTPUT" | grep -q "1.5000"; then
  _pass "single record: cost shown"
else
  _fail "single record: expected cost 1.5000 in output; got: $OUTPUT"
fi

if printf '%s' "$OUTPUT" | grep -q "| Run ID |"; then
  _pass "single record: table header present"
else
  _fail "single record: table header missing"
fi

if printf '%s' "$OUTPUT" | grep -q "TOTAL"; then
  _pass "single record: TOTAL row present"
else
  _fail "single record: TOTAL row missing"
fi

# ---- Test 2: multi-record, correct sum ----
FAKE2="$(mktemp -d)"
mkdir -p "${FAKE2}/dev/budget"
_make_record "${FAKE2}/dev/budget" "2026-04-21-run1" "1.00"
_make_record "${FAKE2}/dev/budget" "2026-04-21-run2" "2.50"
_make_record "${FAKE2}/dev/budget" "2026-04-22-run1" "0.75"

OUTPUT2="$(REPO_ROOT="${FAKE2}" bash "$ROLLUP" 2>/dev/null)"
if printf '%s' "$OUTPUT2" | grep -q "4.2500"; then
  _pass "multi-record: total sum correct (4.25)"
else
  _fail "multi-record: expected 4.2500 total; got: $OUTPUT2"
fi
rm -rf "$FAKE2"

# ---- Test 3: date range with no matches ----
FAKE3="$(mktemp -d)"
mkdir -p "${FAKE3}/dev/budget"
_make_record "${FAKE3}/dev/budget" "2026-04-21-run1" "1.00"

OUTPUT3="$(REPO_ROOT="${FAKE3}" bash "$ROLLUP" 2026-04-01 2026-04-10 2>/dev/null)"
if printf '%s' "$OUTPUT3" | grep -qi "no budget records"; then
  _pass "empty range: informative message"
else
  _fail "empty range: expected 'no budget records'; got: $OUTPUT3"
fi
rm -rf "$FAKE3"

# ---- Test 4: missing dev/budget dir ----
FAKE4="$(mktemp -d)"
# Don't create dev/budget/
OUTPUT4="$(REPO_ROOT="${FAKE4}" bash "$ROLLUP" 2>/dev/null)"
if printf '%s' "$OUTPUT4" | grep -qi "no budget records"; then
  _pass "missing dir: graceful exit 0"
else
  _fail "missing dir: expected 'no budget records'; got: $OUTPUT4"
fi
rm -rf "$FAKE4"

# ---- Test 5: invalid date exits 1 ----
FAKE5="$(mktemp -d)"
mkdir -p "${FAKE5}/dev/budget"
EXIT5=0
REPO_ROOT="${FAKE5}" bash "$ROLLUP" "not-a-date" 2>/dev/null || EXIT5=$?
if [ "$EXIT5" -eq 1 ]; then
  _pass "invalid date: exits 1"
else
  _fail "invalid date: expected exit 1; got $EXIT5"
fi
rm -rf "$FAKE5"

# ---- Test 6: single-date filter ----
FAKE6="$(mktemp -d)"
mkdir -p "${FAKE6}/dev/budget"
_make_record "${FAKE6}/dev/budget" "2026-04-21-run1" "1.11"
_make_record "${FAKE6}/dev/budget" "2026-04-22-run1" "2.22"

OUTPUT6="$(REPO_ROOT="${FAKE6}" bash "$ROLLUP" 2026-04-21 2>/dev/null)"
if printf '%s' "$OUTPUT6" | grep -q "1.1100" && ! printf '%s' "$OUTPUT6" | grep -q "2.2200"; then
  _pass "single-date filter: only matching date shown"
else
  _fail "single-date filter: expected only 1.1100; got: $OUTPUT6"
fi
rm -rf "$FAKE6"

# ---- Summary ----
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "OK: budget_rollup_check — all ${PASS} assertions passed."
  exit 0
else
  echo "FAIL: budget_rollup_check — ${FAIL} assertion(s) failed (${PASS} passed)."
  exit 1
fi
