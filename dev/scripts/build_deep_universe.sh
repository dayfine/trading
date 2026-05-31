#!/usr/bin/env bash
# build_deep_universe.sh — rebuild the 2000-2026 deep-history dataset end-to-end.
#
# WHY THIS EXISTS
#   The 27-year deep backtest (dot-com bust + GFC) is the load-bearing
#   macro-regime cell of every promotion-confirmation grid
#   (.claude/rules/promotion-confirmation.md). Its bar data is huge and
#   deliberately NOT committed (survivorship-biased deep bars would bloat the
#   repo). This script rebuilds that data from the ONE committed seed — the
#   point-in-time 2000 S&P 500 snapshot — so the deep capability is a
#   one-command rebuild rather than load-bearing uncommitted worktree state.
#
#   Pairs with the `fetch-historical-data` skill (the manual workflow this
#   automates) and memory/project_gspc_index_golden_2017_floor (the data-floor
#   failure mode the validation step guards against).
#
# WHAT IT BUILDS (into --data-dir, NONE of it committed)
#   1. Per-symbol EODHD bars 1999-2026 for the 515 names in the 2000 snapshot,
#      INCLUDING delistings (LEH/BS/YHOO/...) at their real death dates — the
#      survivorship-bias guard.
#   2. The GSPC.INDX index golden extended back to 1999 (the macro gate needs
#      index coverage spanning the window, else early folds silently zero-trade).
#
# WHAT IS ALREADY COMMITTED (the seed — survives any worktree wipe)
#   trading/test_data/backtest_scenarios/universes/sp500-historical/sp500-2000-01-01.sexp
#   trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2000-2026.sexp
#
# USAGE
#   EODHD_API_KEY=... dev/scripts/build_deep_universe.sh                 # full rebuild
#   EODHD_API_KEY=... dev/scripts/build_deep_universe.sh --probe-only    # Phase-1 audit only
#   dev/scripts/build_deep_universe.sh --data-dir /tmp/deep-data --from 1999-01-01
#
# ENVIRONMENT
#   EODHD_API_KEY   required (or the secrets file below). The container env does
#                   NOT carry it — run on the host or pass it in.
#
# DO NOT COMMIT the bars or the extended GSPC golden this produces. They are an
# experiment input, rebuildable via this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

DATA_DIR="${TRADING_DATA_DIR:-${REPO_ROOT}/trading/test_data}"
SNAPSHOT="${REPO_ROOT}/trading/test_data/backtest_scenarios/universes/sp500-historical/sp500-2000-01-01.sexp"
SECRETS_FILE="${REPO_ROOT}/trading/analysis/data/sources/eodhd/secrets"
FROM="1999-01-01"
TO="2026-05-31"
PARALLELISM=8
PROBE_ONLY=0
MIN_ROWS=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-dir)    DATA_DIR="$2"; shift 2 ;;
    --snapshot)    SNAPSHOT="$2"; shift 2 ;;
    --from)        FROM="$2"; shift 2 ;;
    --to)          TO="$2"; shift 2 ;;
    --parallel)    PARALLELISM="$2"; shift 2 ;;
    --probe-only)  PROBE_ONLY=1; shift ;;
    -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

BASE_URL="https://eodhd.com/api/eod"

# --- token resolution: env first, then gitignored secrets file -------------
TOKEN="${EODHD_API_KEY:-}"
if [[ -z "${TOKEN}" && -f "${SECRETS_FILE}" ]]; then
  TOKEN="$(tr -d '[:space:]' < "${SECRETS_FILE}")"
fi
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: EODHD_API_KEY not set and ${SECRETS_FILE} absent." >&2
  exit 1
fi

# EODHD ticker for an equity: dots -> dashes, suffix .US (BRK.B -> BRK-B.US).
# The CSV-store symbol keeps the dashed form (repo convention).
_eodhd_ticker() { echo "${1//./-}.US"; }
_store_sym()    { echo "${1//./-}"; }

