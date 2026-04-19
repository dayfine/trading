#!/bin/sh
# Check 1: Dead code — .ml files in lib/ not referenced by any dune file.
#
# Usage: sh check_01_dead_code.sh <report_file> [findings_file]
#   report_file    Path of the report file; this check appends its detail section.
#   findings_file  Optional. When present (orchestrated mode), severity findings
#                  and metrics are written here for main.sh to assemble into the
#                  consolidated summary. When absent (standalone), findings are
#                  written inline into the report.
#
# Exits non-zero only if the check itself errors (bad args, etc.).

set -e

REPORT_FILE="${1:?Usage: check_01_dead_code.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 1: Dead code — .ml files in lib/ not referenced by dune
# ────────────────────────────────────────────────────────────────

DEAD_CODE_COUNT=0

# Build set of modules listed in dune files (library stanzas implicitly
# include all .ml files in their directory, so a file is "referenced" if
# it lives in a directory that has a dune file with a library stanza).
# Files outside any library directory are dead code candidates.
for ml_file in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml"); do
  lib_dir="$(dirname "$ml_file")"
  dune_file="${lib_dir}/dune"
  if [ ! -f "$dune_file" ]; then
    DEAD_CODE_COUNT=$((DEAD_CODE_COUNT + 1))
    rel_path="${ml_file#"$TRADING_DIR"/}"
    add_info "Dead code candidate: \`${rel_path}\` — no dune file in its lib/ directory"
  fi
done

# Also check for .ml files in lib/ directories whose dune file uses
# (modules ...) — files not listed in the modules stanza are dead.
for dune_file in $(find "$TRADING_DIR" -path "*/lib/dune" \
    -not -path "*/_build/*"); do
  if grep -q '(modules' "$dune_file" 2>/dev/null; then
    lib_dir="$(dirname "$dune_file")"
    # Extract module names from (modules ...) — this is a rough parse
    modules_line="$(sed -n '/(modules/,/)/p' "$dune_file" | tr '\n' ' ')"
    for ml_file in "$lib_dir"/*.ml; do
      [ -f "$ml_file" ] || continue
      basename_no_ext="$(basename "$ml_file" .ml)"
      # Skip .mli-only check; just check .ml
      if ! echo "$modules_line" | grep -qi "$basename_no_ext"; then
        DEAD_CODE_COUNT=$((DEAD_CODE_COUNT + 1))
        rel_path="${ml_file#"$TRADING_DIR"/}"
        add_info "Dead code candidate: \`${rel_path}\` — not listed in (modules ...) stanza"
      fi
    done
  fi
done

add_metric DEAD_CODE_COUNT "$DEAD_CODE_COUNT"
flush_findings
