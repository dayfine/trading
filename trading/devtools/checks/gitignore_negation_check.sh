#!/bin/sh
# .gitignore directory-negation check.
#
# A directory negation under dev/backtest/ or dev/experiments/ (a line that
# starts with `!` and ends with `/`) re-opens the whole directory to git, so
# any NEW run output written there would show up as untracked and could be
# committed by accident. Every such negation must be followed, later in the
# file, by the exact re-ignore line `<dir>/*` (the `!` stripped), after which
# individual records are re-included file by file.
#
# The anchored form `!/dev/backtest/<dir>/` is checked too. In a root
# .gitignore a leading slash is redundant for a pattern that already contains a
# slash, so `<dir>/*` and `/<dir>/*` are equivalent; either re-ignore clears
# either negation form.
#
# Origin: qc-behavioral on PR #3321 -- the first draft used `!dir/*/` with no
# re-ignore. This is the parse-only variant (no `git check-ignore`), because
# the dune sandbox does not reliably expose `.git`.
#
# Usage: gitignore_negation_check.sh [path/to/.gitignore]
#   default: <repo root>/.gitignore
# Output: OK line, or FAIL with each offending `file:line: text`; exit 1.

. "$(dirname "$0")/_check_lib.sh"

if [ -n "$1" ]; then
  gi="$1"
else
  gi="$(repo_root)/.gitignore"
fi
[ -f "$gi" ] || { echo "FAIL: gitignore_negation_check: $gi not found"; exit 1; }

# Single awk pass: remember each in-scope directory negation with its line
# number; a later line equal to "<dir>*" (dir ends in /) clears it.
violations=$(awk '
  /^!\/?(dev\/backtest\/|dev\/experiments\/).*\/$/ {
    d = substr($0, 2)
    if (substr(d, 1, 1) == "/") d = substr(d, 2)   # anchored form: key on the bare dir
    pending[d] = NR; text[d] = $0
    next
  }
  {
    for (d in pending) if ($0 == d "*" || $0 == "/" d "*") delete pending[d]
  }
  END { for (d in pending) printf "%d: %s\n", pending[d], text[d] }
' "$gi" | sort -n)

if [ -n "$violations" ]; then
  echo "FAIL: gitignore_negation_check: directory negation without a following '<dir>/*' re-ignore in $gi:"
  echo "$violations" | sed 's/^/  line /'
  echo "  Fix: add '<dir>/*' after the negation, then re-include only the records to track."
  exit 1
fi
echo "OK: gitignore_negation_check -- every dev/backtest|experiments directory negation is re-ignored."
