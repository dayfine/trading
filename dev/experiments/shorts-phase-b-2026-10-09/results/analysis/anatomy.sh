#!/bin/sh
# Pre-registered reading items 3 (paired v1 - v0 read, RV2 regime split) and 4-6 (anatomy C, forced covers and
# margin calls, dividends paid by shorts), plus the #3145 / #3148 after-merge evidence and the selection read.
# usage: sh anatomy.sh   (after prep.sh and decision8.sh, which writes the per-cell DAY/POS files; same env)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
TAB=$(printf '\t')
cit() { sed -nE 's/.*cashinteresttotal ([0-9.]+)\).*/\1/p' "$R/$1-v12-summary.sexp"; }
: > "$WORK/rows.tsv"
for c in $CELLS; do
  awk -f "$HERE/trade_rows.awk" -v CELL="$c" "$WORK/$c.audit.tsv" "$WORK/$c.pos.csv" "$R/$c-v12-force_liquidations.sexp" \
    "$WORK/macro.txt" "$WORK/spy.csv" "$R/$c-v12-trades.csv" > "$WORK/$c.rows0.tsv"
  awk -f "$HERE/prior_adv.awk" "$WORK/bars.csv" "$WORK/$c.audit.tsv" "$WORK/$c.rows0.tsv" >> "$WORK/rows.tsv"
done
echo "=== RV2: return ex interest / SPY / mean short exposure / SPY short at the same exposure, by period and regime"
echo "cell period regime days book_ex_int% SPY% short_exp% index_short_same_exposure%"
for c in $CELLS; do awk -f "$HERE/regime.awk" -v CIT="$(cit "$c")" -v CELL="$c" "$WORK/spy.csv" "$WORK/$c.day.csv"; done
echo
echo "=== paired v1 - v0 per salt (symbol|entry_date); gate 3 exit 0 on every salt (gates.sh)"
for s in 0 1 2; do
  [ -f "$WORK/v0-26-s$s.entries_tr.txt" ] || { echo "run liveness.sh first"; exit 1; }
  awk -f "$HERE/pair.awk" -v SALT="$s" "$R/v0-26-s$s-v12-trades.csv" "$R/v1-26-s$s-v12-trades.csv" "$WORK/v0-26-s$s.audit.tsv" \
    "$WORK/v1-26-s$s.audit.tsv" "$WORK/v0-26-s$s.entries_tr.txt" | sort
