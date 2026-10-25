#!/bin/sh
# path-stability-2026-10-23 results read: reproducible extracts behind README §Results.
# Usage: sh ps-analysis.sh <results-dir> <raw-sweep-dir> <review-pack-root> <out-dir>
#   results-dir     per-cell *-trades.csv, *-actual.sexp, *-open_positions.csv, *-cash_rejections.csv
#   raw-sweep-dir   per-cell *-trade_audit.sexp (.sweep-output/path-stability)
#   review-pack-root  .sweep-output (holds review-ps-<arm>-p0/site/data/{p0_nav,spy,spy_warmup}.json)
#   out-dir         where the four extracts are written
# POSIX sh + awk only. regime.awk must sit next to this script.
set -eu
R=$1; RAW=$2; P=$3; O=$4
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$O"
ARMS="A S SR SC"; KS="0 1 2 3 4 5"

# 1. Tail decomposition: realised total-return P&L (pnl_dollars + dividends_received) of the
#    three tail trades, the rest, end unrealised P&L (actual.sexp), per cell.
{
  printf "%-6s %7s %6s %8s %8s %8s %8s %8s %9s\n" cell lnR trades ADMA_k APPS_k GLNG_k rest_k unrl_k nav_k
  for a in $ARMS; do for k in $KS; do c=$a-p$k
    tr=$(grep -oE 'total_return_pct [-0-9.e]+' "$R/ps-$c-s0-actual.sexp" | awk '{print $2}')
    un=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$R/ps-$c-s0-actual.sexp" | awk '{print $2}')
    awk -F, -v c="$c" -v tr="$tr" -v un="$un" 'NR>1{p=$9+$25; if($1=="ADMA")ad+=p; else if($1=="APPS")ap+=p; else if($1=="GLNG")gl+=p; else rest+=p; n++}
      END{printf "%-6s %7.4f %6d %8.0f %8.0f %8.0f %8.0f %8.0f %9.0f\n", c, log(1+tr/100), n, ad/1000, ap/1000, gl/1000, rest/1000, un/1000, (1+tr/100)*1000}' "$R/ps-$c-s0-trades.csv"
  done; done
  echo
  echo "# paired trade join per seed (symbol|entry_date), realised TR P&L in \$k; dUnrl = arm minus S end unrealised"
  for a in SR SC; do
    printf "%-3s %-3s %6s %9s %9s %7s %9s %9s %7s %7s %9s\n" arm k shared S_shr arm_shr q_ratio S_only arm_only nSonly narmonly dUnrl
    for k in $KS; do
      uS=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$R/ps-S-p$k-s0-actual.sexp" | awk '{print $2}')
      uA=$(grep -oE 'unrealized_pnl [-0-9.e]+' "$R/ps-$a-p$k-s0-actual.sexp" | awk '{print $2}')
      awk -F, -v a="$a" -v k="$k" -v uS="$uS" -v uA="$uA" 'FNR==1{fi++; next}
        fi==1{key=$1"|"$3; s[key]+=$9+$25; sq[key]+=$8; next}
        {key=$1"|"$3; c[key]+=$9+$25; cq[key]+=$8}
        END{for(x in s){ if(x in c){ns++; S1+=s[x]; C1+=c[x]; r+=cq[x]/sq[x]} else {so+=s[x]; nso++} }
            for(x in c) if(!(x in s)){co+=c[x]; nco++}
            printf "%-3s %-3s %6d %9.0f %9.0f %7.2f %9.0f %9.0f %7d %7d %9.0f\n", a, k, ns, S1/1000, C1/1000, r/ns, so/1000, co/1000, nso, nco, (uA-uS)/1000}' \
        "$R/ps-S-p$k-s0-trades.csv" "$R/ps-$a-p$k-s0-trades.csv"
    done
  done
} > "$O/tail-decomposition.txt"

