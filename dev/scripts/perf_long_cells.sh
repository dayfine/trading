#!/bin/sh
# perf_long_cells.sh -- runtime ledger for LOCAL long backtest cells (5y / 26y
# chains). No GHA perf tier runs these shapes (the warehouses live in the
# container only), so each chain log is the only record of a cell's wall time.
# This script collects those records into one committed CSV and flags a cell
# that got slower than earlier cells of the same shape.
#
# usage:
#   sh dev/scripts/perf_long_cells.sh collect CHAIN_LOG...   # CSV rows to stdout (no header)
#   sh dev/scripts/perf_long_cells.sh update  CHAIN_LOG...   # merge into the ledger (dedupe on date+tag)
#   sh dev/scripts/perf_long_cells.sh check                  # exit 1 if the newest cell of any shape
#                                                            # is > PERF_LONG_TOLERANCE (default 20) %
#                                                            # slower per simulated year than the median
#                                                            # of that shape's earlier cells
#
# Input: a chain log whose cells end with the chain-template line
#   [MM-DD HH:MM:SS] RESULT <tag> => <metrics> ... (wall <N>s)
# plus optional header lines "HEAD=<sha>" and "SNAPSHOT_MAX_MMAP_HANDLES=<n>"
# (a chain that never logs the cap ran at the pre-#2882 default, 256).
# The cell's spec is found by name (<tag> minus "-s<salt>[-suffix]") under the
# chain log's experiment directory, or under PERF_LONG_SPECS if set; window
# and universe come from it. A cell whose spec cannot be found keeps "?" for
# both and never enters a comparison.
#
# Ledger: dev/status/perf-long-cells.csv (override: PERF_LONG_LEDGER), columns
#   date,experiment,tag,universe,years,cap,head,wall_s,s_per_year
# where date is the cell's RESULT timestamp (YYYY-MM-DDTHH:MM:SS; the year from
# PERF_LONG_YEAR, else the log's mtime, since chain logs stamp MM-DD only), so
# the ledger sorts in time order and "newest" means the latest run. Golden
# specs resolve under PERF_LONG_GOLDEN_SPECS (default: the scenario fixtures).
# shape = universe + rounded years + cap. <no result> / guard-killed cells are
# skipped: their wall is a timeout, not a runtime.
set -eu

REPO="$(cd "$(dirname "$0")/.." && cd .. && pwd)"
LEDGER="${PERF_LONG_LEDGER:-$REPO/dev/status/perf-long-cells.csv}"
TOL="${PERF_LONG_TOLERANCE:-20}"
HEADER="date,experiment,tag,universe,years,cap,head,wall_s,s_per_year"

