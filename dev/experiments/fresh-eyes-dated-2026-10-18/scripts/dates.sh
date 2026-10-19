#!/bin/sh
# dates.sh [--pilot]: the decision Fridays (plan §2). 24 blocks of equal length over 2000-01-07..2024-06-28, one
# Friday drawn at random inside each block (awk srand(SEED), default 20261018). Prints "block date" per line.
# --pilot: for each of PILOT_YEARS (default "2002 2008 2017") the drawn date nearest that year's 1 July, one per
# line (with the default seed no date falls in calendar 2008: blocks 8 and 9 drew 2007-12-14 and 2009-01-16, so the
# "2008" pilot date is the nearer one, 2009-01-16, inside the 2007-09 bear market; a note goes to stderr).
# The committed record is results/dates.txt (the draw depends on awk's rand(); macOS awk wrote it).
# Run from the repo root.
set -e
S0=dev/experiments/fresh-eyes-2026-10-13/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
SEED=${SEED:-20261018}; N=${N:-24}; FROM=${FROM:-2000-01-07}; TO=${TO:-2024-06-28}
draw() { awk -v seed="$SEED" -v n="$N" -v from="$FROM" -v to="$TO" -f $S0/days.awk -f $S/dates.awk; }
if [ "$1" = --pilot ]; then
  out=$(draw)
  for y in ${PILOT_YEARS:-2002 2008 2017}; do
    printf '%s\n' "$out" | awk -v y="$y" -v mode=nearest -f $S0/days.awk -f $S/dates.awk
  done
else draw; fi
