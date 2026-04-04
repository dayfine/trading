#!/bin/sh
# Formatting gate: all .ml and .mli source files must be formatted with
# ocamlformat. Fails if any file differs from what ocamlformat would produce.
#
# Uses `ocamlformat --check` which exits non-zero when a file needs
# reformatting, without modifying it.
#
# Run `dune fmt` to fix all violations at once.

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

for f in $(find "$TRADING_DIR" \( -name "*.ml" -o -name "*.mli" \) \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml" \
    -not -name "*.pp.mli" \
    -not -path "*/ta_ocaml/*"); do
  if ! ocamlformat --check "$f" 2>/dev/null; then
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
