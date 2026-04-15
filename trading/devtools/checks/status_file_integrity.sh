#!/bin/sh
# Linter: status file integrity.
#
# Verifies that each `dev/status/<feature>.md` has the required fields so that
# the lead-orchestrator and health-scanner can rely on the schema.
#
# Schema:
#   All status files must declare:
#     - `## Status` followed on the next non-empty line by one of:
#       IN_PROGRESS | READY_FOR_REVIEW | APPROVED | MERGED | BLOCKED
#     - `## Last updated: YYYY-MM-DD`
#
#   Feature status files must additionally declare:
#     - `## Interface stable` followed on the next non-empty line by YES or NO
#
# Exempt files (do not require `## Interface stable`):
#   - harness.md         — orchestrator's own backlog (different shape)
#   - backtest-infra.md  — human-driven infrastructure tracker (uses `## Ownership`)
#
# Skipped entirely (not status files — meta / index / notes):
#   - any file whose basename starts with `_` (e.g. `_index.md`)
#
# This check runs as part of `dune runtest` and is invoked by the
# `health-scanner` fast scan Step 4.
#
# Path resolution: `dev/status/` lives at the repository root, outside the
# dune workspace (`trading/`), so it is not reachable via `%{dep:...}` or
# `%{workspace_root}`. Use `repo_root` from _check_lib.sh (git rev-parse)
# to locate it — works identically from dune's sandbox and from a direct
# shell invocation.

set -e

. "$(dirname "$0")/_check_lib.sh"

VALID_STATUSES='IN_PROGRESS|READY_FOR_REVIEW|APPROVED|MERGED|BLOCKED'
INTERFACE_EXEMPT='harness.md backtest-infra.md'
VIOLATIONS=""

STATUS_DIR="$(repo_root)/dev/status"
[ -d "$STATUS_DIR" ] || die "status_file_integrity: $STATUS_DIR does not exist"

_is_interface_exempt() {
  basename="$1"
  for exempt in $INTERFACE_EXEMPT; do
    [ "$basename" = "$exempt" ] && return 0
  done
  return 1
}

# Extract the first non-empty, non-heading line after a `## <heading>` marker.
# Stops at the next `## ` heading. Trims leading/trailing whitespace.
_value_after_heading() {
  file="$1"
  heading="$2"
  awk -v h="## $heading" '
    $0 == h { found = 1; next }
    found && /^## / { exit }
    found && NF > 0 {
      sub(/^[ \t]+/, "")
      sub(/[ \t]+$/, "")
      print
      exit
    }
  ' "$file"
}

# `## Last updated: YYYY-MM-DD` is inline with the heading, not on the next line.
_last_updated_date() {
  file="$1"
  grep -E '^## Last updated:' "$file" \
    | head -1 \
    | sed -E 's/^## Last updated:[ \t]*//' \
    | sed -E 's/[ \t]+$//'
}

_record_violation() {
  VIOLATIONS="${VIOLATIONS}$1\n"
}

for status_file in "$STATUS_DIR"/*.md; do
  [ -f "$status_file" ] || continue
  basename=$(basename "$status_file")

  # Skip meta / index files (basename starts with `_`) — they are not
  # per-track status files and do not follow the schema.
  case "$basename" in
    _*) continue ;;
  esac

  # 1. ## Last updated: YYYY-MM-DD
  last_updated=$(_last_updated_date "$status_file")
  if [ -z "$last_updated" ]; then
    _record_violation "$basename: missing '## Last updated: YYYY-MM-DD'"
  elif ! printf '%s' "$last_updated" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    _record_violation "$basename: '## Last updated' is not YYYY-MM-DD: '$last_updated'"
  fi

  # 2. ## Status with a valid value on the next non-empty line
  status_value=$(_value_after_heading "$status_file" "Status")
  if [ -z "$status_value" ]; then
    _record_violation "$basename: missing '## Status' section or value"
  elif ! printf '%s' "$status_value" | grep -qE "^($VALID_STATUSES)$"; then
    _record_violation "$basename: '## Status' value '$status_value' is not one of $VALID_STATUSES"
  fi

  # 3. ## Interface stable (feature status files only)
  if _is_interface_exempt "$basename"; then
    :
  else
    interface_value=$(_value_after_heading "$status_file" "Interface stable")
    if [ -z "$interface_value" ]; then
      _record_violation "$basename: missing '## Interface stable' section (required for feature status files; add to $INTERFACE_EXEMPT to exempt)"
    elif ! printf '%s' "$interface_value" | grep -qE '^(YES|NO)$'; then
      _record_violation "$basename: '## Interface stable' value '$interface_value' is not YES or NO"
    fi
  fi
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: status file integrity linter — malformed or missing fields in dev/status/:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Schema: ## Status (valid value), ## Last updated: YYYY-MM-DD,"
  echo "        ## Interface stable (YES|NO) — required except for: $INTERFACE_EXEMPT"
  exit 1
fi

echo "OK: all dev/status/*.md files have required fields."
