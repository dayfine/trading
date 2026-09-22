#!/bin/sh
# Local PIT-warehouse smoke cell (issue #2896).
#
# No tier (1-4) opens a snapshot warehouse: perf-tier1/2/3/4 all discover
# scenarios under trading/test_data/backtest_scenarios/{goldens-small,
# goldens-broad,perf-sweep,smoke[,goldens-sp500*,goldens-custom-universe-
# scenarios]}, which are all CSV-mode cells. The workload that actually
# burns the container -- the PIT 26y chain in --snapshot-dir mode against
# the _v11pit warehouse, 3h37m-4h19m per cell at SNAPSHOT_MAX_MMAP_HANDLES=
# 12000, 8.5-10h at the default 256 (#2882) -- is invisible to every tier.
#
# This script runs ONE short scenario (trading/test_data/backtest_scenarios/
# perf-pit/pit-smoke-4mo.sexp: the a0-pit-null / t1-topn-40 null config, a
# 4-month 2020 window, per the v1-index-veto-smoke.sexp template) TWICE
# against the full _v11pit warehouse (9,364 symbols) -- once at
# SNAPSHOT_MAX_MMAP_HANDLES=256 (default, forces LRU cycling across the
# whole universe) and once at 12,000 (never evicts) -- so a cache-thrash
# regression in the mmap handle cap / Daily_panels path shows as a wall
# delta between the two runs. The two runs use the same salt and the same
# deterministic strategy, so their actual.sexp + trades.csv MUST be
# byte-identical; this script fails loudly if they are not.
#
# LOCAL-ONLY: the warehouse lives in the trading-1-dev container at
# /tmp/snap_top3000_pit_v11pit (tens of GB) and is never built on GHA.
# Intended to be run by hand as part of the weekly perf review
# (.claude/rules/perf-review-weekly.md), logging its table into
# dev/status/backtest-perf.md "## Weekly review" -- not wired into any
# GHA workflow.
#
# Reuses the run_tier4_release_gate.sh $SNAPSHOT_FLAGS convention
# (--snapshot-mode [--snapshot-dir <dir>]) and the
# top-of-funnel-2026-09-21/chain-funnel.sh runner invocation shape
# (TRADING_PATH_SEED_SALT, SNAPSHOT_CACHE_MB, SNAPSHOT_MAX_MMAP_HANDLES env
# vars + /usr/bin/time -f '%M' + --no-emit-all-eligible --parallel 1). Peak
# RSS parsing reuses dev/lib/gnu_time_rss.sh's _parse_gnu_time_rss (the
# #2553/#2559 fused-digit bug guard) by docker-cp'ing each run's .rss file
# to the host before parsing it.
#
# Usage:
#   dev/scripts/perf_pit_smoke.sh                          -- default: repo root's trading/
#   dev/scripts/perf_pit_smoke.sh --worktree .claude/worktrees/sweep-x
#                                                            -- run against a pinned worktree
#   PERF_PIT_SMOKE_TIMEOUT=3600 dev/scripts/perf_pit_smoke.sh
#   PERF_PIT_SMOKE_WAREHOUSE=/tmp/snap_other dev/scripts/perf_pit_smoke.sh
#
# Output artefacts (container path, bind-mounted to <repo>/.sweep-output/ on
# the host -- see "Bind-mount discovery" below):
#   /tmp/sweeps/perf-pit-smoke/<timestamp>/cap<N>.log            scenario_runner stdout/stderr
#   /tmp/sweeps/perf-pit-smoke/<timestamp>/cap<N>.rss             GNU /usr/bin/time -f '%M' output
#   /tmp/sweeps/perf-pit-smoke/<timestamp>/cap<N>-actual.sexp     copied run artefact
#   /tmp/sweeps/perf-pit-smoke/<timestamp>/cap<N>-trades.csv      copied run artefact
#   /tmp/sweeps/perf-pit-smoke/<timestamp>/summary.txt            the printed table
#
# Exit status:
#   0 both runs completed and their actual.sexp + trades.csv match byte-for-byte
#   1 a run failed / timed out, or the two runs produced different output
#   2 invocation error (bad --worktree, missing container, missing warehouse manifest)

set -eu