# Experiment dir of a chain log: the dev/experiments/<exp> ancestor, else its own dir.
exp_dir() {
  d=$(cd "$(dirname "$1")" && pwd)
  case "$d" in
    */dev/experiments/*) printf '%s\n' "$d" | sed 's#\(/dev/experiments/[^/]*\).*#\1#' ;;
    *) printf '%s\n' "$d" ;;
  esac
}

# "<universe>,<years>" for a spec name, "?,?" when not found.
spec_shape() { # $1 search dir, $2 spec name
  f=$(grep -rlE "^\(\(name \"$2\"\)" "$1" --include='*.sexp' 2>/dev/null | head -1 || true)
  [ -n "$f" ] || { echo "?,?"; return; }
  awk '
    /start_date/ { match($0, /start_date [0-9-]+/); s = substr($0, RSTART + 11, 10) }
    /end_date/   { match($0, /end_date [0-9-]+/);   e = substr($0, RSTART + 9, 10) }
    /universe_schedule/ { sched = 1 }
    /\(universe_path/ { match($0, /"[^"]+"/); up = substr($0, RSTART + 1, RLENGTH - 2) }
    /\(universe_size/ { match($0, /universe_size [0-9]+/); us = substr($0, RSTART + 14, RLENGTH - 14) }
    END {
      if (s == "" || e == "") { print "?,?"; exit }
      y = (substr(e,1,4) - substr(s,1,4)) + (substr(e,6,2) - substr(s,6,2)) / 12 + (substr(e,9,2) - substr(s,9,2)) / 365
      n = split(up, p, "/"); u = p[n]; sub(/\.sexp$/, "", u)
      if (sched) u = "pit-schedule-" us
      printf "%s,%.2f\n", (u == "" ? "?" : u), y
    }' "$f"
}

collect_one() { # $1 chain log
  exp=$(exp_dir "$1"); name_exp=$(basename "$exp"); search=${PERF_LONG_SPECS:-$exp}
  # chain logs stamp MM-DD only; the year comes from PERF_LONG_YEAR, else the log mtime
  yr=${PERF_LONG_YEAR:-$(date -r "$1" +%Y 2>/dev/null || date +%Y)}
  awk '
    /HEAD=[0-9a-f]+/ { match($0, /HEAD=[0-9a-f]+/); head = substr($0, RSTART + 5, RLENGTH - 5) }
    /SNAPSHOT_MAX_MMAP_HANDLES=[0-9]+/ { match($0, /SNAPSHOT_MAX_MMAP_HANDLES=[0-9]+/); cap = substr($0, RSTART + 26, RLENGTH - 26) }
    /^\[[0-9][0-9]-[0-9][0-9] [0-9:]+\] RESULT / && /\(wall [0-9]+s\)/ && !/<no result>/ {
      md = substr($0, 2, 5); hms = substr($0, 8, 8)
      match($0, / RESULT [^ ]+/); tag = substr($0, RSTART + 8, RLENGTH - 8)
      match($0, /\(wall [0-9]+s\)/); w = substr($0, RSTART + 6, RLENGTH - 8)
      printf "%s\t%s\t%s\t%s\t%s\n", md "T" hms, tag, (cap == "" ? 256 : cap), (head == "" ? "?" : head), w
    }' "$1" | while IFS="$(printf '\t')" read -r md tag cap head w; do
    name=$(printf '%s\n' "$tag" | sed -E 's/-s[0-9]+(-.*)?$//')
    shape=$(spec_shape "$search" "$name")
    if [ "$shape" = "?,?" ]; then
      # golden cells are tagged <family>--<golden>-new|old; their specs are fixtures
      gname=$(printf '%s\n' "$name" | sed -E 's/^.*--//; s/-(new|old)$//')
      shape=$(spec_shape "${PERF_LONG_GOLDEN_SPECS:-$REPO/trading/test_data/backtest_scenarios}" "$gname")
    fi
    years=${shape#*,}
    spy=$(awk -v w="$w" -v y="$years" 'BEGIN { if (y + 0 > 0) printf "%.0f", w / y; else print "?" }')
    printf '%s-%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$yr" "$md" "$name_exp" "$tag" "${shape%,*}" "$years" "$cap" "$head" "$w" "$spy"
  done
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  collect) for f in "$@"; do collect_one "$f"; done ;;
  update)
    tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
    { [ -f "$LEDGER" ] && tail -n +2 "$LEDGER"; for f in "$@"; do collect_one "$f"; done; } \
      | awk -F, '!seen[$1 FS $3]++' | sort -t, -k1,1 -k3,3 > "$tmp"
    { echo "$HEADER"; cat "$tmp"; } > "$LEDGER"
    echo "perf_long_cells: $(($(wc -l < "$LEDGER") - 1)) cells in $LEDGER" ;;
  check)
    [ -f "$LEDGER" ] || { echo "perf_long_cells: no ledger at $LEDGER" >&2; exit 2; }
    tail -n +2 "$LEDGER" | awk -F, -v tol="$TOL" '
      $4 == "?" || $9 == "?" || $9 + 0 <= 0 { next }
      { k = $4 "|" int($5 + 0.5) "y|cap" $6; n[k]++; r[k, n[k]] = $9; row[k, n[k]] = $0 }
      END {
        bad = 0
        for (k in n) {
          if (n[k] < 2) continue
          m = 0; for (i = 1; i < n[k]; i++) v[++m] = r[k, i]
          for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++) if (v[j] < v[i]) { t = v[i]; v[i] = v[j]; v[j] = t }
          med = (m % 2) ? v[(m + 1) / 2] : (v[m / 2] + v[m / 2 + 1]) / 2
          d = 100 * (r[k, n[k]] / med - 1)
          st = (d > tol) ? "SLOWER" : "ok"; if (d > tol) bad = 1
          printf "%-6s %-28s newest %6d s/yr vs median %6d of %d earlier (%+.0f%%)  %s\n", st, k, r[k, n[k]], med, m, d, row[k, n[k]]
        }
        exit bad
      }' ;;
  *) sed -n '2,30p' "$0"; exit 2 ;;
esac
