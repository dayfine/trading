#!/bin/sh
# Smoke test for posix_sh_check.sh.
#
# Verifies that the linter catches bash-isms by running it against known-bad
# fixtures in a temp directory. Proves the linter would have caught the PR #483
# class of violations.
#
# What dash -n catches (parse-time failures):
#   - bash arrays:           arr=(one two three)  -- Syntax error: "(" unexpected
#   - here-strings:          cmd <<< "value"       -- Syntax error: redirection unexpected
#   - process substitution:  cmd <(other-cmd)      -- Syntax error: redirection unexpected
#
# What dash -n does NOT catch (runtime failures -- not in scope for this linter):
#   - mapfile:        runtime bash-builtin, not a parse error
#   - [[ ... ]]:      dash parses as nested [ [ ... ] ], fails at runtime
#   - ${BASH_SOURCE}: special variable, not caught at parse time
#
# Test structure:
#   1. bad-fixture:   #!/bin/sh script with bash array -- linter must exit non-zero
#   2. clean-fixture: #!/bin/sh script, POSIX only    -- linter must exit 0
#   3. bash-exempt:   #!/usr/bin/env bash script      -- must be exempt (exit 0)

set -e

. "$(dirname "$0")/_check_lib.sh"

LINTER="$(dirname "$0")/posix_sh_check.sh"
[ -f "$LINTER" ] || die "posix_sh_check_test: linter not found at $LINTER"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# ---- Fixture 1: bad #!/bin/sh script with bash array ----

BAD_DIR="${TMPDIR_BASE}/bad"
mkdir -p "$BAD_DIR"
cat > "${BAD_DIR}/bash_array.sh" << 'EOF'
#!/bin/sh
# Bad: bash array syntax is not valid POSIX sh.
# dash -n exits 2: Syntax error: "(" unexpected
FILES=(one two three)
echo "${FILES[0]}"
EOF

ACTUAL_OUTPUT="$(POSIX_SH_CHECK_SCAN_DIRS="$BAD_DIR" sh "$LINTER" 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?

if [ "$ACTUAL_EXIT" -eq 0 ]; then
  echo "FAIL: posix_sh_check_test -- linter exited 0 on bash-array fixture (expected non-zero)"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "bash_array.sh"; then
  echo "FAIL: posix_sh_check_test -- 'bash_array.sh' not in linter output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "FAIL"; then
  echo "FAIL: posix_sh_check_test -- 'FAIL' not in linter output"
  echo "  output: $ACTUAL_OUTPUT"
  exit 1
fi

# ---- Fixture 2: clean POSIX sh script ----

CLEAN_DIR="${TMPDIR_BASE}/clean"
mkdir -p "$CLEAN_DIR"
cat > "${CLEAN_DIR}/posix_clean.sh" << 'EOF'
#!/bin/sh
# Clean POSIX sh -- no bash-isms.
set -e
x="hello"
if [ -n "$x" ]; then echo "x is set"; fi
EOF

CLEAN_OUTPUT="$(POSIX_SH_CHECK_SCAN_DIRS="$CLEAN_DIR" sh "$LINTER" 2>&1)" && CLEAN_EXIT=0 || CLEAN_EXIT=$?

if [ "$CLEAN_EXIT" -ne 0 ]; then
  echo "FAIL: posix_sh_check_test -- linter failed on clean fixture (expected exit 0)"
  echo "  output: $CLEAN_OUTPUT"
  exit 1
fi

if ! printf '%s' "$CLEAN_OUTPUT" | grep -q "OK"; then
  echo "FAIL: posix_sh_check_test -- 'OK' not in clean-fixture output"
  echo "  output: $CLEAN_OUTPUT"
  exit 1
fi

if ! printf '%s' "$CLEAN_OUTPUT" | grep -q "1 scripts clean"; then
  echo "FAIL: posix_sh_check_test -- expected '1 scripts clean' in output"
  echo "  output: $CLEAN_OUTPUT"
  exit 1
fi

# ---- Fixture 3: #!/usr/bin/env bash script (must be exempt) ----

BASH_DIR="${TMPDIR_BASE}/bash_exempt"
mkdir -p "$BASH_DIR"
cat > "${BASH_DIR}/explicit_bash.sh" << 'EOF'
#!/usr/bin/env bash
# Explicit bash -- exempt from POSIX linting.
set -euo pipefail
FILES=(one two three)
echo "${FILES[@]}"
EOF

EXEMPT_OUTPUT="$(POSIX_SH_CHECK_SCAN_DIRS="$BASH_DIR" sh "$LINTER" 2>&1)" && EXEMPT_EXIT=0 || EXEMPT_EXIT=$?

if [ "$EXEMPT_EXIT" -ne 0 ]; then
  echo "FAIL: posix_sh_check_test -- linter failed on bash-exempt fixture (expected exit 0)"
  echo "  output: $EXEMPT_OUTPUT"
  exit 1
fi

if ! printf '%s' "$EXEMPT_OUTPUT" | grep -q "OK"; then
  echo "FAIL: posix_sh_check_test -- 'OK' not in bash-exempt output"
  echo "  output: $EXEMPT_OUTPUT"
  exit 1
fi

echo "OK: posix_sh_check_test -- all 3 assertions passed (bad-fixture FAIL, clean-fixture OK, bash-exempt OK)."
