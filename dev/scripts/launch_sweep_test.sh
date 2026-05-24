#!/usr/bin/env bash
# launch_sweep_test.sh — fixture-driven smoke test for launch_sweep.sh.
#
# Uses env-var hooks (LAUNCH_SWEEP_DF_BIN, LAUNCH_SWEEP_DOCKER_BIN, etc.)
# to inject mock binaries that return controlled output, then asserts the
# script's exit code + error messages per precondition.
#
# Run:
#   bash dev/scripts/launch_sweep_test.sh
#
# Exit: 0 on success, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="${SCRIPT_DIR}/launch_sweep.sh"

if [[ ! -x "${LAUNCHER}" ]]; then
  echo "FAIL: launcher not executable: ${LAUNCHER}" >&2
  exit 1
fi

TMP_BASE="$(mktemp -d -t launch_sweep_test.XXXXXX)"
trap 'rm -rf "${TMP_BASE}"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# ---------------------------------------------------------------------------
# Build a fresh mock-bin dir for each scenario.
# Each mock is a tiny shell script that emits canned output for the
# specific flags the launcher uses.
# ---------------------------------------------------------------------------
make_mocks() {
  local dir="$1"
  local df_free_kb="$2"        # numeric KB for `df -k /` Available column
  local du_kb="$3"             # numeric KB for `du -sk <path>` (0 = no Docker.raw)
  local container_running="$4" # true / false / notfound
  local has_bind_mount="$5"    # 1 / 0
  local existing_runner="$6"   # PID string (empty = none)

  mkdir -p "${dir}"

  cat > "${dir}/df" <<EOF
#!/bin/sh
# Mock df: emit canned 2-line output with Available field = ${df_free_kb}
cat <<INNER
Filesystem 1024-blocks Used Available Capacity MountedOn
/dev/disk1 1000000000 100  ${df_free_kb} 50%      /
INNER
EOF

  cat > "${dir}/du" <<EOF
#!/bin/sh
# Mock du: emit "<kb>\t<path>" for any input
echo "${du_kb}	\$2"
EOF

  cat > "${dir}/docker" <<EOF
#!/bin/sh
# Mock docker — handles the subset of flags launch_sweep.sh uses.
case "\$1 \$2" in
  "inspect -f")
    # \$3 is the template, \$4 is the container.
    case "\$3" in
      *State.Running*)
        case "${container_running}" in
          true)     echo "true";;
          false)    echo "false";;
          notfound) exit 1;;
        esac
        ;;
      *Mounts*)
        if [ "${has_bind_mount}" = "1" ]; then
          printf "/tmp/sweeps\n/workspaces/trading-1\n"
        else
          printf "/workspaces/trading-1\n"
        fi
        ;;
    esac
    ;;
  "exec "*)
    # \$2 is the container, \$3 is "pgrep" (or other) — handle pgrep only.
    if [ "\$3" = "pgrep" ]; then
      if [ -n "${existing_runner}" ]; then
        echo "${existing_runner}"
      fi
      # exit 0 either way; pgrep returns 1 if no match but we tolerate || true in caller
    fi
    ;;
esac
EOF

  chmod +x "${dir}/df" "${dir}/du" "${dir}/docker"
}

# A fake Docker.raw fixture (used when du-mock is nonzero — we still need the
# file to exist so the launcher progresses past the file-existence test).
RAW_FIXTURE="${TMP_BASE}/Docker.raw"
touch "${RAW_FIXTURE}"

# A fresh worktrees dir (used to control the stale-worktree check).
WORKTREES_FIXTURE="${TMP_BASE}/worktrees"
mkdir -p "${WORKTREES_FIXTURE}"

# Common args — every scenario invokes the launcher with --dry-run + these.
COMMON_ARGS=(
  --name test-sweep
  --spec /spec.sexp
  --walk-forward-spec /wf.sexp
  --baseline-aggregate /agg.sexp
  --container fakectr
  --dry-run
)

