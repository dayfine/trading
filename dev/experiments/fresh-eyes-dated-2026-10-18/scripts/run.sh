#!/bin/sh
# run.sh <date ...> | --pilot | --all: the dated-picks run (plan §3-§6), one directory per decision date under
# OUT (default the parent repo's .sweep-output/fresh-eyes-dated/run), then compare_dates.sh over OUT.
# Per date: the quota guard, ours.sh, day.sh (steps A-D), follow.sh (§4); a finished date gets a `done` marker and
# is skipped on a rerun; an unfinished one resumes where it stopped (every step keeps its files).
# Guards (plan §8, batch-model-run skill):
#   - before each date: `sh dev/scripts/quota_status.sh --guard ${GUARD:-0.85} --no-log` (QUOTA_CMD overrides the
#     command); exit 3 (over the guard) or 4 (no reading) stops the run: no new date starts;
#   - a usage-limit reply (ask.sh exit 7) stops the run the same way; nothing waits in a retry loop;
#   - the stop is a file, OUT/STOP, with the reason; delete it to resume in a later session;
#   - at most 2 dates in flight (JOBS, default 1).
# AGENT_STUB=1: stand-in answers, no model calls, and the quota guard is skipped (it makes a small model call)
# unless QUOTA_GUARD=on. REP=r<k>: a self-consistency repeat, written to <date>-r<k> (plan §6 read 5).
# Models: MODEL_A / MODEL_D / MODEL_F (default claude-opus-5-5), MODEL_C (default claude-sonnet-5-5).
# Run from the repo root.
set -e
S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
OUT=${OUT:-/Users/difan/Projects/trading-1/.sweep-output/fresh-eyes-dated/run}; JOBS=${JOBS:-1}
[ "$JOBS" -le 2 ] || { echo "run.sh: JOBS is at most 2 (plan §8)" >&2; exit 2; }
QUOTA_GUARD=${QUOTA_GUARD:-$( [ "${AGENT_STUB:-0}" = 1 ] && echo off || echo on )}
export OUT QUOTA_GUARD
mkdir -p "$OUT/logs"
one_date() {
  d=$1; b=$d; [ -n "$REP" ] && b=$d-$REP; DD=$OUT/$b; L=$OUT/logs/$b.log
  [ -f "$OUT/STOP" ] && { echo "run.sh: $b not started: $(cat "$OUT/STOP")"; return 0; }
  [ -f "$DD/done" ] && { echo "run.sh: $b already done"; return 0; }
  if [ "$QUOTA_GUARD" = on ]; then
    set +e; ${QUOTA_CMD:-sh dev/scripts/quota_status.sh} --guard "${GUARD:-0.85}" --no-log >> "$L" 2>&1; g=$?; set -e
    case $g in
      0) ;;
      3) echo "quota guard ${GUARD:-0.85} reached before $b" > "$OUT/STOP"; echo "run.sh: $b: $(cat "$OUT/STOP")"; return 0 ;;
      *) echo "quota reading failed (exit $g) before $b" > "$OUT/STOP"; echo "run.sh: $b: $(cat "$OUT/STOP")"; return 0 ;;
    esac
  fi
  t0=$(date +%s); mkdir -p "$DD"
  set +e
  { [ -s "$DD/ours/top.csv" ] || sh $S/ours.sh "$d" "$DD"; } >> "$L" 2>&1 \
    && sh $S/day.sh "$d" "$DD" >> "$L" 2>&1 && sh $S/follow.sh "$d" "$DD" >> "$L" 2>&1
  rc=$?; set -e
  case $rc in
    0) touch "$DD/done" ;;
    7) echo "usage-limit reply during $b (see $L)" > "$OUT/STOP" ;;
  esac
  echo "run.sh: $b exit $rc wall $(( $(date +%s) - t0 ))s calls $(($(wc -l < "$DD/calls.csv" 2>/dev/null || echo 1) - 1))"
}
case "$1" in
  --one) one_date "$2"; exit 0 ;;
  --pilot) set -- $(sh $S/dates.sh --pilot 2>/dev/null) ;;
  --all) set -- $(awk '{ print $2 }' dev/experiments/fresh-eyes-dated-2026-10-18/results/dates.txt) ;;
esac
[ $# -gt 0 ] || { echo "usage: run.sh <date ...> | --pilot | --all" >&2; exit 2; }
printf '%s\n' "$@" | xargs -P "$JOBS" -n 1 sh "$0" --one
sh $S/compare_dates.sh "$OUT" > /dev/null && echo "run.sh: compare -> $OUT/compare/report.txt"
[ ! -f "$OUT/STOP" ] || { echo "run.sh: STOPPED: $(cat "$OUT/STOP")"; exit 3; }