C="${TRADING_CONTAINER_NAME:-trading-1-dev}"
SPEC_REL="perf-pit/pit-smoke-4mo.sexp"
SALT="${PERF_PIT_SMOKE_SALT:-0}"
CACHE_MB="${PERF_PIT_SMOKE_CACHE_MB:-1024}"
WAREHOUSE="${PERF_PIT_SMOKE_WAREHOUSE:-/tmp/snap_top3000_pit_v11pit}"
TIMEOUT="${PERF_PIT_SMOKE_TIMEOUT:-3600}"
WORKTREE_REL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --worktree)
      [ $# -ge 2 ] || { echo "FAIL: --worktree requires an argument" >&2; exit 2; }
      WORKTREE_REL="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,48p' "$0"
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      echo "See '$0 --help'." >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Shared GNU /usr/bin/time peak-RSS parser -- see dev/lib/gnu_time_rss.sh for
# the fused-digit bug this guards against (#2553, #2559).
. "${REPO_ROOT}/dev/lib/gnu_time_rss.sh"

if ! docker exec "$C" true >/dev/null 2>&1; then
  echo "FAIL: container '$C' not responsive (docker daemon down or container stopped)" >&2
  exit 2
fi

# Container trading root -- default is the container's parent-tree mount;
# --worktree points this at a pinned worktree instead, same convention as
# every chain script (dev/experiments/*/chain-*.sh WT=...).
if [ -n "$WORKTREE_REL" ]; then
  WT="/workspaces/trading-1/${WORKTREE_REL}/trading"
else
  WT="/workspaces/trading-1/trading"
fi
if ! docker exec "$C" test -f "${WT}/dune-workspace"; then
  echo "FAIL: no dune-workspace at ${WT} (bad --worktree, or worktree not bind-mounted)" >&2
  exit 2
fi
FIX="${WT}/test_data/backtest_scenarios"
if ! docker exec "$C" test -f "${FIX}/${SPEC_REL}"; then
  echo "FAIL: spec not found in container at ${FIX}/${SPEC_REL}" >&2
  exit 2
fi

if ! docker exec "$C" test -f "${WAREHOUSE}/manifest.sexp"; then
  echo "FAIL: no warehouse manifest at ${WAREHOUSE}/manifest.sexp -- this cell needs the" >&2
  echo "  _v11pit snapshot warehouse built locally in the container; it is never present" >&2
  echo "  on GHA. See dev/experiments/top-of-funnel-2026-09-21/chain-funnel.sh for how it" >&2
  echo "  was built, or set PERF_PIT_SMOKE_WAREHOUSE to point at a different warehouse." >&2
  exit 2
fi

# Bind-mount discovery: /tmp/sweeps inside the container maps to
# <repo>/.sweep-output on the host (via docker inspect, not hardcoded --
# see dev/lib/run-in-env.sh's analogous worktree-path discovery for why: a
# hardcoded host path breaks the moment this runs from a machine with a
# different checkout location).
HOST_SWEEP_SRC="$(docker inspect "$C" \
  --format '{{range .Mounts}}{{if eq .Destination "/tmp/sweeps"}}{{.Source}}{{end}}{{end}}' \
  2>/dev/null || true)"

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT_DIR="/tmp/sweeps/perf-pit-smoke/${TS}"
docker exec "$C" mkdir -p "$OUT_DIR"

# Local staging area for files we pull out of the container to parse on the
# host (the .rss files -- _parse_gnu_time_rss reads a local path).
HOST_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/perf_pit_smoke.XXXXXX")"
trap 'rm -rf "$HOST_STAGE"' EXIT

printf 'PIT-warehouse smoke cell (issue #2896).\n'
printf '  Container       : %s\n' "$C"
printf '  Trading root    : %s\n' "$WT"
printf '  Spec            : %s/%s\n' "$FIX" "$SPEC_REL"
printf '  Warehouse       : %s\n' "$WAREHOUSE"
printf '  Salt            : %s\n' "$SALT"
printf '  Cache MB        : %s\n' "$CACHE_MB"
printf '  Per-cell timeout: %ss\n' "$TIMEOUT"
printf '  Output dir      : %s\n' "$OUT_DIR"
if [ -n "$HOST_SWEEP_SRC" ]; then
  printf '  Host mirror     : %s/perf-pit-smoke/%s\n\n' "$HOST_SWEEP_SRC" "$TS"
else
  printf '  Host mirror     : <docker inspect returned no /tmp/sweeps mount>\n\n'
fi

printf '[build] scenario_runner.exe\n'
docker exec "$C" bash -c \
  "cd $WT && eval \$(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe" \
  2>&1 | tail -20
if ! docker exec "$C" test -x "${WT}/_build/default/trading/backtest/scenarios/scenario_runner.exe"; then
  echo "FAIL: build did not produce scenario_runner.exe" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
TABLE_ROWS=""

_run_one() {
  cap="$1"
  stage_dir="${OUT_DIR}/_stage_cap${cap}"
  log_path="${OUT_DIR}/cap${cap}.log"
  rss_path="${OUT_DIR}/cap${cap}.rss"

  docker exec "$C" sh -c "mkdir -p '$stage_dir' && cp '${FIX}/${SPEC_REL}' '$stage_dir/'"

  printf '[run]  cap=%s\n' "$cap"
  start_epoch=$(date +%s)
  docker exec "$C" bash -c \
    "cd $WT && eval \$(opam env) && \
     TRADING_DATA_DIR=$WT/test_data \
     TRADING_PATH_SEED_SALT=$SALT \
     SNAPSHOT_CACHE_MB=$CACHE_MB \
     SNAPSHOT_MAX_MMAP_HANDLES=$cap \
     /usr/bin/time -f '%M' -o '$rss_path' \
       timeout $TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
         --dir '$stage_dir' --fixtures-root '$FIX' --snapshot-dir '$WAREHOUSE' \
         --no-emit-all-eligible --parallel 1 --progress-every 26 \
       > '$log_path' 2>&1; \
     echo exit=\$? >> '$log_path'"
  end_epoch=$(date +%s)
  wall_sec=$((end_epoch - start_epoch))

  rss_value="?"
  if docker exec "$C" test -f "$rss_path"; then
    docker cp "${C}:${rss_path}" "${HOST_STAGE}/cap${cap}.rss" >/dev/null 2>&1 || true
    if [ -f "${HOST_STAGE}/cap${cap}.rss" ]; then
      rss_value="$(_parse_gnu_time_rss "${HOST_STAGE}/cap${cap}.rss")"
    fi
  fi

  out_root="$(docker exec "$C" sh -c "grep 'Output root' '$log_path' | tail -1 | sed 's/.*: //'" || true)"
  scenario_name="$(basename "$SPEC_REL" .sexp)"
  if [ -n "$out_root" ]; then
    docker exec "$C" sh -c \
      "cp '${out_root}/${scenario_name}/actual.sexp' '${OUT_DIR}/cap${cap}-actual.sexp' 2>/dev/null; \
       cp '${out_root}/${scenario_name}/trades.csv' '${OUT_DIR}/cap${cap}-trades.csv' 2>/dev/null" || true
  fi

  cache_line="$(docker exec "$C" sh -c "grep -h 'snapshot cache' '$log_path' | tail -1" || true)"
  exit_line="$(docker exec "$C" sh -c "grep -h '^exit=' '$log_path' | tail -1" || true)"

  docker exec "$C" rm -rf "$stage_dir"

  if [ "$exit_line" != "exit=0" ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TABLE_ROWS="${TABLE_ROWS}FAIL  cap=${cap}  ${wall_sec}s  ${rss_value}kB  ${exit_line:-<no exit line>} -- see ${log_path}
"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    TABLE_ROWS="${TABLE_ROWS}PASS  cap=${cap}  ${wall_sec}s  ${rss_value}kB  ${cache_line:-<no cache line>}
"
  fi
}

# md5 of one artefact for one cap, computed inside the container (files stay
# remote -- only the printable digest crosses to the host).
_md5_of() {
  cap="$1"; field="$2"
  docker exec "$C" sh -c "md5sum '${OUT_DIR}/cap${cap}-${field}' 2>/dev/null | cut -d' ' -f1"
}

_run_one 256
_run_one 12000

MD5_256_ACTUAL="$(_md5_of 256 actual.sexp)"
MD5_256_TRADES="$(_md5_of 256 trades.csv)"
MD5_12000_ACTUAL="$(_md5_of 12000 actual.sexp)"
MD5_12000_TRADES="$(_md5_of 12000 trades.csv)"

TRIPWIRE="MISMATCH"
if [ -n "$MD5_256_ACTUAL" ] && [ "$MD5_256_ACTUAL" = "$MD5_12000_ACTUAL" ] \
   && [ -n "$MD5_256_TRADES" ] && [ "$MD5_256_TRADES" = "$MD5_12000_TRADES" ]; then
  TRIPWIRE="MATCH"
fi

SUMMARY_TEXT="$(cat <<EOF
PIT-warehouse smoke cell summary (${TS})
  passed: ${PASS_COUNT}
  failed: ${FAIL_COUNT}

STATUS CAP        WALL     PEAK_RSS   NOTES
----------------------------------------------------------------------
${TABLE_ROWS}
md5 actual.sexp  cap=256:${MD5_256_ACTUAL}  cap=12000:${MD5_12000_ACTUAL}
md5 trades.csv   cap=256:${MD5_256_TRADES}  cap=12000:${MD5_12000_TRADES}
byte-identity tripwire: ${TRIPWIRE}
EOF
)"

printf '%s\n' "$SUMMARY_TEXT" | docker exec -i "$C" sh -c "cat > '${OUT_DIR}/summary.txt'"
printf '\n%s\n' "$SUMMARY_TEXT"

if [ "$FAIL_COUNT" -gt 0 ] || [ "$TRIPWIRE" != "MATCH" ]; then
  exit 1
fi
exit 0
