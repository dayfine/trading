#!/bin/sh
# Orchestrator for the delisted-aware composition-goldens pipeline.
#
# After fetch_delisted_bars.exe (P2) has populated bars under data/, this
# script chains the 3 follow-on steps:
#
#   1. build_inventory.exe          → refresh data/inventory.sexp
#   2. asset_type_enrichment.exe    → refresh data/symbol_types.sexp
#                                     (with -include-delisted)
#   3. build_composition_universes_runner.exe
#                                   → re-emit goldens-custom-universe/composition/*.sexp
#
# Designed to be safe to re-run after each P2 increment lands. Each step
# is idempotent and overwrites its output file via atomic temp+rename.
#
# Prerequisites:
#   - data/delisted_symbols.sexp (output of fetch_delisted_symbols.exe, P1)
#   - data/<X>/<Y>/<SYM>/data.csv for the delisted symbols you care about
#     (P2 output; partial caches are fine but limit downstream coverage)
#   - EODHD_API_KEY env var available (used by step 2)
#
# Usage:
#   dev/scripts/run_delisted_pipeline.sh
#   dev/scripts/run_delisted_pipeline.sh --skip-rebuild   # steps 1+2 only
#
# Designed to run on the developer host wrapping docker exec. The
# in-container path mirrors what we'd run by hand.
#
# Exit codes: 0 on success, non-zero on the first step that fails.
#
# Companion docs:
#   dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md §"Concrete unblock path"
#   dev/notes/next-session-priorities-2026-05-20.md §P0
#
# Companion PRs: #1184 (P1), #1185 (P2), #1186 (P3).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONTAINER="${TRADING_CONTAINER:-trading-1-dev}"

SKIP_REBUILD=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-rebuild) SKIP_REBUILD=1; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0 ;;
    *)
      printf 'Unknown arg: %s (use --help)\n' "$1" >&2
      exit 1 ;;
  esac
done

if [ -z "${EODHD_API_KEY:-}" ]; then
  printf 'FAIL: EODHD_API_KEY env var is required (set on the host before running)\n' >&2
  exit 1
fi

if ! docker exec "$CONTAINER" true 2>/dev/null; then
  printf 'FAIL: docker container "%s" is not responsive\n' "$CONTAINER" >&2
  exit 1
fi

_run_in_container() {
  docker exec -e EODHD_API_KEY="$EODHD_API_KEY" "$CONTAINER" bash -c "$1"
}

printf '=== Step 1/3: build_inventory.exe ===\n'
_run_in_container '
  cd /workspaces/trading-1/trading && eval $(opam env) > /dev/null
  dune exec --no-build analysis/scripts/build_inventory/build_inventory.exe -- \
    -data-dir /workspaces/trading-1/data
'

printf '\n=== Step 2/3: asset_type_enrichment.exe (with -include-delisted) ===\n'
_run_in_container '
  cd /workspaces/trading-1/trading && eval $(opam env) > /dev/null
  echo "$EODHD_API_KEY" > /tmp/eodhd-secrets
  dune exec --no-build analysis/scripts/asset_type_enrichment/bin/main.exe -- \
    -inventory-path /workspaces/trading-1/data/inventory.sexp \
    -output-path /workspaces/trading-1/data/symbol_types.sexp \
    -secrets-path /tmp/eodhd-secrets \
    -include-delisted
'

if [ "$SKIP_REBUILD" = "1" ]; then
  printf '\n--skip-rebuild: stopping after enrichment.\n'
  printf 'Run step 3 manually when ready:\n'
  printf '  dune exec analysis/data/universe/bin/build_composition_universes_runner.exe\n'
  exit 0
fi

printf '\n=== Step 3/3: build_composition_universes_runner.exe ===\n'
# --out-dir MUST be absolute. The runner default is the relative path
# "trading/test_data/goldens-custom-universe/composition/", which under
# `dune exec` from /workspaces/trading-1/trading/ resolves to
# /workspaces/trading-1/trading/trading/test_data/... — the WRONG location
# (canonical path is /workspaces/trading-1/trading/test_data/...). The first
# end-to-end run on 2026-05-18 caught this; see
# dev/notes/delisted-aware-p4-result-2026-05-18.md §"Bug found".
_run_in_container '
  cd /workspaces/trading-1/trading && eval $(opam env) > /dev/null
  dune exec --no-build analysis/data/universe/bin/build_composition_universes_runner.exe -- \
    --bars-root /workspaces/trading-1/data \
    --inventory /workspaces/trading-1/data/inventory.sexp \
    --sectors-csv /workspaces/trading-1/data/sectors.csv \
    --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
    --out-dir /workspaces/trading-1/trading/test_data/goldens-custom-universe/composition/
'

printf '\n=== Done ===\n'
printf 'Pipeline complete. The 75 composition goldens at\n'
printf '  trading/test_data/goldens-custom-universe/composition/top-N-YYYY.sexp\n'
printf 'are now delisted-aware. P4 (re-run #1180 scenarios) is unblocked.\n'
