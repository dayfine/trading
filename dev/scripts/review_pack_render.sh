#!/bin/sh
# review_pack_render.sh -- render a review pack (dev/scripts/review_pack.sh) to
# PNG screenshots so the pack can be LOOKED AT, not just read
# (.claude/rules/backtest-result-review.md).
#
# usage:
#   sh dev/scripts/review_pack_render.sh --site DIR [--out DIR] [--width W]
#   sh dev/scripts/review_pack_render.sh --plan TOTAL   (print the slice plan only)
#
#   --site DIR   the pack's site directory (holds index.html + data/)
#   --out DIR    where the PNGs go (default DIR/../render)
#   --width W    viewport width in px (default 1400)
#   --plan TOTAL print "part y height" for a page TOTAL px tall and exit
#
# Writes OUT/inline.html (the page with every data/*.json embedded behind a
# fetch shim, so it loads from file:// -- the published page fetches data/
# relative to itself, which file:// cannot do) and the screenshots:
#   OUT/top.png     the first screen: KPIs, equity vs SPY, drawdown + exposure, macro gate
#   OUT/full.png    the WHOLE page at its measured height (#3177: a fixed 9000 px
#                   capture cut the page after the validator's V8 and left the
#                   conformance table out of every slice)
#   OUT/part-N.png  full.png cut into 1500 px slices, readable one by one; the
#                   last slice is the bottom 1500 px, so every pixel row of the
#                   page is in some part
#
# The page height is measured by loading the page once in Chrome (--dump-dom)
# with a probe that writes document height into <html data-page-h>. A page that
# failed to load its data ("Could not load the data files") stops the render.
#
# Slicing uses macOS sips or ImageMagick (convert / magick), whichever exists.
# Needs jq and Google Chrome or Chromium (CHROME=<path> overrides the macOS
# default; run as root, Chrome gets --no-sandbox). Host-only; no container, no
# build -- safe beside a running backtest.
set -eu
SITE=""; OUT=""; W=1400; PLAN=""
SLICE=1500        # slice height, px
FALLBACK_H=9000   # page height used when the measurement fails
while [ $# -gt 0 ]; do
  case $1 in
    --site) SITE=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --width) W=$2; shift 2 ;;
    --plan) PLAN=$2; shift 2 ;;
    *) echo "review_pack_render: unknown argument $1" >&2; exit 2 ;;
  esac
done

# Slices of a TOTAL px page: "part y height", SLICE px each, y >= 1 and the last
# one ending one row above the bottom. sips silently writes the WHOLE image when
# the offset is 0 ("no offset": it crops the centre) or when the crop's bottom
# edge lands exactly on the image's, so the offset is clamped to
# [1, TOTAL - SLICE - 1] (one pixel row lost at each end). A page shorter than
# two slices is one part, the whole page.
slice_plan() {
  awk -v t="$1" -v h="$SLICE" 'BEGIN {
    if (t <= h + 2) { print 1, 0, t; exit }
    n = int((t + h - 1) / h)
    for (i = 1; i <= n; i++) { y = (i - 1) * h; if (y < 1) y = 1; if (y > t - h - 1) y = t - h - 1; print i, y, h }
  }'
}
if [ -n "$PLAN" ]; then slice_plan "$PLAN"; exit 0; fi

[ -n "$SITE" ] && [ -s "$SITE/index.html" ] || { echo "review_pack_render: --site DIR with index.html required" >&2; exit 2; }
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[ -x "$CHROME" ] || { echo "review_pack_render: Chrome not found at $CHROME (set CHROME=)" >&2; exit 2; }
SITE=$(cd "$SITE" && pwd); OUT=${OUT:-$SITE/../render}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
NOSANDBOX=""; [ "$(id -u)" = 0 ] && NOSANDBOX="--no-sandbox"

# data/<path>.json -> one JSON object keyed by "data/<path>.json"
data=$OUT/data.json
(cd "$SITE" && find data -name '*.json' | sort | while read -r f; do
  printf '%s\t' "$f"; jq -c . "$f"; done) |
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: (.[1:] | join("\t") | fromjson)}) | from_entries' > "$data"