done
echo
echo "=== anatomy C: trade return distributions (price-only % and total return %, side-signed), per cell and pooled per arm"
for spec in 0:all 14:entry_year 15:macro_at_fill 17:ticket_age 18:price_band 19:stop_exit 22:squeeze 23:forced 24:hold 26:mfe 30:index_stage 31:stage_tag 32:weeks_declining 34:trigger_kind 42:prior_advance; do
  k=${spec%%:*}; l=${spec#*:}; echo "--- by $l"
  for c in $CELLS; do awk -F"$TAB" -v c="$c" '$1==c' "$WORK/rows.tsv" | awk -f "$HERE/dist.awk" -v K="$k" -v LABEL="$c" | sort -t"$TAB" -k2,2; done
  for a in v0 v1; do awk -F"$TAB" -v a="$a" 'index($1, a "-")==1' "$WORK/rows.tsv" | awk -f "$HERE/dist.awk" -v K="$k" -v LABEL="$a-pooled" | sort -t"$TAB" -k2,2; done
done
echo
echo "=== planned vs realised stop distance (losing stop exits), and MAE of the winners (audit max_adverse_excursion)"
for c in $CELLS; do
  awk -F"$TAB" -v c="$c" '$1==c && $29=="stop_loss" && $9<0 { n++; p+=$20; r+=$21; if ($21>$20+0.005) b++ } END { printf "%s losing stop exits %d: planned mean %.1f%%, realised mean %.1f%%, realised beyond planned by > 0.5pp: %d\n", c, n, 100*p/n, 100*r/n, b }' "$WORK/rows.tsv"
  awk -F"$TAB" 'NR==FNR { if ($1=="T") mae[$2]=$22; next } $1==c && $9>0 { m=-100*mae[$2]; n++; s+=m; if (m>4) a++; if (m>6) b++ } END { printf "%s winners %d: mean MAE %.1f%%, MAE > 4%%: %d, > 6%%: %d\n", c, n, s/n, a, b }' c="$c" "$WORK/$c.audit.tsv" "$WORK/rows.tsv"
  awk -F"$TAB" -v c="$c" '$1==c { print 100*$20 }' "$WORK/rows.tsv" | sort -g | awk -v c="$c" '{ v[NR]=$1 } END { printf "%s planned stop distance from the fill: p10 %.1f p25 %.1f median %.1f p75 %.1f p90 %.1f; >= 10%%: ", c, v[int(0.1*(NR-1))+1], v[int(0.25*(NR-1))+1], v[int(0.5*(NR-1))+1], v[int(0.75*(NR-1))+1], v[int(0.9*(NR-1))+1]; for (i=1;i<=NR;i++) if (v[i]>=10) k++; print k " of " NR }'
done
echo
echo "=== give-back: positions whose favourable excursion reached >= 20 %"
for c in $CELLS; do
  awk -F"$TAB" -v c="$c" '$1==c && $25+0>=20 { n++; m+=$25; r+=$7; notl=$39*$35; pk+=$25/100*notl; rz+=$9; if ($7 < $25/2) half++; if ($7<0) neg++ }
    END { printf "%s n=%d mean MFE %.1f%% mean realised %+.1f%%; realised under half the MFE %d, ended losing %d; open gain at the MFE points %.0f, realised %.0f, given back %.0f\n", c, n, m/n, r/n, half, neg, pk, rz, pk-rz }' "$WORK/rows.tsv"
done
echo
echo "=== squeezes and forced covers by exit date (SPY return over the exit week, adjusted close)"
for c in v0-26-s0 v1-26-s0; do
  awk -F"$TAB" -v c="$c" 'BEGIN { while ((getline l < "'"$WORK"'/spy.csv") > 0) { split(l, f, ","); n++; d[n]=f[1]; a[n]=f[3] } }
    $1==c && ($22=="squeeze" || $23=="forced") { x=$5; lo=1; hi=n; while (lo<hi) { mid=int((lo+hi+1)/2); if (d[mid]<=x) lo=mid; else hi=mid-1 }
      printf "%s %s %s exit %s %s %s ret %+.1f%% planned %.1f%% realised %.1f%% SPY 5d to exit %+.1f%%\n", c, $3, $4, x, $22, $23, $7, 100*$20, 100*$21, 100*(a[lo]/a[lo-5]-1) }' "$WORK/rows.tsv" | sort -k5,5
done
echo
echo "=== top and bottom 5 positions per cell by total-return P&L (price P&L - dividends paid - borrow - commissions)"
for c in $CELLS; do
  awk -F"$TAB" -v c="$c" '$1==c' "$WORK/rows.tsv" | sort -t"$TAB" -k10,10gr | head -5 | awk -F"$TAB" '{ printf "%s TOP %s %s->%s %dd fill %.2f exit %.2f stop %.2f->%.2f px %+.1f%% TR %+.0f (div %s borrow %s) %s/%s MFE %s%%\n", $1, $3, $4, $5, $6, $35, $36, $37, $38, $7, $10, $11, $12, $29, $19, $25 }'
  awk -F"$TAB" -v c="$c" '$1==c' "$WORK/rows.tsv" | sort -t"$TAB" -k10,10g | head -5 | awk -F"$TAB" '{ printf "%s BOT %s %s->%s %dd fill %.2f exit %.2f stop %.2f->%.2f px %+.1f%% TR %+.0f (div %s borrow %s) %s/%s %s %s\n", $1, $3, $4, $5, $6, $35, $36, $37, $38, $7, $10, $11, $12, $29, $19, $22, $23 }'
done
echo
echo "=== selection estimand (stop-free): each short's own forward return vs an SPY short over the same bars"
for c in $CELLS; do for nb in 5 20 40 65; do
  awk -f "$HERE/fwd.awk" -v CELL="$c" -v NB="$nb" "$WORK/bars.csv" "$WORK/spy.csv" "$R/$c-v12-trades.csv" | awk -F"$TAB" -v c="$c" -v nb="$nb" '
    function srt(x, n,   i, j, t) { for (i=2; i<=n; i++) { t=x[i]; j=i-1; while (j>0 && x[j]>t) { x[j+1]=x[j]; j-- } x[j+1]=t } }
    $5!="NA" { n++; s+=$5; q+=$6; d+=$7; if ($7>0) p++; if ($5>0) w++; v[n]=$7; a[n]=$5; b[n]=$6 }
    END { srt(v, n); srt(a, n); srt(b, n); m=int(0.5*(n-1))+1
      printf "%s %2d bars n=%d: stock mean %+.2f%% median %+.2f%% (fell in %d) | SPY short mean %+.2f%% median %+.2f%% | paired diff mean %+.2f%% median %+.2f%% p10 %+.1f p25 %+.1f p75 %+.1f p90 %+.1f; stock beat the index short %d of %d\n",
        c, nb, n, 100*s/n, 100*a[m], w, 100*q/n, 100*b[m], 100*d/n, 100*v[m], 100*v[int(0.1*(n-1))+1], 100*v[int(0.25*(n-1))+1], 100*v[int(0.75*(n-1))+1], 100*v[int(0.9*(n-1))+1], p, n }'
done; done
echo
echo "=== stop timing: live buy-stop breached (bar high >= stop) before the exit day (sim_stop_exit_fill_on_trigger_bar on)"
for c in $CELLS; do
  awk -f "$HERE/late_stop.awk" -v CELL="$c" "$WORK/bars.csv" "$WORK/$c.audit.tsv" "$R/$c-v12-force_liquidations.sexp" "$R/$c-v12-trades.csv" > "$WORK/$c.late.tsv"
  awk -F"$TAB" 'NR==FNR { if (FNR>1) { split($0, t, ","); q[t[20]]=t[8] } next }
    $2=="SUMMARY" { print; next }
    { cf=($8>$7 ? $8 : $7); d=($10-cf)*q[$2]; s+=d; print "  " $0 "\ttrigger-bar fill " sprintf("%.2f", cf) " cost " sprintf("%.0f", -d) }
    END { printf "  total cost of the late exits vs a trigger-bar fill: %.0f\n", -s }' "$R/$c-v12-trades.csv" "$WORK/$c.late.tsv"
done
echo
echo "=== #3145 evidence: Tightened positions, lowering, ADSK-shaped freezes"
for c in $CELLS; do awk -f "$HERE/stops.awk" -v CELL="$c" "$WORK/bars.csv" "$WORK/$c.audit.tsv" "$R/$c-v12-trades.csv"; done
echo
echo "=== item 5 / #3148: exit triggers, force liquidations, margin calls (mark, equity ratio on the fill, FINRA requirement)"
for c in $CELLS; do
  awk -F, -v c="$c" 'NR>1 { t[$13]++ } END { printf "%s exit_trigger:", c; for (k in t) printf " %s=%d", k, t[k]; print "" }' "$R/$c-v12-trades.csv"
  printf '%s force_liquidations.sexp events: %s (reasons: %s)\n' "$c" "$(grep -c '(position_id' "$R/$c-v12-force_liquidations.sexp")" "$(grep -o '(reason [A-Za-z_]*)' "$R/$c-v12-force_liquidations.sexp" | sort | uniq -c | tr -s ' ' | tr '\n' ';')"
  a=$(audit_of "$c")
  if [ -f "$a" ]; then
    grep -A2 'label margin_call' "$a" | grep -o 'current_price=[0-9.]*' | while read -r cp; do
      m=${cp#current_price=}
      awk -F, -v c="$c" -v m="$m" 'NR>1 && $13=="margin_call" { e=$6+0; r=(1.5*e-m)/m; f=(m>=5 ? (5/m>0.30 ? 5/m : 0.30) : 1.0); printf "%s margin call %s fill %.2f mark %.2f equity ratio (1.5 x fill - mark) / mark = %.4f vs FINRA requirement %.2f -> %s\n", c, $1, e, m, r, f, (r<f ? "call justified" : "DEFECT: called above the requirement") }' "$R/$c-v12-trades.csv"
    done
  fi
done
echo
echo "=== item 6: dividends paid by shorts"
for c in $CELLS; do
  awk -f "$HERE/div_events.awk" -v CELL="$c" "$WORK/divs.csv" "$WORK/bars.csv" "$R/$c-v12-trades.csv" "$R/$c-v12-equity_curve.csv" > "$WORK/$c.divev.tsv"
  grep SUMMARY "$WORK/$c.divev.tsv"
  printf '%s dividendmissingfilecount %s, dividendskippednoamountcount %s\n' "$c" "$(sed -nE 's/.*dividendmissingfilecount ([0-9]+)\).*/\1/p' "$R/$c-v12-summary.sexp")" "$(sed -nE 's/.*dividendskippednoamountcount ([0-9]+)\).*/\1/p' "$R/$c-v12-summary.sexp")"
done
for c in v0-26-s0 v1-26-s0; do echo "--- $c ten largest"; grep EVENT "$WORK/$c.divev.tsv" | sort -t"$TAB" -k10,10gr | head -10 | cut -f3-11; done
echo
echo "=== perturbations: decision-time macro without the stuck Momentum Index vote; tickets priced above the decision close"
for c in $CELLS; do
  awk -v c="$c" 'NR==FNR { split($0, t, "\t"); if (t[1]=="T") { y=substr(t[4], 1, 4)+0; per=(y<2017 ? "pre-2017" : "2017+")
        dep=(t[25]+0>=0.35) ? "Bearish only with the Momentum vote" : "Bearish without it"; key=per " | momentum " t[28] " | " dep; k[t[2]]=key; n[key]++
        g=(t[16]!="-") ? t[15]/t[8]-1 : 0; tk[t[2]]=(g>0.02 ? "trigger > 2% above the decision close" : g>0 ? "trigger 0-2% above" : "trigger at or below the close") } next }
    FNR>1 { split($0, u, ","); kk=k[u[20]]; f[kk]++; p[kk]+=u[9]; if (u[9]>0) w[kk]++; t2=tk[u[20]]; f2[t2]++; p2[t2]+=u[9] }
    END { for (x in n) printf "%s tickets %-62s %3d, filled %3d (wins %d), realised %.0f\n", c, x, n[x], f[x], w[x]+0, p[x]
          for (x in f2) printf "%s fills %-40s %3d, realised %.0f\n", c, x, f2[x], p2[x] }' "$WORK/$c.audit.tsv" "$R/$c-v12-trades.csv" | sort
