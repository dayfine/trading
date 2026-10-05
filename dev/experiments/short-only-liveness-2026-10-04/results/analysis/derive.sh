#!/bin/sh
# Derivations behind results-2026-10-05.md (short-only Phase A). Read-only.
#
# usage: sh derive.sh <results-dir> <bars-root> [arm ...]
#   results-dir: dev/experiments/short-only-liveness-2026-10-04/results
#                (needs <arm>-5d-s0-v11-{trades.csv,open_positions.csv,equity_curve.csv,
#                 macro_trend.sexp,actual.sexp,summary.sexp,trade_audit.sexp})
#   bars-root:   the host CSV store, <root>/<first letter>/<last letter>/<SYM>/data.csv
#   arms:        default "soT soTs"
#
# Prints, per arm:
#   1. entries by screen week (latest macro_trend row <= fill date), trades + open positions,
#      and every non-Bearish entry traced through the trade audit;
#   2. the P&L split: A sub-$17 fills (#3131), B tier-crossing margin calls, C stale tickets
#      (filled in a non-Bearish week), E the rest, plus open positions and costs;
#   3. costs: residual (final - initial - realised - unrealised), commission and borrow estimates;
#   4. the SPY-regime split by period (review-pack regime definition, full SPY history);
#   5. short-semantics stop check (bar HIGH >= live stop before the exit day).
set -eu
R=$1; DATA=$2; shift 2
ARMS=${*:-"soT soTs"}
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d "${TMPDIR:-/tmp}/derive.XXXXXX"); trap 'rm -rf "$T"' EXIT
bars() { printf '%s/%s/%s/%s/data.csv' "$DATA" "$(printf %s "$1" | cut -c1)" "$(printf %s "$1" | rev | cut -c1)" "$1"; }