# CSV-store path: <data_dir>/<first char>/<last char>/<SYM>/data.csv
_store_path() {
  local sym="$1"
  local first="${sym:0:1}"
  local last="${sym: -1}"
  echo "${DATA_DIR}/${first}/${last}/${sym}/data.csv"
}

# Fetch one EODHD ticker over [FROM,TO]; emit CSV body with lowercased header
# on stdout. Empty stdout on miss/404.
_fetch_csv() {
  local ticker="$1"
  curl -s -m 30 \
    "${BASE_URL}/${ticker}?api_token=${TOKEN}&fmt=csv&from=${FROM}&to=${TO}&period=d" \
    | awk 'NR==1 { print tolower($0); next } /^[12][0-9]{3}-/ { print }'
}

# =====================================================================
# Phase 1 — availability probe (survivors + delistings). The load-bearing
# check: if EODHD has dropped the delisted names, the deep universe would be
# survivorship-biased and the rebuild is not worth running.
# =====================================================================
echo "=== Phase 1: availability probe ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
PROBE_FAIL=0
# Survivors confirm the date floor; delistings prove retained dead bars.
for spec in "AAPL:survivor" "GE:survivor" "LEH:delisting~2008-09" "BS:delisting~2004-01" "YHOO:delisting~2017-06"; do
  sym="${spec%%:*}"; kind="${spec#*:}"
  body="$(_fetch_csv "$(_eodhd_ticker "${sym}")")"
  rows="$(echo "${body}" | grep -cE '^[12][0-9]{3}-' || true)"
  first="$(echo "${body}" | grep -E '^[12][0-9]{3}-' | head -1 | cut -d, -f1 || true)"
  last="$(echo "${body}"  | grep -E '^[12][0-9]{3}-' | tail -1 | cut -d, -f1 || true)"
  printf '  %-6s %-18s rows=%-5s first=%s last=%s\n' "${sym}" "${kind}" "${rows}" "${first:-NONE}" "${last:-NONE}"
  if [[ "${rows}" -lt 100 ]]; then
    echo "    !! ${sym} returned <100 rows — coverage suspect" >&2
    PROBE_FAIL=1
  fi
done
if [[ "${PROBE_FAIL}" -ne 0 ]]; then
  echo "ABORT: Phase-1 probe failed — vendor coverage insufficient (survivorship risk)." >&2
  exit 2
fi
echo "Phase 1 OK."
[[ "${PROBE_ONLY}" -eq 1 ]] && { echo "--probe-only: stopping after Phase 1."; exit 0; }

# =====================================================================
# Phase 2 — symbol list from the committed point-in-time snapshot.
# =====================================================================
if [[ ! -f "${SNAPSHOT}" ]]; then
  echo "ERROR: snapshot not found: ${SNAPSHOT}" >&2
  exit 1
fi
mapfile -t SYMS < <(grep -oE '\(symbol [A-Za-z0-9.-]+\)' "${SNAPSHOT}" \
  | sed 's/(symbol //; s/)//' | sort -u)
echo "=== Phase 2: ${#SYMS[@]} symbols from $(basename "${SNAPSHOT}") ==="

# =====================================================================
# Phase 3 — bulk fetch into the CSV store, PARALLELISM at a time.
# =====================================================================
echo "=== Phase 3: fetch ${FROM}..${TO} (parallel=${PARALLELISM}) ==="
RESULT_LOG="$(mktemp)"
trap 'rm -f "${RESULT_LOG}"' EXIT

_fetch_one() {
  local raw="$1" sym body rows path
  sym="$(_store_sym "${raw}")"
  body="$(_fetch_csv "$(_eodhd_ticker "${raw}")")"
  rows="$(echo "${body}" | grep -cE '^[12][0-9]{3}-' || true)"
  if [[ "${rows}" -lt "${MIN_ROWS}" ]]; then
    echo "MISS ${sym} rows=${rows}"
    return 0
  fi
  path="$(_store_path "${sym}")"
  mkdir -p "$(dirname "${path}")"
  echo "${body}" > "${path}"
  echo "OK ${sym} rows=${rows} first=$(echo "${body}" | sed -n '2p' | cut -d, -f1)"
}
export -f _fetch_one _fetch_csv _eodhd_ticker _store_sym _store_path
export BASE_URL TOKEN FROM TO DATA_DIR MIN_ROWS