done
echo
echo "=== late stop fills vs the force-liquidation budget: trigger-day close more than 15 % above the fill"
for c in $CELLS; do
  awk -F, -v c="$c" -v late="$WORK/$c.late.tsv" 'BEGIN { while ((getline l < late) > 0) { split(l, f, "\t"); if (f[2]!="SUMMARY") { L[f[2]]=1; bd[f[2]]=f[6] } } }
    FILENAME==ARGV[1] { k[$1]++; d[$1, k[$1]]=$2; cl[$1, k[$1]]=$6+0; next }
    FNR>1 && $13=="stop_loss" { pid=$20; s=$1; dd=(pid in L) ? bd[pid] : $4; c0=0; for (i=1; i<=k[s]; i++) if (d[s, i]==dd) c0=cl[s, i]
      g=(pid in L) ? "late" : "same-day"; n[g]++; if (c0/$6-1>0.15) { o[g]++; if (g=="same-day") ex=ex " " pid " " $4 } }
    END { for (g in n) printf "%s %s stop exits %d, trigger-day close > 15%% above the fill %d%s\n", c, g, n[g], o[g]+0, (g=="same-day" && ex!="" ? " (" ex " )" : "") }' "$WORK/bars.csv" "$R/$c-v12-trades.csv"
done
PACK_V0=${PACK_V0:-.sweep-output/review-spb-v0/site/data}; PACK_V1=${PACK_V1:-.sweep-output/review-spb-v1/site/data}
echo
echo "=== review pack s0 static hard-stop replay (pack trade_extract.awk cf column x notional) and its breach list (blag > 0)"
for p in "$PACK_V0" "$PACK_V1"; do
  [ -f "$p/s0_trades.json" ] || { echo "  (no pack data at $p)"; continue; }
  awk 'BEGIN{RS="},"} { if (!match($0,/"qty":[0-9.]+/)) next; q=substr($0,RSTART+6,RLENGTH-6)+0; match($0,/"ep":[0-9.]+/); e=substr($0,RSTART+5,RLENGTH-5)+0
      match($0,/"pnl":[-0-9.]+/); pn=substr($0,RSTART+6,RLENGTH-6)+0; match($0,/"cf":\[[^]]*\]/); cs=substr($0,RSTART+6,RLENGTH-7); m=split(cs,v,",")
      act+=pn; for (i=1;i<=m;i++) S[i]+=v[i]/100*q*e; nt++
      if (match($0,/"blag":[-0-9]+/)) { b=substr($0,RSTART+7,RLENGTH-7)+0; if (b>0) { match($0,/"id":"[^"]*"/); id=substr($0,RSTART+6,RLENGTH-7); match($0,/"div":[-0-9.]+/); dv=substr($0,RSTART+6,RLENGTH-6); bl=bl " " id "(lag " b ", div " dv ")"; nb++ } } }
    END { split("3 5 6 8 10 15",lv," "); printf "  %s: trades %d, actual %.0f", FILENAME, nt, act; for (i=1;i<=6;i++) printf " | %s%%: %.0f", lv[i], S[i]; print ""
          printf "  breached before the exit day (pack, adjusted basis): %d:%s\n", nb, bl }' "$p/s0_trades.json"
done
echo
echo "=== borrow estimate by the price tier of the mark (margin_config tiers: 100 % under \$5, 25 % under \$17, else 0.5 %)"
for c in $CELLS; do
  awk -F, -v c="$c" 'NR==FNR { k[$1]++; d[$1, k[$1]]=$2; cl[$1, k[$1]]=$6+0; next }
    FNR>1 { s=$1; q=$8+0; for (i=1; i<=k[s]; i++) if (d[s, i]>=$3 && d[s, i]<$4) { p=cl[s, i]; r=(p<5 ? 1.0 : p<17 ? 0.25 : 0.005); t=(p<5 ? "under $5" : p<17 ? "$5-17" : "$17+"); b[t]+=q*p*r/252; nd[t]++ } }
    END { for (t in b) printf "%s marks %-8s borrow %.0f over %d position-days\n", c, t, b[t], nd[t] }' "$WORK/bars.csv" "$R/$c-v12-trades.csv" | sort
done
echo
echo "=== more entry cohorts (perturbation): RS trend, sector rating, support below, the book's 'ideal' setup, fill vs trigger, SPY state at entry"
for c in $CELLS; do
  awk -F"$TAB" -v c="$c" 'NR==FNR { if ($1=="T") { rs[$2]=$30; sec[$2]=$33; sp[$2]=$31; if ($16!="-") ft[$2]=$16/$15-1 } next }
    $1==c { k1=rs[$2]; k2=sec[$2]; k3=sp[$2]
      ideal=((k1=="Negative_declining" || k1=="Bearish_crossover") && k2=="Weak" && k3=="Clean" && $31=="S3toS4") ? "ideal" : "not-ideal"
      f=ft[$2]; fb=(f<=-0.0195 ? "limit fill (2% below trigger)" : f<-0.005 ? "fill 0.5-2% below trigger" : "fill within 0.5% of trigger")
      print $0 "\trs " k1 "\tsector " k2 "\tsupport " k3 "\t" ideal "\t" fb }' "$WORK/$c.audit.tsv" "$WORK/rows.tsv" > "$WORK/$c.rows_more.tsv"
  for k in 43 44 45 46 47; do awk -f "$HERE/dist.awk" -v K="$k" -v LABEL="$c" "$WORK/$c.rows_more.tsv" | sort -t"$TAB" -k2,2; done
  awk -F"$TAB" -v c="$c" 'BEGIN { while ((getline l < "'"$WORK"'/spy.csv") > 0) { split(l, f, ","); n++; d[n]=f[1]; a[n]=f[3]+0 } }
    $1==c { e=$4; lo=1; hi=n; while (lo<hi) { mid=int((lo+hi+1)/2); if (d[mid]<=e) lo=mid; else hi=mid-1 }
      mx=0; for (j=lo-251; j<=lo; j++) if (j>0 && a[j]>mx) mx=a[j]; dd=1-a[lo]/mx; r20=a[lo]/a[lo-20]-1
      b1=(dd<0.10 ? "SPY off its 52-week high < 10%" : dd<0.20 ? "SPY off 10-20%" : dd<0.30 ? "SPY off 20-30%" : "SPY off >= 30%")
      b2=(r20<-0.05 ? "SPY 4-week return < -5%" : r20<0 ? "SPY 4-week -5..0%" : "SPY 4-week >= 0")
      print $0 "\t" b1 "\t" b2 }' "$WORK/rows.tsv" > "$WORK/$c.rows_spy.tsv"
  for k in 43 44; do awk -f "$HERE/dist.awk" -v K="$k" -v LABEL="$c" "$WORK/$c.rows_spy.tsv" | sort -t"$TAB" -k2,2; done
done
echo
echo "=== screener score at entry, by quartile of trades (trades.csv screener_score_at_entry, sorted, four equal groups)"
for c in $CELLS; do
  tail -n +2 "$R/$c-v12-trades.csv" | awk -F, '{ print $19 "," $9 }' | sort -t, -k1,1g | awk -F, -v c="$c" '{ s[NR]=$1; p[NR]=$2 }
    END { n=NR; for (q=1; q<=4; q++) { lo=int((q-1)*n/4)+1; hi=int(q*n/4); t=0; w=0; for (i=lo; i<=hi; i++) { t+=p[i]; if (p[i]>0) w++ }
        printf "%s Q%d scores %s-%s: n=%d wins=%d P&L %.0f\n", c, q, s[lo], s[hi], hi-lo+1, w, t } }'
done
echo
echo "=== exits in the README-named rally windows (2008-11-20..12-05, 2009-03-09..04-30)"
for c in v0-26-s0 v1-26-s0; do
  awk -F, -v c="$c" 'NR>1 && (($4>="2008-11-20" && $4<="2008-12-05") || ($4>="2009-03-09" && $4<="2009-04-30")) {
    printf "%s %s %s -> %s %.2f -> %.2f %+.1f%% %s %s\n", c, $1, $3, $4, $6, $7, $10, $13, $17 }' "$R/$c-v12-trades.csv"
done
echo
echo "=== terminal events and splits during held shorts (README Known gaps): last bar vs exit, vendor splits inside a hold"
for c in v0-26-s0 v1-26-s0; do
  tail -n +2 "$R/$c-v12-trades.csv" | while IFS=, read -r s side ed xd rest; do
    f=$(bars_of "$s"); last=$(tail -1 "$f" | cut -d, -f1)
    sp="$DATA/$(_shard "$s")/$s/splits.csv"
    awk -v c="$c" -v s="$s" -v ed="$ed" -v xd="$xd" -v last="$last" 'function jdn(x,  y,m,d,a){y=substr(x,1,4)+0; m=substr(x,6,2)+0; d=substr(x,9,2)+0; a=int((14-m)/12); y=y+4800-a; m=m+12*a-3; return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045}
      BEGIN { if (jdn(last)-jdn(xd) < 60) printf "%s %s covered %s, last bar %s (within 60 days)\n", c, s, xd, last }' 
    [ -f "$sp" ] && awk -F, -v c="$c" -v s="$s" -v ed="$ed" -v xd="$xd" 'NR>1 && $1>ed && $1<=xd { printf "%s %s held %s..%s across a vendor split %s x%s\n", c, s, ed, xd, $1, $2 }' "$sp"
  done
done
for c in $CELLS; do printf '%s splits applied (splits.csv data rows): %s\n' "$c" "$(tail -n +2 "$R/$c-v12-splits.csv" | grep -c . || true)"; done
echo
echo "=== stop-outs within 4 days of the fill, by entry year"
for c in v0-26-s0 v1-26-s0; do
  awk -F"$TAB" -v c="$c" '$1==c && $6+0<=4 { y=$14; n[y]++; p[y]+=$9; N++; P+=$9 }
    END { printf "%s held <= 4 days: %d, P&L %.0f; by entry year:", c, N, P; for (y in n) printf " %s=%d (%.0fk)", y, n[y], p[y]/1000; print "" }' "$WORK/rows.tsv"
done
