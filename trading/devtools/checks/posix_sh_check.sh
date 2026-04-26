#!/bin/sh
# POSIX shell portability linter.
#
# Runs `dash -n` (syntax-only parse) over shell scripts that are declared as
# POSIX sh (no explicit bash shebang). Catches the class of bash-isms that
# caused rework on PR #483: bash arrays, here-strings <<<, and process
# substitution <(...) -- dash parse-fails on these with exit 2.
#
# Note: dash -n catches parse-time failures only. Runtime-only bash-isms
# (mapfile, [[ ]], ${BASH_SOURCE[0]}) are NOT caught at syntax-check time.
# shellcheck would catch these too; it is not installed in the
# trading-devcontainer base image. Add shellcheck to the image for richer
# coverage (see Follow-up in dev/status/harness.md).
#
# Scope:
#   INCLUDED:
#     trading/devtools/checks/*.sh            (gate scripts, must be POSIX sh)
#     trading/devtools/checks/deep_scan/*.sh  (deep scan per-check scripts)
#     dev/lib/*.sh                            (shared lib scripts)
#     dev/scripts/*.sh                        (one-off dev scripts — e.g.
#                                             perf sweep + tier-1 smoke runners)
#   EXCLUDED:
#     Scripts with explicit bash shebang (#!/bin/bash or #!/usr/bin/env bash)
#     -- those scripts intentionally use bash features and are out of scope.
#
# Output:
#   OK: posix-sh linter -- N scripts clean.
#   FAIL: per-file errors with dash output; exits 1.
#
# Env override for testing:
#   POSIX_SH_CHECK_SCAN_DIRS="<dir1> <dir2>" sh posix_sh_check.sh

set -e

. "$(dirname "$0")/_check_lib.sh"

DASH="${DASH:-dash}"

if ! command -v "$DASH" >/dev/null 2>&1; then
  echo "FAIL: posix_sh_check: '$DASH' not found on PATH."
  exit 1
fi

REPO_ROOT="$(repo_root)"
TRADING_DIR="${REPO_ROOT}/trading"

# Directories to scan. Override POSIX_SH_CHECK_SCAN_DIRS in tests to point
# at temp fixtures instead of real source directories.
if [ -n "${POSIX_SH_CHECK_SCAN_DIRS:-}" ]; then
  SCAN_DIRS="$POSIX_SH_CHECK_SCAN_DIRS"
else
  SCAN_DIRS="${TRADING_DIR}/devtools/checks
${TRADING_DIR}/devtools/checks/deep_scan
${REPO_ROOT}/dev/lib
${REPO_ROOT}/dev/scripts"
fi

CLEAN_COUNT=0
FAIL_COUNT=0
VIOLATIONS=""

# Returns 0 (true) if the script's first line declares bash.
_is_bash_script() {
  first_line=$(head -1 "$1" 2>/dev/null)
  case "$first_line" in
    "#!/bin/bash"*|"#!/usr/bin/env bash"*) return 0 ;;
    *) return 1 ;;
  esac
}

for dir in $SCAN_DIRS; do
  [ -d "$dir" ] || continue
  for script in "$dir"/*.sh; do
    [ -f "$script" ] || continue
    if _is_bash_script "$script"; then
      continue
    fi
    if err=$(dash -n "$script" 2>&1); then
      CLEAN_COUNT=$((CLEAN_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      rel="${script#${REPO_ROOT}/}"
      VIOLATIONS="${VIOLATIONS}FAIL: ${rel}\n${err}\n\n"
    fi
  done
done

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: posix-sh linter -- $FAIL_COUNT script(s) have POSIX portability violations:"
  echo ""
  printf '%b' "$VIOLATIONS"
  echo "Fix: remove bash-isms (arrays, <<<, process substitution <(...), etc.)"
  echo "     or add #!/usr/bin/env bash shebang if bash is intentionally required."
  exit 1
fi

echo "OK: posix-sh linter -- ${CLEAN_COUNT} scripts clean."
