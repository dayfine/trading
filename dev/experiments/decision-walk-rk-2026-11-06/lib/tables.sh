#!/bin/sh
# tables.sh OUT TRADES_CSV -- the 09-26 walk tables, re-run on one run's intermediates (walk-rk.sh steps 1-4).
set -eu
O=$1; TRC=$2; L=$(cd "$(dirname "$0")" && pwd); TAB=$(printf '\t')
q() { sort -t"$TAB" -k1,1 -k2,2g | awk -v S="${1:-100}" -v T1="${2:-0.5}" -v T2="${3:-1.0}" -f "$L/qstats.awk"; }

echo "== A. returns by the strategy's own macro state (screen week -> next week), by era; SPY = total return"
awk -F'\t' '{y=substr($1,1,4); e=(y<2009?"2000-08":(y<2020?"2009-19":"2020-26")); k=e" | "$2; n[k]++; s[k]+=log(1+$14); v[k]+=log(1+$15); x[k]+=$16}
 END{for(k in n) printf "%s | %3d wk | SPY %+5.0f%% | NAV %+5.0f%% | expo %.0f%%\n",k,n[k],100*(exp(s[k])-1),100*(exp(v[k])-1),x[k]/n[k]}' "$O/timeline.tsv" | sort
echo "-- finer eras"
awk -F'\t' '{y=substr($1,1,4); e=(y<2003?"2000-02":(y<2009?"2003-08":(y<2016?"2009-15":(y<2020?"2016-19":(y<2023?"2020-22":"2023-26"))))); k=e" | "$2; n[k]++; s[k]+=log(1+$14); v[k]+=log(1+$15); x[k]+=$16}
 END{for(k in n) printf "%s | %3d wk | SPY %+5.0f%% | NAV %+5.0f%% | expo %.0f%%\n",k,n[k],100*(exp(s[k])-1),100*(exp(v[k])-1),x[k]/n[k]}' "$O/timeline.tsv" | sort
awk -F'\t' '{n[$2]++; s[$2]+=log(1+$14); v[$2]+=log(1+$15); x[$2]+=$16} END{for(k in n) printf "ALL %s | %d wk | SPY %+.0f%% | NAV %+.0f%% | expo %.0f%%\n",k,n[k],100*(exp(s[k])-1),100*(exp(v[k])-1),x[k]/n[k]}' "$O/timeline.tsv" | sort
echo "-- screens that placed nothing, by macro state"
awk -F'\t' '{n[$2]++; if($9==0) z[$2]++} END{for(k in n) printf "%s: %d of %d\n",k,z[k],n[k]}' "$O/timeline.tsv" | sort

echo; echo "== B. picks vs the rest of the top-N at the same screen: forward adjusted return from the screen close"
for H in 3 4 5; do
  case $H in 3) hz=13w ;; 4) hz=26w ;; *) hz=52w ;; esac
  echo "-- $hz; paired per screen week (placed mean vs each alternative class mean)"
  awk -F'\t' -v H=$H -f "$L/picks.awk" "$O/fwd.tsv" "$O/decisions.tsv" 2>&1 >/dev/null
  echo "-- $hz; pooled distributions (% ; last columns = share above +50 % / +100 %)"
  awk -F'\t' -v H=$H -f "$L/picks.awk" "$O/fwd.tsv" "$O/decisions.tsv" 2>/dev/null | q 100 0.5 1.0
done
echo "-- outcomes at the top-N cut, all screens"
awk -F'\t' '{c[$3]++} END{for(k in c) print c[k] "\t" k}' "$O/decisions.tsv" | sort -rn

echo; echo "== C. stops: initial stop kind, width, quick-fails (stop exit <= 20 days with MFE < 3 %)"
awk -F'\t' 'NR==FNR{fk[$3]=$13; next} {k=fk[$1]; n[k]++; p[k]+=$6; c[k]+=$5; sd[k]+=$11; if($7=="stop_loss")s[k]++; if($7=="stop_loss"&&$10<=20&&$9<3)qf[k]++}
 END{for(k in n) printf "%s | %d trades | %+.0fk | mean %+.2f%% | stopped %.0f%% | quick-fail %.0f%% | init stop %.1f%%\n",k,n[k],p[k]/1000,c[k]/n[k],100*s[k]/n[k],100*qf[k]/n[k],100*sd[k]/n[k]}' "$O/entries.tsv" "$O/tr_full.tsv"
