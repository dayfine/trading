#!/bin/sh
# Regression test for H-CHECK-SETE-DIAGNOSTICS.
#
# The bug: several trading/devtools/checks/*.sh scripts run under `set -e`
# with the shape `VAR=$(cmd); CODE=$?`. Under `set -e`, a bare command-
# substitution assignment whose command fails trips `set -e` on the
# assignment itself -- the script dies BEFORE `CODE=$?` (or any FAIL:
# message) is ever reached. Detection still works from the outside (dune
# sees a non-zero exit -> CI red), but the failure surfaces as "non-zero
# exit, empty output, no source-level error" -- exactly the signature
# `.claude/rules/pr-merge-gates.md` documents as an admissible infra-flake
# exception. A real regression can get waved through triage as a sandbox
# race unless the diagnostic survives.
#
# This test proves two things using a fake `jj` binary that fails only on
# `workspace list` (simulating a real jj failure -- lock contention, a
# corrupt workspace, a version-skew syntax break):
#
#   1. NEGATIVE CONTROL: the pre-fix shape (reproduced literally below, not
#      read from git history -- see note at OLD_SCRIPT) dies with a
#      non-zero exit and ZERO diagnostic output when the underlying command
#      fails. This proves the bug is real, not theoretical.
#   2. THE FIX: jj_workspace_smoke.sh's current logic (which wraps the same
#      assignment in `&& CODE=0 || CODE=$?`, per its Step 2 comment) emits a
#      "FAIL: jj_workspace_smoke —" line naming the failure and still exits
#      non-zero. The diagnostic now survives the exact failure the negative
#      control reproduced.
#
# Why the negative control is a literal reproduction instead of `git show
# <old-sha>:...`: this test must keep working on every future commit,
# including in a shallow CI checkout that may not have the pre-fix commit
# in its fetched history. A self-contained reproduction has no such
# dependency.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="sete_diagnostics_check"
PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

REPO_ROOT_REAL="$(repo_root)"
JJ_SMOKE="${REPO_ROOT_REAL}/trading/devtools/checks/jj_workspace_smoke.sh"
[ -f "$JJ_SMOKE" ] || die "sete_diagnostics_check: $JJ_SMOKE does not exist"

FAKE_BIN="$(mktemp -d)"
OLD_SCRIPT="$(mktemp)"
trap 'rm -rf "$FAKE_BIN" "$OLD_SCRIPT"' EXIT INT TERM

# --- Fake `jj`: succeeds on every subcommand except `workspace list` ---
cat > "${FAKE_BIN}/jj" <<'EOF'
#!/bin/sh
case "$*" in
  *"workspace list"*)
    echo "SIMULATED: jj workspace list failed (fake binary for sete_diagnostics_check)" >&2
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/jj"

# ---------------------------------------------------------------------------
# Part 1 (negative control): the pre-fix shape of jj_workspace_smoke.sh's
# Step 2 --
#   WS_LIST=$(jj -R "$REPO" workspace list 2>&1)
#   if ! echo "$WS_LIST" | grep -qF "$AGENT_ID"; then ...
# reproduced literally (see the note above for why this is not `git show`).
# ---------------------------------------------------------------------------
cat > "$OLD_SCRIPT" <<'EOF'
#!/bin/sh
set -e
REPO="fake-repo"
AGENT_ID="fake-agent"
WS_LIST=$(jj -R "$REPO" workspace list 2>&1)
if ! echo "$WS_LIST" | grep -qF "$AGENT_ID"; then
  echo "FAIL: jj_workspace_smoke (old) — 'jj workspace list' does not include '$AGENT_ID'."
  exit 1
fi
echo "OK: jj_workspace_smoke (old) — unreachable if jj workspace list had failed"
EOF
chmod +x "$OLD_SCRIPT"

OLD_OUT=$(PATH="${FAKE_BIN}:${PATH}" sh "$OLD_SCRIPT" 2>&1) && OLD_CODE=0 || OLD_CODE=$?

if [ "$OLD_CODE" -ne 0 ] && ! printf '%s' "$OLD_OUT" | grep -q '^FAIL:'; then
  ok "${LABEL} — negative control: pre-fix shape dies (exit=${OLD_CODE}) with NO FAIL: line (output: '${OLD_OUT}') -- reproduces the silent-failure bug"
else
  bad "${LABEL} — negative control did NOT reproduce the bug: expected non-zero exit with no FAIL: line, got exit=${OLD_CODE} output='${OLD_OUT}'"
fi

# ---------------------------------------------------------------------------
# Part 2 (the fix): jj_workspace_smoke.sh's current Step 2 must name the
# failure instead of dying silently.
# ---------------------------------------------------------------------------
NEW_OUT=$(PATH="${FAKE_BIN}:${PATH}" REPO_ROOT="$REPO_ROOT_REAL" sh "$JJ_SMOKE" 2>&1) && NEW_CODE=0 || NEW_CODE=$?

