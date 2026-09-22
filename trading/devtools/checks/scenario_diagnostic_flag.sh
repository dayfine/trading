#!/bin/sh
# Static check of perf/golden command text, including backslash continuations.
# This deliberately does not execute or expand shell commands.
set -eu
. "$(dirname "$0")/_check_lib.sh"
if [ "$#" -eq 0 ]; then
  root=$(repo_root)
  set -- "$root"/dev/scripts/perf_tier[1234]_*.sh \
    "$root/dev/scripts/run_tier4_release_gate.sh" \
    "$root/dev/scripts/golden_sp500_postsubmit.sh"
fi
for script do
  awk '
    /^[[:space:]]*#/ { next }
    { command = command " " $0 }
    /\\$/ { sub(/\\$/, "", command); next }
    {
      if (command ~ /scenario_runner[.]exe[[:space:]]+--[[:space:]]/) {
        count++
        if (command !~ /[[:space:]]--no-emit-all-eligible([[:space:]]|$)/) {
          print "FAIL: " FILENAME ":" NR ": missing --no-emit-all-eligible"
          failed = 1
        }
      }
      command = ""
    }
    END {
      if (!count) { print "FAIL: " FILENAME ": no scenario_runner invocation"; failed = 1 }
      exit failed
    }
  ' "$script" || exit 1
done