printf '%s\n' "${SYMS[@]}" \
  | xargs -P "${PARALLELISM}" -I {} bash -c '_fetch_one "$@"' _ {} \
  | tee "${RESULT_LOG}"

# =====================================================================
# Phase 4 — extend the GSPC.INDX index golden back to FROM (prepend the
# rows earlier than the existing golden's floor; keep the committed bytes).
# =====================================================================
echo "=== Phase 4: extend GSPC.INDX index golden to ${FROM} ==="
GSPC_PATH="${DATA_DIR}/G/X/GSPC.INDX/data.csv"
GSPC_FLOOR="$(sed -n '2p' "${GSPC_PATH}" 2>/dev/null | cut -d, -f1 || true)"
GSPC_NEW="$(_fetch_csv "GSPC.INDX")"   # index ticker keeps its dotted form
if [[ -z "${GSPC_NEW}" ]]; then
  echo "  WARN: GSPC.INDX fetch empty — leaving golden as-is" >&2
elif [[ -z "${GSPC_FLOOR}" ]]; then
  mkdir -p "$(dirname "${GSPC_PATH}")"
  echo "${GSPC_NEW}" > "${GSPC_PATH}"
  echo "  wrote fresh GSPC golden ($(echo "${GSPC_NEW}" | grep -cE '^[12][0-9]{3}-' || true) rows)"
else
  # Prepend fetched rows strictly earlier than the existing floor; dedupe.
  {
    echo "${GSPC_NEW}" | head -1 || true                          # header
    echo "${GSPC_NEW}" | awk -F, -v floor="${GSPC_FLOOR}" '/^[12][0-9]{3}-/ && $1 < floor'
    tail -n +2 "${GSPC_PATH}"
  } > "${GSPC_PATH}.tmp" && mv "${GSPC_PATH}.tmp" "${GSPC_PATH}"
  echo "  prepended GSPC rows < ${GSPC_FLOOR}; golden now starts $(sed -n '2p' "${GSPC_PATH}" | cut -d, -f1)"
fi

# =====================================================================
# Phase 5 — validate. Coverage + the survivorship re-confirmation.
# =====================================================================
echo "=== Phase 5: validate ==="
OK_N="$(grep -c '^OK ' "${RESULT_LOG}" || true)"
MISS_N="$(grep -c '^MISS ' "${RESULT_LOG}" || true)"
echo "  fetched OK=${OK_N}  MISS=${MISS_N}  / ${#SYMS[@]}"
if [[ "${MISS_N}" -gt 0 ]]; then
  echo "  misses:"; grep '^MISS ' "${RESULT_LOG}" | sed 's/^/    /'
fi
echo "  delisting re-confirmation (must land at real death dates):"
for spec in "LEH:2008-09" "BS:2004-01" "YHOO:2017-06"; do
  sym="${spec%%:*}"; want="${spec#*:}"
  p="$(_store_path "$(_store_sym "${sym}")")"
  if [[ -f "${p}" ]]; then
    last="$(tail -1 "${p}" | cut -d, -f1)"
    mark="ok"; [[ "${last}" == "${want}"* ]] || mark="CHECK"
    printf '    %-6s last=%s (want ~%s) %s\n' "${sym}" "${last}" "${want}" "${mark}"
  else
    printf '    %-6s MISSING from store\n' "${sym}"
  fi
done

echo ""
echo "Deep dataset ready under ${DATA_DIR}."
echo "Next: run the deep grid via the ea-deep spec (see project_promotion_confirmation_grid)."
echo "REMINDER: do NOT commit these bars or the extended GSPC golden."