if [ "$NEW_CODE" -ne 0 ] && printf '%s' "$NEW_OUT" | grep -q '^FAIL: jj_workspace_smoke'; then
  ok "${LABEL} — fix: jj_workspace_smoke.sh emits a FAIL: line naming the 'jj workspace list' failure (exit=${NEW_CODE})"
else
  bad "${LABEL} — expected a 'FAIL: jj_workspace_smoke' line and non-zero exit; got exit=${NEW_CODE} output='${NEW_OUT}'"
fi

# ---------------------------------------------------------------------------
# Parts 3-4: the two linter fixes (linter_file_length.sh, linter_magic_numbers.sh).
#
# 2026-07-29 qc-behavioral rework (FINDING-1, FINDING-2): the first version of
# this PR fixed both linters with a blanket `|| continue`, which cannot tell
# "file vanished (TOCTOU race)" apart from "file exists but is unreadable" --
# collapsing a real violation on an unreadable file into a false green, and
# this test only covered the `jj` fix (1 of 3), leaving that regression
# unpinned. These two parts close both gaps: they exercise the FALSE-GREEN
# scenario specifically (an existing file whose read fails), which is the
# scenario that matters most -- it pins both the original TOCTOU guard
# (vanished files must still be skipped, tested implicitly: neither fixture
# below ever hits the vanished branch, so a regression there would not
# regress this test, but IS covered by the vanished-path code review + the
# `find ... || true` precedent it mirrors) and the FINDING-1 regression
# (unreadable-but-present files must FAIL, never silently pass).
#
# Fixture: a DIRECTORY named to look like a `lib/*.ml` file. `find -path
# "*/lib/*.ml"` has no `-type f` restriction, so a directory matches and is
# printed just like a real file; any bare read of it (`wc -l <`, `while ...
# done <`) fails deterministically. This is deliberately NOT a chmod-000
# file: this check may run as root, and access(2) lets root bypass DAC
# permission checks entirely (chmod 000 is still readable by root) -- a
# directory-as-file is the one read-failure mode that is privilege-independent.

_make_unreadable_fixture() {
  dest="$1"
  linter_script="$2"
  mkdir -p "${dest}/devtools/checks"
  cp "${REPO_ROOT_REAL}/trading/devtools/checks/_check_lib.sh" "${dest}/devtools/checks/"
  cp "${REPO_ROOT_REAL}/trading/devtools/checks/${linter_script}" "${dest}/devtools/checks/"
  mkdir -p "${dest}/somemod/lib/unreadable_dir.ml"
}

# --- Part 3: linter_file_length.sh ---

FIX3_OLD="$(mktemp -d)"
OLD_FL_SCRIPT="$(mktemp)"
mkdir -p "${FIX3_OLD}/somemod/lib/unreadable_dir.ml"
cat > "$OLD_FL_SCRIPT" <<'EOF'
#!/bin/sh
set -e
VIOLATIONS=""
for ml_file in $(find "$1" -path "*/lib/*.ml" -print 2>/dev/null || true); do
  line_count=$(wc -l < "$ml_file" 2>/dev/null) || continue
  if [ "$line_count" -gt 300 ]; then
    VIOLATIONS="${VIOLATIONS}${ml_file}: ${line_count} lines\n"
  fi
done
if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: file length linter:"
  printf '%b' "$VIOLATIONS"
  exit 1
fi
echo "OK: all lib/*.ml files within limits."
EOF
chmod +x "$OLD_FL_SCRIPT"

OLD_FL_OUT=$(sh "$OLD_FL_SCRIPT" "$FIX3_OLD" 2>&1) && OLD_FL_CODE=0 || OLD_FL_CODE=$?
if [ "$OLD_FL_CODE" -eq 0 ] && printf '%s' "$OLD_FL_OUT" | grep -q '^OK:'; then
  ok "${LABEL} — negative control (file_length): pre-fix bare '|| continue' gives a FALSE GREEN ('${OLD_FL_OUT}') on an unreadable-but-present file -- reproduces FINDING-1"
else
  bad "${LABEL} — negative control (file_length) did NOT reproduce FINDING-1: expected exit 0 with an OK: line, got exit=${OLD_FL_CODE} output='${OLD_FL_OUT}'"
fi
rm -rf "$FIX3_OLD" "$OLD_FL_SCRIPT"

