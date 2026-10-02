#!/bin/sh
# review_pack_render.sh -- render a review pack (dev/scripts/review_pack.sh) to
# PNG screenshots so the pack can be LOOKED AT, not just read
# (.claude/rules/backtest-result-review.md).
#
# usage:
#   sh dev/scripts/review_pack_render.sh --site DIR [--out DIR] [--width W]
#
#   --site DIR   the pack's site directory (holds index.html + data/)
#   --out DIR    where the PNGs go (default DIR/../render)
#   --width W    viewport width in px (default 1400)
#
# Writes OUT/inline.html (the page with every data/*.json embedded behind a
# fetch shim, so it loads from file:// -- the published page fetches data/
# relative to itself, which file:// cannot do) and two screenshots:
#   OUT/top.png   the first screen: KPIs, equity vs SPY, drawdown + exposure, macro gate
#   OUT/full.png  the whole page, 9000 px tall: findings, year table, trade list
#   OUT/part-N.png  full.png cut into 1500 px slices (macOS sips), readable one by one
#
# Needs jq and Google Chrome (CHROME=<path> overrides the macOS default).
# Host-only; no container, no build -- safe beside a running backtest.
set -eu
SITE=""; OUT=""; W=1400
while [ $# -gt 0 ]; do
  case $1 in
    --site) SITE=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    --width) W=$2; shift 2 ;;
    *) echo "review_pack_render: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$SITE" ] && [ -s "$SITE/index.html" ] || { echo "review_pack_render: --site DIR with index.html required" >&2; exit 2; }
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
[ -x "$CHROME" ] || { echo "review_pack_render: Chrome not found at $CHROME (set CHROME=)" >&2; exit 2; }
SITE=$(cd "$SITE" && pwd); OUT=${OUT:-$SITE/../render}; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)

# data/<path>.json -> one JSON object keyed by "data/<path>.json"
data=$OUT/data.json
(cd "$SITE" && find data -name '*.json' | sort | while read -r f; do
  printf '%s\t' "$f"; jq -c . "$f"; done) |
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: (.[1:] | join("\t") | fromjson)}) | from_entries' > "$data"

# Shim: fetch("data/...") resolves from the embedded object; anything else
# (fonts, the charting CDN) goes to the network as before.
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
} > "$OUT/inline.html"
rm -f "$data"

shot() { # $1 file, $2 height
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size="$W,$2" --virtual-time-budget=20000 --screenshot="$OUT/$1" \
    "file://$OUT/inline.html" >/dev/null 2>&1
  [ -s "$OUT/$1" ] || { echo "review_pack_render: no screenshot written for $1" >&2; exit 1; }
}
shot top.png 1300
shot full.png 9000
# Slices of the full page at native resolution: a 9000 px image is downscaled
# past legibility by any viewer, so the review reads these one at a time.
H=1500; i=0
while [ $((i * H)) -lt 9000 ]; do i=$((i + 1))
  sips -c $H "$W" --cropOffset $(((i - 1) * H)) 0 "$OUT/full.png" --out "$OUT/part-$i.png" >/dev/null 2>&1 ||
    { echo "review_pack_render: sips crop failed (part $i)" >&2; exit 1; }
done
echo "review_pack_render: $OUT/top.png $OUT/full.png $OUT/part-1..$i.png"
