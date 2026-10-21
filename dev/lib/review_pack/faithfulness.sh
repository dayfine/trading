#!/bin/sh
# Read only assemble.awk's existing per-run trades JSON. No new evidence joins.
set -eu
LIB=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ ! -s "$1" ]; then
  printf '{"available":false,"rows":null}\n'; exit 0
fi
jq -f "$LIB/faithfulness.jq" "$1"
