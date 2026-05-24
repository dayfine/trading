#!/usr/bin/env bash
# sweep_disk_watcher_test.sh — fixture-driven smoke test for sweep_disk_watcher.sh.
#
# Injects mock df/du/docker/kill binaries via env-var hooks, runs a single
# iteration (DISK_WATCHER_MAX_ITERATIONS=1), then asserts exit code +
# threshold-decision log lines.
#
# Run:
#   bash dev/scripts/sweep_disk_watcher_test.sh
#
# Exit: 0 on success, 1 on any assertion failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHER="${SCRIPT_DIR}/sweep_disk_watcher.sh"

if [[ ! -x "${WATCHER}" ]]; then
  echo "FAIL: watcher not executable: ${WATCHER}" >&2
  exit 1
fi

TMP_BASE="$(mktemp -d -t sweep_disk_watcher_test.XXXXXX)"
trap 'rm -rf "${TMP_BASE}"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
pass() { echo "  PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# ---------------------------------------------------------------------------
# Mock factory: emits df / du / docker / kill scripts emulating canned probe
# values + tracking whether kill was invoked.
#
# Args:
#   dir, host_free_kb, raw_kb, tmp_kb, pid_alive (0=dead, 1=alive)
# ---------------------------------------------------------------------------
make_mocks() {
  local dir="$1" host_kb="$2" raw_kb="$3" tmp_kb="$4" pid_alive="$5"
  mkdir -p "${dir}"

  cat > "${dir}/df" <<EOF
#!/bin/sh
cat <<INNER
Filesystem 1024-blocks Used Available Capacity MountedOn
/dev/disk1 1000000000 100  ${host_kb} 50%      /
INNER
EOF

  cat > "${dir}/du" <<EOF
#!/bin/sh
echo "${raw_kb}	\$2"
EOF

  # docker mock: handles `exec <container> du -sk /tmp` AND `exec <container> kill -SIG <pid>`.
  # The watcher routes kill through `docker exec` whenever --container is set
  # (needed on macOS Docker where the container's PID namespace is not visible
  # from the host). The mock records TERMs into kill_calls + reads pid_alive
  # to answer liveness probes.
  cat > "${dir}/docker" <<EOF
#!/bin/sh
case "\$1 \$3" in
  "exec du")
    echo "${tmp_kb}	/tmp"
    ;;
  "exec kill")
    # \$2 is the container name, \$3 is "kill", \$4 is the signal, \$5 is the PID.
    case "\$4" in
      -0)
        [ "${pid_alive}" = "1" ] && exit 0 || exit 1
        ;;
      -TERM)
        echo "TERM sent to pid=\$5" >> "${dir}/kill_calls"
        exit 0
        ;;
    esac
    ;;
esac
EOF

  # kill mock: --container-less fallback path (KILL_BIN); same semantics.
  cat > "${dir}/kill" <<EOF
#!/bin/sh
case "\$1" in
  -0)
    [ "${pid_alive}" = "1" ] && exit 0 || exit 1
    ;;
  -TERM)
    echo "TERM sent to pid=\$2" >> "${dir}/kill_calls"
    exit 0
    ;;
esac
EOF

  chmod +x "${dir}/df" "${dir}/du" "${dir}/docker" "${dir}/kill"
}

run_watcher() {
  local mocks="$1"; shift
  DISK_WATCHER_DF_BIN="${mocks}/df" \
  DISK_WATCHER_DU_BIN="${mocks}/du" \
  DISK_WATCHER_DOCKER_BIN="${mocks}/docker" \
  DISK_WATCHER_KILL_BIN="${mocks}/kill" \
  DISK_WATCHER_DOCKER_RAW_PATH="${RAW_FIXTURE}" \
  DISK_WATCHER_MAX_ITERATIONS=1 \
    bash "${WATCHER}" "$@" 2>&1
}

