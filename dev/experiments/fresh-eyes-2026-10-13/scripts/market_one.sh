#!/bin/sh
# market_one.sh <out dir> <cut>: one market-pack render (the xargs worker of market_pages.sh).
exec sh "$(dirname "$0")/render.sh" MARKET "$2" "$1"
