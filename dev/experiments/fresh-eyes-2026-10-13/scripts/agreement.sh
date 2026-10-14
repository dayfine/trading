#!/bin/sh
# agreement.sh <runs dir>: driving vs shadow reader agreement over every symbol's first-attempt answers (pilot 2).
# Run from the repo root.
S=dev/experiments/fresh-eyes-2026-10-13/scripts
for d in "$1"/*/; do
  for f in "$d"raw/*-1.txt; do grep -q '"action"' "$f" || continue; c=$(basename "$f" -1.txt); printf 'D|%s|%s\n' "$(basename "$d")-$c" "$(tr '\n' ' ' < "$f")"; done
  for f in "$d"shadow-raw/*.txt; do grep -q '"action"' "$f" || continue; c=$(basename "$f" .txt); printf 'S|%s|%s\n' "$(basename "$d")-$c" "$(tr '\n' ' ' < "$f")"; done
done | awk -f $S/agreement.awk
