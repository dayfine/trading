#!/bin/sh
# record-kseed-2026-10-27 results read: reproducible extracts behind README §Results.
# Usage: sh rk-analysis.sh <results-dir> <raw-sweep-dir> <pack-data-dir> <old-N-results> <v3266-results> <v3266-pack-data> <N-pack-data> <out-dir>
#   results-dir    rk-k<k>-s0-{trades.csv,equity_curve.csv,actual.sexp,validator.sexp.md} (this experiment's results/)
#   raw-sweep-dir  rk-k<k>-s0-trade_audit.sexp (.sweep-output/record-kseed; not committed, 14 MB each)
#   pack-data-dir  the K-seed pack's site/data (k<k>_{nav,faithfulness,missed,trades,open}.json, spy*.json)
#   old-N-results  ../breadth-fix-rb1-2026-10-11/results (N-rb1-26-s<s>-v12-*)
#   v3266-results  ../verify-3266-rerun-2026-10-22/results (M = v3266-Mpre3339-s0, Alphabetical on the fixed code)
#   v3266-pack-data / N-pack-data  site/data of those runs' packs (s0_nav.json), for the regime split only
# POSIX sh + awk + jq. regime.awk must sit next to this script.
set -eu
R=$1; RAW=$2; P=$3; OLD=$4; V3=$5; MP=$6; NP=$7; O=$8
HERE=$(cd "$(dirname "$0")" && pwd); KS="0 1 2 3 4"; mkdir -p "$O"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# 1. Yearly log returns per seed (year-end NAV; 2000 from the $1M start), cross-seed SD and spread, sub-window SDs.
for k in $KS; do awk -F, -v k=$k 'NR>1{y=substr($1,1,4); last[y]=$2} END{prev=1000000; for(y=2000;y<=2026;y++) if(y in last){printf "%d,%d,%.6f\n",k,y,log(last[y]/prev); prev=last[y]}}' "$R/rk-k$k-s0-equity_curve.csv"; done > "$T/yearly.csv"
awk -F, '{L[$1,$2]=$3} END{
  printf "%-4s %8s %8s %8s %8s %8s | %7s %8s  (log returns; spread = max-min simple return, pp)\n","year","k0","k1","k2","k3","k4","sd","spread"
  for(y=2000;y<=2026;y++){ s=0; for(k=0;k<5;k++) s+=L[k,y]; m=s/5; ss=0; mn=1e9; mx=-1e9
    for(k=0;k<5;k++){ ss+=(L[k,y]-m)^2; r=100*(exp(L[k,y])-1); if(r<mn)mn=r; if(r>mx)mx=r }
    V[y]=ss/4; printf "%4d %+8.4f %+8.4f %+8.4f %+8.4f %+8.4f | %7.4f %8.1f\n",y,L[0,y],L[1,y],L[2,y],L[3,y],L[4,y],sqrt(V[y]),mx-mn }
  print ""; n=split("2000-2008 2009-2011 2012-2015 2016-2019 2020-2022 2023-2026 2019-2024 2000-2013 2014-2026 2000-2026",P," ")
  for(p=1;p<=n;p++){ split(P[p],yy,"-"); s=0; v=0; for(k=0;k<5;k++){ t[k]=0; for(y=yy[1];y<=yy[2];y++) t[k]+=L[k,y]; s+=t[k] } m=s/5; ss=0
    for(k=0;k<5;k++) ss+=(t[k]-m)^2; for(y=yy[1];y<=yy[2];y++) v+=V[y]
    printf "%-10s cum ln: %.4f %.4f %.4f %.4f %.4f | SD %.4f | sqrt(sum of yearly var) %.4f\n",P[p],t[0],t[1],t[2],t[3],t[4],sqrt(ss/4),sqrt(v) }
  for(k=0;k<5;k++){ t[k]=0; for(y=2000;y<=2026;y++) t[k]+=L[k,y] }
  tv=0; for(y=2000;y<=2026;y++) tv+=V[y]; printf "\nshare of summed yearly variance: 2024 %.0f %%; 2004+2006+2010+2024 %.0f %%\n", 100*V[2024]/tv, 100*(V[2004]+V[2006]+V[2010]+V[2024])/tv
  for(y=2000;y<=2026;y++){ s=0; for(k=0;k<5;k++) s+=L[k,y]; for(k=0;k<5;k++) DV[k,y]=L[k,y]-s/5 }
  sxy=0; sxx=0; syy=0; for(k=0;k<5;k++) for(y=2000;y<2026;y++){ sxy+=DV[k,y]*DV[k,y+1]; sxx+=DV[k,y]^2; syy+=DV[k,y+1]^2 } printf "lag-1 correlation of yearly seed deviations (2000-2026, 130 pairs): %.3f\n", sxy/sqrt(sxx*syy)
  print ""; for(d=-1;d<5;d++){ c=0; s=0; for(k=0;k<5;k++) if(k!=d){c++; s+=t[k]} m=s/c; ss=0; for(k=0;k<5;k++) if(k!=d) ss+=(t[k]-m)^2; printf "leave-out %s: SD %.4f\n",(d<0?"none":"k" d),sqrt(ss/(c-1)) }
}' "$T/yearly.csv" > "$O/yearly.txt"

