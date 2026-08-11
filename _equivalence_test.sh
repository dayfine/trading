#!/bin/sh
# Scratch equivalence-test harness for the magic_numbers_linter rewrite.
# NOT part of the repo -- deleted before the final commit.
#
# Builds a fixture tree exercising every skip rule + extraction edge case,
# runs the ORIGINAL shell script (reconstructed from the pre-removal repo
# text, since the .sh file itself was deleted as part of this PR) and the
# new OCaml exe against it, and diffs the substantive parts of the output.

set -eu

FX="$(mktemp -d)"
trap 'rm -rf "$FX"' EXIT

ORIGINAL_SH="/workspaces/trading-1/.claude/worktrees/agent-ab114f6c3c408d810/.claude/worktrees/jjws-harness-fastmagic-1786407996/_scratch_original_linter_magic_numbers.sh"
CHECK_LIB="/workspaces/trading-1/.claude/worktrees/agent-ab114f6c3c408d810/.claude/worktrees/jjws-harness-fastmagic-1786407996/trading/devtools/checks/_check_lib.sh"
NEW_EXE="/workspaces/trading-1/.claude/worktrees/agent-ab114f6c3c408d810/.claude/worktrees/jjws-harness-fastmagic-1786407996/trading/_build/default/devtools/magic_numbers_linter/magic_numbers_linter.exe"

mkdir -p "${FX}/scripts/checks"
mkdir -p "${FX}/lib"
mkdir -p "${FX}/excluded_dir/lib"
mkdir -p "${FX}/_build/lib"
mkdir -p "${FX}/.formatted/lib"
mkdir -p "${FX}/notlib"
mkdir -p "${FX}/somemod/lib/unreadable_dir.ml"

cp "$CHECK_LIB" "${FX}/scripts/checks/"
cp "$ORIGINAL_SH" "${FX}/scripts/checks/linter_magic_numbers_ORIGINAL.sh"
chmod +x "${FX}/scripts/checks/linter_magic_numbers_ORIGINAL.sh"

cat > "${FX}/scripts/checks/linter_exceptions.conf" <<'EOF'
magic_numbers excluded_dir  test-only exclusion for the equivalence fixture  # review_at: never
EOF

# --- Main fixture file: one test case per line/block, numbered in comments
# above each so failures are easy to locate. ---
cat > "${FX}/lib/fixture_a.ml" <<'EOF'
(* case 1: plain call, should flag 42 *)
foo bar 42 baz
(* case 2: 2+ digit integer, should flag 250 *)
process_batch 250
(* case 3: single digit never captured by the regex, not flagged *)
value 7
(* case 4: float, should flag 3.14 *)
compute 3.14 tail
(* case 5: exempt literal 100.0, not flagged *)
apply 100.0 percent
(* case 6: exempt literal 2.0, not flagged *)
use 2.0 half
(* case 7: config-routed, whole line skipped *)
config.threshold 42
(* case 8: variant arm, whole line skipped *)
Stage1 _ -> 42
(* case 9: labeled arg, whole line skipped *)
foo ~len:42 bar
(* case 10: single-line comment, skipped *)
(* 42 is a magic number *)
(* case 11: multi-line comment depth tracking *)
(* start comment
   42 in the middle should be skipped
   end *)
real_call 42
(* case 12: backslash-continued line, skipped despite containing 42 *)
wrap_call 42 \
continuation_tail
(* case 13: odd quote count (string continuation), skipped despite 42 *)
broken "quote start 42
(* case 14: number entirely inside a balanced quoted string, not flagged *)
log_msg "value is 42 today"
(* case 15: number outside quotes on a line that also has quotes, flagged *)
compute_value 42 label "some text"
(* case 16: digit run glued to an identifier, not flagged *)
identifier42value okay
(* case 17: dotted version-like token, not flagged (PCRE backtrack exhausts) *)
version v1.2.3 here
(* case 18: let-binding named-constant, whole line skipped *)
let max_len = 42
(* case 19: record field default, whole line skipped *)
threshold_default = 42
(* case 20: negative default, whole line skipped *)
y = -42
(* case 21: clean unambiguous violation *)
Array.make 42 0.0
EOF

# --- .pp.ml exclusion: matches "/lib/" but excluded by name. ---
cat > "${FX}/lib/generated.pp.ml" <<'EOF'
generated_call 42
EOF

# --- path-excluded directory (matches linter_exceptions.conf entry). ---
cat > "${FX}/excluded_dir/lib/fixture_b.ml" <<'EOF'
excluded_call 99
EOF

# --- pruned dirs: _build and .formatted must never be scanned. ---
cat > "${FX}/_build/lib/should_be_pruned.ml" <<'EOF'
pruned_call 42
EOF
cat > "${FX}/.formatted/lib/should_be_pruned2.ml" <<'EOF'
pruned_call 43
EOF

# --- not under a "lib" dir at all: must never be scanned. ---
cat > "${FX}/notlib/random.ml" <<'EOF'
not_scanned_call 42
EOF

echo "=== OLD (original shell script) ==="
OLD_OUT=$(sh "${FX}/scripts/checks/linter_magic_numbers_ORIGINAL.sh" 2>&1) && OLD_CODE=0 || OLD_CODE=$?
echo "$OLD_OUT"
echo "exit:${OLD_CODE}"

echo ""
echo "=== NEW (OCaml exe) ==="
NEW_OUT=$("$NEW_EXE" "$FX" "${FX}/scripts/checks/linter_exceptions.conf" 2>&1) && NEW_CODE=0 || NEW_CODE=$?
echo "$NEW_OUT"
echo "exit:${NEW_CODE}"

echo ""
echo "=== Normalized diff (path prefix stripped, sorted) ==="
printf '%s\n' "$OLD_OUT" | sed -E 's#^[^:]*\.ml: #: #; s#^[^:]*\.ml/: #: #' | sort > "${FX}/old_norm.txt"
printf '%s\n' "$NEW_OUT" | sed -E 's#^[^:]*\.ml: #: #; s#^[^:]*\.ml/: #: #' | sort > "${FX}/new_norm.txt"
if diff -u "${FX}/old_norm.txt" "${FX}/new_norm.txt"; then
  echo "NORMALIZED DIFF: EMPTY (match)"
else
  echo "NORMALIZED DIFF: NON-EMPTY (see above)"
fi
echo "old_exit=${OLD_CODE} new_exit=${NEW_CODE}"
