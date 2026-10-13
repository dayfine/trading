#!/bin/sh
# render.sh <SYM|MARKET> <cut YYYY-MM-DD> <outdir>: the pages a reader sees on the cut date (plan §3).
#   SYM:    <outdir>/<DISP>-<cut>-full.{svg,png}, <DISP>-<cut>-5y.{svg,png}, <DISP>-<cut>.json (last bar), where
#           DISP is the ticker as traded (store suffix _old[N] or trailing digits removed; see below)
#   MARKET: <outdir>/MARKET-<cut>-full.{svg,png}, MARKET-<cut>-5y.{svg,png}
# Run from the repo root. DATA = daily store (default data). Needs results/market/ (market.sh) for MARKET.
# Weekly CSVs are cached in $WEEKLY (default .sweep-output/fresh-eyes/weekly). PNG: headless Chrome
# (CHROME= overrides the macOS default); NOPNG=1 writes the SVGs and JSON only.
set -e
s=$1; cut=$2; out=$3
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts; DATA=${DATA:-data}
WEEKLY=${WEEKLY:-.sweep-output/fresh-eyes/weekly}
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
# A cut must be a Friday: a mid-week cut would draw the whole week, including days after the cut.
fri=$(awk -v c="$cut" -f $S/days.awk -f $S/isfriday.awk)
[ "$fri" = 1 ] || { echo "render.sh: cut $cut is not a Friday" >&2; exit 2; }
mkdir -p "$out" "$WEEKLY"
png() {  # png <svg> <png> <height>: up to 3 attempts, each killed after 60 s (headless Chrome can hang)
  [ -n "$NOPNG" ] && return 0
  u="file://$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  for try in 1 2 3; do
    rm -f "$2"
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size="1600,$3" \
      --screenshot="$2" "$u" >/dev/null 2>&1 &
    cpid=$!; t=0
    while kill -0 $cpid 2>/dev/null && [ $t -lt 300 ]; do sleep 0.2; t=$((t + 1)); done
    kill -0 $cpid 2>/dev/null && { kill $cpid 2>/dev/null; sleep 1; kill -9 $cpid 2>/dev/null || true; }
    wait $cpid 2>/dev/null || true
    [ -s "$2" ] && return 0
  done
  echo "render.sh: no PNG written for $1 after 3 attempts" >&2; exit 1
}
if [ "$s" = MARKET ]; then
  M=$E/results/market
  for fr in full 5y; do
    awk -F, -v cut="$cut" -v frame=$fr -f $S/days.awk -f $S/chartlib.awk -f $S/market.awk \
      $M/spy-weekly.csv $M/ad-weekly.csv $M/sector-strength.csv > "$out/MARKET-$cut-$fr.svg"
    png "$out/MARKET-$cut-$fr.svg" "$out/MARKET-$cut-$fr.png" 1260
  done
  exit 0
fi
w=$WEEKLY/$s.csv
[ -s "$w" ] || DATA=$DATA sh $S/weekly.sh "$s" > "$w"
# Two things on the page could leak the future, so they are neutralised:
# - the store's names for reused tickers (DO_old, INFO_old1, SDS1) say the company later lost the ticker, so the
#   page shows the ticker as traded (suffix _old[N] or trailing digits removed);
# - data/sectors.csv is survivor-only (about 44 of the 100 sampled names have no row, mostly delisted ones), so a
#   missing sector says "this stock dies". The sector is therefore hidden for every symbol unless SHOW_SECTOR=1.
disp=$(printf %s "$s" | sed -E 's/_old[0-9]*$//; s/[0-9]+$//')
# Output files carry the display name too (the reader sees the file names), so two sampled symbols must not share
# one display name.
clash=$(awk -v s="$s" -v d="$disp" '{ t = $2; u = t; sub(/_old[0-9]*$/, "", u); sub(/[0-9]+$/, "", u); if (t != s && u == d) print t }' $E/results/sample.txt)
[ -z "$clash" ] || { echo "render.sh: $s and $clash share the display name $disp" >&2; exit 2; }
if [ "${SHOW_SECTOR:-0}" = 1 ]; then
  sector=$(awk -F, -v s="$s" '$1 == s { print $2; exit }' "$DATA/sectors.csv"); [ -n "$sector" ] || sector="sector unknown"
else sector="sector not shown"; fi
for fr in full 5y; do
  awk -F, -v cut="$cut" -v frame=$fr -v sym="$disp" -v sector="$sector" -f $S/days.awk -f $S/chartlib.awk -f $S/chart.awk \
    "$w" > "$out/$disp-$cut-$fr.svg"
  png "$out/$disp-$cut-$fr.svg" "$out/$disp-$cut-$fr.png" 1000
done
# Last bar at or before the cut, on the chart's basis (rescaled so the close is the raw close).
awk -F, -v cut="$cut" -v sym="$disp" -v sector="$sector" -f $S/days.awk -f $S/lastbar.awk "$w" > "$out/$disp-$cut.json"
