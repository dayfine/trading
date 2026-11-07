#!/bin/sh
# stops.sh OUT TRADES_CSV -- the weekly stop decisions (trade_audit stop_decisions, #2977/#2986), read per position.
# Needs OUT/{stopdec,entries,tr_full}.tsv from walk-rk.sh and ./data (bar store) for the per-row bar join.
set -eu
O=$1; TRC=$2; L=$(cd "$(dirname "$0")" && pwd); TAB=$(printf '\t')
q() { sort -t"$TAB" -k1,1 -k2,2g | awk -v S="${1:-100}" -v T1="${2:-0.5}" -v T2="${3:-1.0}" -f "$L/qstats.awk"; }
# bar join: raw close, raw low, adjusted close, basis factor (close / adjusted) of each decision date
sort -t"$TAB" -k2,2 -k1,1 -k3,3 -s "$O/stopdec.tsv" | awk -F'\t' -f "$L/sdbars.awk" > "$O/stopdec_bars.tsv"
awk -f "$L/stale_anchor.awk" "$O/stopdec_bars.tsv" > "$O/stale_anchor.tsv"
awk -f "$L/replay_basis.awk" "$TRC" "$O/stopdec_bars.tsv" > "$O/replay_basis.tsv" 2> "$O/replay_basis.log"

echo "== S0. integrity"
awk -F'\t' '{if($1==pp && ($6+0 > pa*1.0001 || $6+0 < pa*0.9999)) {n++; s=s " " $2 "(" sprintf("%.3f",$6/pa) ")"} pp=$1; pa=$7+0} END{print n+0 " stop moves outside the state machine (split rescales):" s}' "$O/stopdec.tsv"
awk -F'\t' 'NR==FNR{if($7+0>$6+1e-9) r[$1]++; next} FNR>1{split($0,a,","); d=a[23]-(r[a[20]]+0); c[d]++} END{for(k in c) print "trades.csv n_stop_raises minus raises counted in the audit = " k ": " c[k] " trades"}' "$O/stopdec.tsv" "$TRC"
awk -F'\t' '{if($7+0<$6-1e-9) n++} END{print n+0 " rows where the stop moved down inside the state machine"}' "$O/stopdec.tsv"

echo; echo "== S1. how often: rows by reason and state; positions that ever logged each reason"
awk -F'\t' '{c[$14 " | " $4 ">" $5]++} END{for(k in c) print c[k] "\t" k}' "$O/stopdec.tsv" | sort -rn
awk -F'\t' '{if(!seen[$1,$14]++) c[$14]++; P[$1]=1} END{n=0; for(x in P)n++; for(k in c) printf "%d / %d positions\t%s\n", c[k], n, k}' "$O/stopdec.tsv" | sort -rn
echo "-- stop increases per position (Raised + Tightened_ratchet + Entered_tightening rows that moved the stop up)"
awk -F'\t' '{if($7+0>$6+1e-9) r[$1]++; P[$1]=1} END{for(x in P) h[r[x]+0]++; for(k=0;k<=40;k++) if(h[k]) printf "%d: %d positions\n", k, h[k]}' "$O/stopdec.tsv"
echo "-- ever raised, by holding length (closed trades)"
awk -F'\t' 'FILENAME~/stopdec/{if($7+0>$6+1e-9) r[$1]++; next} {d=$10; b=(d<=20?"a) <=20d":(d<=64?"b) 21-64d":(d<=129?"c) 65-129d":(d<=259?"d) 130-259d":"e) 260d+")))); n[b]++; if(r[$1]>0){rr[b]++; pr[b]+=$6; cr[b]+=$5} else {p0[b]+=$6; c0[b]+=$5}}
 END{for(b in n) printf "%s | %3d trades | raised %3d (%2.0f%%) | raised: %+7.0fk mean %+6.1f%% | never: %+7.0fk mean %+6.1f%%\n",b,n[b],rr[b],100*rr[b]/n[b],pr[b]/1000,(rr[b]?cr[b]/rr[b]:0),p0[b]/1000,(n[b]-rr[b]?c0[b]/(n[b]-rr[b]):0)}' "$O/stopdec.tsv" "$O/tr_full.tsv" | sort
echo "-- by exit trigger x ever raised"
awk -F'\t' 'FILENAME~/stopdec/{if($7+0>$6+1e-9) r[$1]++; next} {k=$7 " | " (r[$1]>0?"raised":"never"); n[k]++; p[k]+=$6; c[k]+=$5; d[k]+=$10} END{for(k in n) printf "%-26s | %3d | %+7.0fk | mean %+6.1f%% | mean days %.0f\n",k,n[k],p[k]/1000,c[k]/n[k],d[k]/n[k]}' "$O/stopdec.tsv" "$O/tr_full.tsv" | sort

