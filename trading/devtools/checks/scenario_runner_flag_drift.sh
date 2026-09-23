#!/bin/sh
# Parser-drift guard: every flag a dev/scripts/*.sh shell script passes to
# scenario_runner.exe must be a flag that runner's argument parser accepts.
#
# WHY (#2921): `dev/scripts/run_tier4_release_gate.sh` passed
# `--snapshot-mode`, which `scenario_runner.exe` has never had an arm for --
# its parser accepts only `--snapshot-dir <path>`. Any unknown token falls
# through to `_usage ()` -> exit 1 *before a single cell runs*, so every
# non-`--dry-run` tier-4 invocation died at argument parsing. The flag is a
# legacy no-op on a DIFFERENT parser (`Backtest_runner_args`), and that is
# the second instance of exactly this drift shape: a caller written against
# one runner's flag vocabulary, pointed at another's. The tier-4 gate is
# manual/local and rarely run, so nothing noticed for months.
#
# WHAT IT DOES
#   1. Extracts the accept-set from the runner's own parser: every `"--flag"`
#      string literal inside the `_parse_flag` function body of
#      `trading/trading/backtest/scenarios/scenario_runner.ml`, plus the
#      literals in `_usage ()`. That is the source of truth; nothing is
#      hardcoded here, so adding a flag to the runner needs no edit to this
#      check.
#   2. Joins backslash continuations in each script (same technique as
#      `scenario_diagnostic_flag.sh`), finds commands that invoke the runner,
#      and collects every `--flag` token appearing AFTER the runner mention.
#   3. Fails, naming script + flag, on any collected flag outside the
#      accept-set.
#
# Static text analysis only -- it never executes or shell-expands anything.
#
# SCOPE / KNOWN LIMITS (be honest; do not read a green run as full coverage):
#   - LITERALS ONLY. A flag assembled at runtime that this script cannot see
#     as literal text is invisible. Two partial mitigations are implemented:
#       (a) FLAG VARIABLES. `VAR="--foo --bar"` assignments are collected and
#           expanded when a runner command references `$VAR` / `${VAR}`.
#           This is what catches the #2921 bug, where the bad flag reached
#           the command line via `$SNAPSHOT_FLAGS`. Only single-line,
#           double/single-quoted literal assignments are seen; a flag built
#           by string concatenation, `printf`, a case branch that appends, or
#           an env-var default (`${X:---foo}`) is NOT.
#       (b) RUNNER VARIABLES. `VAR=<...scenario_runner.exe>` assignments are
#           collected (transitively, in file order) so invocations written as
#           `"$runner_exe" --dir ...` are recognised. A runner path assembled
#           out of order, or in a different file, is NOT.
#   - dev/scripts/*.sh ONLY (the default target set). Chain scripts under
#     `dev/experiments/**`, workflow YAML, and ad-hoc shells are out of scope.
#   - ARGUMENT VALUES ARE NOT CHECKED. `--parallel notanumber` passes here.
#   - NO ARM/USAGE CROSS-CHECK. A flag present in `_usage ()` but with no
#     parser arm is accepted by this check (it is in the union). That is a
#     different drift class than the one this guard exists for.
#   - The command window ends at the first line that does not continue with a
#     trailing backslash. A runner invocation spread across a `$(...)` or a
#     here-doc without continuations would be truncated.
#
# Usage:
#   sh scenario_runner_flag_drift.sh                  # all dev/scripts/*.sh
#   sh scenario_runner_flag_drift.sh FILE [FILE...]   # explicit targets
#   SCENARIO_RUNNER_ML=<path> sh scenario_runner_flag_drift.sh ...
#
# Exit status: 0 clean; 1 on a drifted flag or an unusable accept-set.
set -eu
. "$(dirname "$0")/_check_lib.sh"

root=$(repo_root)
runner_ml="${SCENARIO_RUNNER_ML:-$root/trading/trading/backtest/scenarios/scenario_runner.ml}"

[ -f "$runner_ml" ] || die "scenario_runner.ml not found: $runner_ml"