# 2. Tie-cut traces: the top-N admitted list and each name's outcome, for the three decision weeks
#    that decide ADMA / GLNG / APPS, in every cell; then each cell's admitted-slot outcomes, all weeks.
{
  for d in 2020-06-12 2022-02-04 2023-08-18; do
    echo "## decision $d (admitted top-N in screen order; x = Skipped No_structural_stop)"
    for a in $ARMS; do for k in $KS; do c=$a-p$k
      blk=$(awk -v d="$d" 'index($0,"(date " d ") (total_stocks"){f=1} f && /\(date 20[0-9-]+\) \(total_stocks/ && !index($0,d){exit} f' "$RAW/ps-$c-s0-trade_audit.sexp")
      cnt=$(printf '%s\n' "$blk" | head -8 | grep -oE '\((total_stocks|candidates_after_held|long_grade_admitted|long_top_n_admitted|entered) [0-9]+\)' | sed -E 's/[()]//g; s/long_//; s/_admitted//; s/candidates_after_held/after_held/; s/total_stocks/stocks/; s/ /=/' | tr '\n' ' ')
      printf "%-6s [%s] " "$c" "$cnt"
      printf '%s\n' "$blk" | grep -oE '\(symbol [A-Z_.]+\) \(side Long\) \(outcome [A-Za-z_( ]+' |
        sed -E 's/\(side Long\) \(outcome //; s/\(symbol //; s/\)//g; s/\(Skipped No_structural_stop/x/; s/Skipped //; s/ +$//' | tr '\n' ',' ; echo
    done; done; echo
  done
  echo "## scores of the names ADMA's A-p0 entry record lists as alternatives (decision 2023-08-18; ADMA itself scores 95)"
  awk '/\(symbol ADMA\) \(entry_date 2023-08-18\)/{f=1} f&&/\(exit_date|\(\(symbol [A-Z]+\) \(entry_date 20/&&!/ADMA/{exit} f' "$RAW/ps-A-p0-s0-trade_audit.sexp" |
    grep -oE '\(symbol [A-Z_.]+\) \(side Long\) \(score [0-9]+\)|cascade_score [0-9]+' | sed -E 's/\(symbol //; s/\) \(side Long\) \(score / /; s/\)//' | tr '\n' ',' ; echo; echo
  echo "## admitted-slot outcomes over all weeks (graded > admitted = cap binds)"
  printf "%-6s %5s %5s %6s %6s %6s %6s %6s %6s\n" cell weeks binds slots no_ss placed ins_cash other ge19x
  for a in $ARMS; do for k in $KS; do c=$a-p$k
    awk -v c="$c" '
      /\(date 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\) \(total_stocks/{ if(on) emit(); on=1; g=-1; t=-1; ns=0; pl=0; ic=0; oth=0 }
      on && /long_grade_admitted/{ match($0,/long_grade_admitted [0-9]+/); g=substr($0,RSTART+20,RLENGTH-20)+0 }
      on && /long_top_n_admitted/{ match($0,/long_top_n_admitted [0-9]+/); t=substr($0,RSTART+20,RLENGTH-20)+0 }
      on && /\(side Long\) \(outcome/{ if($0~/No_structural_stop/) ns++; else if($0~/Placed/) pl++; else if($0~/Insufficient_cash/) ic++; else oth++ }
      function emit(){ if(t>0){ W++; if(g>t) cap++; TT+=t; NS+=ns; PL+=pl; IC+=ic; OT+=oth; if(ns>=t-1 && g>t) hard++ } }
      END{ if(on) emit(); printf "%-6s %5d %5d %6d %6d %6d %6d %6d %6d\n", c, W, cap, TT, NS, PL, IC, OT, hard }' "$RAW/ps-$c-s0-trade_audit.sexp"
  done; done
} > "$O/tie-cut-traces.txt"

# 3. A->Z bias: first-letter mix of filled trades, per cell and against the scheduled-list union.
{
  printf "%-6s %5s %7s %7s %7s\n" cell n A_pct AF_pct AM_pct
  for a in $ARMS; do for k in $KS; do c=$a-p$k
    awk -F, -v c="$c" 'NR>1{x=substr($1,1,1); n++; if(x=="A")A++; if(x<="F")F++; if(x<="M")M++}
      END{printf "%-6s %5d %6.1f%% %6.1f%% %6.1f%%\n", c, n, 100*A/n, 100*F/n, 100*M/n}' "$R/ps-$c-s0-trades.csv"
  done; done
} > "$O/letter-mix.txt"

# 4. Exposure and return by SPY regime and period, p0 cells, replicating the pack's regime rule
#    (weekly close vs 30-week MA and its 4-week slope, known at the prior week's close; TR basis).
j2l() { tr -d '[]"' < "$1" | tr '\n' ' ' | sed 's/ //g' | awk -v n="$2" -F, '{for(i=1;i<=NF;i+=n){s=$i; for(k=1;k<n;k++) s=s","$(i+k); print s}}'; }
T=$(mktemp -d)
j2l "$P/review-ps-A-p0/site/data/spy_warmup.json" 3 > "$T/spy_warm.csv"
j2l "$P/review-ps-A-p0/site/data/spy.json" 2 > "$T/spy.csv"
for a in $ARMS; do j2l "$P/review-ps-$a-p0/site/data/p0_nav.json" 4 > "$T/nav_$a.csv"; done
(cd "$T" && awk -f "$HERE/regime.awk" spy_warm.csv spy.csv nav_A.csv nav_S.csv nav_SR.csv nav_SC.csv) > "$O/regime-split.txt"
rm -rf "$T"
echo "wrote $O/{tail-decomposition,tie-cut-traces,letter-mix,regime-split}.txt"