echo "-- by stop distance from the fill (sfd)"
awk -F'\t' '{d=$11; b=(d<0.06?"a) <6%":(d<0.08?"b) 6-8%":(d<0.10?"c) 8-10%":(d<0.12?"d) 10-12%":(d<0.15?"e) 12-15%":"f) >=15%"))))); n[b]++; p[b]+=$6; c[b]+=$5; if($7=="stop_loss")s[b]++; if($7=="stop_loss"&&$10<=20&&$9<3)qf[b]++; if($5>50) t[b]++}
 END{for(b in n) printf "%s | %3d trades | %+6.0fk | mean %+6.2f%% | stopped %3.0f%% | quick-fail %3.0f%% | >+50%% %d\n",b,n[b],p[b]/1000,c[b]/n[b],100*s[b]/n[b],100*qf[b]/n[b],t[b]}' "$O/tr_full.tsv" | sort
echo "-- by stop distance / ATR20 at the fill"
awk -F'\t' '{r=$7/$8; b=(r<2?"a) <2 ATR":(r<3?"b) 2-3":(r<4?"c) 3-4":(r<6?"d) 4-6":"e) 6+ ATR")))); n[b]++; if($3=="stop_loss"&&$4<=20&&$5<3)qf[b]++; p[b]+=$6}
 END{for(b in n) printf "%s | %3d | quick-fail %3.0f%% | %+6.0fk\n",b,n[b],100*qf[b]/n[b],p[b]/1000}' "$O/atr.tsv" | sort
awk -F'\t' '{print $8}' "$O/atr.tsv" | sort -g | awk '{a[NR]=$1} END{printf "ATR20 at the fill: median %.1f%%, p25 %.1f%%, p75 %.1f%%\n", 100*a[int(NR/2)], 100*a[int(NR/4)], 100*a[int(3*NR/4)]}'
echo "-- quick-fails, by era: cost and the 13 weeks after the exit"
awk -F'\t' '$7=="stop_loss"&&$10<=20&&$9<3{y=substr($4,1,4); e=(y<2009?"2000-08":(y<2020?"2009-19":"2020-26")); n[e]++; p[e]+=$6; s13[e]+=$8; if($8>0) u[e]++}
 END{for(e in n) printf "%s | %d | %+.0fk | after 13w mean %+.1f%%, higher %d/%d\n",e,n[e],p[e]/1000,s13[e]/n[e],u[e],n[e]}' "$O/tr_full.tsv" | sort
echo "-- every stop exit: realised, the 13 weeks after the exit, and fill -> exit+13w (a hold-through proxy); (last columns: share above +20 % / +50 %)"
awk -F'\t' 'FILENAME~/stopdec/{if($7+0>$6+1e-9) r[$1]=1; next} $7=="stop_loss"{g=($10<=20&&$9<3)?"quick-fail":(r[$1]?"raised stop":"initial stop, later"); h=(1+$5/100)*(1+$8/100)-1; print g "|realised\t" $5/100; print g "|13w after exit\t" $8/100; print g "|fill->exit+13w\t" h}' "$O/stopdec.tsv" "$O/tr_full.tsv" | q 100 0.2 0.5

echo; echo "== D. resting tickets: age at fill, macro state at fill"
awk -F'\t' 'NR==FNR{if($10==1)age[$3]=$7; next} {a=age[$1]; b=(a<=1?"a) 0-1w":(a<=4?"b) 2-4w":(a<=13?"c) 5-13w":(a<=25?"d) 14-25w":(a<=52?"e) 26-52w":"f) >52w"))))); n[b]++; p[b]+=$6; c[b]+=$5}
 END{for(b in n) printf "%s | %3d fills | %+7.0fk | mean %+6.2f%%\n",b,n[b],p[b]/1000,c[b]/n[b]}' "$O/entries.tsv" "$O/tr_full.tsv" | sort