# --- 1. Accept-set from the runner's own parser + usage string. ------------
# Non-vacuity guard: a rename of `_parse_flag` / `_usage` that silently
# yielded an empty accept-set would make every script "clean" forever, so an
# empty extraction is a hard failure rather than a pass.
accept_set=$(
  awk '
    /^let _parse_flag/ { in_parse = 1 }
    /^let _parse_args/ { in_parse = 0 }
    /^let _usage/      { in_usage = 1 }
    in_usage && /Stdlib[.]exit/ { in_usage = 0 }
    (in_parse || in_usage) {
      line = $0
      while (match(line, /--[A-Za-z][A-Za-z0-9-]*/)) {
        print substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$runner_ml" | sort -u
)

if [ -z "$accept_set" ]; then
  die "extracted an EMPTY accept-set from $runner_ml -- the _parse_flag /
_usage markers this check keys on have moved. Fix the extractor; do not
delete the check (an empty accept-set would pass every script silently)."
fi

if [ "$#" -eq 0 ]; then
  set -- "$root"/dev/scripts/*.sh
fi

failed=0
scanned=0

for script do
  [ -f "$script" ] || continue
  scanned=$((scanned + 1))
  found=$(
    awk '
      # Pass 1 (file read twice): collect flag-valued and runner-valued
      # variable assignments, in file order.
      NR == FNR {
        if ($0 !~ /^[[:space:]]*#/ &&
            $0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/) {
          name = $0
          sub(/^[[:space:]]*/, "", name)
          sub(/=.*$/, "", name)
          rhs = $0
          sub(/^[^=]*=/, "", rhs)
          if (rhs ~ /scenario_runner[.]exe/ || _refs_runner(rhs)) {
            runnervar[name] = 1
          }
          if (rhs ~ /--[A-Za-z]/) {
            flagvar[name] = flagvar[name] " " rhs
          }
        }
        next
      }

      # Pass 2: join backslash continuations into one logical command.
      /^[[:space:]]*#/ { next }
      { command = command " " $0 }
      /\\$/ { sub(/\\$/, "", command); next }
      {
        _scan(command)
        command = ""
      }
      END {
        if (command != "") _scan(command)
      }

      function _refs_runner(text,   n) {
        for (n in runnervar) {
          if (index(text, "$" n) > 0 || index(text, "${" n) > 0) return 1
        }
        return 0
      }

      # Offset of the runner mention in a command, or 0 if it is not one.
      function _runner_at(text,   at, n, i) {
        at = index(text, "scenario_runner.exe")
        for (n in runnervar) {
          i = index(text, "$" n)
          if (i > 0 && (at == 0 || i < at)) at = i
          i = index(text, "${" n)
          if (i > 0 && (at == 0 || i < at)) at = i
        }
        return at
      }

      # Splice a flag-variable value in, keeping only the part that is
      # actually passed to the runner: a variable like run_tier4s $cmd holds
      # the WHOLE command line ("dune exec --no-build ... runner -- --dir"),
      # and --no-build belongs to dune, not to the runner.
      function _flagvar_value(n,   v, a) {
        v = flagvar[n]
        a = _runner_at(v)
        if (a > 0) v = substr(v, a)
        return v
      }

      function _scan(text,   at, tail, n, i, tok, parts, count, round, grew) {
        at = _runner_at(text)
        if (at == 0) return
        tail = substr(text, at)
        # Expand flag-valued variables referenced in the invocation, to a
        # fixpoint (a variable may itself reference another, as
        # run_tier4_release_gate.shs $cmd references $SNAPSHOT_FLAGS).
        # Each name is spliced at most once, which bounds the loop.
        for (n in seen) delete seen[n]
        for (round = 0; round < 8; round++) {
          grew = 0
          for (n in flagvar) {
            if (n in seen) continue
            if (index(tail, "$" n) > 0 || index(tail, "${" n) > 0) {
              seen[n] = 1
              tail = tail " " _flagvar_value(n)
              grew = 1
            }
          }
          if (!grew) break
        }
        count = split(tail, parts, /[[:space:]]+/)
        for (i = 1; i <= count; i++) {
          tok = parts[i]
          gsub(/["'"'"'\\]/, "", tok)
          if (tok ~ /^--[A-Za-z][A-Za-z0-9-]*$/) print tok
        }
      }
    ' "$script" "$script" | sort -u
  )
  [ -n "$found" ] || continue
  for flag in $found; do
    if ! printf '%s\n' "$accept_set" | grep -qx -- "$flag"; then
      printf 'FAIL: %s: passes %s to scenario_runner.exe, which its parser does not accept\n' \
        "$script" "$flag" >&2
      failed=1
    fi
  done
done

if [ "$scanned" -eq 0 ]; then
  die "no target scripts scanned -- check the arguments / dev/scripts path"
fi

[ "$failed" -eq 0 ] || exit 1
printf 'OK: scenario_runner flag drift -- %s script(s) clean.\n' "$scanned"
