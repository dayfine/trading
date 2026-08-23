#!/bin/sh
# backtest_appendix_drift_check.sh — PR-time gate for the backtest/
# subdirectory inventory appendix in
# dev/plans/backtest-scale-optimization-2026-04-17.md.
#
# WHY THIS EXISTS
#
#   The appendix table has drifted from new feature PRs landing a new
#   trading/trading/backtest/ subdirectory without adding a row for it —
#   twice already (PR #2096 added the table; PR #2461 reconciled 4 missing
#   rows on 2026-08-21; see dev/status/cleanup.md's
#   design_doc_drift_mechanization item). A hand-maintained snapshot table
#   will keep recurring without a mechanical check.
#
#   A detector for this drift CLASS already exists —
#   deep_scan/check_02_design_doc_drift.sh has a backtest-plan block — but
#   it (a) only runs on the weekly deep-scan cadence, not per PR, and
#   (b) is warning-only (add_warning, never fails the build). Drift
#   accumulates silently between scans and gets fixed by hand, repeatedly.
#   This script closes that specific gap: same drift class, wired into
#   every `dune runtest`, and it FAILS instead of warning.
#
# WHAT IT CHECKS
#
#   Every subdirectory under trading/trading/backtest/, EXCLUDING lib/,
#   test/, and scenarios/, must have a matching row in the appendix table —
#   the `| \`<name>/\` | <description> |` rows under the
#   "## Appendix: `trading/trading/backtest/` subdirectory inventory"
#   heading.
#
#   The lib/test/scenarios exclusion is NOT an accident of the glob — it is
#   the plan file's own documented scope note (added 2026-08-21, in the
#   paragraph starting "Scope note ..."): those three are the foundational
#   package layout that predates the plan (April 2026), not separately
#   planned work, so the appendix intentionally omits them. This script
#   hardcodes the same three names below (EXCLUDED_SUBDIRS) rather than
#   re-deriving them from the doc, so a change to that exclusion set is a
#   deliberate two-file edit (doc + script), not a silent divergence.
#
#   This is a NARROWER, STRICTER check than deep_scan's check_02: check_02
#   greps the whole plan-file TEXT for the subdir name (a loose substring
#   match anywhere in the doc, including prose); this script requires an
#   actual TABLE ROW under the appendix heading specifically. A subdir name
#   that merely happens to appear in a sentence elsewhere in the plan does
#   NOT satisfy this check.
#
# VACUOUS-PASS GUARDS
#
#   This checks suite's recurring defect class is a check that reports OK
#   having scanned nothing (or having silently swallowed an error). Three
#   guards close that off here, each a hard `die` (exit 1), never a silent
#   "0 drifted":
#     1. The appendix heading is not found in the plan file.
#     2. The heading is found but zero table rows parse out of it.
#     3. Zero subdirectories are found on disk (after exclusions).
#   All three are exercised by backtest_appendix_drift_check_test.sh, which
#   also proves each guard actually fires by deleting it and re-running
#   against fixtures that would otherwise report a false OK.
#
# USAGE
#
#   sh backtest_appendix_drift_check.sh
#
#   Honors the same REPO_ROOT override as _check_lib.sh's repo_root(), so a
#   test can point this at a synthetic fixture tree instead of the real
#   repo. backtest_appendix_drift_check_test.sh does exactly that.
#
# Exit status: 0 = every on-disk subdir (minus the documented exclusions)
# has an appendix row. 1 = at least one is missing a row, OR any vacuous-
# pass guard above tripped, OR the plan file / backtest dir does not exist.

set -eu

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_RESOLVED="$(repo_root)"

PLAN_FILE="${REPO_ROOT_RESOLVED}/dev/plans/backtest-scale-optimization-2026-04-17.md"
BACKTEST_DIR="${REPO_ROOT_RESOLVED}/trading/trading/backtest"

# Documented exclusion (plan file's own "Scope note", added 2026-08-21): the
# foundational package layout that predates the plan, out of scope for the
# appendix table by the plan's own convention. See header comment above.
EXCLUDED_SUBDIRS="lib test scenarios"

APPENDIX_HEADING='## Appendix: `trading/trading/backtest/` subdirectory inventory'