# Helper: run the launcher with given mock-dir + env overrides.
run_launcher() {
  local mocks="$1"
  shift
  LAUNCH_SWEEP_DF_BIN="${mocks}/df" \
  LAUNCH_SWEEP_DU_BIN="${mocks}/du" \
  LAUNCH_SWEEP_DOCKER_BIN="${mocks}/docker" \
  LAUNCH_SWEEP_DOCKER_RAW_PATH="${RAW_FIXTURE}" \
  LAUNCH_SWEEP_WORKTREES_DIR="${WORKTREES_FIXTURE}" \
    bash "${LAUNCHER}" "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Scenario 1 — all preconditions pass (--dry-run prints the launch command)
# ---------------------------------------------------------------------------
SCEN1="${TMP_BASE}/s1"
make_mocks "${SCEN1}" 100000000 1000000 true 1 ""
# df_free_kb=100_000_000 KB ≈ 95 GB free
# du_kb=1_000_000 KB ≈ 0.95 GB Docker.raw
out=$(run_launcher "${SCEN1}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 0 )) && grep -q 'DRY RUN' <<< "${out}" && grep -q '/tmp/sweeps/test-sweep' <<< "${out}"; then
  pass "scenario 1 — all preconditions pass; --dry-run prints the launch line"
else
  fail "scenario 1 — expected rc=0 + 'DRY RUN' + out-dir; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 2 — disk free too low (35 GB < 50 GB default)
# ---------------------------------------------------------------------------
SCEN2="${TMP_BASE}/s2"
make_mocks "${SCEN2}" 36700160 1000000 true 1 ""   # 36_700_160 KB ≈ 35 GB
out=$(run_launcher "${SCEN2}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'host disk free.*GB <' <<< "${out}" && grep -q 'disk_free' <<< "${out}"; then
  pass "scenario 2 — low disk fails check 1 with exit 2"
else
  fail "scenario 2 — expected rc=2 + disk_free failure; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 3 — Docker.raw too large (40 GB >= 30 GB cap)
# ---------------------------------------------------------------------------
SCEN3="${TMP_BASE}/s3"
make_mocks "${SCEN3}" 100000000 41943040 true 1 ""  # 41_943_040 KB = 40 GB
out=$(run_launcher "${SCEN3}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'Docker.raw at .* GB >= ' <<< "${out}" && grep -q 'docker_raw' <<< "${out}"; then
  pass "scenario 3 — oversized Docker.raw fails check 2 with exit 2"
else
  fail "scenario 3 — expected rc=2 + docker_raw failure; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 4 — container not running
# ---------------------------------------------------------------------------
SCEN4="${TMP_BASE}/s4"
make_mocks "${SCEN4}" 100000000 1000000 false 1 ""
out=$(run_launcher "${SCEN4}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q "container 'fakectr' is not running" <<< "${out}"; then
  pass "scenario 4 — stopped container fails check 3 with exit 2"
else
  fail "scenario 4 — expected rc=2 + container-not-running; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 5 — missing /tmp/sweeps bind-mount
# ---------------------------------------------------------------------------
SCEN5="${TMP_BASE}/s5"
make_mocks "${SCEN5}" 100000000 1000000 true 0 ""
out=$(run_launcher "${SCEN5}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q '/tmp/sweeps is not bind-mounted' <<< "${out}"; then
  pass "scenario 5 — missing bind-mount fails check 4 with exit 2"
else
  fail "scenario 5 — expected rc=2 + bind-mount failure; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 6 — another bayesian_runner.exe is running
# ---------------------------------------------------------------------------
SCEN6="${TMP_BASE}/s6"
make_mocks "${SCEN6}" 100000000 1000000 true 1 "12345"
out=$(run_launcher "${SCEN6}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'another bayesian_runner.exe is already running' <<< "${out}"; then
  pass "scenario 6 — concurrent runner fails check 5 with exit 2"
else
  fail "scenario 6 — expected rc=2 + concurrent-runner failure; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 7 — stale worktree under the worktrees dir
# ---------------------------------------------------------------------------
SCEN7="${TMP_BASE}/s7"
make_mocks "${SCEN7}" 100000000 1000000 true 1 ""
STALE_WT_DIR="${TMP_BASE}/stale-worktrees"
mkdir -p "${STALE_WT_DIR}/agent-stale-1"
# Backdate the agent-stale-1 dir's mtime to 30h ago. `touch -t` accepts
# [[CC]YY]MMDDhhmm[.ss]; we compute "now minus 30h" portably.
if date -v -30H +'%Y%m%d%H%M' >/dev/null 2>&1; then
  past="$(date -v -30H +'%Y%m%d%H%M')"            # BSD/macOS date
else
  past="$(date -d '30 hours ago' +'%Y%m%d%H%M')"  # GNU/Linux date
fi
touch -t "${past}" "${STALE_WT_DIR}/agent-stale-1"
out=$(LAUNCH_SWEEP_DF_BIN="${SCEN7}/df" \
      LAUNCH_SWEEP_DU_BIN="${SCEN7}/du" \
      LAUNCH_SWEEP_DOCKER_BIN="${SCEN7}/docker" \
      LAUNCH_SWEEP_DOCKER_RAW_PATH="${RAW_FIXTURE}" \
      LAUNCH_SWEEP_WORKTREES_DIR="${STALE_WT_DIR}" \
      bash "${LAUNCHER}" "${COMMON_ARGS[@]}" 2>&1) && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'stale worktree(s) older than' <<< "${out}" && grep -q 'no_stale_worktrees' <<< "${out}"; then
  pass "scenario 7 — stale worktree fails check 6 with exit 2"
else
  fail "scenario 7 — expected rc=2 + stale worktree failure; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 8 — usage error: missing required --name
# ---------------------------------------------------------------------------
SCEN8="${TMP_BASE}/s8"
make_mocks "${SCEN8}" 100000000 1000000 true 1 ""
out=$(run_launcher "${SCEN8}" --spec /a --walk-forward-spec /b --baseline-aggregate /c --dry-run) && rc=0 || rc=$?
if (( rc == 1 )) && grep -q 'required' <<< "${out}"; then
  pass "scenario 8 — missing --name returns exit 1 (usage error, not 2)"
else
  fail "scenario 8 — expected rc=1 + 'required'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 9 — multiple failures reported together (disk + docker_raw)
# ---------------------------------------------------------------------------
SCEN9="${TMP_BASE}/s9"
make_mocks "${SCEN9}" 36700160 41943040 true 1 ""   # both fail
out=$(run_launcher "${SCEN9}" "${COMMON_ARGS[@]}") && rc=0 || rc=$?
if (( rc == 2 )) \
   && grep -q 'disk_free' <<< "${out}" \
   && grep -q 'docker_raw' <<< "${out}" \
   && grep -qE '2 precondition\(s\) failed' <<< "${out}"; then
  pass "scenario 9 — multiple failures reported in one run (no short-circuit)"
else
  fail "scenario 9 — expected rc=2 + both failures listed; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 10 — invalid --name (path-traversal char)
# ---------------------------------------------------------------------------
SCEN10="${TMP_BASE}/s10"
make_mocks "${SCEN10}" 100000000 1000000 true 1 ""
out=$(run_launcher "${SCEN10}" --name '../escape' --spec /a --walk-forward-spec /b --baseline-aggregate /c --dry-run) && rc=0 || rc=$?
if (( rc == 1 )) && grep -q 'must match' <<< "${out}"; then
  pass "scenario 10 — unsafe --name rejected with exit 1"
else
  fail "scenario 10 — expected rc=1 + 'must match'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "launch_sweep_test: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
