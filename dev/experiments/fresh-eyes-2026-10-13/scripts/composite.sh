#!/bin/sh
# composite.sh <stock base> <market base> <out.png> [<width>]: one PNG holding the cut's four pages in a 2x2 grid
# (top: stock full | stock 5y; bottom: market full | market 5y), so a reader decision is one image read. Built from
# the SVGs render.sh writes (<base>-full.svg, <base>-5y.svg), drawn vectorially at the grid size in one headless
# Chrome launch, so nothing is resampled twice. <width> (default 2400) is the composite's pixel width; each page is
# drawn at width/2. The same timeout / retry as render.sh.
set -e
sb=$1; mb=$2; out=$3; W=${4:-2400}
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
half=$((W / 2)); hs=$((half * 1000 / 1600)); hm=$((half * 1260 / 1600)); H=$((hs + hm + 3))
d=$(cd "$(dirname "$out")" && pwd); n=$(basename "$out" .png); html=$d/$n.composite.html
ab() { (cd "$(dirname "$1")" && printf '%s/%s' "$(pwd)" "$(basename "$1")"); }
printf '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:#fff}
.g{display:grid;grid-template-columns:%dpx %dpx;gap:1px;margin:1px}img{display:block}</style></head><body><div class="g">
<img src="file://%s-full.svg" width="%d" height="%d"><img src="file://%s-5y.svg" width="%d" height="%d">
<img src="file://%s-full.svg" width="%d" height="%d"><img src="file://%s-5y.svg" width="%d" height="%d">
</div></body></html>\n' $half $half "$(ab "$sb-full.svg" | sed 's/-full\.svg$//')" $half $hs "$(ab "$sb-5y.svg" | sed 's/-5y\.svg$//')" $half $hs \
  "$(ab "$mb-full.svg" | sed 's/-full\.svg$//')" $half $hm "$(ab "$mb-5y.svg" | sed 's/-5y\.svg$//')" $half $hm > "$html"
for try in 1 2 3; do
  rm -f "$out"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size="$((W + 3)),$H" --screenshot="$out" "file://$html" >/dev/null 2>&1 &
  cpid=$!; t=0
  while kill -0 $cpid 2>/dev/null && [ $t -lt 300 ]; do sleep 0.2; t=$((t + 1)); done
  kill -0 $cpid 2>/dev/null && { kill $cpid 2>/dev/null; sleep 1; kill -9 $cpid 2>/dev/null || true; }
  wait $cpid 2>/dev/null || true
  [ -s "$out" ] && break
done
rm -f "$html"
[ -s "$out" ] || { echo "composite.sh: no PNG for $out after 3 attempts" >&2; exit 1; }