FIX3_NEW="$(mktemp -d)"
_make_unreadable_fixture "$FIX3_NEW" "linter_file_length.sh"
NEW_FL_OUT=$(sh "${FIX3_NEW}/devtools/checks/linter_file_length.sh" 2>&1) && NEW_FL_CODE=0 || NEW_FL_CODE=$?
if [ "$NEW_FL_CODE" -ne 0 ] && printf '%s' "$NEW_FL_OUT" | grep -qF "unreadable_dir.ml"; then
  ok "${LABEL} — fix (file_length): linter_file_length.sh FAILs and names unreadable_dir.ml instead of a false green (exit=${NEW_FL_CODE})"
else
  bad "${LABEL} — expected linter_file_length.sh to FAIL naming unreadable_dir.ml; got exit=${NEW_FL_CODE} output='${NEW_FL_OUT}'"
fi
rm -rf "$FIX3_NEW"

# --- Part 4: linter_magic_numbers.sh ---

FIX4_OLD="$(mktemp -d)"
OLD_MN_SCRIPT="$(mktemp)"
mkdir -p "${FIX4_OLD}/somemod/lib/unreadable_dir.ml"
cat > "$OLD_MN_SCRIPT" <<'EOF'
#!/bin/sh
set -e
VIOLATIONS=""
for f in $(find "$1" -path "*/lib/*.ml" -print 2>/dev/null || true); do
  while IFS= read -r line; do
    case "$line" in
      *[0-9][0-9]*) VIOLATIONS="${VIOLATIONS}${f}: number in: ${line}\n" ;;
    esac
  done < "$f" || continue
done
if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: magic number linter:"
  printf '%b' "$VIOLATIONS"
  exit 1
fi
echo "OK: no magic numbers found in lib/ files."
EOF
chmod +x "$OLD_MN_SCRIPT"

OLD_MN_OUT=$(sh "$OLD_MN_SCRIPT" "$FIX4_OLD" 2>&1) && OLD_MN_CODE=0 || OLD_MN_CODE=$?
if [ "$OLD_MN_CODE" -eq 0 ] && printf '%s' "$OLD_MN_OUT" | grep -q '^OK:'; then
  ok "${LABEL} — negative control (magic_numbers): pre-fix bare 'done < \$f || continue' gives a FALSE GREEN ('${OLD_MN_OUT}') on an unreadable-but-present file -- reproduces FINDING-1"
else
  bad "${LABEL} — negative control (magic_numbers) did NOT reproduce FINDING-1: expected exit 0 with an OK: line, got exit=${OLD_MN_CODE} output='${OLD_MN_OUT}'"
fi
rm -rf "$FIX4_OLD" "$OLD_MN_SCRIPT"

FIX4_NEW="$(mktemp -d)"
_make_unreadable_fixture "$FIX4_NEW" "linter_magic_numbers.sh"
NEW_MN_OUT=$(sh "${FIX4_NEW}/devtools/checks/linter_magic_numbers.sh" 2>&1) && NEW_MN_CODE=0 || NEW_MN_CODE=$?
if [ "$NEW_MN_CODE" -ne 0 ] && printf '%s' "$NEW_MN_OUT" | grep -qF "unreadable_dir.ml"; then
  ok "${LABEL} — fix (magic_numbers): linter_magic_numbers.sh FAILs and names unreadable_dir.ml instead of a false green (exit=${NEW_MN_CODE})"
else
  bad "${LABEL} — expected linter_magic_numbers.sh to FAIL naming unreadable_dir.ml; got exit=${NEW_MN_CODE} output='${NEW_MN_OUT}'"
fi
rm -rf "$FIX4_NEW"

# ---------------------------------------------------------------------------
# Part 5 (H-WRITE-AUDIT-SHEBANG-MISMATCH N4): pin the bash-only decision.
# write_audit.sh requires bash (`set -o pipefail`); invoking it under `sh`
# (dash in this container) must fail immediately and loudly at the `set`
# line naming `pipefail`, never silently or with an unrelated error.
# ---------------------------------------------------------------------------
WA_SCRIPT="${REPO_ROOT_REAL}/trading/devtools/checks/write_audit.sh"
WA_SH_OUT=$(sh "$WA_SCRIPT" 2>&1) && WA_SH_CODE=0 || WA_SH_CODE=$?
if [ "$WA_SH_CODE" -ne 0 ] && printf '%s' "$WA_SH_OUT" | grep -qi 'pipefail'; then
  ok "${LABEL} — write_audit.sh under sh fails loudly naming pipefail (exit=${WA_SH_CODE}), confirms the bash-only decision (H-WRITE-AUDIT-SHEBANG-MISMATCH N4)"
else
  bad "${LABEL} — expected 'sh write_audit.sh' to fail mentioning pipefail; got exit=${WA_SH_CODE} output='${WA_SH_OUT}'"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: ${LABEL} — ${PASS} assertion(s) passed, 0 failed."
