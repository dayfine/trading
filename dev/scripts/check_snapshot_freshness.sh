#!/usr/bin/env bash
# check_snapshot_freshness.sh — report per-symbol staleness of a snapshot
# warehouse vs the source CSVs.
#
# A snapshot entry is "stale" when its source CSV's mtime is newer than the
# manifest entry's recorded csv_mtime — meaning the CSV has been refreshed
# (e.g. nightly fetch) since the snapshot was last built.
#
# Usage:
#   check_snapshot_freshness.sh \
#     --manifest <path>      (default: <output-dir>/manifest.sexp)
#     --output-dir <path>    (alternative to --manifest; resolves to
#                             <output-dir>/manifest.sexp)
#     --csv-data-dir <path>  (default: data)
#     --threshold-pct N      Exit non-zero if stale > N% (default: 0 = always 0)
#     --list-stale           Print every stale symbol; default summary only
#     --quiet                Summary line only
#
# Output (stdout):
#   snapshot-freshness: <stale>/<total> stale = <pct>% (manifest=<path>)
#
# Exit codes:
#   0    stale ≤ threshold-pct (or threshold not enforced)
#   1    stale > threshold-pct
#   2    setup error (manifest missing, parse error, etc)
#
# Use cases:
#   - Pre-flight gate before tier-4 release-gate runs (require <5% stale)
#   - Surface symbols needing rebuild for ops-data dispatch
#   - Cron sentinel to trigger build_broad_snapshot_incremental.sh
#
# Implementation note: this script does NOT parse the manifest sexp directly
# (avoiding a host dependency on sexp tooling). It reads the symbol list +
# csv_mtime values via a small sed/awk extraction over the manifest's
# canonical sexp shape — see Snapshot_manifest.write for the format.

set -euo pipefail

manifest=""
output_dir=""
csv_data_dir="data"
threshold_pct=0
list_stale=false
quiet=false

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)        manifest="$2";        shift 2 ;;
    --output-dir)      output_dir="$2";      shift 2 ;;
    --csv-data-dir)    csv_data_dir="$2";    shift 2 ;;
    --threshold-pct)   threshold_pct="$2";   shift 2 ;;
    --list-stale)      list_stale=true;      shift ;;
    --quiet)           quiet=true;           shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "[check-snapshot-freshness] unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$manifest" ]; then
  if [ -z "$output_dir" ]; then
    echo "[check-snapshot-freshness] one of --manifest or --output-dir required" >&2
    exit 2
  fi
  manifest="$output_dir/manifest.sexp"
fi

if [ ! -f "$manifest" ]; then
  echo "[check-snapshot-freshness] manifest not found: $manifest" >&2
  exit 2
fi
if [ ! -d "$csv_data_dir" ]; then
  echo "[check-snapshot-freshness] csv data dir not found: $csv_data_dir" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Extract (symbol, csv_mtime) pairs from the manifest.
#
# Manifest sexp shape (per Snapshot_manifest.write, Sexp.to_string_hum):
#   ((schema_hash ...)
#    (schema (...))
#    (entries
#     (((symbol AAPL) (path /.../AAPL.snap) (byte_size 1024)
#       (payload_md5 ...) (csv_mtime 1234567890.5))
#      ((symbol MSFT) ...))))
#
# We grep for `(symbol X)` and the matching `(csv_mtime Y)` pair via awk.
# The pairing assumption: each entry record contains exactly one symbol and
# exactly one csv_mtime, in order. This holds for the canonical writer; if
# the manifest is hand-edited with reordered fields, awk pairs by appearance
# order — the script docs note this.
# ---------------------------------------------------------------------------

pairs=$(awk '
  /\(symbol [A-Za-z0-9_.\-]+\)/ {
    if (match($0, /\(symbol [^)]+\)/)) {
      sym = substr($0, RSTART + 8, RLENGTH - 9)
      have_sym = 1
    }
  }
  /\(csv_mtime [0-9.+\-eE]+\)/ {
    if (have_sym && match($0, /\(csv_mtime [^)]+\)/)) {
      mt = substr($0, RSTART + 11, RLENGTH - 12)
      printf "%s\t%s\n", sym, mt
      have_sym = 0
    }
  }
' "$manifest")

total=$(printf '%s\n' "$pairs" | grep -c '	' || true)
if [ "$total" -eq 0 ]; then
  echo "[check-snapshot-freshness] no entries parsed from manifest: $manifest" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# For each (sym, recorded_mtime), compare against current CSV mtime under
# csv_data_dir/<l1>/<last>/<sym>/data.csv (matching csv_storage.symbol_data_dir).
# ---------------------------------------------------------------------------
stale=0
stale_list=""

while IFS=$'\t' read -r sym recorded_mtime; do
  [ -z "$sym" ] && continue

  l1=$(printf '%s' "$sym" | cut -c1)
  sym_len=${#sym}
  l2=$(printf '%s' "$sym" | cut -c"${sym_len}")
  csv_path="$csv_data_dir/$l1/$l2/$sym/data.csv"

  # If CSV is gone, treat as not-stale (cannot verify; rebuild won't help).
  [ -f "$csv_path" ] || continue

  # mtime as integer seconds (drop sub-second; recorded float may have ".0")
  if stat --version >/dev/null 2>&1; then
    # GNU stat (Linux)
    actual_mtime=$(stat -c %Y "$csv_path")
  else
    # BSD stat (macOS)
    actual_mtime=$(stat -f %m "$csv_path")
  fi

  is_stale=$(awk -v a="$actual_mtime" -v r="$recorded_mtime" 'BEGIN { print (a + 0 > r + 0) ? "yes" : "no" }')
  if [ "$is_stale" = "yes" ]; then
    stale=$((stale + 1))
    if [ "$list_stale" = "true" ]; then
      stale_list="${stale_list}${sym}\n"
    fi
  fi
done <<EOF
$pairs
EOF

pct=$(awk -v s="$stale" -v t="$total" 'BEGIN { printf "%.2f", (s * 100.0) / t }')

if [ "$quiet" != "true" ]; then
  echo "[check-snapshot-freshness] manifest=$manifest csv_data_dir=$csv_data_dir"
fi

if [ "$list_stale" = "true" ] && [ -n "$stale_list" ]; then
  echo "[check-snapshot-freshness] stale symbols ($stale):"
  printf '%b' "$stale_list" | sort | head -50
  if [ "$stale" -gt 50 ]; then
    echo "  ... (+$((stale - 50)) more)"
  fi
fi

echo "snapshot-freshness: $stale/$total stale = ${pct}% (manifest=$manifest)"

# Threshold gate
if [ "$threshold_pct" -gt 0 ]; then
  meets=$(awk -v p="$pct" -v t="$threshold_pct" 'BEGIN { print (p+0 <= t+0) ? "yes" : "no" }')
  if [ "$meets" != "yes" ]; then
    echo "[check-snapshot-freshness] FAIL: stale ${pct}% > threshold ${threshold_pct}%" >&2
    exit 1
  fi
fi

exit 0
