#!/bin/sh
# Formatting gate: all .ml and .mli source files must be formatted with
# ocamlformat. Fails if any file differs from what ocamlformat would produce.
#
# Uses `ocamlformat --check` which exits non-zero when a file needs
# reformatting, without modifying it.
#
# Run `dune fmt` to fix all violations at once.
#
# --root (issue #2598): `.ocamlformat` lives at the workspace root
# ($TRADING_DIR, e.g. `trading/.ocamlformat`), but ocamlformat's ancestor
# search for a project root stops at the nearest `dune-project` -- which
# for real source paths under `trading/trading/...` is `trading/trading/`,
# ONE LEVEL BELOW where `.ocamlformat` lives. With no project root
# containing `.ocamlformat`, ocamlformat prints "Ocamlformat disabled" and
# exits 0 on every file -- a permanent, silent no-op. `--root="$TRADING_DIR"`
# pins the project root explicitly to where `.ocamlformat` actually is, so
# `--check` performs the real check instead of silently passing. (`dune
# build @fmt` never hit this: dune's `_build/default` tree contains a copy
# of `.ocamlformat` but no `dune-project`, so its own ancestor search
# resolves cleanly.)

set -e

# Find the workspace root (directory containing dune-workspace) by walking up
# from the script location. Works whether run from source or _build/.
_find_workspace_root() {
  dir="$(cd "$(dirname "$0")" && pwd)"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/dune-workspace" ] && echo "$dir" && return
    dir="$(dirname "$dir")"
  done
  echo "ERROR: could not find dune-workspace" >&2
  exit 1
}

TRADING_DIR="$(_find_workspace_root)"
VIOLATIONS=""

# Name-anchored prunes + race guard: -not -path filters still DESCEND into
# _build, racing dune's concurrent sandbox cleanup (find exits non-zero when a
# dir vanishes mid-walk). Same pattern as no_python_check.sh.
for f in $(find "$TRADING_DIR" \
    \( -name '_build' -o -name '.formatted' -o -name 'ta_ocaml' \) -prune -o \
    \( -name "*.ml" -o -name "*.mli" \) \
    -not -name "*.pp.ml" \
    -not -name "*.pp.mli" \
    -print 2>/dev/null || true); do
  if ! ocamlformat --root="$TRADING_DIR" --check "$f" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}  ${f}\n"
  fi
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: formatting gate — files need ocamlformat:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Run 'dune fmt' to fix all formatting violations."
  exit 1
fi

echo "OK: all .ml/.mli files are correctly formatted."
