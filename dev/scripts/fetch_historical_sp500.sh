#!/usr/bin/env bash
# fetch_historical_sp500.sh — bulk-fetch EODHD bars for sp500 historical universe symbols.
#
# For each symbol in the target list:
#   1. Fetch plain <sym> first.
#   2. If plain ticker has no pre-2014 data (indicating ticker reassignment), also fetch
#      <sym>_old. EODHD uses the _old suffix when a ticker was reused by a different company
#      after the original was delisted/merged (e.g. APC -> Anadarko Petroleum via APC_old;
#      APC plain is a different, newer company).
#   3. Log: FETCHED_PLAIN / FETCHED_OLD / UNFETCHABLE per symbol.
#
# Usage:
#   dev/scripts/fetch_historical_sp500.sh [--symbols A,B,C] [--data-dir /path/to/data]
#
# Environment:
#   EODHD_API_KEY must be set.
#
# Typical use: run after generating a historical sp500 universe sexp to populate
# bar data for all delisted/acquired/renamed symbols.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FETCH_EXE="${REPO_ROOT}/trading/_build/default/analysis/scripts/fetch_symbols/fetch_symbols.exe"
RUN_IN_ENV="${REPO_ROOT}/dev/lib/run-in-env.sh"
DATA_DIR="${REPO_ROOT}/data"
SYMBOLS_FILE="${REPO_ROOT}/dev/scripts/sp500_historical_missing.txt"

SPECIFIC_SYMBOLS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --symbols)  SPECIFIC_SYMBOLS="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *)          echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${EODHD_API_KEY:-}" ]]; then
  echo "ERROR: EODHD_API_KEY not set" >&2; exit 1
fi

API_KEY="$EODHD_API_KEY"
BASE_URL="https://eodhd.com/api/eod"

# Count bars before 2014-01-01 for a given symbol (proxy for historical depth)
_bars_before_2014() {
  local sym="$1"
  local result
  result=$(curl -s --max-time 15 \
    "${BASE_URL}/${sym}?api_token=${API_KEY}&fmt=json&from=2000-01-01&to=2013-12-31" \
    2>/dev/null) || true
  echo "$result" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data) if isinstance(data, list) else 0)
except Exception:
    print(0)
" 2>/dev/null || echo "0"
}

_fetch_sym() {
  local sym="$1"
  "${RUN_IN_ENV}" "${FETCH_EXE}" \
    -symbols "${sym}" \
    -data-dir "${DATA_DIR}" \
    -api-key "${API_KEY}" 2>&1
}

# Build symbol list
if [[ -n "$SPECIFIC_SYMBOLS" ]]; then
  IFS=',' read -ra SYMS <<< "$SPECIFIC_SYMBOLS"
elif [[ -f "$SYMBOLS_FILE" ]]; then
  mapfile -t SYMS < "$SYMBOLS_FILE"
else
  echo "ERROR: no symbols specified and $SYMBOLS_FILE not found" >&2; exit 1
fi

TOTAL=${#SYMS[@]}
FETCHED_PLAIN=0
FETCHED_OLD=0
UNFETCHABLE=0
UNFETCHABLE_LIST=()

echo "=== sp500 historical bulk-fetch $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo "Total symbols: $TOTAL"
echo ""

for SYM in "${SYMS[@]}"; do
  SYM="${SYM// /}"
  [[ -z "$SYM" ]] && continue

  echo -n "[$SYM] checking pre-2014 depth ... "
  BARS_PRE2014=$(_bars_before_2014 "$SYM")

  if [[ "$BARS_PRE2014" -gt 0 ]]; then
    echo "plain ticker has ${BARS_PRE2014} pre-2014 bars — fetching plain"
    _fetch_sym "$SYM"
    FETCHED_PLAIN=$((FETCHED_PLAIN + 1))
  else
    OLD_SYM="${SYM}_old"
    echo "plain ticker empty pre-2014 — trying ${OLD_SYM}"
    BARS_OLD=$(_bars_before_2014 "$OLD_SYM")
    if [[ "$BARS_OLD" -gt 0 ]]; then
      echo "  [${OLD_SYM}] has ${BARS_OLD} pre-2014 bars — fetching _old"
      _fetch_sym "$OLD_SYM"
      FETCHED_OLD=$((FETCHED_OLD + 1))
    else
      BARS_TOTAL=$(curl -s --max-time 15 \
        "${BASE_URL}/${SYM}?api_token=${API_KEY}&fmt=json&from=2000-01-01&to=2026-04-30" \
        2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(len(data) if isinstance(data, list) else 0)
except Exception:
    print(0)
" 2>/dev/null || echo "0")
      if [[ "$BARS_TOTAL" -gt 0 ]]; then
        echo "  [${SYM}] has ${BARS_TOTAL} total bars (no pre-2014) — fetching plain (partial)"
        _fetch_sym "$SYM"
        FETCHED_PLAIN=$((FETCHED_PLAIN + 1))
      else
        echo "  UNFETCHABLE: ${SYM} — 404 or empty on both plain and _old"
        UNFETCHABLE=$((UNFETCHABLE + 1))
        UNFETCHABLE_LIST+=("$SYM")
      fi
    fi
  fi
done

echo ""
echo "=== Summary ==="
echo "Fetched (plain): $FETCHED_PLAIN"
echo "Fetched (_old):  $FETCHED_OLD"
echo "Unfetchable:     $UNFETCHABLE"
if [[ ${#UNFETCHABLE_LIST[@]} -gt 0 ]]; then
  echo "Unfetchable symbols:"
  for s in "${UNFETCHABLE_LIST[@]}"; do echo "  - $s"; done
fi
