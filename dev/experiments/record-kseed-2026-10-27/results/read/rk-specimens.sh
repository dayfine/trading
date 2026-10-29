#!/bin/sh
# record-kseed-2026-10-27: raw-file specimens quoted in README §Results (defects and the ADMA trace).
# Usage: sh rk-specimens.sh <raw-sweep-dir> <data-dir> <out-file>
set -eu
RAW=$1; D=$2; O=$3
{
  echo "## ADMA entry record, k1 (decision 2023-08-18)"
  awk '/\(symbol ADMA\) \(entry_date 2023-08-18\)/{f=1} f' "$RAW/rk-k1-s0-trade_audit.sexp" | grep -oE '\((cascade_score|suggested_entry|close_at_decision|installed_stop|stop_floor_kind|risk_pct|initial_position_value|placement_date|ticket_age_weeks_at_fill) [^()]+\)' | head -9 | tr '\n' ' '; echo; echo
  echo "## SGNT-wein-703, k0: installed stop (unrounded) and the bars around the exit"
  awk '/\(symbol SGNT\) \(entry_date 2014-07-11\)/{f=1} f' "$RAW/rk-k0-s0-trade_audit.sexp" | grep -oE '\(installed_stop [^()]+\)' | head -1
  head -1 "$D/S/T/SGNT/data.csv"; grep -E '^2014-08-0[1-6]' "$D/S/T/SGNT/data.csv"; echo
  echo "## IHG 2012-06-19 entry bar and its later consolidation"
  head -1 "$D/I/G/IHG/data.csv"; grep -E '^2012-06-19' "$D/I/G/IHG/data.csv"; grep -E '^2012-10-09' "$D/I/G/IHG/splits.csv"
} > "$O"
echo "wrote $O"