echo; echo "== S2. by how much: Raised rows (first cycle = anchored on the entry-seeded extreme)"
awk -F'\t' '$14=="Raised"{k=($9==0?"first cycle":"later cycle"); print k "|raise, % of the old stop\t" ($7/$6-1); print k "|new stop below that close\t" (1-$7/$15)}' "$O/stopdec_bars.tsv" | q 100 0.05 0.10
P=$(mktemp -t walkstops); trap 'rm -f "$P"' EXIT
cat > "$P" <<'EOF'
FILENAME~/stopdec/{ if($7+0>$6+1e-9 && !($1 in fr)) fr[$1]=$3; next } ($1 in fr){ print "days from fill to the first stop increase\t" (jd(fr[$1])-jd($3)) }
EOF
awk -F'\t' -f "$L/days.awk" -f "$P" "$O/stopdec.tsv" "$O/tr_full.tsv" | q 1 30 90

echo; echo "== S3. which rule: completed cycles (Raised + Cycle_stalled) by the term that binds the candidate and the basis gap"
echo "   candidate = 0.99 x min(correction extreme, MA); MA on adjusted closes, correction extreme on raw bars (#2982); gap = close/adjusted >= 1.05"
awk -F'\t' '$14=="Raised"||$14=="Cycle_stalled"{ma=$13; cl=$12; f=$18; bind=(ma<cl)?"MA":"corr-low"; gap=(f>=1.05)?"gap>=5%":"no-gap"; k=$14 " | " bind " | " gap; n[k]++; if(!((k SUBSEP $1) in PP)){PP[k SUBSEP $1]=1; np[k]++}
  if($14=="Cycle_stalled"){ ref2=(ma*f<cl)?ma*f:cl; c2=0.99*ref2; if(c2>$6+1e-9){wb[k]++; up[k]+=c2/$6-1} } }
 END{for(k in n){printf "%-34s rows %4d positions %3d", k, n[k], np[k]; if(k~/stalled/) printf " | a same-basis candidate would raise: %d rows (mean +%.1f%% on the stop)", wb[k], (wb[k]?100*up[k]/wb[k]:0); print ""}}' "$O/stopdec_bars.tsv" | sort
echo "-- ever raised, by the basis factor at entry"
awk -F'\t' '$4=="Initial"{if(!($1 in F)) F[$1]=$18} {if($7+0>$6+1e-9) r[$1]++} END{for(x in F){g=(F[x]>=1.5?"c) >=1.5":(F[x]>=1.05?"b) 1.05-1.5":"a) <1.05")); n[g]++; if(r[x]>0) rr[g]++} for(g in n) printf "factor %s: %d positions, %d ever raised (%.0f%%)\n", g, n[g], rr[g], 100*rr[g]/n[g]}' "$O/stopdec_bars.tsv" | sort
echo "-- ever raised by factor at entry, within era (fill year)"
awk -F'\t' '$4=="Initial"{if(!($1 in F)){F[$1]=$18; Y[$1]=substr($3,1,4)}} {if($7+0>$6+1e-9) r[$1]++} END{for(x in F){e=(Y[x]<2009?"2000-08":(Y[x]<2020?"2009-19":"2020-26")); g=e " | " (F[x]>=1.5?"c) >=1.5":(F[x]>=1.05?"b) 1.05-1.5":"a) <1.05")); n[g]++; if(r[x]>0) rr[g]++} for(g in n) printf "%s: %d positions, %d ever raised (%.0f%%)\n", g, n[g], rr[g], 100*rr[g]/n[g]}' "$O/stopdec_bars.tsv" | sort

echo; echo "== S4. stops that never rose: closed trades held >= 65 days, by why"
awk -F'\t' 'FILENAME~/stopdec_bars/{x=$1; if($7+0>$6+1e-9) r[x]++; if($14=="Raised"||$14=="Cycle_stalled"){cyc[x]++; if($14=="Cycle_stalled"){ ref=$13*$18; if($12+0<ref) ref=$12+0; if(0.99*ref>$6+1e-9) gapblk[x]++ }} next}
 FILENAME~/stale/{ if($5>=13) st[$1]=1; next}
 $10>=65 && !(r[$1]>0){ w=(cyc[$1]==0?"a) no completed cycle (no 8% correction + recovery)":(gapblk[$1]>0?"b) a cycle stalled only because of the basis gap":(st[$1]?"c) stale anchor >= 13 weeks":"d) cycles stalled: MA below the stop on one basis")));
   n[w]++; pp[w]+=$6; c[w]+=$5; mx[w]+=$9; d[w]+=$10 }
 END{for(w in n) printf "%-52s | %3d | %+7.0fk | mean %+6.1f%% | mean MFE %+6.1f%% | mean days %.0f\n",w,n[w],pp[w]/1000,c[w]/n[w],mx[w]/n[w],d[w]/n[w]}' "$O/stopdec_bars.tsv" "$O/stale_anchor.tsv" "$O/tr_full.tsv" | sort
