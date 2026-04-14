#!/bin/sh
# @testing-only enforcement: libraries annotated with "; @testing-only" in
# their dune file must not appear in any (library ...) stanza's (libraries ...)
# list. They may only be depended on by (test ...) and (tests ...) stanzas.
#
# Annotation syntax — comment on the line immediately before the stanza:
#
#   ; @testing-only
#   (library
#    (name my_test_support_lib)
#    (public_name some.public.name)
#    ...)
#
# The checker collects both the internal name and public_name (if any) and
# flags either if they appear in a (library ...) dependency list.

set -e

. "$(dirname "$0")/_check_lib.sh"

ROOT="$(trading_dir)"
TMPFILE=$(mktemp /tmp/testing_only_libs.XXXXXX)
trap 'rm -f "$TMPFILE"' EXIT

# ── Step 1: collect @testing-only library names (internal + public) ───────────

find "$ROOT" -name "dune" | while IFS= read -r dune_file; do
  awk '
    /; @testing-only/ { annotated = 1; next }
    annotated && /\(library/ { in_lib = 1; next }
    in_lib && /\(name[ \t]/ {
      gsub(/.*\(name[ \t]+/, ""); gsub(/\).*/, ""); gsub(/^[ \t]+|[ \t]+$/, "")
      print
    }
    in_lib && /\(public_name[ \t]/ {
      gsub(/.*\(public_name[ \t]+/, ""); gsub(/\).*/, ""); gsub(/^[ \t]+|[ \t]+$/, "")
      print
    }
    in_lib && /^\)/ { in_lib = 0; annotated = 0 }
    !in_lib { annotated = 0 }
  ' "$dune_file"
done | sort -u > "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
  echo "OK: no @testing-only libraries defined."
  exit 0
fi

# ── Step 2: check no (library ...) stanza depends on them ─────────────────────

VIOLATIONS=""

while IFS= read -r lib_name; do
  [ -z "$lib_name" ] && continue
  matches=$(
    find "$ROOT" -name "dune" | while IFS= read -r f; do
      awk -v lib="$lib_name" '
        /^\(library[ \t]/ { in_lib = 1 }
        /^\(tests?[ \t(]/ { in_lib = 0 }
        /^\)/ && in_lib { in_lib = 0 }
        in_lib {
          for (i = 1; i <= NF; i++) {
            field = $i; gsub(/[()"]/, "", field)
            if (field == lib) {
              print FILENAME ":" NR ": " $0
            }
          }
        }
      ' "$f"
    done
  )
  if [ -n "$matches" ]; then
    VIOLATIONS="${VIOLATIONS}  library \"${lib_name}\":
${matches}
"
  fi
done < "$TMPFILE"

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: @testing-only library used in a (library ...) stanza:"
  printf '%s\n' "$VIOLATIONS"
  echo "Testing-only libraries may only appear in (test ...) or (tests ...) dependencies."
  exit 1
fi

echo "OK: no @testing-only libraries used in production library stanzas."
