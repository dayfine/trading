#!/bin/sh
# docker_dune_smoke.sh -- smoke test for dev/scripts/docker_dune.sh.
#
# Pins the fixes from the PR #2280 qc-behavioral rework (B1-B4):
#   B2  the sentinel is `__docker_dune_exit=<code>` (not a bare `exit=<code>`
#       a first-match grep could confuse with dune/OUnit/linter output that
#       happens to start with `exit=`), and the poller reads the LAST match.
#   B3  a `docker exec` that fails mid-poll (container vanished) is reported
#       with a `docker_dune:` diagnostic and a non-zero exit, not a silent
#       `set -e` death.
#   B4  a bad --dir (cd failure) is captured in the log via a brace-grouped
#       redirect, not swallowed by binding the redirect to `dune` alone.
#
# Does NOT require docker: a fake `docker` (plus fake `dune` / `opam`) is put
# first on PATH, mirroring sete_diagnostics_check.sh's fake-`jj` pattern and
# sweep_worktrees_smoke.sh's bash-availability skip-guard. The fake `docker`
# actually execs the generated `bash -c` / `sh -c` command lines locally
# (via the real bash/sh on PATH) rather than faking their output, so the
# wrapper's actual sentinel-write + poll + brace-group logic all run for
# real -- only the container boundary is faked.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="docker_dune_smoke"
PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

# --- Skip if bash is not available (the wrapper's generated command always
# runs under `bash -c`, and this test's fake dune/opam scripts are #!/bin/sh
# but invoked via that bash). ---
if ! command -v bash >/dev/null 2>&1; then
  echo "OK: ${LABEL} — SKIPPED (bash not on PATH)."
  exit 0
fi

REPO_ROOT_REAL="$(repo_root)"
WRAPPER="${REPO_ROOT_REAL}/dev/scripts/docker_dune.sh"
[ -f "$WRAPPER" ] || die "${LABEL}: $WRAPPER does not exist"

FAKE_BIN="$(mktemp -d)"
WORK="$(mktemp -d)"
trap 'rm -rf "$FAKE_BIN" "$WORK"' EXIT INT TERM

# ---------------------------------------------------------------------------
# Fake `opam`: `opam env` prints nothing and succeeds, so `eval $(opam env)`
# inside the wrapper's generated command is a harmless no-op.
# ---------------------------------------------------------------------------
cat > "${FAKE_BIN}/opam" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "${FAKE_BIN}/opam"

# ---------------------------------------------------------------------------
# Fake `docker`: intercepts `inspect` and `exec` (detached and not) and runs
# the real command lines locally via the real bash/sh, so the wrapper's own
# logic (redirect, sentinel, polling) executes for real against a host-
# visible --log path. Behavior at the container boundary is controlled by
# env vars set before each assertion below:
#   FAKE_DOCKER_RUNNING          "true" | "false" (default true) -- answer
#                                 for `docker inspect ... State.Running`.
#   FAKE_DOCKER_EXEC_FAIL_AFTER  integer N -- the (N+1)th and every later
#                                 non-detached `exec` call fails with exit 1
#                                 (simulates the container vanishing
#                                 mid-poll). Unset = never fail.
#   FAKE_DOCKER_COUNTER_FILE     path to a counter file, required when
#                                 FAKE_DOCKER_EXEC_FAIL_AFTER is set.
# ---------------------------------------------------------------------------
cat > "${FAKE_BIN}/docker" <<'FAKE_DOCKER_EOF'
#!/bin/sh
case "$1" in
  inspect)
    printf '%s\n' "${FAKE_DOCKER_RUNNING:-true}"
    exit 0
    ;;
  exec)
    shift
    DETACHED=0
    if [ "$1" = "-d" ]; then
      DETACHED=1
      shift
    fi
    shift # drop container name
    INTERP="$1"
    shift
    shift # drop -c
    CMD="$1"
    if [ "$DETACHED" -eq 1 ]; then
      "$INTERP" -c "$CMD" </dev/null >/dev/null 2>&1 &
      exit 0
    fi
    if [ -n "${FAKE_DOCKER_EXEC_FAIL_AFTER:-}" ]; then
      COUNT=$(cat "$FAKE_DOCKER_COUNTER_FILE" 2>/dev/null || echo 0)
      COUNT=$((COUNT + 1))
      echo "$COUNT" > "$FAKE_DOCKER_COUNTER_FILE"
      if [ "$COUNT" -gt "$FAKE_DOCKER_EXEC_FAIL_AFTER" ]; then
        echo "docker: Error: No such container: fake (simulated by docker_dune_smoke.sh)" >&2
        exit 1
      fi
    fi
    "$INTERP" -c "$CMD"
    exit $?
    ;;
  *)
    exit 0
    ;;