awk -F'\t' 'FILENAME~/stopdec/{if($7+0>$6+1e-9) r[$1]++; next} $10>=65{n++; if(r[$1]>0) k++} END{print n " closed trades held >= 65 days; raised at least once: " k}' "$O/stopdec.tsv" "$O/tr_full.tsv"
awk -F'\t' '$1!=cur{cur=$1; anchor=""} {h=($4=="Trailing" && ($14=="No_correction_yet"||$14=="Correction_not_recovered"||$14=="Anchor_not_fresh")); if(h){n++; if(anchor!="" && $12+0>=anchor*(1-1e-9)) s++} if($14=="Raised"||$14=="Cycle_stalled") anchor=$15+0; if($5!="Trailing") anchor=""} END{printf "trailing hold rows %d; with a stale anchor (no bar back at the last reset close) %d\n", n, s}' "$O/stopdec_bars.tsv"
echo "-- stale anchor: longest stretch per position after a reset with no bar back at the reset close (weeks)"
awk -F'\t' '{w=$5; b=(w<4?"a) <4w":(w<13?"b) 4-13w":(w<26?"c) 13-26w":"d) 26w+"))); n[b]++; if($6>0.25) big[b]++} END{for(b in n) printf "%s: %d positions (trend extreme > 25%% above the anchor: %d)\n", b, n[b], big[b]}' "$O/stale_anchor.tsv" | sort
awk -F'\t' 'NR==FNR{x[$1]=$4" "$7" "sprintf("%+.0f%%",$5)" "sprintf("%+.0fk",$6/1000); next} $5>=13{printf "  %s stale %s..%s (%.0f wk), trend extreme %+.0f%% above the anchor | exit %s\n",$2,$3,$4,$5,100*$6,x[$1]}' "$O/tr_full.tsv" "$O/stale_anchor.tsv" | sort

echo; echo "== S5. exits after a raise vs never raised (stop exits)"
cat > "$P" <<'EOF'
FILENAME~/stopdec/{if($7+0>$6+1e-9){lr[$1]=$3; why[$1]=$14}; next}
$7=="stop_loss"{ if(!($1 in lr)) g="a) never raised (initial stop)"; else { dd=jd($4)-jd(lr[$1]); g=(dd<=10?"b) last raise <=10d before the exit":(dd<=60?"c) last raise 11-60d before":"d) last raise >60d before")) }
 n[g]++; p[g]+=$6; c[g]+=$5; s13[g]+=$8; if($8>0)u[g]++; if($8>10)u10[g]++
 if($1 in lr){ k=why[$1] " | " (dd<=10?"<=10d":">10d"); m[k]++; mp[k]+=$6; mc[k]+=$5; m13[k]+=$8; mu[k]+=($8>0) } }
END{for(g in n) printf "%-38s | %3d | %+7.0fk | mean %+6.1f%% | 13w after: mean %+5.1f%%, higher %d, > +10%% %d\n",g,n[g],p[g]/1000,c[g]/n[g],s13[g]/n[g],u[g],u10[g]
 print "-- by the rule that made the last stop move"; for(k in m) printf "%-30s | %3d | %+7.0fk | mean %+6.1f%% | 13w after: mean %+5.1f%%, higher %d\n",k,m[k],mp[k]/1000,mc[k]/m[k],m13[k]/m[k],mu[k]}
EOF
awk -F'\t' -f "$L/days.awk" -f "$P" "$O/stopdec.tsv" "$O/tr_full.tsv"
echo "-- positions that entered the Tightened state (Stage 3/4 or a flat / falling MA in Stage 2)"
awk -F'\t' 'FILENAME~/stopdec/{ if($14=="Entered_tightening"){t[$1]=$3; fr[$1]=$4; j[$1]=$7/$6-1}; next} ($1 in t){k=fr[$1]; n[k]++; p[k]+=$6; c[k]+=$5; s13[k]+=$8; if($7=="stop_loss")s[k]++; jj[k]+=j[$1]} END{for(k in n) printf "from %s: %d | %+.0fk | mean %+.1f%% | stop exits %d | stop jump at tightening %+.1f%% | 13w after exit %+.1f%%\n",k,n[k],p[k]/1000,c[k]/n[k],s[k],100*jj[k]/n[k],s13[k]/n[k]}' "$O/stopdec.tsv" "$O/tr_full.tsv"