# Shim: fetch("data/...") resolves from the embedded object; anything else
# (fonts, the charting CDN) goes to the network as before. The probe at the end
# keeps <html data-page-h> at the document's current height.
{
  printf '<meta charset="utf-8">\n<script>window.__PACK__ = '
  cat "$data"
  printf ';\n(function () { var real = window.fetch; window.fetch = function (u, o) {\n'
  printf '  var k = String(u).replace(/^\\.\\//, "");\n'
  printf '  if (Object.prototype.hasOwnProperty.call(window.__PACK__, k)) {\n'
  printf '    var body = JSON.stringify(window.__PACK__[k]);\n'
  printf '    return Promise.resolve(new Response(body, { headers: { "Content-Type": "application/json" } })); }\n'
  printf '  return real.call(this, u, o); }; })();</script>\n'
  grep -v '^<meta charset="utf-8">$' "$SITE/index.html"
  printf '<script>setInterval(function () { document.documentElement.setAttribute("data-page-h", document.documentElement.scrollHeight); }, 200);</script>\n'
} > "$OUT/inline.html"
rm -f "$data"

chrome() { # extra Chrome args...
  # shellcheck disable=SC2086
  "$CHROME" --headless=new $NOSANDBOX --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --virtual-time-budget=20000 "$@" "file://$OUT/inline.html" 2>/dev/null
}
shot() { # $1 file, $2 height
  chrome --window-size="$W,$2" --screenshot="$OUT/$1" >/dev/null || true
  [ -s "$OUT/$1" ] || { echo "review_pack_render: no screenshot written for $1" >&2; exit 1; }
}
dom=$(chrome --window-size="$W,1300" --dump-dom || true)
# the page's own source carries the message as a template (${e.message}); a rendered failure does not
if printf '%s' "$dom" | grep -q 'Could not load the data files ([^$]'; then
  echo "review_pack_render: the page failed to load: $(printf '%s' "$dom" | grep -o 'Could not load the data files ([^$][^<]*' | head -1)" >&2; exit 1
fi
TOTAL=$(printf '%s' "$dom" | grep -o 'data-page-h="[0-9]*"' | head -1 | tr -dc '0-9')
[ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] || { echo "review_pack_render: could not measure the page; using ${FALLBACK_H} px" >&2; TOTAL=$FALLBACK_H; }

shot top.png 1300
shot full.png "$TOTAL"
crop() { # $1 y, $2 height, $3 out
  if command -v sips >/dev/null 2>&1; then
    sips -c "$2" "$W" --cropOffset "$1" 0 "$OUT/full.png" --out "$3" >/dev/null 2>&1
  elif command -v magick >/dev/null 2>&1; then magick "$OUT/full.png" -crop "${W}x$2+0+$1" +repage "$3"
  elif command -v convert >/dev/null 2>&1; then convert "$OUT/full.png" -crop "${W}x$2+0+$1" +repage "$3"
  else echo "review_pack_render: no sips or ImageMagick to cut full.png into parts" >&2; return 1; fi
}
height() { # $1 png -> pixel height
  if command -v sips >/dev/null 2>&1; then sips -g pixelHeight "$1" | awk '/pixelHeight/ {print $2}'
  else identify -format '%h' "$1"; fi
}
rm -f "$OUT"/part-*.png
n=0
slice_plan "$TOTAL" > "$OUT/plan.txt"
while read -r i y h; do
  if [ "$i" = 1 ] && [ "$y" = 0 ]; then cp "$OUT/full.png" "$OUT/part-1.png"
  else crop "$y" "$h" "$OUT/part-$i.png" || { echo "review_pack_render: crop failed (part $i)" >&2; exit 1; }; fi
  [ "$(height "$OUT/part-$i.png")" = "$h" ] ||
    { echo "review_pack_render: part $i is not $h px tall (the crop ignored the offset)" >&2; exit 1; }
  n=$i
done < "$OUT/plan.txt"
rm -f "$OUT/plan.txt"
echo "review_pack_render: $OUT/top.png $OUT/full.png ($TOTAL px) $OUT/part-1..$n.png"