esac
FAKE_DOCKER_EOF
chmod +x "${FAKE_BIN}/docker"

_set_fake_dune() {
  cat > "${FAKE_BIN}/dune"
  chmod +x "${FAKE_BIN}/dune"
}

# ---------------------------------------------------------------------------
# Assertion 1: container down -> exit 125, no exec ever attempted.
# ---------------------------------------------------------------------------
LOG1="${WORK}/log1"
OUT1=$(FAKE_DOCKER_RUNNING=false PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --log "$LOG1" -- build 2>&1) && CODE1=0 || CODE1=$?
if [ "$CODE1" -eq 125 ] && printf '%s' "$OUT1" | grep -qi 'not running'; then
  ok "${LABEL} — container down: exit=125 with a 'not running' diagnostic"
else
  bad "${LABEL} — container down: expected exit=125 with 'not running'; got exit=${CODE1} output='${OUT1}'"
fi

# ---------------------------------------------------------------------------
# Assertion 2: sentinel exit=7 -> wrapper exits 7 (basic round-trip).
# REPO_IN_CONTAINER points at a real host tmp dir (with --dir .) so `cd`
# succeeds without a real docker container backing /workspaces/trading-1.
# ---------------------------------------------------------------------------
_set_fake_dune <<'EOF'
#!/bin/sh
exit 7
EOF
LOG2="${WORK}/log2"
OUT2=$(FAKE_DOCKER_RUNNING=true REPO_IN_CONTAINER="$WORK" PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --dir . --log "$LOG2" --timeout 5 --poll 1 --quiet -- build 2>&1) && CODE2=0 || CODE2=$?
if [ "$CODE2" -eq 7 ]; then
  ok "${LABEL} — sentinel round-trip: dune exit=7 propagates as wrapper exit=7"
else
  bad "${LABEL} — sentinel round-trip: expected exit=7; got exit=${CODE2} output='${OUT2}'"
fi

# ---------------------------------------------------------------------------
# Assertion 3: --timeout elapses before any sentinel is written -> exit 124.
# ---------------------------------------------------------------------------
_set_fake_dune <<'EOF'
#!/bin/sh
sleep 10
exit 0
EOF
LOG3="${WORK}/log3"
OUT3=$(FAKE_DOCKER_RUNNING=true REPO_IN_CONTAINER="$WORK" PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --dir . --log "$LOG3" --timeout 2 --poll 1 --quiet -- build 2>&1) && CODE3=0 || CODE3=$?
if [ "$CODE3" -eq 124 ] && printf '%s' "$OUT3" | grep -qi 'TIMEOUT'; then
  ok "${LABEL} — timeout: no sentinel within --timeout gives exit=124 with a TIMEOUT diagnostic"
else
  bad "${LABEL} — timeout: expected exit=124 with TIMEOUT; got exit=${CODE3} output='${OUT3}'"
fi