# Docker.raw fixture must exist for du-mock to be invoked.
RAW_FIXTURE="${TMP_BASE}/Docker.raw"
touch "${RAW_FIXTURE}"

# Each scenario writes its log + kill-call markers into a per-scenario log-dir.
make_log_dir() {
  local d="${TMP_BASE}/$1-log"
  mkdir -p "${d}"
  echo "${d}"
}

COMMON_ARGS=(
  --sweep-pid 99999
  --sweep-name test-sweep
  --container fakectr
  --poll-interval 1
)

# ---------------------------------------------------------------------------
# Scenario 1 — all clear, sweep alive: 1 iteration then exit 0 (max-iter mode)
# ---------------------------------------------------------------------------
SCEN1="${TMP_BASE}/s1"
make_mocks "${SCEN1}" 100000000 1000000 500000 1   # 95GB free, 1GB raw, 0.5GB /tmp
LOG1="$(make_log_dir s1)"
out=$(run_watcher "${SCEN1}" "${COMMON_ARGS[@]}" --log-dir "${LOG1}") && rc=0 || rc=$?
if (( rc == 0 )) && grep -q 'probes: host_free=95GB docker_raw=0GB' <<< "${out}" \
   && grep -q 'max iterations reached' <<< "${out}" \
   && [[ ! -f "${SCEN1}/kill_calls" ]]; then
  pass "scenario 1 — all clear, no kill, exits 0 at max-iter"
else
  fail "scenario 1 — expected rc=0 + all-clear + no TERM; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 2 — host disk free below minimum → SIGTERM + exit 2
