#!/usr/bin/env bash
# build_sp500_universe.sh — join data/sp500.csv against the local bar-data
# inventory and emit trading/test_data/backtest_scenarios/universes/sp500.sexp.
#
# Selection logic:
#   1. Read data/sp500.csv (Symbol, Security, GICS Sector, ...) — 503 rows.
#   2. Normalise ticker symbols: replace "." with "-" (EODHD convention:
#      BF.B -> BF-B, BRK.B -> BRK-B).
#   3. Read data/inventory.sexp to build the set of symbols with cached bars.
#   4. Inner-join sp500 symbols against the inventory; emit only symbols that
#      have bar data.  Document any misses in the header comment.
#   5. Sort alphabetically by normalised symbol; emit Pinned sexp with sector.
#
# Output: writes the Pinned sexp to $OUT (default:
#   trading/test_data/backtest_scenarios/universes/sp500.sexp).
#   Pass a path argument to redirect elsewhere.
#
# Notes on symbol normalisation:
#   EODHD (and this repo's data/ cache) converts dots in ticker symbols to
#   dashes.  sp500.csv uses the exchange-native form (with dots).  This script
#   normalises for the join, but the sexp is written with the EODHD form so
#   that the backtest data loader can resolve CSV paths directly.
#
# Typical usage:
#   bash dev/scripts/build_sp500_universe.sh
#   bash dev/scripts/build_sp500_universe.sh /tmp/sp500-test.sexp
#
# To refresh after fetching new symbols:
#   dev/lib/run-in-env.sh ./_build/default/trading/analysis/scripts/build_inventory/build_inventory.exe \
#     --data-dir /workspaces/trading-1/data
#   bash dev/scripts/build_sp500_universe.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
DATA_DIR="${TRADING_DATA_DIR:-${REPO_ROOT}/data}"
SP500_CSV="${DATA_DIR}/sp500.csv"
INVENTORY_SEXP="${DATA_DIR}/inventory.sexp"
OUT="${1:-${REPO_ROOT}/trading/test_data/backtest_scenarios/universes/sp500.sexp}"

if [[ ! -f "${SP500_CSV}" ]]; then
  echo "ERROR: sp500.csv not found at ${SP500_CSV}" >&2
  exit 1
fi

if [[ ! -f "${INVENTORY_SEXP}" ]]; then
  echo "ERROR: inventory.sexp not found at ${INVENTORY_SEXP}" >&2
  echo "Run build_inventory.exe first." >&2
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_LOCAL}"' EXIT

# ---------------------------------------------------------------------------
# 1. Parse sp500.csv into (normalised_symbol, sector) pairs.
#    Normalise: replace "." with "-" (EODHD convention).
#    Use sector-name scanning to handle security names with embedded commas
#    (e.g. "F5, Inc.", "Tapestry, Inc.") which shift naive field indices.
# ---------------------------------------------------------------------------
tail -n +2 "${SP500_CSV}" \
  | awk -F',' '{
      sym = $1; gsub(/\./, "-", sym)
      sector = ""
      for (i = 2; i <= NF; i++) {
        if ($i == "Industrials" || $i == "Financials" || $i == "Materials" ||
            $i == "Energy" || $i == "Utilities" || $i == "Real Estate" ||
            $i == "Health Care" || $i == "Consumer Staples" ||
            $i == "Consumer Discretionary" || $i == "Information Technology" ||
            $i == "Communication Services") {
          sector = $i; break
        }
      }
      if (sector != "") print sym "\t" sector
    }' \
  | sort -k1,1 > "${TMPDIR_LOCAL}/sp500_norm.tsv"

total_sp500=$(wc -l < "${TMPDIR_LOCAL}/sp500_norm.tsv" | tr -d ' ')

# ---------------------------------------------------------------------------
# 2. Extract inventory symbols (normalised already — inventory uses dashes).
# ---------------------------------------------------------------------------
grep '(symbol ' "${INVENTORY_SEXP}" \
  | sed 's/.*symbol *//; s/).*//; s/ //g' \
  | sort -u > "${TMPDIR_LOCAL}/inventory_symbols.txt"

# ---------------------------------------------------------------------------
# 3. Inner-join: sp500 symbols present in inventory.
# ---------------------------------------------------------------------------
awk -F'\t' 'NR==FNR { inv[$1]=1; next } ($1 in inv) { print $0 }' \
  "${TMPDIR_LOCAL}/inventory_symbols.txt" "${TMPDIR_LOCAL}/sp500_norm.tsv" \
  | sort -t$'\t' -k1,1 > "${TMPDIR_LOCAL}/matched.tsv"

matched_count=$(wc -l < "${TMPDIR_LOCAL}/matched.tsv" | tr -d ' ')
missing_count=$(( total_sp500 - matched_count ))

# ---------------------------------------------------------------------------
# 4. Identify missing symbols (sp500 but not in inventory).
# ---------------------------------------------------------------------------
awk -F'\t' '{ print $1 }' "${TMPDIR_LOCAL}/sp500_norm.tsv" \
  > "${TMPDIR_LOCAL}/sp500_symbols.txt"
comm -23 \
  <(sort "${TMPDIR_LOCAL}/sp500_symbols.txt") \
  <(sort "${TMPDIR_LOCAL}/inventory_symbols.txt") \
  > "${TMPDIR_LOCAL}/missing.txt"

# ---------------------------------------------------------------------------
# 5. Emit Pinned sexp.
# ---------------------------------------------------------------------------
today=$(date +%Y-%m-%d)
{
  echo ";; S&P 500 universe — joined from data/sp500.csv against the local"
  echo ";; bar-data inventory under data/. Generated ${today} by"
  echo ";; dev/scripts/build_sp500_universe.sh."
  echo ";;"
  if [[ "${missing_count}" -eq 0 ]]; then
    echo ";; ${matched_count} / ${total_sp500} S&P 500 symbols have bar data."
  else
    echo ";; ${matched_count} / ${total_sp500} S&P 500 symbols have bar data;"
    echo ";; ${missing_count} missing from cache:"
    while IFS= read -r sym; do
      echo ";;   ${sym}"
    done < "${TMPDIR_LOCAL}/missing.txt"
    echo ";; Run fetch_symbols.exe for the missing symbols then re-run this script."
  fi
  echo ";;"
  echo ";; Symbol convention: dots replaced with dashes (EODHD: BF.B -> BF-B)."
  echo ";; Used by goldens-sp500/ scenarios as a regression-pinned trading +"
  echo ";; performance benchmark. The S&P 500 is a moving target — this"
  echo ";; snapshot is fixed at generation time so the golden trades are"
  echo ";; reproducible across reruns of the same scenario."
  echo "(Pinned ("
  awk -F'\t' '{ printf "  ((symbol %-7s) (sector \"%s\"))\n", $1, $2 }' \
    "${TMPDIR_LOCAL}/matched.tsv"
  echo "))"
} > "${OUT}"

echo "Wrote ${matched_count} symbols to ${OUT}" >&2
if [[ "${missing_count}" -gt 0 ]]; then
  echo "  ${missing_count} symbols missing from cache: $(cat "${TMPDIR_LOCAL}/missing.txt" | tr '\n' ' ')" >&2
fi
