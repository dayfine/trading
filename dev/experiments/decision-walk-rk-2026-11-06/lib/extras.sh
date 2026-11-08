#!/bin/sh
# extras.sh OUT TRADES_CSV PREFIX -- per-year table, exposure vs the configured caps, entry-geometry and specimen traces
# quoted in the walkthrough draft. Needs walk-rk.sh steps 1-4 + stops.sh outputs, and ./data.
set -eu
O=$1; TRC=$2; PREFIX=$3; TAB=$(printf '\t')
sym_csv() { printf 'data/%s/%s/%s/data.csv' "$(printf %s "$1" | cut -c1)" "$(printf %s "$1" | rev | cut -c1)" "$1"; }

echo "== X1. per year: NAV return (equity curve), SPY total return (pack spy.json), fills, stop exits, quick-fails, P&L by exit year"
echo "year | NAV | SPY TR | fills | stop exits | quick-fails | stop P&L | rotation P&L | best realised (by exit year)"
awk -F'\t' 'FILENAME~/nav.tsv/{y=substr($1,1,4); l[y]=$2; next} FILENAME~/spy.tsv/{y=substr($1,1,4); if(!(y in s0)) s0[y]=$2; sl[y]=$2; next}
 {fy=substr($3,1,4); xy=substr($4,1,4); nf[fy]++; if($7=="stop_loss"){ns[xy]++; sp[xy]+=$6; if($10<=20&&$9<3) qf[xy]++} if($7=="laggard_rotation") rp[xy]+=$6; if($5>best[xy]){best[xy]=$5; bs[xy]=$2}}
 END{py=""; for(y=2000;y<=2026;y++){ y=y ""; base=(py==""?1000000:l[py]); sb=(py==""?s0[y]:sl[py]); printf "%s | %+6.1f%% | %+6.1f%% | %3d | %3d | %3d | %+6.0fk | %+6.0fk | %s %+.0f%%\n", y, 100*(l[y]/base-1), 100*(sl[y]/sb-1), nf[y], ns[y], qf[y], sp[y]/1000, rp[y]/1000, bs[y], best[y]; py=y }}' "$O/nav.tsv" "$O/spy.tsv" "$O/tr_full.tsv"

echo; echo "== X2. book exposure vs the spec's max_long_exposure_pct 0.70 / min_cash_pct 0.30 (pack NAV series, % of NAV in positions)"
awk -F'\t' '{n++; if($3>70)a++; if($3>85)b++; if($3>95)c++; if($3>mx){mx=$3; md=$1}} END{printf "days %d: >70%% %d (%.1f%%), >85%% %d (%.1f%%), >95%% %d (%.1f%%); max %.1f%% on %s\n", n, a, 100*a/n, b, 100*b/n, c, 100*c/n, mx, md}' "$O/nav.tsv"
echo "-- top-N outcomes by the book's exposure on the screen date"
awk -F'\t' 'FILENAME~/nav.tsv/{e[$1]=$3; next} ($3=="Sized_to_zero"||$3=="Insufficient_cash"||$3=="Placed"){x=e[$1]; if(x=="") next; b=(x<50?"a) <50%":(x<70?"b) 50-70%":(x<85?"c) 70-85%":"d) 85%+"))); n[$3 " | " b]++} END{for(k in n) print n[k] "\t" k}' "$O/nav.tsv" "$O/decisions.tsv" | sort -t'|' -k1,1 -k2,2
awk -F'\t' 'FILENAME~/nav.tsv/{e[$1]=$3; next} $10==1{x=e[$2]; if(x=="") next; if(x>70) a++; else b++} END{printf "filled tickets placed while the book was > 70%% invested: %d (at or under 70%%: %d)\n", a, b}' "$O/nav.tsv" "$O/entries.tsv"
D=2025-01-02; grep "^$D" "${PREFIX}equity_curve.csv" | sed 's/^/NAV /'
awk -F, -v D=$D 'NR>1 && $3<=D && $4>D {print $1, $8}' "$TRC" | while read -r s q; do awk -F, -v D=$D -v s="$s" -v q="$q" '$1<=D{c=$5} END{printf "  %s qty %d close %.2f value %.0f\n", s, q, c, q*c}' "$(sym_csv "$s")"; done