# 2. Trade overlap on symbol|entry_date (position_id is not a cross-arm key); P&L split by seed set; matrix with M and N.
for k in $KS; do awk -F, -v k=$k 'NR>1{printf "%s,%s|%s,%.2f,%.2f\n",k,$1,$3,$9+$25,$9}' "$R/rk-k$k-s0-trades.csv"; done > "$T/all.csv"
{
  awk -F, '{n[$2]++} END{for(x in n) c[n[x]]++; for(i=5;i>=1;i--) printf "keys in %d seeds: %d\n",i,c[i]}' "$T/all.csv"
  echo; echo "per seed: shared-by-all-5 / in 2-4 seeds / this seed only (n, total-return \$, price-only \$)"
  awk -F, 'FNR==NR{n[$2]++; next}{k=$1; g=(n[$2]==5)?"all5":(n[$2]==1?"only":"some"); N[k,g]++; TR[k,g]+=$3; PR[k,g]+=$4}
    END{for(k=0;k<5;k++){printf "k%d",k; split("all5 some only",G," "); for(i=1;i<=3;i++) printf " | %s n=%d TR=%.0f price=%.0f",G[i],N[k,G[i]],TR[k,G[i]],PR[k,G[i]]; printf " | not-in-all-5 price=%.0f\n",PR[k,"some"]+PR[k,"only"]}}' "$T/all.csv" "$T/all.csv"
  echo; echo "trades by seed set, any seed's total-return P&L > \$300k (k\$ per seed; - = not taken)"
  awk -F, '{have[$2]=have[$2] $1; p[$1","$2]=$3} END{for(x in have){b=-1e18; for(k=0;k<5;k++) if((k","x) in p && p[k","x]>b) b=p[k","x]; if(b>300000){split(x,a,"|"); printf "%s %s seeds=%s",a[2],a[1],have[x]; for(k=0;k<5;k++) printf " k%d=%s",k,(((k","x) in p)?sprintf("%.0f",p[k","x]/1000):"-"); print ""}}}' "$T/all.csv" | sort
  echo; echo "shared-trade matrix (symbol|entry_date), seeds vs M (v3266, Alphabetical, fixed code) vs N s0-s2"
  { awk -F, '{print "k"$1","$2}' "$T/all.csv"; awk -F, 'NR>1{print "M,"$1"|"$3}' "$V3/v3266-Mpre3339-s0-trades.csv"
    for s in 0 1 2; do awk -F, -v s=$s 'NR>1{print "N"s","$1"|"$3}' "$OLD/N-rb1-26-s$s-v12-trades.csv"; done; } |
  awk -F, '{S[$1 SUBSEP $2]=1; n[$1]++; K[$2]=1} END{split("k0 k1 k2 k3 k4 M N0 N1 N2",A," "); printf "%4s",""; for(j=1;j<=9;j++) printf " %5s",A[j]; print ""
    for(i=1;i<=9;i++){printf "%4s",A[i]; for(j=1;j<=9;j++){c=0; for(x in K) if(((A[i] SUBSEP x) in S)&&((A[j] SUBSEP x) in S)) c++; printf " %5d",c} printf "\n"}}'
} > "$O/overlap.txt"