[ -f "$PLAN_FILE" ] || die "backtest_appendix_drift_check: plan file not found at $PLAN_FILE"
[ -d "$BACKTEST_DIR" ] || die "backtest_appendix_drift_check: backtest dir not found at $BACKTEST_DIR"

APPENDIX_ROWS_FILE="$(mktemp)"
ACTUAL_SUBDIRS_FILE="$(mktemp)"
trap 'rm -f "$APPENDIX_ROWS_FILE" "$ACTUAL_SUBDIRS_FILE"' EXIT

# --- Guard 1: appendix heading must exist ---

if ! grep -qF "$APPENDIX_HEADING" "$PLAN_FILE"; then
  die "backtest_appendix_drift_check: appendix heading not found in $PLAN_FILE (expected exactly: $APPENDIX_HEADING). Has the section been renamed or removed? Refusing to report a vacuous pass — fix the heading or this script's APPENDIX_HEADING constant, don't ignore this."
fi

# --- Extract table rows from the heading to EOF ---
# The appendix is the last section in the file today, so "heading to EOF" is
# sufficient; a match failure downstream (guard 2, or a real drift) is the
# fallback if that ever stops being true — never a silent pass.

awk -v heading="$APPENDIX_HEADING" '
  $0 == heading { found = 1 }
  found { print }
' "$PLAN_FILE" \
  | sed -n 's/^| `\([A-Za-z0-9_]*\)\/` |.*/\1/p' \
  > "$APPENDIX_ROWS_FILE"

# --- Guard 2: at least one row must have parsed ---

if [ ! -s "$APPENDIX_ROWS_FILE" ]; then
  die "backtest_appendix_drift_check: found the appendix heading but parsed ZERO table rows from it (expected '| \`name/\` | description |' rows). Table format may have changed out from under this script's sed pattern. Refusing to report a vacuous pass."
fi

# --- List actual subdirectories, minus the documented exclusions ---

for d in "$BACKTEST_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  skip=0
  for ex in $EXCLUDED_SUBDIRS; do
    if [ "$name" = "$ex" ]; then
      skip=1
      break
    fi
  done
  [ "$skip" -eq 1 ] && continue
  printf '%s\n' "$name" >> "$ACTUAL_SUBDIRS_FILE"
done

# --- Guard 3: at least one on-disk subdir must remain after exclusions ---

if [ ! -s "$ACTUAL_SUBDIRS_FILE" ]; then
  die "backtest_appendix_drift_check: found ZERO subdirectories under $BACKTEST_DIR after excluding {$EXCLUDED_SUBDIRS} — expected several. Refusing to report a vacuous pass (this would otherwise look identical to 'no drift')."
fi

sort -u "$APPENDIX_ROWS_FILE" -o "$APPENDIX_ROWS_FILE"
sort -u "$ACTUAL_SUBDIRS_FILE" -o "$ACTUAL_SUBDIRS_FILE"

# --- Diff: any actual subdir with no matching appendix row is drift ---

MISSING="$(comm -23 "$ACTUAL_SUBDIRS_FILE" "$APPENDIX_ROWS_FILE" 2>/dev/null || true)"

if [ -n "$MISSING" ]; then
  echo "FAIL: backtest_appendix_drift_check — subdirectories under trading/trading/backtest/ with no row in the dev/plans/backtest-scale-optimization-2026-04-17.md appendix:"
  printf '%s\n' "$MISSING" | while IFS= read -r name; do
    [ -n "$name" ] && echo "  trading/trading/backtest/${name}/"
  done
  echo ""
  echo "Add a one-line '| \`<name>/\` | <what it does> |' row to the appendix"
  echo "table in the SAME PR that adds the subdirectory — see the plan file's"
  echo "Scope note (added 2026-08-21). This is the recurrence that note warned"
  echo "about; this check exists so a 4th silent drift can't happen."
  exit 1
fi

ACTUAL_COUNT="$(wc -l < "$ACTUAL_SUBDIRS_FILE" | tr -d ' ')"
echo "OK: backtest_appendix_drift_check — ${ACTUAL_COUNT} on-disk subdirectories under trading/trading/backtest/ (excluding {${EXCLUDED_SUBDIRS}}), all have an appendix row."
