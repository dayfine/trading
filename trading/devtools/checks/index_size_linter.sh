#!/bin/sh
# Linter: _index.md size + row-length guard.
#
# Prevents dev/status/_index.md from re-bloating with run-history prose.
# Two checks:
#
#   1. Total file size <= MAX_FILE_BYTES (20 KB).
#      The terse rewrite is ~5 KB; 20 KB gives headroom for ~30 additional
#      tracks while staying well below the prior 150 KB bloat level.
#
#   2. Max characters per table row <= MAX_ROW_CHARS (250).
#      A table row is any line that starts with "|". This caps the "Next task"
#      column to roughly one sentence and prevents multi-paragraph accumulation.
#      250 chars comfortably fits a full track name + status + owner + PR + a
#      160-char Next task cell (the widest realistic single-line entry).
#
# Both thresholds are intentionally generous — the goal is to catch
# multi-kilobyte per-row run-history accumulation, not to force heroic brevity.
#
# This script exits 0 (pass) or 1 (fail). It is wired into `dune runtest`
# via trading/devtools/checks/dune and runs on every CI build.
#
# Path resolution: dev/status/_index.md is at the repo root (outside the
# dune workspace). Use repo_root from _check_lib.sh.

set -e

. "$(dirname "$0")/_check_lib.sh"

MAX_FILE_BYTES=20480   # 20 KB
MAX_ROW_CHARS=250

INDEX="$(repo_root)/dev/status/_index.md"

[ -f "$INDEX" ] || die "index_size_linter: $INDEX does not exist"

# Check 1: total file size
ACTUAL_BYTES=$(wc -c < "$INDEX" | tr -d ' ')
if [ "$ACTUAL_BYTES" -gt "$MAX_FILE_BYTES" ]; then
  echo "FAIL: index_size_linter — dev/status/_index.md is ${ACTUAL_BYTES} bytes (limit ${MAX_FILE_BYTES})."
  echo "  Run-history prose belongs in per-track dev/status/<track>.md, not in the index."
  echo "  Trim the file; the linter passes once it is <= ${MAX_FILE_BYTES} bytes."
  exit 1
fi

# Check 2: max chars per table row (lines starting with |)
VIOLATIONS=""
LINE_NO=0
while IFS= read -r line; do
  LINE_NO=$((LINE_NO + 1))
  case "$line" in
    \|*)
      CHARS=$(printf '%s' "$line" | wc -c | tr -d ' ')
      if [ "$CHARS" -gt "$MAX_ROW_CHARS" ]; then
        VIOLATIONS="${VIOLATIONS}  line ${LINE_NO}: ${CHARS} chars (limit ${MAX_ROW_CHARS})\n"
      fi
      ;;
  esac
done < "$INDEX"

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: index_size_linter — table rows exceed ${MAX_ROW_CHARS} chars in dev/status/_index.md:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "  Keep 'Next task' to ONE line (<= ~160 chars). History belongs in the per-track file."
  exit 1
fi

echo "OK: index_size_linter — dev/status/_index.md within limits (${ACTUAL_BYTES}/${MAX_FILE_BYTES} bytes, all table rows <= ${MAX_ROW_CHARS} chars)."
