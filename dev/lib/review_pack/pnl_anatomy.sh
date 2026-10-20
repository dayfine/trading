#!/bin/sh
# The staged run's trades/equity and existing 65-bar continuation extraction.
set -eu
LIB=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
RUN=$1
if [ ! -s "$RUN/trades.csv" ]; then
  printf '{"available":false,"rows":null}\n'; exit 0
fi
nav="$RUN/equity_curve.csv"; [ -s "$nav" ] || nav=/dev/null
trace="$RUN/x_trades.tsv"; [ -s "$trace" ] || trace=/dev/null
awk -f "$LIB/pnl_anatomy.awk" "$nav" "$RUN/trades.csv" "$trace"
