#!/bin/sh
# render.sh <SYM|MARKET> <cut YYYY-MM-DD> <outdir>: the pages a reader sees on the cut date (plan §3).
#   SYM:    <outdir>/<SYM>-<cut>-full.{svg,png}, <SYM>-<cut>-5y.{svg,png}, <SYM>-<cut>.json (last bar)
#   MARKET: <outdir>/MARKET-<cut>-full.{svg,png}, MARKET-<cut>-5y.{svg,png}
# Run from the repo root. DATA = daily store (default data). Needs results/market/ (market.sh) for MARKET.
# Weekly CSVs are cached in $WEEKLY (default .sweep-output/fresh-eyes/weekly). PNG: headless Chrome
# (CHROME= overrides the macOS default); NOPNG=1 writes the SVGs and JSON only.
set -e
s=$1; cut=$2; out=$3
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts; DATA=${DATA:-data}
WEEKLY=${WEEKLY:-.sweep-output/fresh-eyes/weekly}
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
mkdir -p "$out" "$WEEKLY"
png() {  # png <svg> <png> <height>
  [ -n "$NOPNG" ] && return 0
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size="1600,$3" \
    --screenshot="$2" "file://$(cd "$(dirname "$1")" && pwd)/$(basename "$1")" >/dev/null 2>&1 || true
  [ -s "$2" ] || { echo "render.sh: no PNG written for $1" >&2; exit 1; }
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
if [ "${SHOW_SECTOR:-0}" = 1 ]; then
  sector=$(awk -F, -v s="$s" '$1 == s { print $2; exit }' "$DATA/sectors.csv"); [ -n "$sector" ] || sector="sector unknown"
else sector="sector not shown"; fi
for fr in full 5y; do
  awk -F, -v cut="$cut" -v frame=$fr -v sym="$disp" -v sector="$sector" -f $S/days.awk -f $S/chartlib.awk -f $S/chart.awk \
    "$w" > "$out/$s-$cut-$fr.svg"
  png "$out/$s-$cut-$fr.svg" "$out/$s-$cut-$fr.png" 1000
done
# Last bar at or before the cut, on the chart's basis (rescaled so the close is the raw close).
awk -F, -v cut="$cut" -v sym="$disp" -v sector="$sector" -f $S/days.awk -f $S/lastbar.awk "$w" > "$out/$s-$cut.json"