# ---------------------------------------------------------------------------
SCEN2="${TMP_BASE}/s2"
make_mocks "${SCEN2}" 15728640 1000000 500000 1    # 15GB free (< 20GB default)
LOG2="$(make_log_dir s2)"
out=$(run_watcher "${SCEN2}" "${COMMON_ARGS[@]}" --log-dir "${LOG2}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'host_free=15GB < 20GB minimum' <<< "${out}" \
   && [[ -f "${SCEN2}/kill_calls" ]] && grep -q 'TERM sent to pid=99999' "${SCEN2}/kill_calls"; then
  pass "scenario 2 — host disk < min → SIGTERM, exit 2"
else
  fail "scenario 2 — expected rc=2 + TERM + host-free msg; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  echo "      kill_calls: $(cat "${SCEN2}/kill_calls" 2>/dev/null || echo "(none)")"
fi

# ---------------------------------------------------------------------------
# Scenario 3 — Docker.raw at warn threshold (50-64GB) → warning, no kill
# ---------------------------------------------------------------------------
SCEN3="${TMP_BASE}/s3"
# 55GB raw = 55 * 1024 * 1024 = 57671680 KB
make_mocks "${SCEN3}" 100000000 57671680 500000 1
LOG3="$(make_log_dir s3)"
out=$(run_watcher "${SCEN3}" "${COMMON_ARGS[@]}" --log-dir "${LOG3}") && rc=0 || rc=$?
if (( rc == 0 )) && grep -q 'WARNING: Docker.raw=55GB >= 50GB warn threshold' <<< "${out}" \
   && [[ ! -f "${SCEN3}/kill_calls" ]]; then
  pass "scenario 3 — Docker.raw at warn band → warning, no kill"
else
  fail "scenario 3 — expected rc=0 + warn + no TERM; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 4 — Docker.raw at kill threshold → SIGTERM + exit 2
# ---------------------------------------------------------------------------
SCEN4="${TMP_BASE}/s4"
# 70GB raw = 73400320 KB
make_mocks "${SCEN4}" 100000000 73400320 500000 1
LOG4="$(make_log_dir s4)"
out=$(run_watcher "${SCEN4}" "${COMMON_ARGS[@]}" --log-dir "${LOG4}") && rc=0 || rc=$?
if (( rc == 2 )) && grep -q 'Docker.raw=70GB >= 65GB kill threshold' <<< "${out}" \
   && [[ -f "${SCEN4}/kill_calls" ]]; then
  pass "scenario 4 — Docker.raw at kill threshold → SIGTERM, exit 2"
else
  fail "scenario 4 — expected rc=2 + raw-kill + TERM; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 5 — container /tmp at warn threshold → warning, no kill
# ---------------------------------------------------------------------------
SCEN5="${TMP_BASE}/s5"
# 32GB /tmp = 33554432 KB
make_mocks "${SCEN5}" 100000000 1000000 33554432 1
LOG5="$(make_log_dir s5)"
out=$(run_watcher "${SCEN5}" "${COMMON_ARGS[@]}" --log-dir "${LOG5}") && rc=0 || rc=$?
if (( rc == 0 )) && grep -q 'WARNING: container /tmp=32GB' <<< "${out}" \
   && [[ ! -f "${SCEN5}/kill_calls" ]]; then
  pass "scenario 5 — container /tmp at warn → warning, no kill"
else
  fail "scenario 5 — expected rc=0 + tmp-warn + no TERM; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 6 — sweep PID already dead → exit 0 immediately, no probes
# ---------------------------------------------------------------------------
SCEN6="${TMP_BASE}/s6"
make_mocks "${SCEN6}" 100000000 1000000 500000 0   # pid_alive=0
LOG6="$(make_log_dir s6)"
out=$(run_watcher "${SCEN6}" "${COMMON_ARGS[@]}" --log-dir "${LOG6}") && rc=0 || rc=$?
if (( rc == 0 )) && grep -q 'sweep pid=99999 exited' <<< "${out}" \
   && [[ ! -f "${SCEN6}/kill_calls" ]]; then
  pass "scenario 6 — dead sweep PID → exit 0 + no TERM"
else
  fail "scenario 6 — expected rc=0 + 'sweep pid=… exited'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 7 — usage: missing --sweep-pid
# ---------------------------------------------------------------------------
SCEN7="${TMP_BASE}/s7"
make_mocks "${SCEN7}" 100000000 1000000 500000 1
out=$(run_watcher "${SCEN7}" --sweep-name test --container fakectr) && rc=0 || rc=$?
if (( rc == 1 )) && grep -q 'required' <<< "${out}"; then
  pass "scenario 7 — missing --sweep-pid → exit 1 (usage)"
else
  fail "scenario 7 — expected rc=1 + 'required'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 8 — unsafe --sweep-name rejected
# ---------------------------------------------------------------------------
SCEN8="${TMP_BASE}/s8"
make_mocks "${SCEN8}" 100000000 1000000 500000 1
out=$(run_watcher "${SCEN8}" --sweep-pid 99999 --sweep-name '../escape' --container fakectr) && rc=0 || rc=$?
if (( rc == 1 )) && grep -q 'must match' <<< "${out}"; then
  pass "scenario 8 — unsafe --sweep-name → exit 1"
else
  fail "scenario 8 — expected rc=1 + 'must match'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 9 — append-only log file is written under --log-dir
# ---------------------------------------------------------------------------
SCEN9="${TMP_BASE}/s9"
make_mocks "${SCEN9}" 100000000 1000000 500000 1
LOG9="$(make_log_dir s9)"
out=$(run_watcher "${SCEN9}" "${COMMON_ARGS[@]}" --log-dir "${LOG9}") && rc=0 || rc=$?
LOG_FILE9="${LOG9}/test-sweep.watcher.log"
if (( rc == 0 )) && [[ -f "${LOG_FILE9}" ]] && grep -q 'watching sweep pid=99999' "${LOG_FILE9}"; then
  pass "scenario 9 — log file written under --log-dir"
else
  fail "scenario 9 — expected log file at ${LOG_FILE9} with 'watching sweep' line"
  echo "      output: ${out}" | sed 's/^/      /'
  [[ -f "${LOG_FILE9}" ]] && echo "      log: $(cat "${LOG_FILE9}")"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "sweep_disk_watcher_test: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
