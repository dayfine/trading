#!/bin/sh
# Check 12: Stale local jj bookmarks (harness gap sub-item 4).
#
# Usage: sh check_12_stale_bookmarks.sh <report_file> [findings_file]
#
# Local jj bookmarks accumulate after PRs merge and the local ref is never
# cleaned up. This check surfaces:
#   a) Local-only bookmarks — exist locally but have no @origin counterpart.
#      Protected prefixes (main, master, HEAD, trunk) are skipped.
#   b) Local bookmarks behind origin — bookmark exists on both, but local
#      commit is an ancestor of the origin commit.
# Local-ahead (unpushed work) and in-sync bookmarks are silently skipped.
#
# Severity: INFO (housekeeping; no false-positive FAILs).
# Degrades gracefully when jj is absent or .jj/ does not exist.
# Section "## Stale Local Bookmarks" is always emitted in the report.

set -e

REPORT_FILE="${1:?Usage: check_12_stale_bookmarks.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 12: Stale local jj bookmarks
# ────────────────────────────────────────────────────────────────

STALE_LOCAL_ONLY_DETAILS=""
STALE_BEHIND_ORIGIN_DETAILS=""
STALE_LOCAL_ONLY_COUNT=0
STALE_BEHIND_COUNT=0
JJ_AVAILABLE=false
JJ_SKIP_REASON=""

# Graceful degradation: jj and .jj/ must both be present.
if ! command -v jj >/dev/null 2>&1; then
  JJ_SKIP_REASON="jj not available on PATH"
elif [ ! -d "${REPO_ROOT}/.jj" ]; then
  JJ_SKIP_REASON=".jj/ directory not found (not a jj repository)"
else
  JJ_AVAILABLE=true
fi

if $JJ_AVAILABLE; then
  # Enumerate bookmarks. Output format (colocated mode):
  #   name: CHANGE_ID GIT_HASH description        <- local bookmark
  #     @git: CHANGE_ID GIT_HASH description      <- git alias (indented, skip)
  #   name@origin: CHANGE_ID GIT_HASH description <- remote tracking ref
  JJ_RAW="$(jj bookmark list --all 'glob:*' 2>/dev/null || true)"

  # Local bookmarks: non-indented lines whose name has no @.
  LOCAL_MAP="$(printf '%s\n' "$JJ_RAW" \
    | awk '
      /^[^ \t]/ && !/^[^ \t]*@[^ \t]*:/ {
        colon = index($0, ": ")
        if (colon == 0) next
        name = substr($0, 1, colon - 1)
        rest = substr($0, colon + 2)
        n = split(rest, tok, " ")
        if (n >= 1) print name "=" tok[1]
      }
    ' 2>/dev/null || true)"

  # Remote tracking entries: lines containing "@origin: ".
  ORIGIN_MAP="$(printf '%s\n' "$JJ_RAW" \
    | awk '
      /@origin: / {
        at_pos = index($0, "@origin: ")
        name = substr($0, 1, at_pos - 1)
        rest = substr($0, at_pos + 9)
        n = split(rest, tok, " ")
        if (n >= 1) print name "=" tok[1]
      }
    ' 2>/dev/null || true)"

  _is_protected_bookmark() {
    case "$1" in
      main|master|HEAD|trunk) return 0 ;;
    esac
    return 1
  }

  while IFS='=' read -r bm_name bm_commit; do
    [ -z "$bm_name" ] && continue
    _is_protected_bookmark "$bm_name" && continue

    origin_commit="$(printf '%s\n' "$ORIGIN_MAP" \
      | awk -F'=' -v name="$bm_name" '$1 == name {print $2; exit}' 2>/dev/null || true)"

    if [ -z "$origin_commit" ]; then
      STALE_LOCAL_ONLY_COUNT=$((STALE_LOCAL_ONLY_COUNT + 1))
      desc="$(jj log -r "${bm_commit}" --no-graph \
        -T 'description.first_line()' 2>/dev/null | head -1 || echo "(unknown)")"
      STALE_LOCAL_ONLY_DETAILS="${STALE_LOCAL_ONLY_DETAILS}| \`${bm_name}\` | \`${bm_commit}\` | ${desc} |\n"
    else
      if [ "$bm_commit" = "$origin_commit" ]; then
        : # in-sync -- skip
      else
        is_behind=false
        range_out="$(jj log -r "${bm_commit}..${origin_commit}" \
          --no-graph -T 'change_id' 2>/dev/null || true)"
        if [ -n "$range_out" ]; then
          is_behind=true
        fi

        if $is_behind; then
          STALE_BEHIND_COUNT=$((STALE_BEHIND_COUNT + 1))
          STALE_BEHIND_ORIGIN_DETAILS="${STALE_BEHIND_ORIGIN_DETAILS}| \`${bm_name}\` | \`${bm_commit}\` | \`${origin_commit}\` |\n"
        fi
      fi
    fi
  done << JJEOF
$(printf '%s\n' "$LOCAL_MAP")
JJEOF

  STALE_TOTAL=$((STALE_LOCAL_ONLY_COUNT + STALE_BEHIND_COUNT))
  if [ "$STALE_TOTAL" -gt 0 ]; then
    add_info "Stale local jj bookmarks: ${STALE_LOCAL_ONLY_COUNT} local-only candidate(s), ${STALE_BEHIND_COUNT} behind-origin bookmark(s) -- see ## Stale Local Bookmarks"
  fi
fi

add_metric STALE_LOCAL_ONLY_COUNT "$STALE_LOCAL_ONLY_COUNT"
add_metric STALE_BEHIND_COUNT "$STALE_BEHIND_COUNT"
flush_findings

# Always emit the Stale Local Bookmarks section (Check 12).
{
  printf "\n## Stale Local Bookmarks\n\n"
  printf "Checks local jj bookmarks for refs no longer needed after PR merges.\n"
  printf "Severity: INFO -- housekeeping only; no false-positive failures.\n\n"

  if ! $JJ_AVAILABLE; then
    printf "jj not available -- skipping stale bookmark check. (%s)\n" "$JJ_SKIP_REASON"
  else
    printf "### Local-only candidates\n\n"
    printf "Bookmarks that exist locally but have no matching @origin entry.\n"
    printf "Protected names (main, master, HEAD, trunk) are excluded.\n\n"
    if [ "$STALE_LOCAL_ONLY_COUNT" -eq 0 ]; then
      printf "No stale local bookmarks found.\n\n"
    else
      printf "| Name | Local commit | Last commit description |\n|---|---|---|\n"
      printf '%b' "$STALE_LOCAL_ONLY_DETAILS"
      printf "\n"
    fi

    printf "### Behind origin\n\n"
    printf "Bookmarks where local commit is an ancestor of the origin commit\n"
    printf "(origin has moved on -- usually means PR merged, local never refreshed).\n\n"
    if [ "$STALE_BEHIND_COUNT" -eq 0 ]; then
      printf "No stale local bookmarks found.\n\n"
    else
      printf "| Name | Local commit | Origin commit |\n|---|---|---|\n"
      printf '%b' "$STALE_BEHIND_ORIGIN_DETAILS"
      printf "\n"
    fi
  fi
} >> "$REPORT_FILE"
