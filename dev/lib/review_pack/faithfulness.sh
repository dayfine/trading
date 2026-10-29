#!/bin/sh
# Read only assemble.awk's existing per-run trades JSON. No new evidence joins.
# usage: faithfulness.sh TRADES_JSON [DROP_IDS]   DROP_IDS: comma-separated check ids read as n/a
#   for every trade (review_pack.sh passes "1,13", the stage-replay checks, when only some runs have a replay)
set -eu
LIB=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ ! -s "$1" ]; then
  printf '{"available":false,"rows":null}\n'; exit 0
fi
drop=$(jq -n -c --arg d "${2:-}" '$d | split(",") | map(select(length > 0) | tonumber)')
jq --argjson drop "$drop" -f "$LIB/faithfulness.jq" "$1"
