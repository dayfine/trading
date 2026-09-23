#!/bin/sh
# Fixture-driven test for scenario_runner_flag_drift.sh.
#
# It exercises the REAL checker against the REAL scripts (must be clean) and
# against disposable mutations that must make it FAIL. A check that has never
# been observed failing is not a check -- see
# `pr_gate_status_mutation_test.sh`'s header ("hand verification has been
# WRONG TWICE IN THE SAME DIRECTION") and `dev/status/harness.md`
# H-SCHEDULED-WORKFLOW-HEALTH.
#
# The load-bearing cases:
#   - the #2921 regression itself, reconstructed verbatim (a
#     `SNAPSHOT_FLAGS="--snapshot-mode"` variable spliced into the command);
#   - the same fixture going GREEN once the runner's parser is stubbed to
#     accept `--snapshot-mode`, which proves the accept-set is read from the
#     runner rather than hardcoded here;
#   - dropping a flag from the runner's parser turns a real, currently-clean
#     script RED, which proves the accept-set is actually consulted.
set -eu
. "$(dirname "$0")/_check_lib.sh"
root=$(repo_root)
checker="$(dirname "$0")/scenario_runner_flag_drift.sh"
runner_ml="$root/trading/trading/backtest/scenarios/scenario_runner.ml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
checks=0

expect() {
  expected=$1
  shift
  actual=0
  sh "$checker" "$@" >"$work/output" 2>&1 || actual=$?
  [ "$actual" -eq "$expected" ] || {
    cat "$work/output"
    die "expected exit $expected, got $actual (args: $*)"
  }
  checks=$((checks + 1))
}

# --- the real world is clean -----------------------------------------------
expect 0
for script in "$root"/dev/scripts/*.sh; do
  expect 0 "$script"
done

# --- the #2921 regression, reconstructed -----------------------------------
# Verbatim shape of the pre-fix wrapper: the bad flag never appears on the
# invocation line, only via $SNAPSHOT_FLAGS.
cat >"$work/regression.sh" <<'EOF'
SNAPSHOT_FLAGS="--snapshot-mode"
if [ -n "$SNAPSHOT_DIR" ]; then
  SNAPSHOT_FLAGS="--snapshot-mode --snapshot-dir $SNAPSHOT_DIR"
fi
cmd="dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- --dir $stage_dir --parallel 1 --no-emit-all-eligible $SNAPSHOT_FLAGS"
"$RUN_IN_ENV" sh -c "$cmd"
EOF
expect 1 "$work/regression.sh"
grep -q -- '--snapshot-mode' "$work/output" || die "regression case did not name the flag"

# Same file with the fix applied is clean.
sed 's/--snapshot-mode --snapshot-dir/--snapshot-dir/; s/SNAPSHOT_FLAGS="--snapshot-mode"/SNAPSHOT_FLAGS=""/' \
  "$work/regression.sh" >"$work/regression_fixed.sh"
expect 0 "$work/regression_fixed.sh"

# --- other drift shapes ----------------------------------------------------
printf '%s\n' \
  'scenario_runner.exe -- --dir one --totally-bogus' >"$work/literal.sh"
expect 1 "$work/literal.sh"

printf '%s\n' \
  'runner_exe="trading/_build/default/trading/backtest/scenarios/scenario_runner.exe"' \
  '"$runner_exe" --dir one --snapshot-mode' >"$work/via_runner_var.sh"
expect 1 "$work/via_runner_var.sh"

printf '%s\n' \
  'scenario_runner.exe -- --dir one \' \
  '  --not-a-flag-either' >"$work/continuation.sh"
expect 1 "$work/continuation.sh"

# --- shapes that must NOT fail ---------------------------------------------
# dune's own flags sit BEFORE the exe and are not the runner's business.
printf '%s\n' \
  'dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- --dir one' \
  >"$work/dune_flags.sh"
expect 0 "$work/dune_flags.sh"

# A build line is not an invocation.
printf '%s\n' 'dune build trading/backtest/scenarios/scenario_runner.exe' \
  >"$work/build_only.sh"
expect 0 "$work/build_only.sh"

# A commented-out bad flag is not a passed flag.
printf '%s\n' '# scenario_runner.exe -- --snapshot-mode' \
  'scenario_runner.exe -- --dir one' >"$work/commented.sh"
expect 0 "$work/commented.sh"

# --- the accept-set is READ, not hardcoded ---------------------------------
# Stub a parser that DOES accept --snapshot-mode: the regression fixture must
# then be clean. If this stayed red the check would be matching a literal.
cat >"$work/accepting_runner.ml" <<'EOF'
let _usage () =
  eprintf "Usage: scenario_runner [--dir <path>] [--parallel N] [--snapshot-mode] [--snapshot-dir <path>] [--no-emit-all-eligible]\n";
  Stdlib.exit 1

let _parse_flag args =
  let rec loop args =
    match args with
    | [] -> ()
    | "--dir" :: _ :: rest -> loop rest
    | "--parallel" :: _ :: rest -> loop rest
    | "--snapshot-mode" :: rest -> loop rest
    | "--snapshot-dir" :: _ :: rest -> loop rest
    | "--no-emit-all-eligible" :: rest -> loop rest
    | _ -> _usage ()
  in
  loop args

let _parse_args () = ()
EOF
SCENARIO_RUNNER_ML="$work/accepting_runner.ml" expect 0 "$work/regression.sh"

# Conversely, dropping a flag the real scripts DO pass turns them red.
sed 's/"--no-emit-all-eligible"/"--retired-flag"/g; s/\[--no-emit-all-eligible\]//g' \
  "$runner_ml" >"$work/narrowed_runner.ml"
SCENARIO_RUNNER_ML="$work/narrowed_runner.ml" \
  expect 1 "$root/dev/scripts/run_tier4_release_gate.sh"
grep -q -- '--no-emit-all-eligible' "$work/output" \
  || die "narrowed-accept-set case did not name the dropped flag"

# --- non-vacuity guard on the accept-set itself ----------------------------
# A runner file whose parser markers have moved must be a HARD FAIL, never a
# silent pass -- an empty accept-set would otherwise bless every script.
printf '%s\n' 'let something_else () = ()' >"$work/no_parser.ml"
SCENARIO_RUNNER_ML="$work/no_parser.ml" expect 1 "$work/literal.sh"
grep -q 'EMPTY accept-set' "$work/output" || die "missing empty-accept-set diagnostic"

SCENARIO_RUNNER_ML="$work/does_not_exist.ml" expect 1 "$work/literal.sh"

printf 'OK: scenario_runner flag drift test -- %s checks clean.\n' "$checks"
