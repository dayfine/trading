#!/bin/sh
# Decision-time large-dividend split over all events (host only). Writes results/analysis/divsplit.txt.
E=dev/experiments/short-setup-map-2026-10-12; T=${TMPDIR:-/tmp}/ssm-divsplit; mkdir -p "$T"; : > "$T/rows.csv"
cat $E/results/events/*.csv | awk -F, 'NR==1{for(k=1;k<=NF;k++)c[$k]=k;next} /^sym,/{next}
  {ev[$1]=ev[$1] (ev[$1]==""?"":";") $(c["date"]) "|" $(c["raw_close"]) "|" $(c["e1_date"]) "|" $(c["e1_o2_exc"])}
  END{for(s in ev) print s "\t" ev[s]}' |
while IFS="$(printf '\t')" read -r s evs; do
  a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=data/$a/$b/$s
  dv=$p/dividends.csv; [ -f "$dv" ] || dv=/dev/null
  awk -F, -v sym="$s" -v ev="$evs" -f $E/results/analysis/divsplit.awk "$p/data.csv" "$dv" >> "$T/rows.csv"
done
awk -F, '{g=$3; n[g]++; s[g]+=$4; if($4>0)b[g]++} END{for(g=1;g>=0;g--) printf "decision-time large dividend in hold=%d: n=%d beat=%.1f%% mean=%+.2f%%\n", g, n[g], 100*b[g]/n[g], 100*s[g]/n[g]}' "$T/rows.csv" > $E/results/analysis/divsplit.txt
cat $E/results/analysis/divsplit.txt
