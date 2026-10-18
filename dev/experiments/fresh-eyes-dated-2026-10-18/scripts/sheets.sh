#!/bin/sh
# sheets.sh <date> <date dir>: the step-C contact sheets (plan §3): every pool name as a 5-year thumbnail
# (thumb.awk) under its pseudonym, 20 to a sheet (4 columns x 5 rows of 600 x 400 = 2400 x 2000 px), in pool.csv's
# random order, so our screener's names are not grouped. Needs pool.sh's pool.csv and store/.
# Writes <date dir>/sheets/sheet-<n>.png and sheet-<n>.txt (the pseudonyms on it, in reading order);
# weekly CSVs go to <date dir>/weekly/<PSEUDO>.csv (shared with day.sh and follow.sh), thumbnails to thumbs/.
# Restartable: an existing sheet PNG is kept. Run from the repo root.
set -e
d=$1; DD=$2
S0=dev/experiments/fresh-eyes-2026-10-13/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
PER=${PER:-20}; COLS=${COLS:-4}
mkdir -p "$DD/sheets" "$DD/thumbs" "$DD/weekly"
awk -F, 'NR > 1 { print $1 }' "$DD/pool.csv" > "$DD/sheets/order.txt"
while read -r p; do
  w=$DD/weekly/$p.csv
  [ -s "$w" ] || DATA=$DD/store sh $S0/weekly.sh "$p" > "$w"
  [ -s "$DD/thumbs/$p.svg" ] || awk -F, -v cut="$d" -v sym="$p" -f $S0/days.awk -f $S0/chartlib.awk -f $S/thumb.awk "$w" > "$DD/thumbs/$p.svg"
done < "$DD/sheets/order.txt"
rm -f "$DD"/sheets/sheet-*.txt.tmp
awk -v per="$PER" -v dir="$DD/sheets" '{ f = dir "/sheet-" (int((NR - 1) / per) + 1) ".txt.tmp"; print > f }' "$DD/sheets/order.txt"
for t in "$DD"/sheets/sheet-*.txt.tmp; do
  b=${t%.txt.tmp}; mv "$t" "$b.txt"
  [ -s "$b.png" ] && continue
  rows=$(( ($(wc -l < "$b.txt") + COLS - 1) / COLS ))
  { printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#fff}'
    printf '.g{display:grid;grid-template-columns:repeat(%d,600px);gap:1px;margin:1px}img{display:block}</style></head><body><div class="g">\n' "$COLS"
    while read -r p; do printf '<img src="file://%s/%s.svg" width="600" height="400">\n' "$(cd "$DD/thumbs" && pwd)" "$p"; done < "$b.txt"
    printf '</div></body></html>\n'; } > "$b.html"
  sh $S/shot.sh "$b.html" "$b.png" $((COLS * 601 + 2)) $((rows * 401 + 2))
  rm -f "$b.html"
done
echo "sheets.sh: $d $(ls "$DD"/sheets/sheet-*.png | wc -l | tr -d ' ') sheets, $(wc -l < "$DD/sheets/order.txt" | tr -d ' ') names"