for a in $ARMS; do
  P="$R/$a-5d-s0-v11"
  echo "=================== $a"
  awk -f "$HERE/audit_extract.awk" "$P-trade_audit.sexp" > "$T/audit.tsv"
  sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\).*/\1 \2/p' "$P-macro_trend.sexp" > "$T/macro.txt"

  echo "--- 1. entries by screen week (trades.csv + open_positions.csv)"
  { tail -n +2 "$P-trades.csv" | awk -F, '{print $3, $1, "closed", $20}'
    tail -n +2 "$P-open_positions.csv" | awk -F, '{print $3, $1, "open", "-"}'; } | sort > "$T/entries.txt"
  awk 'NR==FNR{d[NR]=$1; t[NR]=$2; n=NR; next}
       { tr="NONE"; for (i=1;i<=n;i++) { if (d[i] <= $1) tr=t[i]; else break } print $0, tr }' \
      "$T/macro.txt" "$T/entries.txt" > "$T/entries_tr.txt"
  awk '{c[$5]++; c[$3" "$5]++} END{for (k in c) print "  " k, c[k]}' "$T/entries_tr.txt" | sort
  # first non-Bearish macro row after each placement = the week the screen left Bearish
  awk '$5!="Bearish" && $3=="closed" {print $4, $1, $2, $5}' "$T/entries_tr.txt" | while read -r pid fd sym tr; do
    awk -F'\t' -v p="$pid" '$1==p{print $9, $10}' "$T/audit.tsv" | { read -r plc age
      left=$(awk -v p="$plc" '$1>p && $2!="Bearish"{print $1; exit}' "$T/macro.txt")
      # calendar days via the Julian day number (no date(1), no DST)
      days=$(awk -v a="$left" -v b="$fd" 'function j(s,  y,m,d,q){y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0
        q=int((14-m)/12); y=y+4800-q; m=m+12*q-3; return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045}
        BEGIN{print j(b)-j(a)}')
      pnl=$(awk -F, -v p="$pid" '$20==p{print $9}' "$P-trades.csv")
      echo "  $sym placed $plc (Bearish), age at fill ${age} wk, screen left Bearish $left, filled $fd ($tr week, +${days} d), pnl $pnl"; }
  done

  echo "--- 2. P&L split (closed trades; A/B/C/E) + open positions"
  awk '/\(external_exit/{x=1} /\(execution/{x=0}
       x && match($0,/\(position_id [^)]*\)/){pid=substr($0,RSTART+13,RLENGTH-14)}
       x && /\(label margin_call\)/{print pid}' "$P-trade_audit.sexp" | sort -u > "$T/mc_audit.txt"
  awk 'NR==FNR{d[NR]=$1; t[NR]=$2; n=NR; next} FNR>1{split($0,f,","); tr="NONE"
       for (i=1;i<=n;i++) { if (d[i] <= f[3]) tr=t[i]; else break } print f[20] "\t" tr }' \
      "$T/macro.txt" "$P-trades.csv" > "$T/filltr.tsv"
  awk -F'\t' -v OFS='\t' 'FILENAME ~ /mc_audit/ {mc[$1]=1; next} FILENAME ~ /filltr/ {ft[$1]=$2; next}
       FNR>1 { split($0,f,","); pid=f[20]; b="E_rest"
         if (f[6] < 17) b="A_sub17_fill"; else if (pid in mc) b="B_tier_cross_mc"; else if (ft[pid] != "Bearish") b="C_stale_nonBearish"
         print pid, f[1], f[3], f[4], f[6], f[7], f[9], f[13], b, f[10], f[5] }' \
      "$T/mc_audit.txt" "$T/filltr.tsv" "$P-trades.csv" > "$T/buckets.tsv"
  awk -F'\t' '{n[$9]++; p[$9]+=$7; if ($7>0) w[$9]++} END{for (k in n) printf "  %-20s n=%3d win=%3d pnl=%10.0f\n", k, n[k], w[k], p[k]}' "$T/buckets.tsv" | sort
  awk -F'\t' '{y=substr($3,1,4); k=y" "$9; n[k]++; p[k]+=$7} END{for (k in n) printf "  %s n=%d pnl=%.0f\n", k, n[k], p[k]}' "$T/buckets.tsv" | sort
  echo "  open positions, unrealised at the last equity_curve date (raw close):"
  last=$(tail -1 "$P-equity_curve.csv" | cut -d, -f1)
  tail -n +2 "$P-open_positions.csv" | while IFS=, read -r sym _side ed ep q; do
    c=$(awk -F, -v d="$last" '$1==d{print $5}' "$(bars "$sym")")
    awk -v s="$sym" -v ed="$ed" -v ep="$ep" -v q="$q" -v c="$c" 'BEGIN{printf "    %-9s %s %s x %s mark %s -> %.0f\n", s, ed, ep, q, c, (ep-c)*q}'
  done
  echo "  clean-trade return distribution (pnl_percent, E_rest):"
  awk -F'\t' '$9=="E_rest"{print $10}' "$T/buckets.tsv" | sort -g | awk '{v[NR]=$1; s+=$1} END{n=NR
    printf "    n=%d mean=%.2f p10=%.2f p25=%.2f med=%.2f p75=%.2f p90=%.2f max=%.2f\n", n, s/n, v[int(0.1*(n-1))+1], v[int(0.25*(n-1))+1], v[int(0.5*(n-1))+1], v[int(0.75*(n-1))+1], v[int(0.9*(n-1))+1], v[n]}'

  echo "--- 3. costs"
  fin=$(sed -nE 's/.*\(final_portfolio_value ([-0-9.]+)\).*/\1/p' "$P-summary.sexp")
  ini=$(sed -nE 's/.*\(initial_cash ([-0-9.]+)\).*/\1/p' "$P-summary.sexp")
  rea=$(sed -nE 's/.*totalpnl ([-0-9.]+)\).*/\1/p' "$P-summary.sexp")
  unr=$(sed -nE 's/.*\(unrealized_pnl ([-0-9.e]+)\).*/\1/p' "$P-actual.sexp")
  awk -v f="$fin" -v i="$ini" -v r="$rea" -v u="$unr" 'BEGIN{printf "  residual (final - initial - realised - unrealised) = %.0f\n", f-i-r-u}'
  awk -F, 'NR>1{c=$8*0.01; if (c<1) c=1; s+=2*c} END{printf "  commission estimate, closed (2 sides, $0.01/sh, $1 min) = %.0f\n", s}' "$P-trades.csv"
  awk -F, 'NR>1{c=$5*0.01; if (c<1) c=1; s+=c} END{printf "  commission estimate, open (entry side) = %.0f\n", s}' "$P-open_positions.csv"
  { tail -n +2 "$P-trades.csv" | awk -F, '{print $1","$8","$3","$4}'
    tail -n +2 "$P-open_positions.csv" | awk -F, '{print $1","$5","$3",9999-12-31"}'; } |
  while IFS=, read -r sym q ed xd; do
    awk -F, -v s="$sym" -v q="$q" -v ed="$ed" -v xd="$xd" -v last="$last" \
      'NR>1 && $1>=ed && $1<xd && $1<=last { c=$5+0; r=(c<5?1.00:(c<17?0.25:0.005)); fee+=q*c*r/252; mv=q*c; print $1 "\t" mv > "/dev/stderr" }
       END{printf "%s\t%s\t%.2f\n", s, ed, fee}' "$(bars "$sym")"
  done 2> "$T/mv_raw.tsv" > "$T/borrow.tsv"
  awk -F'\t' '{s+=$3} END{printf "  borrow estimate (tiers 0.5%%/25%%/100%% at >=17 / <17 / <5) = %.0f\n", s}' "$T/borrow.tsv"
  sort -t "$(printf '\t')" -k3,3gr "$T/borrow.tsv" | head -3 | awk -F'\t' '{printf "    top: %s %s %.0f\n", $1, $2, $3}'

  echo "--- 4. SPY regime split by period (strategy NAV, SPY, mean short exposure incl. open positions)"
  awk -F'\t' '{mv[$1]+=$2} END{for (d in mv) printf "%s\t%.2f\n", d, mv[d]}' "$T/mv_raw.tsv" > "$T/mv.tsv"
  awk -f "$HERE/regime.awk" "$(bars SPY)" "$P-equity_curve.csv" "$T/mv.tsv" | sort

  echo "--- 5. short-semantics stop check"
  awk '/\(stop_decisions/{s=1} /\(cascade_summaries/{exit}
       s && match($0,/\(\(date [0-9-]+\) \(position_id [^)]*\)/){ x=substr($0,RSTART,RLENGTH)
         match(x,/date [0-9-]+/); d=substr(x,RSTART+5,RLENGTH-5); match(x,/position_id [^)]*/); p=substr(x,RSTART+12,RLENGTH-12)
         getline a; getline b; t=$0 a b; if (match(t,/\(stop_after [0-9.]+\)/)) print p "\t" d "\t" substr(t,RSTART+12,RLENGTH-13) }' \
      "$P-trade_audit.sexp" > "$T/stopdec.tsv"
  sh "$HERE/short_late.sh" "$P-trades.csv" "$T/stopdec.tsv" "$DATA" | awk -F'\t' '{n++; if ($6!="-") late++; if ($9>0) lb++}
    END{printf "  stop_loss exits %d: breached (high >= live stop) before the exit day: %d; long test (low <= stop) would flag: %d\n", n, late, lb}'
  awk -F, 'NR>1 && $13=="stop_loss"{n++; if ($12>0 && ($7-$12)/$12>0.005) up++} END{printf "  stop exits filled > 0.5%% ABOVE the stop: %d of %d\n", up, n}' "$P-trades.csv"

  echo "--- 6. why: give-back, regime at fill, perturbations, costs by bucket"
  # 6a. open gains at the NAV peak vs what those positions finally realised
  pk=$(awk -F, 'NR>1{v=$2+0; if (v>m){m=v; d=$1}} END{print d}' "$P-equity_curve.csv")
  { tail -n +2 "$P-trades.csv" | awk -F, -v pd="$pk" '$3<=pd && $4>pd {print $1","$8","$6","$9}'
    tail -n +2 "$P-open_positions.csv" | awk -F, -v pd="$pk" '$3<=pd {print $1","$5","$4",OPEN"}'; } |
  while IFS=, read -r sym q ep pnl; do
    c=$(awk -F, -v pd="$pk" 'NR>1 && $1<=pd {c=$5} END{print c}' "$(bars "$sym")")
    echo "$sym $q $ep $c $pnl"
  done | awk -v pd="$pk" '{u=($3-$4)*$2; tu+=u; if ($5!="OPEN") tp+=$5; s=s " " $1}
    END{printf "  NAV peak %s: open shorts%s carry %.0f unrealised; the closed ones finally realised %.0f\n", pd, s, tu, tp}'
  # 6b. favourable excursion (audit exit_ records) vs realised, rest bucket
  awk '/\(exit_ *$/{x=1} /\(execution/{x=0} x && match($0,/\(position_id [^)]*\)/){pid=substr($0,RSTART+13,RLENGTH-14)}
       x && match($0,/\(max_favorable_excursion_pct [-0-9.e]+\)/){print pid "\t" substr($0,RSTART+29,RLENGTH-30)*100}' \
      "$P-trade_audit.sexp" > "$T/mfe.tsv"
  awk -F'\t' 'NR==FNR{m[$1]=$2; next} $9=="E_rest" && ($1 in m) && m[$1]>=20 {n++; sm+=m[$1]; sr+=$10; if ($10 < m[$1]*0.5) gb++}
    END{printf "  rest trades with favourable excursion >= 20%%: n=%d mean MFE %.1f%% mean realised %.1f%%; realised < half of MFE: %d\n", n, sm/n, sr/n, gb}' \
    "$T/mfe.tsv" "$T/buckets.tsv"
  # 6c. rest-bucket P&L by SPY regime at the fill date, with the top trade removed
  awk -F, -f "$HERE/spy_regime_map.awk" "$(bars SPY)" > "$T/regmap.tsv"
  awk -F'\t' 'NR==FNR{r[$1]=$2; next} $9=="E_rest"{g=r[$3]; n[g]++; p[g]+=$7; if (!(g in mx) || $7>mx[g]) {mx[g]=$7; ms[g]=$2}}
    END{for (g in n) printf "  rest entries in %-5s regime: n=%d pnl=%.0f, top %s %.0f, ex-top %.0f\n", g, n[g], p[g], ms[g], mx[g], p[g]-mx[g]}' \
    "$T/regmap.tsv" "$T/buckets.tsv" | sort
  # 6d. sub-$17 bucket under other thresholds / the decision-close basis
  for t in 15 16 18 19; do awk -F'\t' -v t="$t" '$5<t{n++; p+=$7} END{printf "  fill < $%s: n=%d pnl=%.0f\n", t, n, p}' "$T/buckets.tsv"; done
  awk -F'\t' 'NR==FNR{c[$1]=$6; next} c[$1]<17 {n++; p+=$7} END{printf "  decision close < $17: n=%d pnl=%.0f\n", n, p}' "$T/audit.tsv" "$T/buckets.tsv"
  awk -F'\t' 'NR==FNR{a[$1]=$10; next} a[$1]>=4 {n++; p+=$7} END{printf "  tickets rested >= 4 weeks: n=%d pnl=%.0f\n", n, p}' "$T/audit.tsv" "$T/buckets.tsv"
  awk -F'\t' '$9=="E_rest" && substr($3,1,4)=="2008" {p+=$7; if (mn=="" || $7<mn) {mn=$7; ms=$2" "$3}}
    END{printf "  rest 2008 entries: pnl=%.0f; without the largest loser (%s %.0f): %.0f\n", p, ms, mn, p-mn}' "$T/buckets.tsv"
  awk -F'\t' '$9=="E_rest"{print $7}' "$T/buckets.tsv" | sort -g | awk '{v[NR]=$1; s+=$1} END{x=v[1]+v[2]+v[3]+v[4]
    printf "  rest closed pnl=%.0f; without the four largest losers (%.0f): %.0f\n", s, x, s-x}'
  printf '  alternatives skipped for Short_notional_cap (audit alternatives_considered): %s\n' \
    "$(grep -c 'reason_skipped Short_notional_cap' "$P-trade_audit.sexp")"
  # 6e. estimated costs by bucket (borrow from section 3, commission $0.01/sh both sides)
  awk -F'\t' 'FILENAME ~ /borrow/ {b[$1 "|" $2]=$3; next}
    { k=$2 "|" $3; c=$11 + 0; bo[$9]+=b[k]; seen[k]=1 }
    END{ for (k in b) if (!(k in seen)) bo["open"]+=b[k]; for (g in bo) printf "  borrow estimate %-20s %.0f\n", g, bo[g] }' \
    "$T/borrow.tsv" "$T/buckets.tsv" | sort
  awk -F, 'NR==FNR{if (FNR>1) q[$20]=$8; next} {split($0,f,"\t"); c=q[f[1]]*0.01; if (c<1) c=1; cm[f[9]]+=2*c}
    END{for (g in cm) printf "  commission estimate %-20s %.0f\n", g, cm[g]}' "$P-trades.csv" "$T/buckets.tsv" | sort

  echo "--- 7. other quoted figures"
  awk -F'\t' '{k[$8]++} END{for (x in k) printf "  audited tickets by stop_floor_kind: %s %d\n", x, k[x]}' "$T/audit.tsv" | sort
  awk -F, 'NR>1{print ($11/$6-1)*100}' "$P-trades.csv" | sort -g | awk '{v[NR]=$1} END{n=NR
    printf "  installed stop above fill (%%): n=%d p10=%.1f med=%.1f p90=%.1f max=%.1f\n", n, v[int(0.1*(n-1))+1], v[int(0.5*(n-1))+1], v[int(0.9*(n-1))+1], v[n]}'
  awk -F, 'NR>1{print $16*100}' "$P-trades.csv" | sort -g | awk '{v[NR]=$1} END{printf "  trades.csv stop_initial_distance_pct median (base-top basis): %.1f%%\n", v[int(0.5*(NR-1))+1]}'
  awk -F'\t' 'NR==FNR{mv[$1]=$2; next} FNR>1{split($0,b,","); y=substr(b[1],1,4); x=100*mv[b[1]]/b[2]; s[y]+=x; n[y]++; S+=x; N++}
    END{for (y in s) printf "  mean short exposure %s: %.1f%%\n", y, s[y]/n[y]; printf "  mean short exposure whole window: %.1f%%\n", S/N}' \
    "$T/mv.tsv" "$P-equity_curve.csv" | sort
  awk -F, 'NR>1{v=$2+0; if (v>pk){pk=v; pd=$1}; dd=1-v/pk; if (dd>m){m=dd; a=pd; av=pk; b=$1; bv=v}}
    END{printf "  max drawdown %.2f%%: peak %s (%.0f) -> trough %s (%.0f)\n", 100*m, a, av, b, bv}' "$P-equity_curve.csv"
  awk -F, 'NR>1{y=substr($1,1,4); if (y!=py && py!="") {printf "  NAV %s: %+.2f%%\n", py, 100*(last/base-1); base=last} if (py=="") base=$2; py=y; last=$2}
    END{printf "  NAV %s: %+.2f%%\n", py, 100*(last/base-1)}' "$P-equity_curve.csv"
  awk -F'\t' '$9=="A_sub17_fill"{print $10}' "$T/buckets.tsv" | sort -g | awk '{v[NR]=$1; s+=$1} END{n=NR
    printf "  bucket A pnl%%: n=%d mean=%.2f p10=%.2f med=%.2f p90=%.2f\n", n, s/n, v[int(0.1*(n-1))+1], v[int(0.5*(n-1))+1], v[int(0.9*(n-1))+1]}'
  awk -F'\t' '$9=="A_sub17_fill"{print $11}' "$T/buckets.tsv" | sort -n | awk '{v[NR]=$1} END{printf "  bucket A days held: median=%s max=%s\n", v[int((NR+1)/2)], v[NR]}'
  awk -F'\t' 'NR==FNR{r[$1]=$2; next} $9=="E_rest"{print r[$3] "\t" $10}' "$T/regmap.tsv" "$T/buckets.tsv" | sort -t "$(printf '\t')" -k1,1 -k2,2g |
    awk -F'\t' '{g[$1]=g[$1] " " $2; n[$1]++} END{for (k in g) { split(substr(g[k],2), v, " "); printf "  rest entries in %-5s regime: median pnl%% %s\n", k, v[int((n[k]+1)/2)] }}' | sort
done
F=$(bars SPY)
awk -F, -v e="$(tail -1 "$R/$(echo "$ARMS" | cut -d' ' -f1)-5d-s0-v11-equity_curve.csv" | cut -d, -f1)" \
  '$1=="2008-12-31"{a=$6} $1==e{b=$6} END{printf "SPY 2008-12-31 -> %s: %+.1f%%\n", e, 100*(b/a-1)}' "$F"