# ---------------------------------------------------------------------------
# Assertion 4 (regression pin for B2): an `exit=`-prefixed line in dune's own
# output, written BEFORE the real sentinel, must not be mistaken for it. The
# pre-fix wrapper used a bare `exit=` sentinel with `grep -m1` (first match),
# so this line would have been consumed early, reporting exit=999 instead of
# the real final code.
# ---------------------------------------------------------------------------
_set_fake_dune <<'EOF'
#!/bin/sh
echo "exit=999 (looks like a sentinel but is just dune/OUnit/linter output)"
sleep 1
exit 3
EOF
LOG4="${WORK}/log4"
OUT4=$(FAKE_DOCKER_RUNNING=true REPO_IN_CONTAINER="$WORK" PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --dir . --log "$LOG4" --timeout 5 --poll 1 --quiet -- build 2>&1) && CODE4=0 || CODE4=$?
LOG4_CONTENT=$(cat "$LOG4" 2>/dev/null || echo "")
if [ "$CODE4" -eq 3 ] && printf '%s' "$LOG4_CONTENT" | grep -q '^exit=999'; then
  ok "${LABEL} — B2 regression pin: an incidental 'exit=999' line in dune output does not short-circuit the wait; final exit=3 (dune's real code) recovered"
else
  bad "${LABEL} — B2 regression pin: expected exit=3 with an 'exit=999' noise line present in the log; got exit=${CODE4} log='${LOG4_CONTENT}' output='${OUT4}'"
fi

# ---------------------------------------------------------------------------
# Assertion 5 (regression pin for B3): `docker exec` failing mid-poll
# (container vanished) must be diagnosed with a `docker_dune:` message and a
# non-zero exit, not die silently under `set -e`.
# ---------------------------------------------------------------------------
_set_fake_dune <<'EOF'
#!/bin/sh
sleep 3
exit 0
EOF
LOG5="${WORK}/log5"
COUNTER5="${WORK}/counter5"
rm -f "$COUNTER5"
OUT5=$(FAKE_DOCKER_RUNNING=true FAKE_DOCKER_EXEC_FAIL_AFTER=0 FAKE_DOCKER_COUNTER_FILE="$COUNTER5" \
  REPO_IN_CONTAINER="$WORK" PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --dir . --log "$LOG5" --timeout 5 --poll 1 -- build 2>&1) && CODE5=0 || CODE5=$?
if [ "$CODE5" -ne 0 ] && printf '%s' "$OUT5" | grep -q '^docker_dune:.*unreachable'; then
  ok "${LABEL} — B3 regression pin: docker exec failing mid-poll gives a non-zero exit (${CODE5}) with a 'docker_dune: ... unreachable' diagnostic"
else
  bad "${LABEL} — B3 regression pin: expected non-zero exit with a 'docker_dune: ... unreachable' diagnostic; got exit=${CODE5} output='${OUT5}'"
fi

# ---------------------------------------------------------------------------
# Assertion 6 (B4): a bad --dir (cd failure) must land in the log, not
# produce an empty log with no diagnostic. REPO_IN_CONTAINER is pointed at a
# real tmp dir and DUNE_SUBDIR at a subdir that does not exist there, so `cd`
# fails deterministically regardless of host layout.
# ---------------------------------------------------------------------------
BADROOT="${WORK}/badroot"
mkdir -p "$BADROOT"
LOG6="${WORK}/log6"
OUT6=$(FAKE_DOCKER_RUNNING=true REPO_IN_CONTAINER="$BADROOT" PATH="${FAKE_BIN}:${PATH}" \
  sh "$WRAPPER" --dir does-not-exist --log "$LOG6" --timeout 5 --poll 1 --quiet -- build 2>&1) && CODE6=0 || CODE6=$?
LOG6_CONTENT=$(cat "$LOG6" 2>/dev/null || echo "")
if [ "$CODE6" -ne 0 ] && [ -n "$LOG6_CONTENT" ] && printf '%s' "$LOG6_CONTENT" | grep -qi 'no such file or directory'; then
  ok "${LABEL} — B4: a bad --dir produces a non-empty log naming the cd failure (exit=${CODE6})"
else
  bad "${LABEL} — B4: expected a non-empty log naming the cd failure; got exit=${CODE6} log='${LOG6_CONTENT}' output='${OUT6}'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: ${LABEL} — ${PASS} assertion(s) passed, 0 failed."
