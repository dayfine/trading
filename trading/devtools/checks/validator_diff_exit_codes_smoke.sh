#!/bin/sh
# Smoke test: pin the process exit code of validator_diff.exe for every case
# the CLI's contract names, against fixture reports built here.
#
# The gate's whole value is that a chain can branch on the exit code, so the
# codes are the contract:
#
#   0  every selected check agrees (the arms are a paired read)
#   1  the selected checks differ (a real finding)
#   2  the reports could not be read or compared (an operator error)
#
# Exit 1 and exit 2 must never be confused: a chain gating on `[ $? -eq 1 ]`
# would otherwise report a typo'd path as a twin-position data defect. That
# was a live defect -- before this test existed, `Sexp.load_sexp` raised on a
# missing or malformed report and the uncaught exception exited 1 (PR #2735
# qc-behavioral, item CP4-a). A unit test cannot pin a process exit code, so
# this check drives the real executable.
#
# VALIDATOR_DIFF_EXE is supplied by the dune rule (%{exe:...}), which also
# makes the built executable a dependency so the cache invalidates when the
# CLI changes.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="validator_diff_exit_codes_smoke"

EXE="${VALIDATOR_DIFF_EXE:-}"
if [ -z "$EXE" ]; then
  die "${LABEL} — VALIDATOR_DIFF_EXE is unset; the dune rule must pass it"
fi
if [ ! -x "$EXE" ]; then
  die "${LABEL} — VALIDATOR_DIFF_EXE=$EXE is not an executable"
fi

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

# --- Fixtures: minimal Validator_types.report sexps ---------------------
# One Invariant check (V6, twin positions), which is what the paired-read
# gate selects by default.
write_report() {
  # $1 = path, $2 = n_violations, $3 = specimens sexp
  cat >"$1" <<EOF
((checks
  (((id V6)
    (severity Invariant)
    (passed false)
    (n_violations $2)
    (n_skipped 0)
    (specimens $3))))
 (audit_join ((matched 0) (total 0))))
EOF
}

CLEAN="$WORK/a0-null-validator.sexp"
TWIN="$WORK/a1-map-validator.sexp"
MALFORMED="$WORK/malformed-validator.sexp"
WRONG_SHAPE="$WORK/wrong-shape-validator.sexp"
MISSING="$WORK/does-not-exist-validator.sexp"

write_report "$CLEAN" 0 "()"
write_report "$TWIN" 1 \
  '(((symbol BFX) (entry_date 2020-04-22) (detail "twin positions: BFX/NLS")))'

# Not a sexp at all: an unterminated list -- Sexp.load_sexp raises.
printf '((checks (((id V6)\n' >"$MALFORMED"
# A well-formed sexp of the wrong shape: report_of_sexp raises.
printf '(not a validator report)\n' >"$WRONG_SHAPE"

fail_count=0

# Run the CLI and echo its exit code without tripping `set -e`.
exit_of() {
  set +e
  "$EXE" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  echo "$rc"
}

check() {
  desc="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $desc (exit=$actual)"
  else
    echo "  FAIL: $desc (expected exit=$expected, got exit=$actual)" >&2
    fail_count=$((fail_count + 1))
  fi
}

# --- 0: the arms agree --------------------------------------------------
check "identical reports agree" "0" \
  "$(exit_of -report "null=$CLEAN" -report "map=$CLEAN")"

# --- 1: the arms differ (a real finding) --------------------------------
check "differing V6 counts are a finding" "1" \
  "$(exit_of -report "null=$CLEAN" -report "map=$TWIN")"

# --- 2: operator errors -------------------------------------------------
check "bad -report form (no '=')" "2" \
  "$(exit_of -report "$CLEAN" -report "map=$TWIN")"

check "nonexistent report path" "2" \
  "$(exit_of -report "null=$MISSING" -report "map=$TWIN")"

check "malformed sexp (unparseable)" "2" \
  "$(exit_of -report "null=$MALFORMED" -report "map=$TWIN")"

check "well-formed sexp of the wrong shape" "2" \
  "$(exit_of -report "null=$WRONG_SHAPE" -report "map=$TWIN")"

check "fewer than two reports" "2" \
  "$(exit_of -report "null=$CLEAN")"

check "unknown -check id" "2" \
  "$(exit_of -report "null=$CLEAN" -report "map=$TWIN" -check V99)"

# A read failure must NOT be reported as the "arms differ" code, which is the
# distinction the whole 0/1/2 split exists for. Re-stated as its own case so a
# regression names the confusion rather than just a wrong number.
missing_rc="$(exit_of -report "null=$MISSING" -report "map=$TWIN")"
if [ "$missing_rc" = "1" ]; then
  echo "  FAIL: an unreadable report exited 1 (\"the arms differ\") instead of 2" >&2
  fail_count=$((fail_count + 1))
fi

if [ "$fail_count" -ne 0 ]; then
  die "${LABEL} — $fail_count exit-code case(s) wrong."
fi

echo "OK: ${LABEL} — 8 exit-code cases pinned."
