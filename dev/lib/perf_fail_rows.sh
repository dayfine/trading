# Shared parser + GHA-surfacing helpers for perf-tier summary.txt FAIL rows.
#
# Use:
#   . "$REPO_ROOT/dev/lib/perf_fail_rows.sh"
#   _perf_write_fail_summary "$summary_file" "Tier-3 perf weekly" >>"$GITHUB_STEP_SUMMARY"
#   _perf_emit_fail_annotations "$summary_file" "perf-tier3-weekly-${RUN_ID}"
#
# dev/scripts/perf_tier{1,2,3}_*.sh each write a summary.txt in this shape
# (see perf_tier3_weekly.sh's SUMMARY block -- tier1/tier2 mirror it):
#
#   Tier-3 perf weekly summary (<timestamp>)
#     passed: <int>
#     failed: <int>
#
#   STATUS  SCENARIO                          WALL      PEAK_RSS
#   ----------------------------------------------------------------------
#   PASS    <name>                            <n>s      <n>kB
#   FAIL    <name>                            <n>s      <n>kB
#
# Rows are printed with `printf '%-6s  %-32s  %-8s  %s\n' STATUS SCENARIO
# WALL PEAK_RSS`, so a FAIL row's line always starts with the literal
# token "FAIL" as its first whitespace-separated field -- awk's default
# field splitting collapses the padding and handles this directly.
#
# Extracted 2026-09-22 (#2891) so all three perf workflows share ONE parser
# instead of three near-identical awk blocks inlined in YAML -- same
# rationale as dev/lib/gnu_time_rss.sh (#2559): a bug fixed in one copy
# silently survives in its siblings until something forces a comparison.
#
# Regression test: trading/devtools/checks/perf_fail_rows_smoke.sh.
# See issue #2891.

# _perf_fail_row_fields <summary-file>
#
# Print one line per FAIL row as "<scenario> <wall> <rss>" (space
# separated -- scenario base names in this repo never contain whitespace).
# Prints nothing if the file is missing or has zero FAIL rows.
_perf_fail_row_fields() {
  summary_file="$1"
  [ -f "$summary_file" ] || return 0
  awk '$1 == "FAIL" { print $2, $3, $4 }' "$summary_file"
}

# _perf_failed_count <summary-file>
#
# Print the integer from the summary's "  failed: N" line. Falls back to
# counting FAIL rows directly (via _perf_fail_row_fields) if that line is
# missing or malformed, so a format drift in one half of the file doesn't
# silently zero out the other half's signal.
_perf_failed_count() {
  summary_file="$1"
  if [ ! -f "$summary_file" ]; then
    printf '0\n'
    return 0
  fi
  count="$(grep -E '^[[:space:]]*failed:[[:space:]]*[0-9]+' "$summary_file" \
    | sed -E 's/^[[:space:]]*failed:[[:space:]]*([0-9]+).*/\1/' | head -n 1)"
  if [ -z "$count" ]; then
    count="$(_perf_fail_row_fields "$summary_file" | grep -c '.')"
  fi
  printf '%s\n' "$count"
}

# _perf_write_fail_summary <summary-file> <tier-label>
#
# Write a Markdown block to stdout: a heading naming the FAIL count, plus
# one bullet per FAIL row (scenario + wall + peak RSS). The caller appends
# this to $GITHUB_STEP_SUMMARY BEFORE the full summary.txt table is
# appended (a separate, existing step), so FAIL rows are visible above the
# fold without scrolling the full pass/fail table. Writes nothing when
# there are zero failures -- the full table already reads clean in that
# case and a "0 failed" banner would just be noise.
_perf_write_fail_summary() {
  summary_file="$1"
  tier_label="$2"
  failed="$(_perf_failed_count "$summary_file")"
  case "$failed" in
    '' | 0) return 0 ;;
  esac
  printf '## perf FAIL -- %s: %s scenario(s)\n\n' "$tier_label" "$failed"
  _perf_fail_row_fields "$summary_file" | while read -r scenario wall rss; do
    printf '%s\n' "- \`${scenario}\` wall=${wall} rss=${rss}"
  done
  printf '\n'
}

# _perf_emit_fail_annotations <summary-file> <artifact-name>
#
# Write one `::warning::` GHA annotation line per FAIL row to stdout, so
# the run page shows every failing cell without opening the raw log.
# <artifact-name> is named in the message so a reader knows which uploaded
# artifact carries that cell's .log / .error / .peak_rss files.
_perf_emit_fail_annotations() {
  summary_file="$1"
  artifact_name="$2"
  _perf_fail_row_fields "$summary_file" | while read -r scenario wall rss; do
    printf '::warning title=perf FAIL::%s wall=%s rss=%s -- see artifact %s\n' \
      "$scenario" "$wall" "$rss" "$artifact_name"
  done
}