awk -F'\t' '$10==1{print $7}' "$O/entries.tsv" | sort -n | tail -1 | sed 's/^/max ticket age at fill (weeks): /'
awk -F'\t' '$10==0' "$O/entries.tsv" | wc -l | sed 's/^ */placed rows without a fill (unfilled tickets + open positions, which carry no execution block): /'
echo "-- macro state of the last screen strictly before the fill (closed trades)"
awk -F'\t' 'FILENAME~/timeline/{wd[++n]=$1; st[n]=$2; next} FILENAME~/entries/{if($10==1)age[$3]=$7; next}
 { i=0; for(k=n;k>=1;k--) if(wd[k]<$3){i=k;break}; b=(i?st[i]:"?") (age[$1]>=4?" stale(>=4w)":" fresh"); c[b]++; p[b]+=$6; m[b]+=$5 }
 END{for(b in c) printf "%s | %d | %+.0fk | mean %+.2f%%\n",b,c[b],p[b]/1000,m[b]/c[b]}' "$O/timeline.tsv" "$O/entries.tsv" "$O/tr_full.tsv" | sort

echo; echo "== E. installed stop vs the screener's proxy stop (distance below suggested_entry), placed tickets"
awk -F'\t' '$17>0{print "installed_stop\t" 1-$18/$17; print "screener_proxy_stop\t" 1-$22/$17}' "$O/entries.tsv" | q 100 0.10 0.15

echo; echo "== F. exits"
awk -F'\t' '{n[$7]++; p[$7]+=$6; c[$7]+=$5; d[$7]+=$10} END{for(k in n) printf "%s | %d | %+.0fk | mean %+.2f%% | mean days %.0f\n",k,n[k],p[k]/1000,c[k]/n[k],d[k]/n[k]}' "$O/tr_full.tsv" | sort
echo "-- laggard rotation: realised and the 13 weeks after the exit"
awk -F'\t' '$7=="laggard_rotation"{print "rotation|realised\t" $5/100; print "rotation|13w after exit\t" $8/100}' "$O/tr_full.tsv" | q 100 0.10 0.25
awk -F'\t' '$7=="laggard_rotation"{n++; if($8>0)u++; if($8>10)u10++} END{printf "rotation exits %d; higher 13 weeks later %d (%.0f%%); more than +10%% %d\n",n,u,100*u/n,u10}' "$O/tr_full.tsv"

echo; echo "== G. entry geometry"
echo "-- extension above the 30-week MA at decision (adjusted close / MA - 1), filled trades: realised %"
awk -F'\t' 'NR==FNR{ if($10==1 && $21>0) ext[$3]=$20/$21-1; next} ($1 in ext){x=ext[$1]; b=(x<0.10?"a) <10%":(x<0.20?"b) 10-20%":(x<0.35?"c) 20-35%":(x<0.50?"d) 35-50%":"e) >=50%")))); print b "\t" $5/100}' "$O/entries.tsv" "$O/tr_full.tsv" | q 100 0.5 1.0
echo "-- fill position in the stop-limit band (fill_vs_trigger_pct): realised %"
awk -F'\t' 'NR==FNR{ if($10==1) fv[$3]=$16; next} ($1 in fv){x=fv[$1]; b=(x>=0.0199?"c) at the limit (+2%)":(x>0.005?"b) inside the band":"a) at the trigger (<=0.5%)")); print b "\t" $5/100}' "$O/entries.tsv" "$O/tr_full.tsv" | q 100 0.25 0.5
echo "-- initial stop distance from E (trades.csv stop_initial_distance_pct), cutoff sweep"
for c in 0.015 0.02 0.03 0.04 0.05 0.06; do awk -F, -v C=$c 'NR>1 && $16<C {n++; p+=$9; if($13=="stop_loss") s++; if($13=="stop_loss" && $5<=5) qq++; if($10>mx) mx=$10} END{printf "initial stop < %4.1f%% of E: %3d trades, %+6.0fk, stop exits %d (within 5 days %d), best %+.1f%%\n", 100*C, n, p/1000, s, qq, mx}' "$TRC"; done
echo "-- E vs the decision close, cutoff sweep (E below the close = the breakout already happened)"
for c in 0.88 0.90 0.92 0.94 0.96; do awk -F'\t' -v C=$c 'NR==FNR{ if($10==1 && $19>0) r[$3]=$17/$19; next} ($1 in r) && r[$1]<C {n++; p+=$6; if($5>0)w++; if($5>mx) mx=$5} END{printf "E/close < %s: %d fills, %+.0fk, winners %d, best %+.1f%%\n", C, n, p/1000, w, mx}' "$O/entries.tsv" "$O/tr_full.tsv"; done
