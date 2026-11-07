#!/bin/sh
# seeds.sh RAWDIR OUTROOT -- the two first-order stop replays (replay_basis.awk, replay_anchor.awk) on every seed
# rk-k<k>-s0 of the record band. RAWDIR holds rk-k<k>-s0-{trade_audit.sexp,trades.csv,equity_curve.csv}. Needs ./data.
set -eu
R=$1; OR=$2; L=$(cd "$(dirname "$0")" && pwd); TAB=$(printf '\t')
for k in 0 1 2 3 4; do
  P="$R/rk-k$k-s0-"; D="$OR/k$k"; mkdir -p "$D"
  tr '\n' ' ' < "${P}trade_audit.sexp" | tr -s ' ' | sed 's/ (cascade_summaries/\
CASCADE/' | head -1 | sed 's/((entry /\
ENTRY /g' | grep '^ENTRY' > "$D/records.txt"
  awk -f "$L/stopdec.awk" "$D/records.txt" > "$D/stopdec.tsv"
  sort -t"$TAB" -k2,2 -k1,1 -k3,3 -s "$D/stopdec.tsv" | awk -F'\t' -f "$L/sdbars.awk" > "$D/stopdec_bars.tsv"
  awk -f "$L/replay_basis.awk" "${P}trades.csv" "$D/stopdec_bars.tsv" > "$D/replay_basis.tsv" 2> "$D/replay_basis.log"
  awk -f "$L/stale_anchor.awk" "$D/stopdec_bars.tsv" > "$D/stale_anchor.tsv"
  awk -v SAME=0 -f "$L/replay_anchor.awk" "${P}trades.csv" "$D/stale_anchor.tsv" "$D/stopdec_bars.tsv" > "$D/replay_anchor_s0.tsv"
  realised=$(awk -F, 'NR>1{s+=$9} END{printf "%.0f", s}' "${P}trades.csv")
  anchor=$(awk -F'\t' '{s+=$9} END{printf "%.0f", s}' "$D/replay_anchor_s0.tsv")
  awk -v k=$k -v R="$realised" -v A="$anchor" 'FNR==NR{if(FNR>1){split($0,a,","); nav[a[1]]=a[2]+0; last=a[2]+0; d[++n]=a[1]}; next}
    {split($0,t,"\t"); T+=t[13]; if(t[10]<t[4]){e++; if(t[9]>0.5){w++; wd+=t[13]}}; x=t[10]; if(!(x in nav)){for(i=n;i>=1;i--) if(d[i]<=x){x=d[i];break}} C+=t[13]*last/nav[x]; m++}
    END{printf "k%s: %d closed positions replayed | basis fix %+.0fk = %.1f%% of realised %+.0fk; earlier exits %d, of which > +50%% winners %d (%+.0fk) | compounded at the run'"'"'s own NAV growth: ln(1+R) %+.3f | anchor fix alone %+.0fk\n", k, m, T/1000, 100*T/R, R/1000, e, w, wd/1000, log((last+C)/last), A/1000}' "${P}equity_curve.csv" "$D/replay_basis.tsv"
  printf '   largest cuts: '; awk -F'\t' '$10<$4 && $13<-150000{printf "%s %s %+.0fk; ", $2, substr($3,1,4), $13/1000}' "$D/replay_basis.tsv"; echo
done
