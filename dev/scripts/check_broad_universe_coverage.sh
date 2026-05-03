#!/usr/bin/env bash
# check_broad_universe_coverage.sh — report data-completeness for the
# broad universe (data/sectors.csv vs data/<L1>/<L2>/<sym>/data.csv).
#
# Usage:
#   check_broad_universe_coverage.sh [--data-dir <path>] [--sectors <path>] [--quiet]
#                                    [--threshold-pct <N>] [--list-missing]
#
# Flags:
#   --data-dir <path>      Root of the bar-data tree (default: data)
#   --sectors <path>       Sectors CSV (default: data/sectors.csv)
#   --threshold-pct N      Exit non-zero if coverage < N% (default: 0 = always 0)
#   --list-missing         Print every missing symbol (vs default summary)
#   --quiet                Suppress per-section headers; print summary only
#
# Output (stdout): summary line of the form
#   broad-universe-coverage: <have>/<total> = <pct>% (missing <N>)
#
# Exit codes:
#   0    coverage ≥ threshold-pct (or threshold not enforced)
#   1    coverage < threshold-pct
#   2    setup error (sectors.csv missing, data dir missing, etc)
#
# Use cases:
#   - Pre-flight before running tier-4 release-gate scenarios at full broad
#     universe (`dev/scripts/run_tier4_release_gate.sh`)
#   - Surface gaps for ops-data dispatch (which symbols need fetching)
#   - Document baseline coverage in `dev/notes/broad-universe-coverage-*.md`

set -euo pipefail

data_dir="data"
sectors_csv=""
threshold_pct=0
list_missing=false
quiet=false

while [ $# -gt 0 ]; do
  case "$1" in
    --data-dir)        data_dir="$2"; shift 2 ;;
    --sectors)         sectors_csv="$2"; shift 2 ;;
    --threshold-pct)   threshold_pct="$2"; shift 2 ;;
    --list-missing)    list_missing=true; shift ;;
    --quiet)           quiet=true; shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "[check-broad-coverage] unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$sectors_csv" ]; then
  sectors_csv="$data_dir/sectors.csv"
fi

if [ ! -f "$sectors_csv" ]; then
  echo "[check-broad-coverage] sectors CSV not found: $sectors_csv" >&2
  exit 2
fi
if [ ! -d "$data_dir" ]; then
  echo "[check-broad-coverage] data dir not found: $data_dir" >&2
  exit 2
fi

# Skip header; cut symbol column; strip CR if present.
symbols=$(tail -n +2 "$sectors_csv" | cut -d',' -f1 | tr -d '\r')
total=$(printf '%s\n' "$symbols" | wc -l | tr -d ' ')

if [ "$total" -eq 0 ]; then
  echo "[check-broad-coverage] sectors CSV empty"
  exit 2
fi

have=0
missing_list=""

# Probe each symbol using the storage module path convention:
#   data_dir/<first_char>/<last_char>/<symbol>/data.csv
# See csv_storage.ml: symbol_data_dir uses String.get 0 and String.get (len-1).
# Dot-notation symbols (BF.A, BRK.B) are also checked with dots replaced by
# dashes (BF-A, BRK-B) since EODHD returns dash-form for dual-class shares.
while IFS= read -r sym; do
  [ -z "$sym" ] && continue
  l1=$(printf '%s' "$sym" | cut -c1)
  sym_len=${#sym}
  l2=$(printf '%s' "$sym" | cut -c"${sym_len}")

  csv_path="$data_dir/$l1/$l2/$sym/data.csv"

  found=false
  if [ -f "$csv_path" ]; then
    found=true
  else
    # dot-notation fallback: also check dash form (e.g. BF.A -> BF-A)
    sym_dash=$(printf '%s' "$sym" | tr '.' '-')
    if [ "$sym_dash" != "$sym" ]; then
      sym_dash_len=${#sym_dash}
      l2d=$(printf '%s' "$sym_dash" | cut -c"${sym_dash_len}")
      dash_path="$data_dir/$l1/$l2d/$sym_dash/data.csv"
      [ -f "$dash_path" ] && found=true
    fi
  fi

  if [ "$found" = "true" ]; then
    have=$((have + 1))
  else
    if [ "$list_missing" = "true" ]; then
      missing_list="$missing_list$sym\n"
    fi
  fi
done <<EOF
$symbols
EOF

missing=$((total - have))
pct=$(awk -v h="$have" -v t="$total" 'BEGIN { printf "%.2f", (h * 100.0) / t }')

if [ "$quiet" != "true" ]; then
  echo "[check-broad-coverage] sectors=$sectors_csv data_dir=$data_dir"
fi

if [ "$list_missing" = "true" ] && [ -n "$missing_list" ]; then
  echo "[check-broad-coverage] missing symbols ($missing):"
  printf '%b' "$missing_list" | sort | head -50
  if [ "$missing" -gt 50 ]; then
    echo "  ... (+$((missing - 50)) more)"
  fi
fi

echo "broad-universe-coverage: $have/$total = ${pct}% (missing $missing)"

# Threshold gate
if [ "$threshold_pct" -gt 0 ]; then
  meets=$(awk -v p="$pct" -v t="$threshold_pct" 'BEGIN { print (p+0 >= t+0) ? "yes" : "no" }')
  if [ "$meets" != "yes" ]; then
    echo "[check-broad-coverage] FAIL: coverage ${pct}% < threshold ${threshold_pct}%" >&2
    exit 1
  fi
fi

exit 0
