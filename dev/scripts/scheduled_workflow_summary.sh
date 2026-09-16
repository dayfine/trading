#!/bin/sh
# Render the captured health-check output without losing its exit class.
# Usage: sh scheduled_workflow_summary.sh <exit-code> <combined-output-file>
set -eu
rc=${1:?exit code required}
report=${2:?captured output required}
test -r "$report"
printf '## Scheduled workflows\n\n'
case "$rc" in
  0)
    measured=$(awk -F '\t' '$1 == "OK" {n++} END {print n+0}' "$report")
    if grep -q '^UNOBSERVABLE' "$report"; then
      printf 'UNMEASURABLE (exit 0: some workflows have no completed scheduled runs; %s measured OK)\n' "$measured"
    elif grep -q '^SUMMARY:' "$report"; then
      printf 'all OK (%s measured; exit 0)\n' "$measured"
    else
      printf 'UNMEASURABLE (exit 0: missing health-check summary)\n'
    fi
    ;;
  1) printf 'FINDINGS (exit 1): RED/STALE workflows and newest_completed_run_id below.\n' ;;
  2|3) printf 'UNMEASURABLE (exit %s: see captured diagnostic below)\n' "$rc" ;;
  *) printf 'UNMEASURABLE (unexpected exit %s: see captured diagnostic below)\n' "$rc" ;;
esac
# Retain all rows and diagnostics, including NO-SCHEDULE and partial results.
# Indented Markdown code avoids collisions with fences in workflow names.
printf '\n'
sed 's/^/    /' "$report"
printf '\n'
