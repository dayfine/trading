#!/bin/sh
# Rule promotion check (T3-F): verify that every rule with Lifecycle: enforced
# in docs/design/dependency-rules.md has a corresponding check wired into
# trading/devtools/checks/dune.
#
# Parsing contract (in dependency-rules.md):
#   - Rules are headed by a line starting with "### R"
#   - Each rule has a markdown table row:  | Lifecycle | `<state>` |
#   - Each rule has a markdown table row:  | Check     | `<path or implicit ...>` |
#   - A Check value starting with "implicit" means the rule is enforced by dune
#     structure (no script to verify); the file-existence check is skipped.
#   - A Check value of "none" means not yet implemented.
#
# Exit codes:
#   0 — all enforced rules are wired up (or implicitly enforced)
#   1 — one or more enforced rules are missing their check script or dune wiring

set -e

. "$(dirname "$0")/_check_lib.sh"

RULES_DOC="$(repo_root)/docs/design/dependency-rules.md"
# The dune file lives in the same directory as this script in the source tree.
# Under dune's sandbox, $(dirname "$0") points into _build, but the dune file
# itself is not a regular dep. We use repo_root to find the canonical copy.
DUNE_FILE="$(repo_root)/trading/devtools/checks/dune"

if [ ! -f "$RULES_DOC" ]; then
  echo "WARNING: rule_promotion_check — docs/design/dependency-rules.md not found, skipping."
  exit 0
fi

if [ ! -f "$DUNE_FILE" ]; then
  echo "WARNING: rule_promotion_check — trading/devtools/checks/dune not found, skipping."
  exit 0
fi

# -----------------------------------------------------------------------
# Parse rules from the doc. We read line-by-line, tracking state:
#   - When we see a "### R" heading, start a new rule.
#   - When we see "| Lifecycle |", extract the lifecycle value.
#   - When we see "| Check |", extract the check value.
# -----------------------------------------------------------------------

failures=0
warnings=0
rules_parsed=0
enforced_ok=0

current_rule=""
current_lifecycle=""
current_check=""

_process_rule() {
  rule="$1"
  lifecycle="$2"
  check="$3"

  [ -z "$rule" ] && return
  [ -z "$lifecycle" ] && return

  # Strip backtick quoting from values
  lifecycle=$(printf '%s' "$lifecycle" | tr -d '`')
  check=$(printf '%s' "$check" | tr -d '`')

  rules_parsed=$((rules_parsed + 1))

  case "$lifecycle" in
    proposed|monitored)
      # Not enforced — no check expected
      return
      ;;
    enforced)
      : # fall through to check verification
      ;;
    *)
      printf 'WARNING: %s has unrecognised Lifecycle value "%s" — skipping\n' "$rule" "$lifecycle"
      warnings=$((warnings + 1))
      return
      ;;
  esac

  # Rule is enforced. Check the Check field.
  if [ -z "$check" ] || [ "$check" = "none" ]; then
    printf 'FAIL: %s is Lifecycle: enforced but Check is "%s" — add a check script and wire it into dune\n' \
      "$rule" "${check:-<missing>}"
    failures=$((failures + 1))
    return
  fi

  case "$check" in
    implicit*)
      # Structurally enforced by dune; no script to verify.
      printf 'OK: %s — enforced (implicit dune structure)\n' "$rule"
      enforced_ok=$((enforced_ok + 1))
      return
      ;;
  esac

  # check is a relative path from repo root. Verify it exists.
  check_abs="$(repo_root)/$check"
  if [ ! -f "$check_abs" ]; then
    printf 'FAIL: %s — check script "%s" does not exist at %s\n' "$rule" "$check" "$check_abs"
    failures=$((failures + 1))
    return
  fi

  # Verify the script is referenced in trading/devtools/checks/dune.
  # We grep for the basename of the check path in the dune file.
  check_basename=$(basename "$check")
  if ! grep -qF "$check_basename" "$DUNE_FILE"; then
    printf 'FAIL: %s — check script "%s" exists but is NOT referenced in trading/devtools/checks/dune\n' \
      "$rule" "$check"
    failures=$((failures + 1))
    return
  fi

  printf 'OK: %s — enforced via %s (wired in dune)\n' "$rule" "$check"
  enforced_ok=$((enforced_ok + 1))
}

# Read the doc and extract rules.
while IFS= read -r line; do
  # New rule heading: flush the previous rule first.
  case "$line" in
    '### R'*)
      _process_rule "$current_rule" "$current_lifecycle" "$current_check"
      current_rule=$(printf '%s' "$line" | sed 's/^### //')
      current_lifecycle=""
      current_check=""
      ;;
    '| Lifecycle |'*)
      # Extract value from markdown table: | Lifecycle | `value` |
      current_lifecycle=$(printf '%s' "$line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
      ;;
    '| Check |'*)
      # Extract value from markdown table: | Check | `value` |
      current_check=$(printf '%s' "$line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
      ;;
  esac
done < "$RULES_DOC"

# Flush the last rule.
_process_rule "$current_rule" "$current_lifecycle" "$current_check"

# Summary
printf '\nrule_promotion_check: parsed %d rules, %d enforced OK, %d warnings, %d failures\n' \
  "$rules_parsed" "$enforced_ok" "$warnings" "$failures"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "To fix: add the check script to trading/devtools/checks/ and wire it"
  echo "into trading/devtools/checks/dune with a (rule (alias runtest) ...) stanza."
  exit 1
fi

echo "OK: all enforced rules have corresponding checks wired into dune runtest."
exit 0