# 3. Tail weights: each trade's total-return P&L / its own seed's NAV on the entry date; top ten share of realised price P&L.
{
  for k in $KS; do awk -F, -v k=$k 'FNR==NR{if(FNR>1) nav[$1]=$2; next} FNR>1{w=($9+$25)/nav[$3]; tot+=w; s=$1" "$3; W[s]=w}
    END{printf "k%d sum(P&L/NAV_entry)=%.3f; top8:",k,tot; for(i=0;i<8;i++){b=-1e9; bk=""; for(x in W) if(W[x]>b){b=W[x]; bk=x} printf " %s %.3f;",bk,b; delete W[bk]} print ""}' "$R/rk-k$k-s0-equity_curve.csv" "$R/rk-k$k-s0-trades.csv"; done
  echo; for k in $KS; do awk -F, 'NR>1{print $9}' "$R/rk-k$k-s0-trades.csv" | sort -g -r | awk -v k=$k '{a[NR]=$1; t+=$1} END{for(i=1;i<=10;i++) s+=a[i]; printf "k%d realised price P&L %.0f; top ten %.0f (%.0f %%); other %d trades %.0f\n",k,t,s,100*s/t,NR-10,t-s}'; done
} > "$O/tail-weights.txt"

# 4. Exposure and return by SPY regime and period (the pack's rule; regime.awk), seeds + M + N s0.
j2l() { tr -d '[]"' < "$1" | tr '\n' ' ' | sed 's/ //g' | awk -v n="$2" -F, '{for(i=1;i<=NF;i+=n){s=$i; for(k=1;k<n;k++) s=s","$(i+k); print s}}'; }
j2l "$P/spy_warmup.json" 3 > "$T/spy_warm.csv"; j2l "$P/spy.json" 2 > "$T/spy.csv"
for k in $KS; do j2l "$P/k${k}_nav.json" 4 > "$T/nav_k$k.csv"; done
j2l "$MP/s0_nav.json" 4 > "$T/nav_M.csv"; j2l "$NP/s0_nav.json" 4 > "$T/nav_N0.csv"
(cd "$T" && awk -v PERIODS="2000-2008 2009-2011 2012-2015 2016-2019 2020-2022 2023-2026 2000-2026" -f "$HERE/regime.awk" spy_warm.csv spy.csv nav_k0.csv nav_k1.csv nav_k2.csv nav_k3.csv nav_k4.csv nav_M.csv nav_N0.csv) > "$O/regime-split.txt"

