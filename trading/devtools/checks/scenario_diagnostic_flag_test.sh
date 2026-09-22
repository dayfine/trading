#!/bin/sh
# Exercise the real checker against real scripts and disposable mutations.
set -eu
. "$(dirname "$0")/_check_lib.sh"
root=$(repo_root)
checker="$(dirname "$0")/scenario_diagnostic_flag.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
checks=0
expect() {
  expected=$1; shift
  actual=0
  sh "$checker" "$@" >"$work/output" 2>&1 || actual=$?
  [ "$actual" -eq "$expected" ] || { cat "$work/output"; die "expected $expected, got $actual"; }
  checks=$((checks + 1))
}
expect 0
for script in "$root"/dev/scripts/perf_tier[1234]_*.sh \
  "$root/dev/scripts/run_tier4_release_gate.sh" \
  "$root/dev/scripts/golden_sp500_postsubmit.sh"; do
  expect 0 "$script"
  sed 's/--no-emit-all-eligible//g' "$script" >"$work/missing.sh"
  expect 1 "$work/missing.sh"
done
# A compliant sibling invocation or comment must not hide a missing flag.
printf '%s\n' '# --no-emit-all-eligible' \
  'scenario_runner.exe -- --dir one --no-emit-all-eligible' \
  'scenario_runner.exe -- --dir two' >"$work/mixed.sh"
expect 1 "$work/mixed.sh"
printf '%s\n' 'scenario_runner.exe -- --no-emit-all-eligible-extra' >"$work/prefix.sh"
expect 1 "$work/prefix.sh"
printf '%s\n' 'dune build scenario_runner.exe' >"$work/build.sh"
expect 1 "$work/build.sh"
printf 'OK: scenario diagnostic flag -- %s checks clean.\n' "$checks"
