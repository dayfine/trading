#!/bin/sh
# table.sh — build the paired markdown table from per-arm actual.sexp files.
#
#   sh table.sh <results-dir> [<old-arm-fallback-dir>] [<chain.log>]
#
# With a chain.log, a "new arm vs OLD pin" column is added from that cell's
# RESULT line ([PASS] or [FAIL (...)]) — i.e. whether the flipped default
# would have tripped the pre-existing golden band.
#
# For every "<family>--<name>-new-actual.sexp" in <results-dir> the old arm is
# "<family>--<name>-old-actual.sexp" in the same dir if present, else
# "<name>-actual.sexp" in the fallback dir (the #2587 clock-surface artifacts,
# validated as the current-main old arm by the armed-stoplimit lineage check).
set -eu
res=$1; fb=${2:-}; log=${3:-}
metric() { tr '\n' ' ' <"$1" | grep -oE "\($2 -?[0-9][0-9.eE+-]*\)" | head -1 | awk '{gsub(/\)/,""); print $2}'; }
fmt() { awk -v v="$1" 'BEGIN{ if (v=="") print "n/a"; else printf "%.2f", v }'; }
fmti() { awk -v v="$1" 'BEGIN{ if (v=="") print "n/a"; else printf "%d", v }'; }
echo "| golden | old return% / trades / sharpe / maxDD | new return% / trades / sharpe / maxDD | Δ return (pp) | old-arm source | new arm vs OLD pin |"
echo "|---|---:|---:|---:|---|---|"
for n in "$res"/*-new-actual.sexp; do
  [ -f "$n" ] || continue
  tag=$(basename "$n" -new-actual.sexp)      # family--name
  name=${tag#*--}
  o="$res/$tag-old-actual.sexp"; src="direct"
  if [ ! -f "$o" ] && [ -n "$fb" ]; then o="$fb/$name-actual.sexp"; src="#2587 artifact"; fi
  [ -f "$o" ] || { o=""; src="none"; }
  pin="n/a"
  if [ -n "$log" ] && [ -f "$log" ]; then
    pin=$(grep "RESULT $tag-new " "$log" | tail -1 | grep -oE "\[(PASS|FAIL)" | tr -d "[" )
    pin=${pin:-n/a}
  fi
  nr=$(metric "$n" total_return_pct); nt=$(metric "$n" total_trades); ns=$(metric "$n" sharpe_ratio); nd=$(metric "$n" max_drawdown_pct)
  if [ -n "$o" ]; then
    or=$(metric "$o" total_return_pct); ot=$(metric "$o" total_trades); os=$(metric "$o" sharpe_ratio); od=$(metric "$o" max_drawdown_pct)
    d=$(awk -v a="$nr" -v b="$or" 'BEGIN{printf "%+.2f", a-b}')
    printf '| %s | %s / %s / %s / %s | %s / %s / %s / %s | %s | %s | %s |\n' "$tag" \
      "$(fmt "$or")" "$(fmti "$ot")" "$(fmt "$os")" "$(fmt "$od")" \
      "$(fmt "$nr")" "$(fmti "$nt")" "$(fmt "$ns")" "$(fmt "$nd")" "$d" "$src" "$pin"
  else
    printf '| %s | n/a | %s / %s / %s / %s | n/a | %s | %s |\n' "$tag" \
      "$(fmt "$nr")" "$(fmti "$nt")" "$(fmt "$ns")" "$(fmt "$nd")" "$src" "$pin"
  fi
done