# 5. Tie-cut traces from the raw audits: the top-N admitted list per seed on the decisive screens, and named candidates' outcomes.
{
  for d in 2000-01-07 2010-02-05 2020-06-12 2022-02-04 2023-08-18 2024-07-05; do
    echo "## decision $d (admitted top-N in screen order; x = Skipped No_structural_stop)"
    for k in $KS; do f="$RAW/rk-k$k-s0-trade_audit.sexp"
      blk=$(awk -v d="$d" 'index($0,"(date " d ") (total_stocks"){f=1} f && /\(date 20[0-9-]+\) \(total_stocks/ && !index($0,d){exit} f' "$f")
      cnt=$(printf '%s\n' "$blk" | head -8 | grep -oE '\((macro_trend [A-Za-z]+|long_grade_admitted [0-9]+|long_top_n_admitted [0-9]+|entered [0-9]+)\)' | tr -d '()' | tr '\n' ' ')
      printf "k%s [%s] " "$k" "$cnt"
      printf '%s\n' "$blk" | grep -oE '\(symbol [A-Za-z_.0-9]+\) \(side Long\) \(outcome [A-Za-z_( ]+' | sed -E 's/\(side Long\) \(outcome //; s/\(symbol //; s/\)//g; s/\(Skipped No_structural_stop/x/; s/\(Skipped //; s/ +$//' | tr '\n' ','; echo
    done; echo
  done
  echo "## scores of ADMA's alternatives, k1's ADMA entry record (decision 2023-08-18; ADMA scores 95)"
  awk '/\(symbol ADMA\) \(entry_date 2023-08-18\)/{f=1} f&&/cascade_score /{match($0,/cascade_score [0-9]+/); print "ADMA " substr($0,RSTART,RLENGTH)} f&&/alternatives_considered/{g=1} g{print} g&&/\(exit_date/{exit}' "$RAW/rk-k1-s0-trade_audit.sexp" |
    grep -oE 'cascade_score [0-9]+|\(symbol [A-Za-z_.0-9]+\) \(side Long\) \(score [0-9]+\)' | sed -E 's/\(symbol //; s/\) \(side Long\) \(score / /; s/\)//' | tr '\n' ',' ; echo; echo
  for s in ADMA GLNG CVNA CMG CRM LAD APPS; do echo "## $s: screen outcomes per seed (date outcome)"
    for k in $KS; do printf "k%s: " "$k"; awk -v S="$s" '/\(date 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\) \(total_stocks/{match($0,/date 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/); d=substr($0,RSTART+5,10)}
      index($0,"(symbol " S ") (side Long) (outcome"){o=$0; sub(/.*\(outcome /,"",o); gsub(/[()]/,"",o); printf "%s %s; ",d,o}' "$RAW/rk-k$k-s0-trade_audit.sexp" | cut -c1-400; echo; done; echo; done
  echo "## first NAV divergence, every pair (equity_curve.csv)"
  for a in $KS; do for b in $KS; do [ "$a" -lt "$b" ] || continue
    paste -d, "$R/rk-k$a-s0-equity_curve.csv" "$R/rk-k$b-s0-equity_curve.csv" | awk -F, -v a=$a -v b=$b 'NR>1&&$2!=$4{print "k"a" vs k"b": "$1; f=1; exit} END{if(!f) print "k"a" vs k"b": never"}'; done; done
  for k in $KS; do paste -d, "$V3/v3266-Mpre3339-s0-equity_curve.csv" "$R/rk-k$k-s0-equity_curve.csv" | awk -F, -v k=$k 'NR>1&&$2!=$4{print "M vs k"k": "$1; exit}'; done
} > "$O/tie-cut-traces.txt"

# 6. A->Z bias: first-letter mix of filled trades, seeds vs Alphabetical M and N.
{
  printf "%-22s %5s %7s %7s\n" cell n A_pct AF_pct
  for f in "$R"/rk-k[0-4]-s0-trades.csv "$V3/v3266-Mpre3339-s0-trades.csv" "$OLD"/N-rb1-26-s[0-2]-v12-trades.csv; do
    awk -F, -v c="$(basename "$f" -trades.csv)" 'NR>1{x=substr($1,1,1); n++; if(x=="A")A++; if(x<="F")F++} END{printf "%-22s %5d %6.1f%% %6.1f%%\n",c,n,100*A/n,100*F/n}' "$f"; done
} > "$O/letter-mix.txt"

# 7. Validator invariant counts (V6/V7/V12/V13/V16), seeds vs N vs M.
for f in "$R"/rk-k[0-4]-s0-validator.sexp.md "$OLD"/N-rb1-26-s[0-2]-v12-validator.sexp.md "$V3/v3266-Mpre3339-s0-validator.sexp.md"; do
  printf "%-20s" "$(basename "$f" -validator.sexp.md)"; for v in V6 V7 V12 V13 V16; do printf " %s=%s" "$v" "$(grep -E "^$v (INVARIANT|EXPECTATION)" "$f" | head -1 | sed -E "s/^$v (INVARIANT|EXPECTATION) //; s/ \(share-class.*//; s/ violations/v/; s/ /_/g")"; done; echo
done > "$O/validator-counts.txt"

# 8. Pack checks: faithfulness grades on each run's own evidence and k0 regraded without checks 1 and 13 (no stage replay
#    for k1-k4); missed-winner capture replica (index.html missedWinners); gate-reopen entries/returns per seed.
{
  for k in $KS; do printf "k%s grades %s; check1 known %s; check13 known %s\n" "$k" "$(jq -c .grades "$P/k${k}_faithfulness.json")" "$(jq '.failures[0].known' "$P/k${k}_faithfulness.json")" "$(jq '.failures[12].known' "$P/k${k}_faithfulness.json")"; done
  printf "k0 regraded without checks 1 and 13: "
  jq -r '.rows[] | [.possible, .earned, ([.checks[]|select(.id==13)|.status][0]), ([.checks[]|select(.id==1)|.status][0])] | @tsv' "$P/k0_faithfulness.json" |
    awk -F'\t' '{p=$1; e=$2; if($3=="pass"){p-=2; e-=2} else if($3=="fail") p-=2; if($4=="fail") p-=2; s=(p>0)?100*e/p:-1; g=(s<0)?"n/a":(s>=90?"A":(s>=80?"B":(s>=70?"C":(s>=60?"D":"F")))); c[g]++} END{printf "A %d B %d C %d D %d F %d n/a %d\n",c["A"],c["B"],c["C"],c["D"],c["F"],c["n/a"]}'
  echo
  for k in $KS; do printf "k%s missed-winner capture: " "$k"
    jq -r --slurpfile tr "$P/k${k}_trades.json" --slurpfile op "$P/k${k}_open.json" '
      ([$tr[0][]|select(.side!="SHORT")|{sym,ed,xd,pct}] + [$op[0].rows[]|{sym,ed,xd:"9999-12-31",pct:null}]) as $pos
      | ($pos|group_by(.sym)|map({key:.[0].sym,value:.})|from_entries) as $by
      | [.episodes[] | . as $e | (($by[$e.sym]//[])|map(select(.ed<=$e.peak and .xd>=$e.d))) as $h
         | if ($h|length)==0 then "unowned" else ([$h[]|(.pct//0)]|max) as $g
           | if $g>=($e.forward/2) then "rode" elif (([$h[]|select(.xd=="9999-12-31")]|length)>0 or $g>0) then "partial" else "cut" end end]
      | group_by(.)|map("\(.[0])=\(length)")|join(" ")' "$P/k${k}_missed.json"; done
  jq -r '[.episodes[]|((.peak[0:4]|tonumber)-(.d[0:4]|tonumber))]|sort|"signal-to-peak years: p25 \(.[length/4|floor]) median \(.[length/2|floor]) p75 \(.[3*length/4|floor])"' "$P/k0_missed.json"
  jq -r '[.episodes[]|.forward]|sort|"forward return %: p25 \(.[length/4|floor]|floor) median \(.[length/2|floor]|floor) p75 \(.[3*length/4|floor]|floor)"' "$P/k0_missed.json"
  echo
  for d in 2009-05-01 2010-08-06 2025-05-30; do for k in $KS; do awk -F, -v d=$d -v k=$k '
    function jd(s, y,m,dd,a,yy,mm){y=substr(s,1,4)+0; m=substr(s,6,2)+0; dd=substr(s,9,2)+0; a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3; return dd+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045}
    FNR==NR{if(FNR>1){n++; D[n]=$1; V[n]=$2} next} FNR>1{e=jd($3)-jd(d); if(e>0&&e<=91) c13++; if(e>0&&e<=182) c26++}
    END{t0=jd(d); for(i=1;i<=n;i++){if(jd(D[i])<=t0) a=i; if(jd(D[i])<=t0+182) b=i} printf "reopen %s k%d entries 13w=%d 26w=%d strategy 26w %+.1f%%\n",d,k,c13,c26,100*(V[b]/V[a]-1)}' "$R/rk-k$k-s0-equity_curve.csv" "$R/rk-k$k-s0-trades.csv"; done; done
} > "$O/pack-checks.txt"


# 9. Gate 1 and gate 2 over the whole window: weeks the top-N cap binds (grade-admitted > top-N), and the outcome mix of
#    the recorded admitted decisions (decisions are "at most" the top-N by contract, audit_recorder.mli).
for k in $KS; do awk -v k=$k '
  /\(date 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\) \(total_stocks/{ if(on) emit(); on=1; g=-1; t=-1; ns=0; pl=0; ic=0; oth=0 }
  on && /long_grade_admitted/{ match($0,/long_grade_admitted [0-9]+/); g=substr($0,RSTART+20,RLENGTH-20)+0 }
  on && /long_top_n_admitted/{ match($0,/long_top_n_admitted [0-9]+/); t=substr($0,RSTART+20,RLENGTH-20)+0 }
  on && /\(side Long\) \(outcome/{ if($0~/No_structural_stop/) ns++; else if($0~/Placed/) pl++; else if($0~/Insufficient_cash/) ic++; else oth++ }
  function emit(){ if(t>0){ W++; if(g>t) cap++; NS+=ns; PL+=pl; IC+=ic; OT+=oth } }
  END{ if(on) emit(); D=NS+PL+IC+OT; printf "k%d screens with a long top-N %d; cap binds %d; recorded decisions %d: No_structural_stop %.1f%%, Placed %.1f%%, Insufficient_cash %.1f%%, other %.1f%%\n",k,W,cap,D,100*NS/D,100*PL/D,100*IC/D,100*OT/D }' "$RAW/rk-k$k-s0-trade_audit.sexp"; done > "$O/gates.txt"
echo "wrote $O/{yearly,overlap,tail-weights,regime-split,tie-cut-traces,letter-mix,validator-counts,pack-checks,gates}.txt"