echo; echo "== X3. entry geometry specimens: initial stop < 2 % of E (E below the decision close)"
awk -F'\t' 'NR==FNR{if(FNR>1){split($0,t,","); sid[t[20]]=t[16]; res[t[20]]=t[3] " -> " t[4] " " t[13] " " t[10] "%"}; next} ($3 in sid) && sid[$3]<0.02 {printf "  %s decision %s: E %.2f, close %.2f (E/close %.2f), installed stop %.2f (%.1f%% under E) | %s\n", $1,$2,$17,$19,$17/$19,$18,100*(1-$18/$17),res[$3]}' "$TRC" "$O/entries.tsv"
echo "-- resting tickets that crossed a split before filling"
awk -F'\t' '$10==1 && $7>0 {print $1"\t"$24"\t"$3}' "$O/entries.tsv" | while IFS="$TAB" read -r s pd pid; do f="$(dirname "$(sym_csv "$s")")/splits.csv"; fd=$(awk -F, -v P="$pid" 'NR>1 && $20==P{print $3}' "$TRC"); [ -n "$fd" ] && [ -f "$f" ] && awk -F, -v a="$pd" -v b="$fd" -v s="$s" 'NR>1 && $1>a && $1<=b {print "  " s " placed " a ", filled " b ", split " $1 " x" $2}' "$f"; done || true

echo; echo "== X4. specimen traces (stop decisions: date state stop_before>stop_after candidate cycles trend/correction extremes MA reason | close low factor)"
for p in APPS-wein-1018 DXCM-wein-953 CVNA-wein-1247 SATL-wein-1390 GME-wein-1025 FOSL-wein-449; do
  echo "-- $p"; grep "$p" "$TRC" | cut -d, -f1-13,16,23 | sed 's/^/  trade: /'
  awk -F'\t' -v P="$p" '$3==P{printf "  decision %s: E %s, installed %s, close %s, adj close %s, MA %s, weeks advancing %s, ticket age %s\n",$2,$17,$18,$19,$20,$21,$23,$7}' "$O/entries.tsv"
  awk -F'\t' -v P="$p" '$1==P && ($14!="No_correction_yet" && $14!="Correction_not_recovered" || ++h[$14]<=3){printf "  %s %s>%s %.2f>%.2f cand=%s cc %s>%s trend %s corr %s ma %.2f %s | close %s low %s f %s\n",$3,substr($4,1,4),substr($5,1,4),$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$18}' "$O/stopdec_bars.tsv" | head -40
done
for p in SDA-wein-1168 AAON-wein-1156; do
  echo "-- $p"; grep "$p" "$TRC" | cut -d, -f1-13,16,23 | sed 's/^/  trade: /'
  awk -F'\t' -v P="$p" '$3==P{printf "  decision %s: E %s, installed %s, close %s, adj close %s, MA %s, placement %s, ticket age %s, fill %s\n",$2,$17,$18,$19,$20,$21,$24,$7,$25}' "$O/entries.tsv"
done
echo "-- screen 2020-06-12 (APPS placed): top-N decisions and 26-week forward returns"
grep '^2020-06-12' "$O/weeks.tsv" | sed 's/^/  week: /'
awk -F'\t' 'NR==FNR{if($1=="2020-06-12") r[$2]=$4; next} $1=="2020-06-12"{printf "  %s %s %s\n", $2, $3, (r[$2]==""?"":sprintf("%+.0f%%", 100*r[$2]))}' "$O/fwd.tsv" "$O/decisions.tsv"

echo; echo "== X5. Bullish screen weeks by the book's exposure band, by era (next-week returns, compounded; SPY total return)"
awk -F'\t' '$2=="Bullish"{y=substr($1,1,4); e=(y<2009?"2000-08":(y<2016?"2009-15":(y<2020?"2016-19":(y<2023?"2020-22":"2023-26")))); x=$16; b=(x<40?"expo <40%":(x<60?"expo 40-60%":"expo 60%+")); k=e" | "b; n[k]++; s[k]+=log(1+$14); v[k]+=log(1+$15); pl[k]+=$9; nss[k]+=$10; top[k]+=($9+$10+$11+$12+$13)}
 END{for(k in n) printf "%s | %3d wk | SPY %+5.0f%% | NAV %+5.0f%% | placed/wk %.2f | NSS share of top-N %.0f%%\n",k,n[k],100*(exp(s[k])-1),100*(exp(v[k])-1),pl[k]/n[k],100*nss[k]/top[k]}' "$O/timeline.tsv" | sort
