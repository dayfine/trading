#!/bin/sh
# Perf-catalog integrity check.
#
# Asserts every scenario sexp under trading/test_data/backtest_scenarios/
# (excluding [universes/] and [experiments/], which are not catalog
# entries) carries a [;; perf-tier: <1|2|3|4>] header line. The tier
# system + format are documented in dev/plans/perf-scenario-catalog-2026-04-25.md.
#
# Also cross-checks that every scenario claimed by the perf tier-1
# workflow actually exists on disk and has [perf-tier: 1] (so the
# workflow can't silently drift away from the tag set).
#
# Failure semantics (see plan §"Decision items" #3):
#   PERF_CATALOG_CHECK_STRICT=1 -> exit 1 on any violation (gate the build)
#   default                     -> emit WARNING lines, exit 0 (annotate only)
#
# We start in annotate-only mode because the catalog will evolve; the
# check exists primarily to prevent NEW scenarios from being added
# without a tier tag. Flip strict mode on once the catalog is stable
# (decision-items item #3 carried in dev/status/backtest-perf.md).

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
TIER1_WORKFLOW="${REPO_ROOT}/.github/workflows/perf-tier1.yml"

STRICT="${PERF_CATALOG_CHECK_STRICT:-0}"

if [ ! -d "$SCENARIO_ROOT" ]; then
  echo "OK: perf-catalog check skipped (no $SCENARIO_ROOT)."
  exit 0
fi

VIOLATIONS=""
TAGGED_COUNT=0
UNTAGGED_COUNT=0

# Scenario directories that are part of the catalog. Anything outside
# these (universes/, experiments/, panel_goldens/, ...) is not a
# tier-tagged scenario and is skipped.
CATALOG_DIRS="goldens-small
goldens-broad
perf-sweep
smoke"

for sub in $CATALOG_DIRS; do
  dir="${SCENARIO_ROOT}/${sub}"
  [ -d "$dir" ] || continue
  for sexp in "$dir"/*.sexp; do
    [ -f "$sexp" ] || continue
    rel="${sexp#${REPO_ROOT}/}"
    if grep -q '^;; perf-tier:' "$sexp"; then
      TAGGED_COUNT=$((TAGGED_COUNT + 1))
    else
      UNTAGGED_COUNT=$((UNTAGGED_COUNT + 1))
      VIOLATIONS="${VIOLATIONS}MISSING_TAG ${rel}\n"
    fi
  done
done

# Cross-check: every scenario referenced from perf-tier1.yml must exist
# AND carry [;; perf-tier: 1]. Format inside the workflow: paths
# appear under a heredoc / list with full repo-relative path. We grep
# the workflow file for any line ending in `.sexp` and validate each.
WORKFLOW_VIOLATIONS=""
if [ -f "$TIER1_WORKFLOW" ]; then
  # Extract every .sexp basename or relative path mentioned in the workflow.
  # Strip leading whitespace + comment markers, then look for tokens ending
  # in .sexp.
  workflow_paths=$(grep -oE '[A-Za-z0-9_./-]+\.sexp' "$TIER1_WORKFLOW" | sort -u)
  for wp in $workflow_paths; do
    # Resolve relative path -- the workflow paths are relative to repo root.
    full_path="${REPO_ROOT}/${wp}"
    if [ ! -f "$full_path" ]; then
      WORKFLOW_VIOLATIONS="${WORKFLOW_VIOLATIONS}WORKFLOW_PATH_NOT_FOUND ${wp}\n"
      continue
    fi
    if ! grep -q '^;; perf-tier: 1' "$full_path"; then
      WORKFLOW_VIOLATIONS="${WORKFLOW_VIOLATIONS}WORKFLOW_PATH_NOT_TIER1 ${wp}\n"
    fi
  done
fi

TOTAL=$((TAGGED_COUNT + UNTAGGED_COUNT))

if [ -n "$VIOLATIONS" ] || [ -n "$WORKFLOW_VIOLATIONS" ]; then
  if [ "$STRICT" = "1" ]; then
    LABEL="FAIL"
  else
    LABEL="WARNING"
  fi
  printf '%s: perf-catalog check -- %d tagged / %d untagged of %d scenarios.\n' \
    "$LABEL" "$TAGGED_COUNT" "$UNTAGGED_COUNT" "$TOTAL"
  if [ -n "$VIOLATIONS" ]; then
    printf '\nMissing [;; perf-tier:] header:\n'
    printf '%b' "$VIOLATIONS"
  fi
  if [ -n "$WORKFLOW_VIOLATIONS" ]; then
    printf '\nWorkflow %s drift:\n' "$TIER1_WORKFLOW"
    printf '%b' "$WORKFLOW_VIOLATIONS"
  fi
  printf '\nFix: add [;; perf-tier: <1|2|3|4>] + [;; perf-tier-rationale: ...]\n'
  printf '     to the top of each scenario sexp. See\n'
  printf '     dev/plans/perf-scenario-catalog-2026-04-25.md.\n'
  if [ "$STRICT" = "1" ]; then
    exit 1
  fi
  exit 0
fi

echo "OK: perf-catalog check -- ${TAGGED_COUNT} scenarios all carry tier tags."