echo; echo "== S6. winners' give-back: (1 + realised)/(1 + MFE) - 1, trades with MFE >= +30 % (last columns: share giving back less than 30 % / 20 %)"
awk -F'\t' 'FILENAME~/stopdec/{if($7+0>$6+1e-9) r[$1]++; next} FILENAME~/stale/{st[$1]=$5; next} $9>=30{ gb=(1+$5/100)/(1+$9/100)-1; print $7 " | " (r[$1]>0?"raised":"never") "\t" gb; print "ALL\t" gb; if(st[$1]>=13) print "stale anchor >= 13w\t" gb }' "$O/stopdec.tsv" "$O/stale_anchor.tsv" "$O/tr_full.tsv" | q 100 -0.3 -0.2
echo "-- largest dollar give-backs: quantity x (peak price - exit price)"
awk -F'\t' 'FILENAME~/csv$/{split($0,t,","); qty[t[20]]=t[8]; next} $9>=30{ pk=$16*(1+$9/100); printf "%.0f\t%s %s->%s %s: MFE %+.0f%%, realised %+.0f%%, pnl %+.0fk\n",qty[$1]*(pk-$17)/1000,$2,$3,$4,$7,$9,$5,$6/1000}' "$TRC" "$O/tr_full.tsv" | sort -t"$TAB" -k1,1 -g -r | head -10 | awk -F'\t' '{printf "  %+.0fk  %s\n", $1, $2}'

echo; echo "== S7. first-order replay of stop_ma_same_basis (#2982) on this run (lib/replay_basis.awk; no portfolio feedback)"
cat "$O/replay_basis.log"
awk -F'\t' '$14>0{n++} END{print n " closed positions where a same-basis candidate beats the stop at least once"}' "$O/replay_basis.tsv"
awk -F'\t' '{a=($10<$4)?"earlier exit":"same exit day"; n[a]++; d[a]+=$13; if($13>0)b[a]++; if($13<0)w[a]++; T+=$13} END{for(k in n) printf "%s: %d positions, delta %+.0fk (better %d, worse %d)\n",k,n[k],d[k]/1000,b[k],w[k]; printf "total first-order delta %+.0fk\n", T/1000}' "$O/replay_basis.tsv"
awk -F'\t' '$10<$4{ if($9>0.5) {w++; wd+=$13} else {o++; od+=$13} } END{printf "earlier exits of trades that actually made > +50%%: %d, delta %+.0fk; the other %d, delta %+.0fk\n", w, wd/1000, o, od/1000}' "$O/replay_basis.tsv"
awk -F'\t' '$10<$4{print "earlier exit: delta per trade, % of the actual exit\t" $11/$8-1}' "$O/replay_basis.tsv" | q 100 0 0.1
echo "-- the seven largest losses and the three largest gains (earlier exits)"
awk -F'\t' '$10<$4' "$O/replay_basis.tsv" | sort -t"$TAB" -k13,13g | awk -F'\t' '{printf "  %s fill %s, actual %s %s %+.1f%% | replay exit %s %+.1f%% | %+.0fk (max factor %.2f)\n",$2,$3,$4,$5,100*$9,$10,100*$12,$13/1000,$15}' | head -7
awk -F'\t' '$10<$4' "$O/replay_basis.tsv" | sort -t"$TAB" -k13,13gr | head -3 | awk -F'\t' '{printf "  %s fill %s, actual %s %s %+.1f%% | replay exit %s %+.1f%% | %+.0fk (max factor %.2f)\n",$2,$3,$4,$5,100*$9,$10,100*$12,$13/1000,$15}'

echo; echo "== S8. first-order replay of a peak-following anchor (correction_must_follow_peak) inside each stale stretch (lib/replay_anchor.awk)"
for S in 0 1; do
  awk -v SAME=$S -f "$L/replay_anchor.awk" "$TRC" "$O/stale_anchor.tsv" "$O/stopdec_bars.tsv" > "$O/replay_anchor_s$S.tsv"
  [ "$S" = 0 ] && echo "-- anchor fix alone (the run's mixed-basis MA)" || echo "-- anchor fix + same-basis MA"
  awk -F'\t' '{n++; if($6<$4){e++; if($9>0)b++; else w++} T+=$9} END{printf "%d stale stretches; earlier exits %d (better %d, worse %d); first-order delta %+.0fk\n", n, e, b, w, T/1000}' "$O/replay_anchor_s$S.tsv"
  awk -F'\t' '$6<$4{printf "  %s (stale from %s): actual exit %s at %.2f | replay exit %s at %.2f | %+.0fk (cycles %d, raises %d)\n",$2,$3,$4,$5,$6,$7,$9/1000,$10,$11}' "$O/replay_anchor_s$S.tsv" | sort
done
