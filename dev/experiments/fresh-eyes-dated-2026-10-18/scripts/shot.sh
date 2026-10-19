#!/bin/sh
# shot.sh <page.html> <out.png> <width> <height>: one headless-Chrome screenshot of a local HTML page, with the
# 2026-10-13 renderers' guard: each launch is killed after 60 s and retried up to 3 times (headless Chrome can hang).
set -e
html=$1; out=$2; w=$3; h=$4
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
d=$(cd "$(dirname "$html")" && pwd); n=$(basename "$html")
for try in 1 2 3; do
  rm -f "$out"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size="$w,$h" --screenshot="$out" "file://$d/$n" >/dev/null 2>&1 &
  cpid=$!; t=0
  while kill -0 $cpid 2>/dev/null && [ $t -lt 300 ]; do sleep 0.2; t=$((t + 1)); done
  kill -0 $cpid 2>/dev/null && { kill $cpid 2>/dev/null; sleep 1; kill -9 $cpid 2>/dev/null || true; }
  wait $cpid 2>/dev/null || true
  [ -s "$out" ] && break
done
[ -s "$out" ] || { echo "shot.sh: no PNG for $out after 3 attempts" >&2; exit 1; }
